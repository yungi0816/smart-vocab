const fs = require('fs');
const path = require('path');

const envPath = path.join(__dirname, '..', '.env');
if (fs.existsSync(envPath)) {
  const lines = fs.readFileSync(envPath, 'utf-8').split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const index = trimmed.indexOf('=');
    if (index < 1) continue;
    const key = trimmed.slice(0, index).trim();
    const value = trimmed.slice(index + 1).trim().replace(/^["']|["']$/g, '');
    if (!process.env[key]) process.env[key] = value;
  }
}

const SERVER_ROOT = path.join(__dirname, '..');
const DATA_DIR = process.env.DATA_DIR || path.join(SERVER_ROOT, 'data');
const DB_PATH = process.env.DB_PATH || path.join(DATA_DIR, 'vocab.db');
const WEB_APP_ROOT =
  process.env.WEB_APP_ROOT ||
  path.join(SERVER_ROOT, '..', 'mobile', 'build', 'web');

const JWT_SECRET = process.env.JWT_SECRET || 'dev-only-smart-vocab-secret';

if (process.env.NODE_ENV === 'production' && !process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET must be set in production.');
}

fs.mkdirSync(DATA_DIR, { recursive: true });
fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });

module.exports = {
  SERVER_ROOT,
  DATA_DIR,
  DB_PATH,
  WEB_APP_ROOT,
  JWT_SECRET,
};
