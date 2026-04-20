# Smart Vocab

TOEIC 단어를 매일 조금씩 보고, 틀린 단어를 다시 끌어올려 복습하는 Flutter 기반 단어 학습 앱입니다. 단어장을 넘기는 데서 끝내지 않고, 오늘의 학습량과 오답 흐름을 같이 관리하는 데 초점을 맞췄습니다.

## 만든 이유

TOEIC 단어는 한 번에 많이 보는 것보다 매일 정해진 양을 보고, 헷갈린 단어를 바로 다시 만나는 방식이 오래 갑니다. 기존 단어장 앱은 목록, 퀴즈, 즐겨찾기 중심인 경우가 많아서 “오늘 내가 틀린 단어가 다음 문제 흐름에 어떻게 반영되는지”가 약했습니다. 그래서 일일 목표, Day 단위 분산, 오답 우선 복습을 한 화면에서 이어지게 만들었습니다.

## 차별점

- 약점 집중 퀴즈: 사용자가 틀린 횟수와 정답 횟수를 바탕으로 아직 안정되지 않은 단어를 먼저 냅니다.
- 일일 목표 관리: 하루 단어 수와 Day 그룹 목표를 분리해서, 한 주제만 몰아서 보는 문제를 줄입니다.
- 오답 흐름 유지: 목표를 채운 뒤에도 남은 오답이 있으면 복습 모드로 이어집니다.
- 선택형 튜터 설명: AI 토큰이 있으면 오답 설명과 예문을 받고, 없으면 기본 오프라인 안내로 앱 흐름을 유지합니다.
- 개인 배포 친화 구조: API 키, JWT secret, DB 파일, 로컬 터널 주소는 코드에 넣지 않고 환경변수와 예시 파일로 분리했습니다.

## 주요 기능

- 회원가입/로그인
- TOEIC 단어 Day/주제별 목록
- 뜻 맞히기/단어 맞히기 랜덤 퀴즈
- 오늘 학습량, 정답률, Day 진행률 확인
- 틀린 단어 목록과 검색
- 약점 집중 퀴즈
- 단어 발음 TTS
- 선택형 AI 튜터 채팅 및 오답 설명
- Android APK 빌드 스크립트

## 기술 스택

- App: Flutter, Dart, Dio, shared_preferences, flutter_tts
- Server: Node.js, Fastify, SQLite, better-sqlite3, JWT
- Data: TOEIC vocabulary JSON seed

## Tree

```text
.
├── README.md
├── build_release.ps1
├── start_server.ps1
├── 토익.json
├── mobile
│   ├── lib
│   │   ├── main.dart
│   │   ├── screens
│   │   │   ├── ai_chat_screen.dart
│   │   │   ├── dashboard_screen.dart
│   │   │   ├── login_screen.dart
│   │   │   ├── quiz_screen.dart
│   │   │   ├── review_screen.dart
│   │   │   ├── settings_screen.dart
│   │   │   ├── signup_screen.dart
│   │   │   └── word_list_screen.dart
│   │   └── services
│   │       ├── ai_service.dart
│   │       ├── api_service.dart
│   │       ├── lang_service.dart
│   │       ├── tts_service.dart
│   │       └── update_service.dart
│   ├── android
│   ├── ios
│   ├── web
│   ├── windows
│   └── pubspec.yaml
└── server
    ├── .env.example
    ├── package.json
    └── src
        ├── config.js
        ├── index.js
        ├── db
        │   ├── seed.js
        │   ├── seed_jp.js
        │   └── seed_topik_jp.js
        └── routes
            ├── ai.js
            ├── admin.js
            ├── auth.js
            ├── progress.js
            ├── update.js
            └── vocab.js
```

## 실행 방법

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

Android 에뮬레이터에서 로컬 PC 서버에 붙을 때는 `API_BASE_URL`을 환경에 맞게 바꿔 주세요.

## 공개 제외 항목

아래 항목은 저장소에 올리지 않습니다.

- API key, AI token, JWT secret, admin key
- SQLite DB 파일과 로컬 데이터 디렉터리
- ngrok 같은 개인 터널 주소
- 빌드 산출물과 패키지 캐시
- 내부 작업 메모
- 펫 관련 에셋과 화면
