/**
 * Apply audited TOPIK Korean -> Japanese meaning and spelling fixes in-place.
 *
 * Usage:
 *   node src/db/fix_topik_meanings.js
 */

const Database = require('better-sqlite3');
const {
  getTopikMeaningOverride,
  normalizeTopikSpell,
} = require('./topik_meaning_overrides');
const { DB_PATH } = require('../config');

const TARGET_LANG = 'KOR_JP';
const TRANSLATE_CHUNK_SIZE = 40;
const RETRY_COUNT = 3;
const DELAY_MS = 120;

const DEFAULT_HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  'Accept-Language': 'ko,en;q=0.8',
};

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function normalizeSpace(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

async function translateChunk(words) {
  const params = new URLSearchParams({
    client: 'gtx',
    sl: 'ko',
    tl: 'ja',
    dt: 't',
    q: words.join('\n'),
  });

  const url = `https://translate.googleapis.com/translate_a/single?${params.toString()}`;

  for (let attempt = 1; attempt <= RETRY_COUNT; attempt += 1) {
    try {
      const response = await fetch(url, { headers: DEFAULT_HEADERS });
      if (!response.ok) {
        throw new Error(`Translate API HTTP ${response.status}`);
      }

      const payload = await response.json();
      const segments = Array.isArray(payload?.[0]) ? payload[0] : [];
      let lines = segments
        .map((segment) => String(segment?.[0] || ''))
        .join('')
        .split('\n');

      if (lines.length < words.length) {
        const fallbackLines = segments.map((segment) => String(segment?.[0] || '').replace(/\n$/, ''));
        if (fallbackLines.length >= words.length) {
          lines = fallbackLines;
        }
      }

      return words.map((word, index) => normalizeSpace(lines[index] || '') || word);
    } catch (error) {
      if (attempt === RETRY_COUNT) {
        return [...words];
      }
      await sleep(DELAY_MS * attempt);
    }
  }

  return [...words];
}

async function buildTranslationMap(words) {
  const map = new Map();

  for (let offset = 0; offset < words.length; offset += TRANSLATE_CHUNK_SIZE) {
    const chunk = words.slice(offset, offset + TRANSLATE_CHUNK_SIZE);
    const translated = await translateChunk(chunk);

    chunk.forEach((sourceWord, index) => {
      map.set(sourceWord, translated[index] || sourceWord);
    });

    await sleep(DELAY_MS);
  }

  return map;
}

async function main() {
  const db = new Database(DB_PATH);
  db.pragma('journal_mode = WAL');

  const rows = db.prepare(`
    SELECT word_id, day_index, theme, spell, meaning
    FROM vocabulary
    WHERE language_type = ?
    ORDER BY word_id
  `).all(TARGET_LANG);

  const planned = [];
  const needsAutoTranslation = new Set();

  for (const row of rows) {
    const normalizedSpell = normalizeTopikSpell(row.spell);
    if (!normalizedSpell) {
      continue;
    }

    const overrideMeaning = getTopikMeaningOverride({
      dayIndex: row.day_index,
      theme: row.theme,
      spell: normalizedSpell,
    });

    if (row.spell !== normalizedSpell && !overrideMeaning) {
      needsAutoTranslation.add(normalizedSpell);
    }

    planned.push({
      ...row,
      normalizedSpell,
      overrideMeaning,
    });
  }

  const translationMap = await buildTranslationMap([...needsAutoTranslation]);
  const update = db.prepare(`
    UPDATE vocabulary
    SET spell = ?, meaning = ?
    WHERE word_id = ? AND language_type = ?
  `);

  let changedRows = 0;
  let normalizedSpells = 0;
  let overriddenMeanings = 0;
  let autoTranslatedMeanings = 0;

  const applyUpdates = db.transaction((updates) => {
    for (const item of updates) {
      const nextMeaning = item.overrideMeaning
        || translationMap.get(item.normalizedSpell)
        || item.meaning;

      if (item.spell === item.normalizedSpell && item.meaning === nextMeaning) {
        continue;
      }

      if (item.spell !== item.normalizedSpell) {
        normalizedSpells += 1;
      }
      if (item.overrideMeaning && item.meaning !== item.overrideMeaning) {
        overriddenMeanings += 1;
      } else if (!item.overrideMeaning && translationMap.has(item.normalizedSpell) && item.meaning !== nextMeaning) {
        autoTranslatedMeanings += 1;
      }

      update.run(item.normalizedSpell, nextMeaning, item.word_id, TARGET_LANG);
      changedRows += 1;
    }
  });

  applyUpdates(planned);

  console.log('--- TOPIK KOR_JP meaning fix completed ---');
  console.log(`Rows scanned: ${rows.length}`);
  console.log(`Rows changed: ${changedRows}`);
  console.log(`Spell normalizations: ${normalizedSpells}`);
  console.log(`Manual meaning overrides: ${overriddenMeanings}`);
  console.log(`Auto translations for normalized spell rows: ${autoTranslatedMeanings}`);

  db.close();
}

main().catch((error) => {
  console.error('TOPIK fix failed:', error.message);
  process.exit(1);
});
