const Fastify = require('fastify');
const cors = require('@fastify/cors');
const jwt = require('@fastify/jwt');
const path = require('path');
const fs = require('fs');
const Database = require('better-sqlite3');
const { DB_PATH, WEB_APP_ROOT, JWT_SECRET } = require('./config');

// ===== DB 연결 설정 (D드라이브) =====
const NO_STORE_HEADERS = {
  'Cache-Control': 'no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0',
  Pragma: 'no-cache',
  Expires: '0',
  'Surrogate-Control': 'no-store',
};

function applyNoStoreHeaders(target) {
  for (const [key, value] of Object.entries(NO_STORE_HEADERS)) {
    if (typeof target.header === 'function') {
      target.header(key, value);
    } else {
      target.setHeader(key, value);
    }
  }
}

function removeCacheValidators(reply) {
  if (typeof reply.removeHeader === 'function') {
    reply.removeHeader('etag');
    reply.removeHeader('last-modified');
  }
  if (reply.raw && typeof reply.raw.removeHeader === 'function') {
    reply.raw.removeHeader('ETag');
    reply.raw.removeHeader('Last-Modified');
  }
}

const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL'); // 쓰기 성능 향상
db.pragma('foreign_keys = ON');

function hasTable(name) {
  return !!db.prepare(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?"
  ).get(name);
}

// 기존 DB 마이그레이션: ui_lang, study_lang 컬럼 추가
try {
  db.prepare("SELECT ui_lang FROM users LIMIT 1").get();
} catch {
  if (hasTable('users')) {
    db.exec("ALTER TABLE users ADD COLUMN ui_lang TEXT DEFAULT 'ko'");
    db.exec("ALTER TABLE users ADD COLUMN study_lang TEXT DEFAULT 'ENG'");
    console.log('[Migration] users 테이블에 ui_lang, study_lang 컬럼 추가 완료');
  }
}

// 기존 DB 마이그레이션: daily_day_quota 컬럼 추가
try {
  db.prepare("SELECT daily_day_quota FROM users LIMIT 1").get();
} catch {
  if (hasTable('users')) {
    db.exec("ALTER TABLE users ADD COLUMN daily_day_quota INTEGER DEFAULT 1");
    console.log('[Migration] users 테이블에 daily_day_quota 컬럼 추가 완료');
  }
}

try {
  db.prepare("SELECT pos FROM vocabulary LIMIT 1").get();
} catch {
  if (hasTable('vocabulary')) {
    db.exec("ALTER TABLE vocabulary ADD COLUMN pos TEXT");
    console.log('[Migration] vocabulary pos column added');
  }
}

// 테이블 초기화 (데이터 보존을 위해 IF NOT EXISTS 사용)
db.exec(`
  CREATE TABLE IF NOT EXISTS users (
    user_id TEXT PRIMARY KEY,
    password TEXT NOT NULL,
    user_name TEXT NOT NULL,
    daily_quota INTEGER DEFAULT 20,
    daily_day_quota INTEGER DEFAULT 1,
    ui_lang TEXT DEFAULT 'ko',
    study_lang TEXT DEFAULT 'ENG',
    created_at TEXT DEFAULT (datetime('now','localtime'))
  );

  CREATE TABLE IF NOT EXISTS vocabulary (
    word_id INTEGER PRIMARY KEY AUTOINCREMENT,
    language_type TEXT DEFAULT 'ENG',
    theme TEXT,
    day_index TEXT,
    pos TEXT,
    spell TEXT NOT NULL,
    meaning TEXT NOT NULL
  );

  CREATE TABLE IF NOT EXISTS user_progress (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id TEXT NOT NULL,
    word_id INTEGER NOT NULL,
    is_correct INTEGER DEFAULT 0,
    studied_at TEXT DEFAULT (datetime('now','localtime')),        
    FOREIGN KEY (user_id) REFERENCES users(user_id),
    FOREIGN KEY (word_id) REFERENCES vocabulary(word_id),
    UNIQUE(user_id, word_id, studied_at)
  );
`);

