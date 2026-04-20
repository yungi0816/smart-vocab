const bcrypt = require('bcryptjs');

async function authRoutes(fastify) {
  const db = fastify.db;
  const normalizeDailyQuota = (value, fallback = 20) => {
    const n = Number(value);
    if (!Number.isFinite(n)) return fallback;
    return Math.max(1, Math.min(500, Math.trunc(n)));
  };
  const normalizeDailyDayQuota = (value, fallback = 1) => {
    const n = Number(value);
    if (!Number.isFinite(n)) return fallback;
    return Math.max(1, Math.min(10, Math.trunc(n)));
  };

  // 회원가입
  fastify.post('/api/auth/signup', async (request, reply) => {
    const { userId, password, userName, dailyQuota, dailyDayQuota } =
      request.body || {};

    if (!userId || !password || !userName) {
      return reply.status(400).send({ error: '필수 항목을 입력해주세요.' });
    }

    const existing = db.prepare('SELECT user_id FROM users WHERE user_id = ?').get(userId);
    if (existing) {
      return reply.status(409).send({ error: '이미 존재하는 아이디입니다.' });
    }

    const hashed = bcrypt.hashSync(password, 10);
    const normalizedDailyQuota = normalizeDailyQuota(dailyQuota, 20);
    const normalizedDailyDayQuota = normalizeDailyDayQuota(dailyDayQuota, 1);
    db.prepare(
      'INSERT INTO users (user_id, password, user_name, daily_quota, daily_day_quota) VALUES (?, ?, ?, ?, ?)'
    ).run(
      userId,
      hashed,
      userName,
      normalizedDailyQuota,
      normalizedDailyDayQuota
    );

    const token = fastify.jwt.sign({ userId, userName });
    return {
      success: true,
      token,
      userName,
      dailyQuota: normalizedDailyQuota,
      dailyDayQuota: normalizedDailyDayQuota,
      uiLang: 'ko',
      studyLang: 'ENG',
    };
  });

  // 로그인
  fastify.post('/api/auth/login', async (request, reply) => {
    const { userId, password } = request.body;

    const user = db.prepare('SELECT * FROM users WHERE user_id = ?').get(userId);
    if (!user) {
      return reply.status(401).send({ error: '아이디 또는 비밀번호가 틀렸습니다.' });
    }

    const valid = bcrypt.compareSync(password, user.password);
    if (!valid) {
      return reply.status(401).send({ error: '아이디 또는 비밀번호가 틀렸습니다.' });
    }

    const token = fastify.jwt.sign({ userId: user.user_id, userName: user.user_name });
    return {
      success: true,
      token,
      userName: user.user_name,
      dailyQuota: user.daily_quota,
      dailyDayQuota: user.daily_day_quota || 1,
      uiLang: user.ui_lang || 'ko',
      studyLang: user.study_lang || 'ENG',
    };
  });

  // 내 정보 조회
  fastify.get('/api/auth/me', {
    preHandler: [fastify.authenticate]
  }, async (request) => {
    const user = db.prepare(
      'SELECT user_id, user_name, daily_quota, daily_day_quota, ui_lang, study_lang, created_at FROM users WHERE user_id = ?'
    ).get(request.user.userId);
    return user;
  });

  // 언어 설정 저장
  fastify.put('/api/auth/lang', {
    preHandler: [fastify.authenticate]
  }, async (request, reply) => {
    const { uiLang, studyLang } = request.body || {};
    const validUi = ['ko', 'ja'];
    const validStudy = ['ENG', 'JPN', 'ENG_JP', 'KOR_JP'];

    if (!validUi.includes(uiLang) || !validStudy.includes(studyLang)) {
      return reply.status(400).send({ error: 'Invalid language settings' });
    }

    db.prepare('UPDATE users SET ui_lang = ?, study_lang = ? WHERE user_id = ?')
      .run(uiLang, studyLang, request.user.userId);

    return { success: true, uiLang, studyLang };
  });

  // 학습 설정 저장
  fastify.put('/api/auth/settings', {
    preHandler: [fastify.authenticate]
  }, async (request) => {
    const { dailyQuota, dailyDayQuota } = request.body || {};
    const normalizedDailyQuota = normalizeDailyQuota(dailyQuota, 20);
    const normalizedDailyDayQuota = normalizeDailyDayQuota(dailyDayQuota, 1);

    db.prepare(
      'UPDATE users SET daily_quota = ?, daily_day_quota = ? WHERE user_id = ?'
    ).run(normalizedDailyQuota, normalizedDailyDayQuota, request.user.userId);

    return {
      success: true,
      dailyQuota: normalizedDailyQuota,
      dailyDayQuota: normalizedDailyDayQuota,
    };
  });
}

module.exports = authRoutes;
