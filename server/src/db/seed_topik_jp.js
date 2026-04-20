/**
 * Seed TOPIK Korean -> Japanese vocabulary (KOR_JP) into SQLite.
 * Source: https://kleocean.com/토픽-어휘-topik-vocab/
 *
 * Usage:
 *   node src/db/seed_topik_jp.js
 */

const Database = require('better-sqlite3');
const {
  WORD_CLASS_LABELS,
  getTopikMeaningOverride,
  normalizeTopikSpell,
} = require('./topik_meaning_overrides');
const { DB_PATH } = require('../config');

const INDEX_URL = 'https://kleocean.com/%ED%86%A0%ED%94%BD-%EC%96%B4%ED%9C%98-topik-vocab/';
const TARGET_LANG = 'KOR_JP';
const LEVELS = [1, 2, 3, 4, 5, 6];
const TRANSLATE_CHUNK_SIZE = 40;
const RETRY_COUNT = 3;
const DELAY_MS = 120;

const DEFAULT_HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
  'Accept-Language': 'ko,en;q=0.8',
};

const KNOWN_WORD_CLASSES = WORD_CLASS_LABELS;

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function normalizeSpace(value) {
  return String(value || '').replace(/\s+/g, ' ').trim();
}

function decodeHtml(value) {
  return String(value || '')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&quot;/gi, '"')
    .replace(/&apos;/gi, "'")
    .replace(/&#39;/g, "'")
    .replace(/&#x([0-9a-f]+);/gi, (_, hex) => String.fromCodePoint(parseInt(hex, 16)))
    .replace(/&#(\d+);/g, (_, num) => String.fromCodePoint(Number(num)))
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/\s+/g, ' ')
    .trim();
}

function cleanSpell(rawSpell) {
  return normalizeTopikSpell(rawSpell);
}

function normalizeWordClass(rawClass) {
  const first = normalizeSpace(rawClass).split('/')[0].trim();
  if (!first) {
    return '기타';
  }

  for (const wordClass of KNOWN_WORD_CLASSES) {
    if (first.includes(wordClass)) {
      return wordClass;
    }
  }

  return first;
}

async function fetchText(url) {
  for (let attempt = 1; attempt <= RETRY_COUNT; attempt += 1) {
    try {
      const response = await fetch(url, { headers: DEFAULT_HEADERS });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      return await response.text();
    } catch (error) {
      if (attempt === RETRY_COUNT) {
        throw error;
      }
      await sleep(DELAY_MS * attempt);
    }
  }

  throw new Error(`Failed to fetch: ${url}`);
}

function extractLevelLinks(indexHtml) {
  const links = new Map();
  const anchorRegex = /<a[^>]+href="([^"]+)"[^>]*>([\s\S]*?)<\/a>/gi;

  for (const match of indexHtml.matchAll(anchorRegex)) {
    const href = match[1] || '';
    const hrefLower = href.toLowerCase();

    if (!hrefLower.includes('topik-level-') || !hrefLower.includes('accumulate-list')) {
      continue;
    }

    const levelMatch = hrefLower.match(/topik-level-(\d)-accumulate-list/);
    if (!levelMatch) {
      continue;
    }

    const level = Number(levelMatch[1]);
    if (!LEVELS.includes(level) || links.has(level)) {
      continue;
    }

    links.set(level, new URL(href, INDEX_URL).href);
  }

  for (const level of LEVELS) {
    if (!links.has(level)) {
      throw new Error(`Could not find TOPIK level ${level} accumulate link.`);
    }
  }

  return links;
}