// ===== Fastify 설정 =====
const app = Fastify({ logger: true });

// CORS 설정 (모바일 및 웹 접속 허용)
app.register(cors, { origin: true });

// ngrok 인터스티셜 우회: 모든 응답에 헤더 추가
app.addHook('onRequest', async (request, reply) => {
  // ngrok 무료 플랜의 브라우저 경고 페이지 우회
  reply.header('ngrok-skip-browser-warning', 'true');
});

// Gzip 압축 (웹 빌드 대역폭 절약)
// WASM 파일은 iOS Safari에서 gzip 디코딩 문제가 있어 제외
app.register(require('@fastify/compress'), {
  global: true,
  encodings: ['gzip', 'deflate'],
  requestEncodings: ['gzip', 'deflate'],
  forceRequestEncoding: undefined,
  customTypes: /^(?!application\/wasm)/,
});

// Flutter 웹 캐시 전략:
// - index.html, flutter_bootstrap.js → no-cache (빌드마다 변경됨)
// - main.dart.js, canvaskit 등 → 캐시 허용 (빌드 해시로 구분됨)
const NO_CACHE_FILES = new Set(['index.html', 'flutter_bootstrap.js', 'flutter_service_worker.js']);
app.addHook('onSend', async (request, reply, payload) => {
  if (request.raw.url.startsWith('/app/')) {
    const fileName = request.raw.url.split('/').pop().split('?')[0];
    if (!fileName || NO_CACHE_FILES.has(fileName) || request.raw.url === '/app/' || request.raw.url === '/app') {
      applyNoStoreHeaders(reply);
      removeCacheValidators(reply);
    }
  }
  return payload;
});

// JWT 인증 설정
app.register(jwt, { secret: JWT_SECRET });

// 인증 데코레이터 등록
app.decorate('authenticate', async (request, reply) => {
  try {
    await request.jwtVerify();
  } catch (err) {
    reply.status(401).send({ error: '인증이 필요합니다.' });
  }
});

// DB 인스턴스 전역 등록
app.decorate('db', db);

// Static 파일 서빙 (관리자 대시보드)
app.register(require('@fastify/static'), {
  root: path.join(__dirname, '..', 'public'),
  prefix: '/admin/',
});

// Static 파일 서빙 (Flutter 웹 앱 - 데모/테스트용)
app.register(require('@fastify/static'), {
  root: WEB_APP_ROOT,
  prefix: '/app/',
  decorateReply: false,
  // 불변 에셋(js, wasm)은 캐시 허용, index.html은 onSend 훅에서 no-cache 적용
  maxAge: 3600000, // 1시간
  immutable: false,
});

// ===== 라우트 등록 =====
app.get('/', async () => ({ status: 'ok', message: '스마트 어학 학습 API 서버 정상 동작 중 ✅' }));
app.register(require('./routes/auth'));
app.register(require('./routes/vocab'));
app.register(require('./routes/progress'));
app.register(require('./routes/update'));
app.register(require('./routes/ai'));
app.register(require('./routes/admin'));

// Flutter 웹 SPA 라우팅 지원: /app/* 경로에서 파일이 없으면 index.html 반환
app.setNotFoundHandler((request, reply) => {
  if (request.raw.url.startsWith('/app/')) {
    const indexPath = path.join(WEB_APP_ROOT, 'index.html');
    applyNoStoreHeaders(reply);
    reply.type('text/html').send(fs.readFileSync(indexPath));
  } else {
    reply.status(404).send({ error: 'Not found' });
  }
});

// ===== 서버 시작 =====
const start = async () => {
  try {
    const port = Number(process.env.PORT || 3000);
    const host = process.env.HOST || '0.0.0.0';
    await app.listen({ port, host });
    console.log('\n=========================================');
    console.log(' Smart Vocab API Server Started!');
    console.log(` URL:  http://localhost:${port}`);
    console.log(' DB:   ' + DB_PATH);
    console.log('=========================================');
  } catch (err) {
    app.log.error(err);
    process.exit(1);
  }
};

start();
