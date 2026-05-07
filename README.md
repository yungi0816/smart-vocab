# Smart Vocab

[한국어 README](README_KOR.md)

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=flat-square&logo=flutter&logoColor=white)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=flat-square&logo=dart&logoColor=white)](https://dart.dev/)
[![Node.js](https://img.shields.io/badge/Node.js-5FA04E?style=flat-square&logo=node.js&logoColor=white)](https://nodejs.org/)
[![Fastify](https://img.shields.io/badge/Fastify-000000?style=flat-square&logo=fastify&logoColor=white)](https://fastify.dev/)
[![SQLite](https://img.shields.io/badge/SQLite-003B57?style=flat-square&logo=sqlite&logoColor=white)](https://www.sqlite.org/)

`Smart Vocab` is a TOEIC vocabulary trainer that helps learners study a small amount every day and review weak words first.

Instead of acting like a simple flashcard list, the app connects daily goals, quiz results, wrong-answer history, focused review, TTS pronunciation, and an optional AI tutor into one learning loop.

## Why It Exists

Vocabulary learning is easier to sustain when learners can keep a daily rhythm and immediately revisit unstable words. This project is designed around that loop: study today, detect weak words, and bring them back into the next review flow automatically.

## Who This Is For

- Flutter developers looking for a small full-stack learning app example
- Builders combining a mobile app, Node.js API, SQLite seed data, JWT auth, and optional AI features
- Learners or product developers interested in daily-goal and weak-word review UX

## Core Ideas

- Weak-word quiz mode based on wrong-answer count
- Separate daily goals and Day-group goals to reduce overloaded sessions
- Wrong-answer continuity after goal completion
- Optional AI tutor for explanations and example sentences
- Offline-friendly fallback guidance when no AI token is available
- Deployment-friendly structure with `.env` and example config separation

## Features

- Sign up and login
- Day-based and topic-based vocabulary lists
- Random meaning-to-word and word-to-meaning quizzes
- Dashboard for today's learning count, accuracy, and Day progress
- Wrong-word search and focused review
- TTS pronunciation
- Optional AI tutor chat
- Android APK build script

## Tech Stack

- App: Flutter, Dart, Dio, shared_preferences, flutter_tts
- Server: Node.js, Fastify, SQLite (better-sqlite3), JWT
- Data: TOEIC vocabulary JSON seed

## Project Structure

```text
.
├── README.md
├── build_release.ps1
├── start_server.ps1
├── 토익.json
├── mobile/
└── server/
```

## Quick Start

### Server

```powershell
cd server
npm install
copy .env.example .env
npm run seed
npm start
```

### Flutter App

```powershell
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

When running from an emulator or physical device, adjust `API_BASE_URL` for that environment.

## Product Design Notes

- Use large enough text and controls for readability.
- Keep learning flows step-by-step instead of showing too many actions at once.
- Combine icon and text labels where meaning must be understood quickly.
- Error messages should explain both what failed and what the user can do next.

## Contributing

- Report bugs or setup problems in [Issues](https://github.com/yungi0816/smart-vocab/issues).
- Share learning UX, feature, or data-structure ideas in [Discussions](https://github.com/yungi0816/smart-vocab/discussions).
- Documentation fixes, vocabulary data improvements, and focused tests are welcome as pull requests.

## License

No explicit license is currently provided. If this project is intended for open reuse, adding MIT or Apache-2.0 is recommended.
