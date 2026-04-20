async function progressRoutes(fastify) {
  const db = fastify.db;
  const toLocalTimestamp = (offsetMs = 0) => {
    const d = new Date(Date.now() + offsetMs);
    const pad2 = (n) => String(n).padStart(2, '0');
    const pad3 = (n) => String(n).padStart(3, '0');
    return `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())} ` +
      `${pad2(d.getHours())}:${pad2(d.getMinutes())}:${pad2(d.getSeconds())}.${pad3(d.getMilliseconds())}`;
  };

  // 학습 결과 기록
  fastify.post('/api/progress/record', {
    preHandler: [fastify.authenticate]
  }, async (request) => {
    const { wordId, isCorrect } = request.body;
    const userId = request.user.userId;

    const insert = db.prepare(`
      INSERT INTO user_progress (user_id, word_id, is_correct, studied_at)
      VALUES (?, ?, ?, ?)
    `);
    let inserted = false;
    let lastError = null;
    for (let i = 0; i < 5; i += 1) {
      try {
        insert.run(userId, wordId, isCorrect ? 1 : 0, toLocalTimestamp(i));
        inserted = true;
        break;
      } catch (e) {
        lastError = e;
      }
    }
    if (!inserted && lastError) {
      throw lastError;
    }

    return { success: true };
  });

  // 오늘의 학습 진행률
  fastify.get('/api/progress/today', {
    preHandler: [fastify.authenticate]
  }, async (request) => {
    const userId = request.user.userId;
    const lang = request.query?.lang || null;
    const params = [userId];
    let langFilter = '';
    if (lang) {
      langFilter = ' AND v.language_type = ?';
      params.push(lang);
    }

    const result = db.prepare(`
      SELECT
        COUNT(DISTINCT p.word_id) as studied_count,
        SUM(p.is_correct) as correct_count,
        COUNT(*) as total_attempts,
        COUNT(DISTINCT v.day_index) as studied_day_count
      FROM user_progress p
      JOIN vocabulary v ON v.word_id = p.word_id
      WHERE p.user_id = ?
        AND DATE(p.studied_at) = DATE('now','localtime')
        ${langFilter}
    `).get(...params);

    const unresolvedWrong = db.prepare(`
      SELECT COUNT(*) as cnt
      FROM (
        SELECT p.word_id
        FROM user_progress p
        JOIN vocabulary v ON v.word_id = p.word_id
        WHERE p.user_id = ?
          AND DATE(p.studied_at) = DATE('now','localtime')
          ${langFilter}
        GROUP BY p.word_id
        HAVING SUM(CASE WHEN p.is_correct = 1 THEN 1 ELSE 0 END) = 0
           AND SUM(CASE WHEN p.is_correct = 0 THEN 1 ELSE 0 END) > 0
      )
    `).get(...params).cnt;

    const user = db.prepare(
      'SELECT daily_quota, daily_day_quota FROM users WHERE user_id = ?'
    ).get(userId);
    const dailyQuota = user?.daily_quota || 20;
    const dailyDayQuota = user?.daily_day_quota || 1;
    const studiedCount = result.studied_count || 0;
    const studiedDayCount = result.studied_day_count || 0;

    return {
      studiedCount,
      correctCount: result.correct_count || 0,
      totalAttempts: result.total_attempts || 0,
      studiedDayCount,
      unresolvedWrongCount: unresolvedWrong || 0,
      dailyQuota,
      dailyDayQuota,
      wordRemaining: Math.max(0, dailyQuota - studiedCount),
      dayRemaining: Math.max(0, dailyDayQuota - studiedDayCount),
      accuracy: result.total_attempts > 0
        ? Math.round((result.correct_count / result.total_attempts) * 100)
        : 0
    };
  });

  // 복습 목록
  fastify.get('/api/progress/review', {
    preHandler: [fastify.authenticate]
  }, async (request) => {
    const userId = request.user.userId;
    const lang = request.query?.lang || 'ENG';
    const scope = request.query?.scope || 'all'; // all | today
    const limit = Math.max(10, Math.min(500, Number(request.query?.limit) || 200));

    const scopeFilter = scope === 'today'
      ? "AND DATE(p.studied_at) = DATE('now','localtime')"
      : '';

    return db.prepare(`
      SELECT
        v.word_id,
        v.spell,
        v.meaning,
        v.day_index,
        v.theme,
        MAX(p.studied_at) as last_studied_at,
        SUM(CASE WHEN p.is_correct = 1 THEN 1 ELSE 0 END) as correct_count,
        COUNT(*) as attempt_count
      FROM user_progress p
      JOIN vocabulary v ON v.word_id = p.word_id
      WHERE p.user_id = ?
        AND v.language_type = ?
        ${scopeFilter}
      GROUP BY v.word_id, v.spell, v.meaning, v.day_index, v.theme
      ORDER BY datetime(last_studied_at) DESC
      LIMIT ?
    `).all(userId, lang, limit);
  });

  // 전체 통계 (웹 대시보드용)
  fastify.get('/api/progress/stats', {
    preHandler: [fastify.authenticate]
  }, async (request) => {
    const userId = request.user.userId;

    // 전체 단어 수
    const totalWords = db.prepare('SELECT COUNT(*) as cnt FROM vocabulary').get().cnt;

    // 외운 단어 수 (3회 이상 정답)
    const memorized = db.prepare(`
      SELECT COUNT(DISTINCT word_id) as cnt FROM user_progress
      WHERE user_id = ? AND is_correct = 1
      GROUP BY word_id HAVING COUNT(*) >= 3
    `).all(userId).length;

    // 전체 정답률
    const overall = db.prepare(`
      SELECT
        SUM(is_correct) as correct,
        COUNT(*) as total
      FROM user_progress WHERE user_id = ?
    `).get(userId);

    // 연속 학습일
    const streakRows = db.prepare(`
      SELECT DISTINCT DATE(studied_at) as study_date
      FROM user_progress WHERE user_id = ?
      ORDER BY study_date DESC
    `).all(userId);

    let streak = 0;
    const today = new Date();
    for (let i = 0; i < streakRows.length; i++) {
      const d = new Date(streakRows[i].study_date);
      const expected = new Date(today);
      expected.setDate(expected.getDate() - i);
      if (d.toDateString() === expected.toDateString()) {
        streak++;
      } else break;
    }

    // Day별 진행률
    const dayProgress = db.prepare(`
      SELECT
        v.day_index,
        v.theme,
        COUNT(DISTINCT v.word_id) as total_words,
        COUNT(DISTINCT p.word_id) as studied_words
      FROM vocabulary v
      LEFT JOIN user_progress p ON v.word_id = p.word_id AND p.user_id = ? AND p.is_correct = 1
      WHERE v.language_type = 'ENG'
      GROUP BY v.day_index, v.theme
      ORDER BY CAST(REPLACE(v.day_index, 'DAY ', '') AS INTEGER)
    `).all(userId);

    // 최근 7일 학습량
    const weeklyData = db.prepare(`
      SELECT DATE(studied_at) as date, COUNT(*) as count
      FROM user_progress WHERE user_id = ?
        AND studied_at >= datetime('now', '-7 days', 'localtime')
      GROUP BY DATE(studied_at)
      ORDER BY date
    `).all(userId);

    return {
      totalWords,
      memorizedWords: memorized,
      streak,
      accuracy: overall.total > 0 ? Math.round((overall.correct / overall.total) * 100) : 0,
      dayProgress,
      weeklyData
    };
  });
}

module.exports = progressRoutes;
