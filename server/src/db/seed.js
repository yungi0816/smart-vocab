/**
 * 토익.json 데이터를 SQLite DB에 적재하는 시드 스크립트
 * 실행 방법: npm run seed
 */
const Database = require('better-sqlite3');
const fs = require('fs');
const path = require('path');
const { DB_PATH } = require('../config');

// ===== 설정 =====
const JSON_PATH = path.join(__dirname, '..', '..', '..', '토익.json');

console.log('--- 데이터 마이그레이션 시작 ---');
console.log('원본 JSON 파일:', JSON_PATH);
console.log('대상 DB 파일:', DB_PATH);

if (!fs.existsSync(JSON_PATH)) {
  console.error('오류: 토익.json 파일을 찾을 수 없습니다.');
  process.exit(1);
}

const db = new Database(DB_PATH);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

// 테이블이 없으면 생성 (index.js와 동일한 구조)
db.exec(`
  CREATE TABLE IF NOT EXISTS vocabulary (
    word_id INTEGER PRIMARY KEY AUTOINCREMENT,
    language_type TEXT DEFAULT 'ENG',
    theme TEXT,
    day_index TEXT,
    pos TEXT,
    spell TEXT NOT NULL,
    meaning TEXT NOT NULL
  );
`);

// 기존 단어 데이터 삭제 (초기화)
console.log('기존 단어 데이터를 삭제합니다...');
db.exec('DELETE FROM vocabulary');

// JSON 읽기
const raw = fs.readFileSync(JSON_PATH, 'utf-8');
const data = JSON.parse(raw);

// INSERT 문 준비
const insert = db.prepare(
  'INSERT INTO vocabulary (language_type, theme, day_index, spell, meaning) VALUES (?, ?, ?, ?, ?)'
);

// 트랜잭션 실행
const insertMany = db.transaction((entries) => {
  for (const entry of entries) {
    insert.run(entry.lang, entry.theme, entry.day, entry.spell, entry.meaning);
  }
});

// 데이터 정규화
const entries = [];
for (const [dayKey, dayObj] of Object.entries(data)) {
  const theme = dayObj.theme;
  const words = dayObj.words;
  for (const [spell, meaning] of Object.entries(words)) {
    entries.push({
      lang: 'ENG',
      theme,
      day: dayKey,
      spell,
      meaning
    });
  }
}

// DB에 저장
insertMany(entries);

console.log(`성공적으로 ${entries.length}개의 단어를 DB에 저장했습니다!`);

// 간단한 통계 출력
console.log('\n--- Day별 저장 현황 ---');
const stats = db.prepare(
  'SELECT day_index, theme, COUNT(*) as cnt FROM vocabulary GROUP BY day_index'
).all();

stats.forEach(s => {
  console.log(`- ${s.day_index} (${s.theme}): ${s.cnt}개`);
});

db.close();
console.log('\n--- 마이그레이션 완료 ---');
