import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// 다국어 서비스 — UI 언어(한국어/일본어) + 학습 언어(영어/일본어/한국어) 관리
class LangService extends ChangeNotifier {
  static final LangService instance = LangService._();
  LangService._();

  // === UI 언어 ===
  String _uiLang = 'ko'; // 'ko' | 'ja'
  String get uiLang => _uiLang;
  bool get isKoreanUi => _uiLang == 'ko';
  bool get isJapaneseUi => _uiLang == 'ja';

  // === 학습 언어 (DB language_type) ===
  String _studyLang = 'ENG'; // 'ENG' | 'JPN' | 'ENG_JP' | 'KOR_JP'
  String get studyLang => _studyLang;

  // 하위호환
  String get lang => _studyLang;

  // === 플래그 ===
  String get uiFlag => _uiLang == 'ko' ? '🇰🇷' : '🇯🇵';

  String get studyFlag {
    switch (_studyLang) {
      case 'ENG':
      case 'ENG_JP':
        return '🇺🇸';
      case 'JPN':
        return '🇯🇵';
      case 'KOR_JP':
        return '🇰🇷';
      default:
        return '🇺🇸';
    }
  }

  String get studyLabel {
    switch (_studyLang) {
      case 'ENG':
        return tr('english');
      case 'JPN':
        return tr('japanese');
      case 'ENG_JP':
        return tr('english');
      case 'KOR_JP':
        return tr('korean');
      default:
        return tr('english');
    }
  }

  String get ttsLocale {
    switch (_studyLang) {
      case 'JPN':
        return 'ja-JP';
      case 'KOR_JP':
        return 'ko-KR';
      default:
        return 'en-US';
    }
  }

  // === 기존 호환 ===
  String get flag => uiFlag;
  String get label => studyLabel;
  bool get isJapanese => _studyLang == 'JPN' || _uiLang == 'ja';

