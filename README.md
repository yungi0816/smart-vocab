# Smart Vocab 🧠📚

TOEIC 단어를 "매일 조금씩" 학습하고, 틀린 단어를 우선적으로 복습하는 Flutter 기반 단어 학습 앱입니다.
단순 단어장 넘기기를 넘어서 오늘의 학습량과 오답 흐름을 함께 관리하는 데 초점을 맞췄습니다.

---

## 🎯 만든 이유

매번 많은 단어를 몰아서 보기보다, 매일 정해진 양을 꾸준히 보고 헷갈리는 단어를 바로 복습하는 방식이 장기 유지에 효과적입니다. 기존 앱들이 문제 흐름과 오답 반영을 분리해둔 것과 달리, 본 앱은 **오답 흐름을 자연스럽게 다음 학습에 연결**하도록 설계했습니다.

---

## ✨ 핵심 차별점

- 🔁 약점 집중 퀴즈: 틀린 횟수 기반으로 불안정 단어 우선 출제
- 📅 일일 목표 분리: 하루 목표 vs Day 그룹 목표 분리로 과도한 편중 학습 방지
- 🔄 오답 흐름 유지: 목표 달성 후에도 남은 오답은 자동 복습으로 전환
- 🤖 선택형 AI 튜터: 토큰이 있을 경우 AI 설명·예문 제공, 없으면 오프라인 가이드 유지
- 🔐 배포 친화 구조: 민감 정보는 `.env` 및 예시 파일로 분리

---

## 🔧 주요 기능

- 회원가입 / 로그인
- Day / 주제별 단어 목록
- 뜻 맞히기 / 단어 맞히기 랜덤 퀴즈
- 오늘 학습량, 정답률, Day 진행률 대시보드
- 틀린 단어 목록 검색 및 복습
- 약점 집중 모드
- 단어 발음(TTS)
- 선택형 AI 튜터 채팅 (옵션)
- Android APK 빌드 스크립트

---

## 🛠 기술 스택

- App: Flutter, Dart, Dio, shared_preferences, flutter_tts
- Server: Node.js, Fastify, SQLite (better-sqlite3), JWT
- Data: TOEIC vocabulary JSON seed

---

## 📁 프로젝트 구조 (요약)

```text
.
├── README.md
├── build_release.ps1
├── start_server.ps1
├── 토익.json
├── mobile/
└── server/
```

더 상세한 트리는 원본 파일을 참고하세요.

---

## 🚀 빠른 실행 가이드

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

> 에뮬레이터에서 로컬 서버 사용 시 `API_BASE_URL`을 환경에 맞게 조정하세요.

---

## 💡 사용자 관점의 설계 포인트

- 텍스트와 컨트롤은 충분히 큰 크기(가독성 우선)
- 단계적 안내(한 번에 한 작업)로 학습 흐름 단순화
- 아이콘 + 텍스트 조합으로 의미를 빠르게 전달
- 오류 메시지는 해결 방법을 함께 제시

이러한 설계는 특히 바쁜 실무자와 장년층 사용자의 진입 장벽을 낮추는 데 목적이 있습니다.

---

## 기여 / 라이선스

PR·이슈 환영합니다. 개인/학습용으로 활용하기 좋게 구성했으니 개선 아이디어 있으시면 자유롭게 제안해주세요. 👍

---

문의: 필요하시면 이 README로 PR 생성(또는 제가 바로 브랜치에 푸시해 PR 생성)해 드립니다.

