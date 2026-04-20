import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  // ★ 기본 ngrok URL (SharedPreferences에 저장된 값이 없을 때 사용)
  static const String _defaultUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000',
  );

  String _baseUrl = _defaultUrl;
  String get baseUrl => _baseUrl;

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
        'ngrok-skip-browser-warning': 'true',
      },
    ),
  );

  /// SharedPreferences에서 저장된 서버 URL을 불러와 적용
  Future<void> loadServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('server_url');
    _baseUrl = (saved != null && saved.isNotEmpty) ? saved : _defaultUrl;
    _dio.options.baseUrl = _baseUrl;
  }

  /// 서버 URL 변경 후 저장
  Future<void> setServerUrl(String url) async {
    // 끝에 슬래시 제거
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    _dio.options.baseUrl = _baseUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', _baseUrl);
  }

  /// 서버 연결 테스트
  Future<bool> testConnection() async {
    try {
      final res = await _dio.get(
        '/',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  String? _token;
  String? _userName;
  int _dailyQuota = 20;
  int _dailyDayQuota = 1;

  String? get userName => _userName;
  int get dailyQuota => _dailyQuota;
  int get dailyDayQuota => _dailyDayQuota;

  int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    _userName = prefs.getString('user_name');
    _dailyQuota = prefs.getInt('daily_quota') ?? 20;
    _dailyDayQuota = prefs.getInt('daily_day_quota') ?? 1;
    if (_token != null) {
      _dio.options.headers['Authorization'] = 'Bearer $_token';
    }
  }

  Future<bool> isLoggedIn() async {
    await _loadToken();
    return _token != null;
  }

  // ===== 인증 =====
  Future<Map<String, dynamic>> signup(
    String userId,
    String password,
    String userName,
    int dailyQuota, {
    int dailyDayQuota = 1,
  }) async {
    final res = await _dio.post(
      '/api/auth/signup',
      data: {
        'userId': userId,
        'password': password,
        'userName': userName,
        'dailyQuota': dailyQuota,
        'dailyDayQuota': dailyDayQuota,
      },
    );
    if (res.data['success'] == true) {
      await _saveAuth(Map<String, dynamic>.from(res.data));
    }
    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> login(String userId, String password) async {
    try {
      final res = await _dio.post(
        '/api/auth/login',
        data: {'userId': userId, 'password': password},
      );
      if (res.data['success'] == true) {
        await _saveAuth(Map<String, dynamic>.from(res.data));
      }
      return Map<String, dynamic>.from(res.data);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.unknown) {
        return _offlineLogin(userId, password);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _offlineLogin(
    String userId,
    String password,
  ) async {
    return {'success': false, 'error': '오프라인 모드: 아이디 또는 비밀번호가 틀렸습니다.'};
  }

  Future<void> _saveAuth(Map<String, dynamic> data) async {
    _token = data['token'];
    _userName = data['userName'];
    _dailyQuota = _asInt(data['dailyQuota'], 20);
    _dailyDayQuota = _asInt(data['dailyDayQuota'], 1);
    _dio.options.headers['Authorization'] = 'Bearer $_token';
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('jwt_token', _token!);
    prefs.setString('user_name', _userName ?? '');
    prefs.setInt('daily_quota', _dailyQuota);
    prefs.setInt('daily_day_quota', _dailyDayQuota);

    // 서버에서 받은 언어 설정 복원
    final uiLang = data['uiLang'] as String?;
    final studyLang = data['studyLang'] as String?;
    if (uiLang != null && studyLang != null) {
      prefs.setString('ui_lang', uiLang);
      prefs.setString('study_lang', studyLang);
    }
  }

  Future<void> logout() async {
    _token = null;
    _userName = null;
    _dio.options.headers.remove('Authorization');
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('jwt_token');
    prefs.remove('user_name');
    prefs.remove('daily_quota');
    prefs.remove('daily_day_quota');
  }

  /// 서버에 언어 설정 저장 (유저별 기억)
  Future<void> saveLangSettings(String uiLang, String studyLang) async {
    if (_token == null) return;
    try {
      await _dio.put(
        '/api/auth/lang',
        data: {'uiLang': uiLang, 'studyLang': studyLang},
      );
    } catch (_) {
      // 오프라인이면 무시 — 다음 로그인 때 로컬값 유지
    }
  }

  // ===== 단어 =====
  Future<List<dynamic>> getDays({String lang = 'ENG'}) async {
    final res = await _dio.get(
      '/api/vocab/days',
      queryParameters: {'lang': lang},
    );
    return res.data;
  }

  Future<List<dynamic>> getWords({
    String? day,
    String? theme,
    String lang = 'ENG',
  }) async {
    final res = await _dio.get(
      '/api/vocab/words',
      queryParameters: {
        ...?day == null ? null : {'day': day},
        ...?theme == null ? null : {'theme': theme},
        'lang': lang,
      },
    );
    return res.data;
  }

  // ===== 퀴즈 =====
  Future<Map<String, dynamic>> getQuiz({
    String lang = 'ENG',
    String? day,
    String? theme,
    bool allowExtra = false,
    bool focusMode = false,
    String? pos,
  }) async {
    final res = await _dio.get(
      '/api/vocab/quiz',
      queryParameters: {
        'lang': lang,
        ...?day == null ? null : {'day': day},
        ...?theme == null ? null : {'theme': theme},
        if (allowExtra) 'allowExtra': '1',
        if (focusMode) 'focusMode': '1',
        ...?pos == null ? null : {'pos': pos},
      },
    );
    return res.data;
  }

  Future<void> recordProgress(dynamic wordId, bool isCorrect) async {
    final normalizedWordId = _asInt(wordId, 0);
    if (normalizedWordId <= 0) return;
    await _dio.post(
      '/api/progress/record',
      data: {'wordId': normalizedWordId, 'isCorrect': isCorrect},
    );
  }

  // ===== 진행률 =====
  Future<Map<String, dynamic>> getTodayProgress({String? lang}) async {
    final res = await _dio.get(
      '/api/progress/today',
      queryParameters: {
        ...?lang == null ? null : {'lang': lang},
      },
    );
    return res.data;
  }

  Future<Map<String, dynamic>> getStats() async {
    final res = await _dio.get('/api/progress/stats');
    return res.data;
  }

  Future<List<dynamic>> getReviewWords({
    String lang = 'ENG',
    String scope = 'all',
    int limit = 200,
  }) async {
    final res = await _dio.get(
      '/api/progress/review',
      queryParameters: {'lang': lang, 'scope': scope, 'limit': limit},
    );
    return res.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> updateLearningSettings({
    required int dailyQuota,
    required int dailyDayQuota,
  }) async {
    final res = await _dio.put(
      '/api/auth/settings',
      data: {'dailyQuota': dailyQuota, 'dailyDayQuota': dailyDayQuota},
    );
    final data = Map<String, dynamic>.from(res.data);
    _dailyQuota = _asInt(data['dailyQuota'], dailyQuota);
    _dailyDayQuota = _asInt(data['dailyDayQuota'], dailyDayQuota);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_quota', _dailyQuota);
    await prefs.setInt('daily_day_quota', _dailyDayQuota);
    return data;
  }

  Future<Map<String, dynamic>> getMySettings() async {
    final res = await _dio.get('/api/auth/me');
    final data = Map<String, dynamic>.from(res.data);
    _dailyQuota = _asInt(data['daily_quota'], _dailyQuota);
    _dailyDayQuota = _asInt(data['daily_day_quota'], _dailyDayQuota);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('daily_quota', _dailyQuota);
    await prefs.setInt('daily_day_quota', _dailyDayQuota);
    return data;
  }
}