  // === 초기화 ===
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _uiLang = prefs.getString('ui_lang') ?? 'ko';
    _studyLang =
        prefs.getString('study_lang') ?? (_uiLang == 'ko' ? 'ENG' : 'ENG_JP');
    notifyListeners();
  }

  // === UI 언어 전환 (국기 토글) ===
  Future<void> toggleUiLang() async {
    if (_uiLang == 'ko') {
      _uiLang = 'ja';
      _studyLang = 'ENG_JP';
    } else {
      _uiLang = 'ko';
      _studyLang = 'ENG';
    }
    await _save();
    notifyListeners();
  }

  // === 학습 언어 전환 (모드 토글) ===
  Future<void> toggleStudyLang() async {
    if (_uiLang == 'ko') {
      _studyLang = _studyLang == 'ENG' ? 'JPN' : 'ENG';
    } else {
      _studyLang = _studyLang == 'ENG_JP' ? 'KOR_JP' : 'ENG_JP';
    }
    await _save();
    notifyListeners();
  }

  // 하위호환
  Future<void> toggle() async => toggleStudyLang();

  String localizeDayLabel(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty || !isJapaneseUi) return value;
    final topikMatch = RegExp(
      r'^TOPIK\s*(\d+)$',
      caseSensitive: false,
    ).firstMatch(value);
    if (topikMatch != null) {
      return 'TOPIK ${topikMatch.group(1)}級';
    }
    return value;
  }

  String localizeThemeLabel(String? raw) {
    var value = (raw ?? '').trim();
    if (value.isEmpty || !isJapaneseUi) return value;

    value = value.replaceAllMapped(
      RegExp(r'(\d+)\s*급'),
      (m) => '${m.group(1)}級',
    );
    _topikThemeKoToJa.forEach((ko, ja) {
      value = value.replaceAll(ko, ja);
    });
    return value;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ui_lang', _uiLang);
    await prefs.setString('study_lang', _studyLang);
    // 서버에도 저장 (유저별 기억)
    ApiService.instance.saveLangSettings(_uiLang, _studyLang);
  }

  // =============================================
  // 다국어 번역
  // =============================================
  String tr(String key) =>
      (_strings[_uiLang]?[key]) ?? (_strings['ko']?[key]) ?? key;

  static const Map<String, String> _topikThemeKoToJa = {
    '의존명사': '依存名詞',
    '대명사': '代名詞',
    '관형사': '連体詞',
    '감탄사': '感嘆詞',
    '형용사': '形容詞',
    '명사': '名詞',
    '동사': '動詞',
    '부사': '副詞',
    '수사': '数詞',
    '조사': '助詞',
    '접사': '接辞',
    '기타': 'その他',
  };

  static const Map<String, Map<String, String>> _strings = {
    'ko': {
      'app_title': '스마트 어학 학습',
      'app_subtitle': '토익 · 일본어 단어 마스터',
      'english': '영어',
      'japanese': '일본어',
      'korean': '한국어',
      'login': '로그인',
      'login_id': '아이디',
      'login_pw': '비밀번호',
      'login_error_empty': '아이디와 비밀번호를 입력해주세요.',
      'login_error_wrong': '아이디 또는 비밀번호가 틀렸습니다.',
      'login_error_server': '서버에 연결할 수 없습니다. 아래 서버 설정을 확인해주세요.',
      'login_error_unknown': '알 수 없는 오류가 발생했습니다.',
      'no_account': '계정이 없으신가요? 회원가입',
      'signup': '회원가입',
      'signup_welcome': '환영합니다! 👋',
      'signup_desc': '학습 계정을 만들어 보세요.',
      'signup_name': '이름',
      'signup_quota': '하루 학습 목표',
      'daily_day_quota': '하루 Day 그룹 목표',
      'daily_day_quota_desc': '오늘 학습에서 최소 몇 개의 DAY/TOPIK 그룹을 다룰지 정합니다.',
      'day_group_prefix': '그룹',
      'signup_error_empty': '모든 항목을 입력해주세요.',
      'signup_error_server': '서버에 연결할 수 없습니다. 네트워크를 확인해주세요.',
      'signup_error_unknown': '알 수 없는 오류가 발생했습니다.',
      'words_per_day': '단어/일',
      'hello': '안녕하세요! 👋',
      'greeting_suffix': '님, 오늘도 화이팅!',
      'mode_suffix': '모드',
      'today_study': '오늘의 학습',
      'day_group_progress': 'Day 그룹',
      'accuracy_label': '정답률',
      'complete': '완료',
      'quiz_start': '퀴즈 시작',
      'word_book': '단어장',
      'review': '복습하기',
      'review_today': '오늘 복습',
      'review_all': '전체 복습',
      'no_review_words': '복습할 단어가 없습니다.',
      'weakness_quiz': '약점 집중',
      'ai_tutor': 'AI 튜터',
      'ai_tutor_suffix': '튜터',
      'settings': '설정',
      'settings_saved': '설정이 저장되었습니다.',
      'settings_save_failed': '설정 저장에 실패했습니다.',
      'day_study': '📅 Day별 학습',
      'word_count_suffix': '단어',
      'quiz': '퀴즈',
      'quiz_no_load': '퀴즈를 불러올 수 없습니다.',
      'quiz_scope_day': '급수/일자',
      'quiz_scope_theme': '품사/테마',
      'quiz_scope_reset': '전체로 초기화',
      'quota_completed': '오늘 목표를 완료했습니다.',
      'wrong_review_mode': '목표 달성: 오늘 틀린 단어 복습 모드',
      'focus_review_mode': '약점 집중 복습 모드',
      'extra_study_mode': '신규 단어 추가 학습 모드',
      'continue_new_words': '신규 단어 계속 학습',
      'spell_to_meaning': '이 단어의 뜻은?',
      'meaning_to_spell': '이 뜻의 단어는?',
      'next_quiz': '다음 문제',
      'word_list': '단어장',
      'all': '전체',
      'search_hint': '단어 또는 뜻 검색',
      'no_results': '검색 결과가 없습니다.',
      'tap_to_show_meaning': '탭하여 뜻 보기',
      'show_meaning': '뜻 보이기',
      'hide_meaning': '뜻 숨기기',
      'quiz_correct_basic': '잘했어요! 🎉',
      'quiz_wrong_basic': '아쉬워요! 다시 도전해 봐요 😊',
      'server_url_title': '서버 URL 설정',
      'server_url_hint': 'https://xxxxx.ngrok-free.dev',
      'server_url_desc': 'PC에서 start_server.ps1 실행 후\n표시된 URL을 입력하세요.',
      'server_test_ok': '✅ 연결 성공!',
      'server_test_fail': '❌ 연결 실패 — URL을 확인해주세요',
      'cancel': '취소',
      'save': '저장',
      'server_prefix': '서버: ',
      'wrong_words_title': '틀린 단어',
      'quiz_scope_select': '퀴즈 범위 선택',
      'select_mode_day': 'Day로 선택',
      'select_mode_topic': '토픽(테마)로 선택',
      'pos_filter_label': '품사 필터',
      'start_quiz': '퀴즈 시작',
      'no_meaning': '의미 정보가 없습니다.',
      'close': '닫기',
      'ai_chat_greeting': '궁금한 단어, 예문, 복습 방법을 물어보세요.',
      'ai_auth_hint': 'AI 기능을 사용하려면 인증이 필요합니다. 우측 상단의 인증 버튼을 눌러 주세요.',
      'ai_auth': 'AI 인증',
      'ai_chat_hint': '단어나 예문을 질문해 보세요...',
      'ai_auth_title': 'GitHub AI 인증',
      'ai_auth_code_desc': '아래 코드를 GitHub 인증 페이지에 입력해 주세요.',
      'code_copied': '코드가 복사되었습니다.',
      'open_auth_page': '인증 페이지 열기',
      'waiting_auth': '브라우저에서 인증을 기다리는 중...',
      'ai_auth_complete': 'AI 인증이 완료되었습니다.',
    },
    'ja': {
      'app_title': 'スマート語学学習',
      'app_subtitle': 'TOEIC · 韓国語 単語マスター',
      'english': '英語',
      'japanese': '日本語',
      'korean': '韓国語',
      'login': 'ログイン',
      'login_id': 'ID',
      'login_pw': 'パスワード',
      'login_error_empty': 'IDとパスワードを入力してください。',
      'login_error_wrong': 'IDまたはパスワードが間違っています。',
      'login_error_server': 'サーバーに接続できません。下のサーバー設定を確認してください。',
      'login_error_unknown': '不明なエラーが発生しました。',
      'no_account': 'アカウントがない方は 新規登録',
      'signup': '新規登録',
      'signup_welcome': 'ようこそ! 👋',
      'signup_desc': '学習アカウントを作りましょう。',
      'signup_name': '名前',
      'signup_quota': '1日の学習目標',
      'daily_day_quota': '1日のDayグループ目標',
      'daily_day_quota_desc': '1日に学習するDAY/TOPIKグループの最小数を設定します。',
      'day_group_prefix': 'グループ',
      'signup_error_empty': 'すべての項目を入力してください。',
      'signup_error_server': 'サーバーに接続できません。ネットワークを確認してください。',
      'signup_error_unknown': '不明なエラーが発生しました。',
      'words_per_day': '単語/日',
      'hello': 'こんにちは! 👋',
      'greeting_suffix': 'さん、今日も頑張りましょう!',
      'mode_suffix': 'モード',
      'today_study': '今日の学習',
      'day_group_progress': 'Dayグループ',
      'accuracy_label': '正解率',
      'complete': '完了',
      'quiz_start': 'クイズ開始',
      'word_book': '単語帳',
      'review': '復習',
      'review_today': '今日の復習',
      'review_all': '全体復習',
      'no_review_words': '復習する単語がありません。',
      'weakness_quiz': '弱点集中',
      'ai_tutor': 'AIチューター',
      'ai_tutor_suffix': 'チューター',
      'settings': '設定',
      'settings_saved': '設定を保存しました。',
      'settings_save_failed': '設定の保存に失敗しました。',
      'day_study': '📅 Day別学習',
      'word_count_suffix': '単語',
      'quiz': 'クイズ',
      'quiz_no_load': 'クイズを読み込めません。',
      'quiz_scope_day': '級/日付',
      'quiz_scope_theme': '品詞/テーマ',
      'quiz_scope_reset': '全体に戻す',
      'quota_completed': '今日の目標を達成しました。',
      'wrong_review_mode': '目標達成: 今日の不正解単語を優先復習',
      'focus_review_mode': '弱点集中レビュー',
      'extra_study_mode': '新規単語の追加学習モード',
      'continue_new_words': '新規単語を続ける',
      'spell_to_meaning': 'この単語の意味は?',
      'meaning_to_spell': 'この意味の単語は?',
      'next_quiz': '次の問題',
      'word_list': '単語帳',
      'all': 'すべて',
      'search_hint': '単語または意味を検索',
      'no_results': '検索結果がありません。',
      'tap_to_show_meaning': 'タップして意味を表示',
      'show_meaning': '意味を表示',
      'hide_meaning': '意味を隠す',
      'quiz_correct_basic': 'よくできました! 🎉',
      'quiz_wrong_basic': '惜しいです! もう一度挑戦しましょう 😊',
      'server_url_title': 'サーバーURL設定',
      'server_url_hint': 'https://xxxxx.ngrok-free.dev',
      'server_url_desc': 'PCでstart_server.ps1を実行し\n表示されたURLを入力してください。',
      'server_test_ok': '✅ 接続成功!',
      'server_test_fail': '❌ 接続失敗 — URLを確認してください',
      'cancel': 'キャンセル',
      'save': '保存',
      'server_prefix': 'サーバー: ',
      'wrong_words_title': '間違いやすい単語',
      'quiz_scope_select': 'クイズ範囲を選択',
      'select_mode_day': 'Dayで選択',
      'select_mode_topic': 'トピックで選択',
      'pos_filter_label': '品詞フィルター',
      'start_quiz': 'クイズを開始',
      'no_meaning': '意味情報がありません。',
      'close': '閉じる',
      'ai_chat_greeting': '気になる単語、例文、復習方法を質問してください。',
      'ai_auth_hint': 'AI機能を使うには認証が必要です。右上の認証ボタンを押してください。',
      'ai_auth': 'AI認証',
      'ai_chat_hint': '単語や例文を質問してください...',
      'ai_auth_title': 'GitHub AI認証',
      'ai_auth_code_desc': '以下のコードをGitHub認証ページに入力してください。',
      'code_copied': 'コードをコピーしました。',
      'open_auth_page': '認証ページを開く',
      'waiting_auth': 'ブラウザでの認証を待っています...',
      'ai_auth_complete': 'AI認証が完了しました。',
    },
  };
}