function parseLevelRows(levelHtml, fallbackLevel) {
  const tableMatch = levelHtml.match(/<table[\s\S]*?<\/table>/i);
  if (!tableMatch) {
    throw new Error(`No table found for TOPIK level ${fallbackLevel}.`);
  }

  const rows = [...tableMatch[0].matchAll(/<tr[\s\S]*?<\/tr>/gi)].map((m) => m[0]);
  const parsed = [];

  for (const row of rows) {
    const cells = [...row.matchAll(/<t[dh][^>]*>([\s\S]*?)<\/t[dh]>/gi)]
      .map((cellMatch) => decodeHtml(cellMatch[1]));

    if (cells.length < 5) {
      continue;
    }

    if (cells[0].includes('번호')) {
      continue;
    }

    const levelText = cells[1];
    const levelFromCell = Number((levelText.match(/(\d+)/) || [])[1]);
    const level = Number.isFinite(levelFromCell) && levelFromCell > 0 ? levelFromCell : fallbackLevel;
    if (!LEVELS.includes(level)) {
      continue;
    }

    const spell = cleanSpell(cells[2]);
    if (!spell) {
      continue;
    }

    const wordClass = normalizeWordClass(cells[3]);

    parsed.push({
      dayIndex: `TOPIK ${level}`,
      theme: `${level}급 ${wordClass}`,
      spell,
      guide: cells[4],
    });
  }

  return parsed;
}

async function translateChunk(words) {
  const query = words.join('\n');
  const params = new URLSearchParams({
    client: 'gtx',
    sl: 'ko',
    tl: 'ja',
    dt: 't',
    q: query,
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

      return words.map((word, index) => {
        const translated = normalizeSpace(lines[index] || '');
        return translated || word;
      });
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

    const current = Math.min(offset + chunk.length, words.length);
    console.log(`  - translated ${current}/${words.length}`);
    await sleep(DELAY_MS);
  }

  return map;
}

function dedupeEntries(entries) {
  const seen = new Set();
  const deduped = [];

  for (const entry of entries) {
    const key = `${entry.dayIndex}::${entry.theme}::${entry.spell}`;
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    deduped.push(entry);
  }

  return deduped;
}

async function main() {
  console.log('--- TOPIK KOR_JP seed started ---');
  console.log(`DB: ${DB_PATH}`);

  const indexHtml = await fetchText(INDEX_URL);
  const levelLinks = extractLevelLinks(indexHtml);

  const allEntries = [];
  for (const level of LEVELS) {
    const levelUrl = levelLinks.get(level);
    console.log(`\n[TOPIK ${level}] fetch: ${levelUrl}`);
    const levelHtml = await fetchText(levelUrl);
    const rows = parseLevelRows(levelHtml, level);
    console.log(`  - rows parsed: ${rows.length}`);
    allEntries.push(...rows);
    await sleep(DELAY_MS);
  }

  const dedupedEntries = dedupeEntries(allEntries);
  const uniqueWords = [...new Set(dedupedEntries.map((entry) => entry.spell))];

  console.log(`\nTotal parsed rows: ${allEntries.length}`);
  console.log(`After dedupe: ${dedupedEntries.length}`);
  console.log(`Unique Korean words to translate: ${uniqueWords.length}`);

  const translationMap = await buildTranslationMap(uniqueWords);

  const db = new Database(DB_PATH);
  db.pragma('journal_mode = WAL');

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

  db.exec(`DELETE FROM vocabulary WHERE language_type = '${TARGET_LANG}'`);

  const insert = db.prepare(
    'INSERT INTO vocabulary (language_type, theme, day_index, spell, meaning) VALUES (?, ?, ?, ?, ?)'
  );

  const insertMany = db.transaction((rows) => {
    for (const row of rows) {
      insert.run(TARGET_LANG, row.theme, row.dayIndex, row.spell, row.meaning);
    }
  });

  const rowsToInsert = dedupedEntries.map((entry) => ({
    ...entry,
    meaning: getTopikMeaningOverride(entry) || translationMap.get(entry.spell) || entry.spell,
  }));

  insertMany(rowsToInsert);

  const stats = db.prepare(`
    SELECT day_index, theme, COUNT(*) AS cnt
    FROM vocabulary
    WHERE language_type = ?
    GROUP BY day_index, theme
    ORDER BY
      CAST(REPLACE(day_index, 'TOPIK ', '') AS INTEGER),
      theme
  `).all(TARGET_LANG);

  console.log(`\nInserted ${rowsToInsert.length} rows into ${TARGET_LANG}.`);
  console.log('\n--- by level/theme ---');
  for (const stat of stats) {
    console.log(`${stat.day_index} | ${stat.theme}: ${stat.cnt}`);
  }

  db.close();
  console.log('\n--- TOPIK KOR_JP seed completed ---');
}

main().catch((error) => {
  console.error('Seed failed:', error.message);
  process.exit(1);
});
