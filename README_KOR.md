# Smart Vocab

[English README](README.md)

`Smart Vocab`은 TOEIC 단어를 매일 조금씩 학습하고, 틀린 단어를 우선적으로 복습하는 Flutter 기반 단어 학습 앱입니다.

단순 단어장 넘기기를 넘어서 오늘의 학습량, 오답 흐름, 약점 집중 복습, TTS 발음, 선택형 AI 튜터를 하나의 학습 루프로 연결하는 데 초점을 맞췄습니다.

## 만든 이유

매번 많은 단어를 몰아서 보기보다, 매일 정해진 양을 꾸준히 보고 헷갈리는 단어를 바로 복습하는 방식이 장기 유지에 효과적입니다. 이 프로젝트는 오늘 학습, 약점 감지, 다음 복습 연결이라는 흐름을 중심으로 설계했습니다.

## 핵심 차별점

- 틀린 횟수 기반 약점 집중 퀴즈
- 하루 목표와 Day 그룹 목표 분리
- 목표 달성 후에도 남은 오답을 자동 복습으로 연결
- 토큰이 있을 경우 AI 설명/예문 제공
- 토큰이 없을 경우 오프라인 가이드 유지

## 주요 기능

- 회원가입 / 로그인
- Day / 주제별 단어 목록
- 뜻 맞히기 / 단어 맞히기 랜덤 퀴즈
- 오늘 학습량, 정답률, Day 진행률 대시보드
- 틀린 단어 검색 및 복습
- 약점 집중 모드
- 단어 발음(TTS)
- 선택형 AI 튜터 채팅
- Android APK 빌드 스크립트

## 기술 스택

- App: Flutter, Dart, Dio, shared_preferences, flutter_tts
- Server: Node.js, Fastify, SQLite, JWT
- Data: TOEIC vocabulary JSON seed

## 실행

### 서버

```powershell
cd server
npm install
copy .env.example .env
npm run seed
npm start
```

### Flutter 앱

```powershell
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:3000
```

에뮬레이터나 실제 기기에서 로컬 서버를 사용할 때는 환경에 맞게 `API_BASE_URL`을 조정해야 합니다.

## 의견과 기여

- 버그나 실행 문제는 [Issues](https://github.com/yungi0816/smart-vocab/issues)에 남겨주세요.
- 학습 UX, 기능, 데이터 구조 아이디어는 [Discussions](https://github.com/yungi0816/smart-vocab/discussions)에 남겨주세요.
- 문서 수정, 단어 데이터 개선, 테스트 보강 PR을 환영합니다.
