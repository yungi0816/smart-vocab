function normalizeText(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

function toNgrams(value) {
  const normalized = normalizeText(value);
  if (!normalized) {
    return new Set();
  }

  const chars = Array.from(normalized);
  if (chars.length <= 2) {
    return new Set([normalized]);
  }

  const grams = new Set();
  for (let i = 0; i < chars.length - 1; i += 1) {
    grams.add(`${chars[i]}${chars[i + 1]}`);
  }
  return grams;
}

function similarityScore(a, b) {
  const aSet = toNgrams(a);
  const bSet = toNgrams(b);
  if (aSet.size === 0 || bSet.size === 0) {
    return 0;
  }

  let intersection = 0;
  for (const token of aSet) {
    if (bSet.has(token)) {
      intersection += 1;
    }
  }
  const union = aSet.size + bSet.size - intersection;
  return union > 0 ? intersection / union : 0;
}

function shuffle(items) {
  const copied = [...items];
  for (let i = copied.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [copied[i], copied[j]] = [copied[j], copied[i]];
  }
  return copied;
}

function uniqueByWordId(rows) {
  const seen = new Set();
  const result = [];
  for (const row of rows) {
    if (seen.has(row.word_id)) {
      continue;
    }
    seen.add(row.word_id);
    result.push(row);
  }
  return result;
}

function labelForQuizType(word, quizType) {
  return quizType === 'SPELL_TO_MEANING' ? word.meaning : word.spell;
}

function toBoolean(value) {
  if (typeof value === 'boolean') return value;
  const normalized = String(value || '').toLowerCase();
  return normalized === '1' || normalized === 'true' || normalized === 'yes';
}

function buildKorJpWrongChoices(db, correctWord, quizType) {
  const labelField = quizType === 'SPELL_TO_MEANING' ? 'meaning' : 'spell';
  const targetLabel = normalizeText(correctWord[labelField]);

  const sameTheme = db.prepare(`
    SELECT word_id, spell, meaning, theme, day_index
    FROM vocabulary
    WHERE language_type = 'KOR_JP'
      AND word_id != ?
      AND day_index = ?
      AND theme = ?
  `).all(correctWord.word_id, correctWord.day_index, correctWord.theme);

  const sameDay = db.prepare(`
    SELECT word_id, spell, meaning, theme, day_index
    FROM vocabulary
    WHERE language_type = 'KOR_JP'
      AND word_id != ?
      AND day_index = ?
  `).all(correctWord.word_id, correctWord.day_index);

  const globalPool = db.prepare(`
    SELECT word_id, spell, meaning, theme, day_index
    FROM vocabulary
    WHERE language_type = 'KOR_JP'
      AND word_id != ?
  `).all(correctWord.word_id);

  const mergedPool = uniqueByWordId([
    ...sameTheme,
    ...sameDay,
    ...shuffle(globalPool).slice(0, 400),
  ]);

  const scored = mergedPool
    .map((candidate) => ({
      ...candidate,
      score: similarityScore(candidate[labelField], correctWord[labelField]),
      sameTheme: candidate.theme === correctWord.theme ? 1 : 0,
    }))
    .filter((candidate) => {
      const label = normalizeText(candidate[labelField]);
      return label && label !== targetLabel;
    })
    .sort((a, b) => {
      if (b.sameTheme !== a.sameTheme) {
        return b.sameTheme - a.sameTheme;
      }
      if (b.score !== a.score) {
        return b.score - a.score;
      }
      return Math.random() - 0.5;
    });

  const top10 = [];
  const seenLabels = new Set();
  for (const candidate of scored) {
    const label = normalizeText(candidate[labelField]);
    if (seenLabels.has(label)) {
      continue;
    }
    seenLabels.add(label);
    top10.push(candidate);
    if (top10.length >= 10) {
      break;
    }
  }

  const primary = shuffle(top10).slice(0, 3);
  if (primary.length >= 3) {
    return primary;
  }

  const existingIds = new Set(primary.map((item) => item.word_id));
  for (const candidate of scored) {
    if (existingIds.has(candidate.word_id)) {
      continue;
    }
    primary.push(candidate);
    existingIds.add(candidate.word_id);
    if (primary.length >= 3) {
      break;
    }
  }

  return primary;
}

function buildDefaultWrongChoices(db, lang, correctWord) {
  return db.prepare(`
    SELECT word_id, spell, meaning
    FROM vocabulary
    WHERE language_type = ?
      AND word_id != ?
    ORDER BY RANDOM()
    LIMIT 3
  `).all(lang, correctWord.word_id);
}

async function vocabRoutes(fastify) {
  const db = fastify.db;

  fastify.get('/api/vocab/days', async (request) => {
    const { lang } = request.query;
    let sql = `
      SELECT day_index, theme, COUNT(*) as word_count, language_type
      FROM vocabulary
    `;
    const params = [];

    if (lang) {
      sql += ' WHERE language_type = ?';
      params.push(lang);
    }

    sql += `
      GROUP BY day_index, theme, language_type
      ORDER BY
        CASE
          WHEN day_index LIKE 'DAY %' THEN 0
          WHEN day_index LIKE 'TOPIK %' THEN 1
          ELSE 2
        END,
        CASE
          WHEN day_index LIKE 'DAY %' THEN CAST(REPLACE(day_index, 'DAY ', '') AS INTEGER)
          WHEN day_index LIKE 'TOPIK %' THEN CAST(REPLACE(day_index, 'TOPIK ', '') AS INTEGER)
          ELSE 9999
        END,
        day_index,
        theme
    `;

    return db.prepare(sql).all(...params);
  });

  fastify.get('/api/vocab/words', async (request) => {
    const { day, lang, theme } = request.query;
    let sql = 'SELECT * FROM vocabulary WHERE 1=1';
    const params = [];

    if (day) {
      sql += ' AND day_index = ?';
      params.push(day);
    }
    if (theme) {
      sql += ' AND theme = ?';
      params.push(theme);
    }
    if (lang) {
      sql += ' AND language_type = ?';
      params.push(lang);
    }
    sql += ' ORDER BY word_id';

    return db.prepare(sql).all(...params);
  });

  fastify.get('/api/vocab/quiz', {
    preHandler: [fastify.authenticate],
  }, async (request) => {
    const {
      lang = 'ENG',
      day,
      theme,
      pos,
      allowExtra,
      focusMode,
    } = request.query || {};
    const userId = request.user.userId;
    const selectedDay = day && day !== 'ALL' ? day : null;
    const selectedTheme = theme && theme !== 'ALL' ? theme : null;
    const isCustomScope = !!(selectedDay || selectedTheme);
    const allowExtraNewWords = toBoolean(allowExtra);
    const useFocusMode = toBoolean(focusMode);
    const userSettings = db.prepare(
      'SELECT daily_quota, daily_day_quota FROM users WHERE user_id = ?'
    ).get(userId);
    const dailyQuota = userSettings?.daily_quota || 20;
    const dailyDayQuota = userSettings?.daily_day_quota || 1;

    const todaySummary = db.prepare(`
      SELECT
        COUNT(DISTINCT p.word_id) as studied_count,
        COUNT(DISTINCT v.day_index) as studied_day_count
      FROM user_progress p
      JOIN vocabulary v ON v.word_id = p.word_id
      WHERE p.user_id = ?
        AND v.language_type = ?
        AND DATE(p.studied_at) = DATE('now','localtime')
    `).get(userId, lang);
    const studiedCount = todaySummary?.studied_count || 0;
    const studiedDayCount = todaySummary?.studied_day_count || 0;

    const unresolvedWrongRows = db.prepare(`
      SELECT v.*
      FROM user_progress p
      JOIN vocabulary v ON v.word_id = p.word_id
      WHERE p.user_id = ?
        AND v.language_type = ?
        AND DATE(p.studied_at) = DATE('now','localtime')
      GROUP BY v.word_id
      HAVING SUM(CASE WHEN p.is_correct = 1 THEN 1 ELSE 0 END) = 0
         AND SUM(CASE WHEN p.is_correct = 0 THEN 1 ELSE 0 END) > 0
      ORDER BY MAX(p.studied_at) DESC
    `).all(userId, lang);
    const unresolvedWrongCount = unresolvedWrongRows.length;

    const scopeParts = ['v.language_type = ?'];
    const scopeParams = [lang];
    if (selectedDay) {
      scopeParts.push('v.day_index = ?');
      scopeParams.push(selectedDay);
    }
    if (selectedTheme) {
      scopeParts.push('v.theme = ?');
      scopeParams.push(selectedTheme);
    }
    if (pos && pos !== 'ALL') {
      scopeParts.push('v.pos = ?');
      scopeParams.push(pos);
    }
    const scopeWhere = scopeParts.join(' AND ');

    const sessionInfo = {
      dailyQuota,
      dailyDayQuota,
      studiedCount,
      studiedDayCount,
      wordRemaining: Math.max(0, dailyQuota - studiedCount),
      dayRemaining: Math.max(0, dailyDayQuota - studiedDayCount),
      unresolvedWrongCount,
      stage: useFocusMode ? 'focus_review' : (isCustomScope ? 'custom' : 'daily_new'),
    };

    const noCustomScopeAndQuotaReached =
      !useFocusMode && !isCustomScope && studiedCount >= dailyQuota;

    if (
      noCustomScopeAndQuotaReached &&
      !allowExtraNewWords &&
      unresolvedWrongCount <= 0
    ) {
      return {
        status: 'quota_completed',
        message:
          '오늘 목표 단어를 완료했습니다. 복습을 하거나 신규 단어 학습을 이어갈 수 있어요.',
        session: {
          ...sessionInfo,
          stage: 'quota_completed',
          canContinueNewWords: true,
        },
        scope: {
          day: selectedDay,
          theme: selectedTheme,
        },
      };
    }

    let correctWord;

    if (useFocusMode) {
      const weakRows = db.prepare(`
        SELECT
          v.*,
          SUM(CASE WHEN p.is_correct = 0 THEN 1 ELSE 0 END) as wrong_count,
          SUM(CASE WHEN p.is_correct = 1 THEN 1 ELSE 0 END) as correct_count,
          COUNT(*) as attempt_count,
          MAX(p.studied_at) as last_studied_at
        FROM user_progress p
        JOIN vocabulary v ON v.word_id = p.word_id
        WHERE p.user_id = ?
          AND ${scopeWhere}
        GROUP BY v.word_id
        HAVING SUM(CASE WHEN p.is_correct = 0 THEN 1 ELSE 0 END) > 0
           AND SUM(CASE WHEN p.is_correct = 1 THEN 1 ELSE 0 END) < 3
        ORDER BY
          (SUM(CASE WHEN p.is_correct = 0 THEN 1 ELSE 0 END) * 2)
            - SUM(CASE WHEN p.is_correct = 1 THEN 1 ELSE 0 END) DESC,
          COUNT(*) DESC,
          RANDOM()
        LIMIT 20
      `).all(userId, ...scopeParams);

      correctWord = shuffle(weakRows)[0];
      sessionInfo.stage = 'focus_review';
      sessionInfo.focusCount = weakRows.length;
    }

    // 목표 달성 이후에는 오답 단어부터 재퀴즈
    if (
      noCustomScopeAndQuotaReached &&
      !allowExtraNewWords &&
      unresolvedWrongCount > 0
    ) {
      const shuffledWrong = shuffle(unresolvedWrongRows);
      correctWord = shuffledWrong[0];
      sessionInfo.stage = 'wrong_review';
    }

    // 오늘 목표 채우는 중에는 오늘 처음 보는 단어를 우선 제공
    if (!correctWord && !isCustomScope && studiedCount < dailyQuota) {
      const studiedDayRows = db.prepare(`
        SELECT DISTINCT v.day_index
        FROM user_progress p
        JOIN vocabulary v ON v.word_id = p.word_id
        WHERE p.user_id = ?
          AND v.language_type = ?
          AND DATE(p.studied_at) = DATE('now','localtime')
      `).all(userId, lang);
      const studiedDayIndexes = studiedDayRows.map((row) => row.day_index);

      const pickNewWord = (enforceNewDay) => {
        const extraDayFilter = enforceNewDay && studiedDayIndexes.length > 0
          ? ` AND v.day_index NOT IN (${studiedDayIndexes.map(() => '?').join(', ')})`
          : '';
        const extraDayParams = enforceNewDay ? studiedDayIndexes : [];
        return db.prepare(`
          SELECT v.*
          FROM vocabulary v
          LEFT JOIN (
            SELECT DISTINCT p.word_id
            FROM user_progress p
            JOIN vocabulary vv ON vv.word_id = p.word_id
            WHERE p.user_id = ?
              AND vv.language_type = ?
              AND DATE(p.studied_at) = DATE('now','localtime')
          ) today_words ON today_words.word_id = v.word_id
          LEFT JOIN (
            SELECT word_id
            FROM user_progress
            WHERE user_id = ? AND is_correct = 1
            GROUP BY word_id
            HAVING COUNT(*) >= 3
          ) mastered ON mastered.word_id = v.word_id
          WHERE ${scopeWhere}
            AND today_words.word_id IS NULL
            AND mastered.word_id IS NULL
            ${extraDayFilter}
          ORDER BY RANDOM()
          LIMIT 1
        `).get(
          userId,
          lang,
          userId,
          ...scopeParams,
          ...extraDayParams
        );
      };

      const shouldSpreadAcrossDays = studiedDayCount < dailyDayQuota;
      correctWord = pickNewWord(shouldSpreadAcrossDays);
      if (!correctWord && shouldSpreadAcrossDays) {
        correctWord = pickNewWord(false);
      }
      sessionInfo.stage = 'daily_new';
    }

    // 사용자 지정 범위 또는 초과 학습(allowExtra)에서는 범위 내 신규 단어 우선
    if (!correctWord && (isCustomScope || allowExtraNewWords)) {
      correctWord = db.prepare(`
        SELECT v.*
        FROM vocabulary v
        LEFT JOIN (
          SELECT DISTINCT p.word_id
          FROM user_progress p
          JOIN vocabulary vv ON vv.word_id = p.word_id
          WHERE p.user_id = ?
            AND vv.language_type = ?
            AND DATE(p.studied_at) = DATE('now','localtime')
        ) today_words ON today_words.word_id = v.word_id
        WHERE ${scopeWhere}
          AND today_words.word_id IS NULL
        ORDER BY RANDOM()
        LIMIT 1
      `).get(userId, lang, ...scopeParams);
      sessionInfo.stage =
        allowExtraNewWords && !isCustomScope ? 'extra_new' : 'custom';
    }

    // 신규 단어가 없으면 범위 내 미완전 단어(3회 정답 미만)를 제공
    if (!correctWord) {
      correctWord = db.prepare(`
        SELECT v.*
        FROM vocabulary v
        LEFT JOIN (
          SELECT word_id
          FROM user_progress
          WHERE user_id = ? AND is_correct = 1
          GROUP BY word_id
          HAVING COUNT(*) >= 3
        ) mastered ON mastered.word_id = v.word_id
        WHERE ${scopeWhere}
          AND mastered.word_id IS NULL
        ORDER BY RANDOM()
        LIMIT 1
      `).get(userId, ...scopeParams);
    }

    // 모든 단어를 거의 다 본 경우 최후 fallback
    if (!correctWord) {
      correctWord = db.prepare(`
        SELECT v.*
        FROM vocabulary v
        WHERE ${scopeWhere}
        ORDER BY RANDOM()
        LIMIT 1
      `).get(...scopeParams);
    }

    if (!correctWord) {
      return { error: 'No vocabulary is available.' };
    }

    const quizType = Math.random() > 0.5 ? 'SPELL_TO_MEANING' : 'MEANING_TO_SPELL';

    const wrongChoices = lang === 'KOR_JP'
      ? buildKorJpWrongChoices(db, correctWord, quizType)
      : buildDefaultWrongChoices(db, lang, correctWord);

    const rawChoices = [
      ...wrongChoices,
      {
        word_id: correctWord.word_id,
        spell: correctWord.spell,
        meaning: correctWord.meaning,
      },
    ];

    const finalChoices = [];
    const seenLabels = new Set();
    for (const choice of shuffle(rawChoices)) {
      const label = normalizeText(labelForQuizType(choice, quizType));
      if (!label || seenLabels.has(label)) {
        continue;
      }
      finalChoices.push(choice);
      seenLabels.add(label);
    }

    if (finalChoices.length < 4) {
      const fallback = db.prepare(`
        SELECT word_id, spell, meaning
        FROM vocabulary
        WHERE language_type = ?
          AND word_id != ?
        ORDER BY RANDOM()
        LIMIT 50
      `).all(lang, correctWord.word_id);

      for (const choice of fallback) {
        const label = normalizeText(labelForQuizType(choice, quizType));
        if (!label || seenLabels.has(label)) {
          continue;
        }
        finalChoices.push(choice);
        seenLabels.add(label);
        if (finalChoices.length >= 4) {
          break;
        }
      }
    }

    const choices = shuffle(finalChoices).slice(0, 4);

    return {
      status: 'ok',
      correctWordId: correctWord.word_id,
      question: quizType === 'SPELL_TO_MEANING' ? correctWord.spell : correctWord.meaning,
      quizType,
      theme: correctWord.theme,
      dayIndex: correctWord.day_index,
      session: sessionInfo,
      scope: {
        day: selectedDay,
        theme: selectedTheme,
      },
      choices: choices.map((choice) => ({
        wordId: choice.word_id,
        label: labelForQuizType(choice, quizType),
      })),
    };
  });

  fastify.get('/api/vocab/search', async (request) => {
    const { q, lang = 'ENG' } = request.query;
    if (!q) {
      return [];
    }
    return db.prepare(`
      SELECT * FROM vocabulary
      WHERE language_type = ? AND (spell LIKE ? OR meaning LIKE ?)
      ORDER BY word_id
      LIMIT 50
    `).all(lang, `%${q}%`, `%${q}%`);
  });
}

module.exports = vocabRoutes;
