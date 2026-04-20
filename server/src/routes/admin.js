/**
 * 관리자 API 라우트
 * - GET  /api/admin/dashboard    : 전체 통계
 * - GET  /api/admin/users        : 사용자 목록
 * - GET  /api/admin/users/:id    : 사용자 상세
 * - DELETE /api/admin/users/:id  : 사용자 삭제 (탈퇴)
 * - PUT  /api/admin/users/:id/quota : 일일 할당량 변경
 * - GET  /api/admin/words/stats  : 단어 통계
 *
 * 인증: 하드코딩 관리자 비밀번호 (x-admin-key 헤더)
 */

const ADMIN_KEY = process.env.ADMIN_KEY || 'dev-only-admin-key';

if (process.env.NODE_ENV === 'production' && !process.env.ADMIN_KEY) {
  throw new Error('ADMIN_KEY must be set in production.');
}

async function adminRoutes(fastify) {
  const db = fastify.db;

  // ===== 관리자 인증 미들웨어 =====
  const verifyAdmin = async (request, reply) => {
    const key = request.headers['x-admin-key'];
    if (key !== ADMIN_KEY) {
      return reply.status(403).send({ error: '관리자 인증 실패' });
    }
  };

  // ===== 관리자 로그인 =====
  fastify.post('/api/admin/login', async (request, reply) => {
    const { password } = request.body || {};
    if (password === ADMIN_KEY) {
      return { success: true };
    }
    return reply.status(401).send({ error: '비밀번호가 틀렸습니다.' });
  });

  // ===== 대시보드 통계 =====
  fastify.get('/api/admin/dashboard', {
    preHandler: [verifyAdmin],
  }, async () => {
    const totalUsers = db.prepare('SELECT COUNT(*) as cnt FROM users').get().cnt;
    const totalWords = db.prepare('SELECT COUNT(*) as cnt FROM vocabulary').get().cnt;
    const totalAttempts = db.prepare('SELECT COUNT(*) as cnt FROM user_progress').get().cnt;

    const todayAttempts = db.prepare(`
      SELECT COUNT(*) as cnt FROM user_progress
      WHERE DATE(studied_at) = DATE('now','localtime')
    `).get().cnt;

    const todayActiveUsers = db.prepare(`
      SELECT COUNT(DISTINCT user_id) as cnt FROM user_progress
      WHERE DATE(studied_at) = DATE('now','localtime')
    `).get().cnt;

    const overallAccuracy = db.prepare(`
      SELECT
        COALESCE(SUM(is_correct), 0) as correct,
        COUNT(*) as total
      FROM user_progress
    `).get();

    const recentSignups = db.prepare(`
      SELECT user_id, user_name, created_at FROM users
      ORDER BY created_at DESC LIMIT 5
    `).all();

    // 최근 7일간 학습 추이
    const weeklyTrend = db.prepare(`
      SELECT DATE(studied_at) as date,
             COUNT(*) as attempts,
             SUM(is_correct) as correct,
             COUNT(DISTINCT user_id) as active_users
      FROM user_progress
      WHERE DATE(studied_at) >= DATE('now','localtime','-6 days')
      GROUP BY DATE(studied_at)
      ORDER BY date
    `).all();

    return {
      totalUsers,
      totalWords,
      totalAttempts,
      todayAttempts,
      todayActiveUsers,
      overallAccuracy: overallAccuracy.total > 0
        ? Math.round((overallAccuracy.correct / overallAccuracy.total) * 100)
        : 0,
      recentSignups,
      weeklyTrend,
    };
  });

  // ===== 사용자 목록 =====
  fastify.get('/api/admin/users', {
    preHandler: [verifyAdmin],
  }, async (request) => {
    const { search } = request.query;

    let sql = `
      SELECT u.user_id, u.user_name, u.daily_quota, u.created_at,
             COUNT(p.id) as total_attempts,
             COALESCE(SUM(p.is_correct), 0) as correct_count,
             MAX(p.studied_at) as last_studied
      FROM users u
      LEFT JOIN user_progress p ON u.user_id = p.user_id
    `;
    const params = [];

    if (search) {
      sql += ' WHERE u.user_id LIKE ? OR u.user_name LIKE ?';
      params.push(`%${search}%`, `%${search}%`);
    }

    sql += ' GROUP BY u.user_id ORDER BY u.created_at DESC';

    return db.prepare(sql).all(...params);
  });

  // ===== 사용자 상세 =====
  fastify.get('/api/admin/users/:id', {
    preHandler: [verifyAdmin],
  }, async (request, reply) => {
    const { id } = request.params;

    const user = db.prepare(
      'SELECT user_id, user_name, daily_quota, created_at FROM users WHERE user_id = ?'
    ).get(id);

    if (!user) return reply.status(404).send({ error: '사용자를 찾을 수 없습니다.' });

    const stats = db.prepare(`
      SELECT COUNT(*) as total, COALESCE(SUM(is_correct), 0) as correct
      FROM user_progress WHERE user_id = ?
    `).get(id);

    const dailyHistory = db.prepare(`
      SELECT DATE(studied_at) as date,
             COUNT(*) as attempts,
             SUM(is_correct) as correct
      FROM user_progress
      WHERE user_id = ?
      GROUP BY DATE(studied_at)
      ORDER BY date DESC
      LIMIT 30
    `).all(id);

    return { ...user, ...stats, dailyHistory };
  });

  // ===== 사용자 삭제 (탈퇴) =====
  fastify.delete('/api/admin/users/:id', {
    preHandler: [verifyAdmin],
  }, async (request, reply) => {
    const { id } = request.params;

    const user = db.prepare('SELECT user_id FROM users WHERE user_id = ?').get(id);
    if (!user) return reply.status(404).send({ error: '사용자를 찾을 수 없습니다.' });

    // 학습 기록 먼저 삭제 (FK)
    db.prepare('DELETE FROM user_progress WHERE user_id = ?').run(id);
    db.prepare('DELETE FROM users WHERE user_id = ?').run(id);

    return { success: true, message: `${id} 사용자가 삭제되었습니다.` };
  });

  // ===== 일일 할당량 변경 =====
  fastify.put('/api/admin/users/:id/quota', {
    preHandler: [verifyAdmin],
  }, async (request, reply) => {
    const { id } = request.params;
    const { quota } = request.body || {};

    if (!quota || quota < 1 || quota > 200) {
      return reply.status(400).send({ error: '할당량은 1~200 사이여야 합니다.' });
    }

    const result = db.prepare('UPDATE users SET daily_quota = ? WHERE user_id = ?').run(quota, id);
    if (result.changes === 0) return reply.status(404).send({ error: '사용자를 찾을 수 없습니다.' });

    return { success: true, quota };
  });

  // ===== 단어 통계 =====
  fastify.get('/api/admin/words/stats', {
    preHandler: [verifyAdmin],
  }, async () => {
    const byDay = db.prepare(`
      SELECT day_index, theme, language_type, COUNT(*) as word_count
      FROM vocabulary
      GROUP BY day_index, theme, language_type
      ORDER BY language_type, CAST(REPLACE(day_index, 'DAY ', '') AS INTEGER)
    `).all();

    const hardestWords = db.prepare(`
      SELECT v.spell, v.meaning, v.day_index,
             COUNT(p.id) as attempts,
             COALESCE(SUM(p.is_correct), 0) as correct,
             ROUND(CAST(COALESCE(SUM(p.is_correct), 0) AS REAL) / COUNT(p.id) * 100) as accuracy
      FROM vocabulary v
      JOIN user_progress p ON v.word_id = p.word_id
      GROUP BY v.word_id
      HAVING COUNT(p.id) >= 3
      ORDER BY accuracy ASC
      LIMIT 20
    `).all();

    return { byDay, hardestWords };
  });
}

module.exports = adminRoutes;
