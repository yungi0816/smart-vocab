import 'package:dio/dio.dart';
import 'api_service.dart';
import 'lang_service.dart';

class AiService {
  static final instance = AiService._();
  AiService._();

  bool _authenticated = false;
  bool get isAuthenticated => _authenticated;

  String get _uiLang => LangService.instance.isJapaneseUi ? 'ja' : 'ko';

  Dio get _dio => Dio(
    BaseOptions(
      baseUrl: ApiService.instance.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  Future<bool> checkAuthStatus() async {
    try {
      final res = await _dio.get('/api/ai/auth/status');
      _authenticated = res.data['authenticated'] == true;
      return _authenticated;
    } catch (_) {
      _authenticated = false;
      return false;
    }
  }

  Future<Map<String, dynamic>?> startDeviceAuth() async {
    try {
      final res = await _dio.post('/api/ai/auth/start');
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(res.data);
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> pollDeviceAuth(String deviceCode) async {
    try {
      final res = await _dio.post(
        '/api/ai/auth/poll',
        data: {'device_code': deviceCode},
      );
      if (res.statusCode == 200) {
        final data = Map<String, dynamic>.from(res.data);
        if (data['success'] == true) _authenticated = true;
        return data;
      }
    } catch (_) {}
    return {'error': 'network_error'};
  }

  Future<String> explainWord({
    required String word,
    required String meaning,
    required String userAnswer,
    required String correctAnswer,
  }) async {
    try {
      final res = await _dio.post(
        '/api/ai/explain',
        data: {
          'word': word,
          'meaning': meaning,
          'userAnswer': userAnswer,
          'correctAnswer': correctAnswer,
          'uiLang': _uiLang,
        },
      );
      if (res.statusCode == 200 && res.data['explanation'] != null) {
        return res.data['explanation'];
      }
    } catch (_) {}

    return _offlineExplain(word, meaning, correctAnswer);
  }

  Future<String> exampleSentence({
    required String word,
    required String meaning,
  }) async {
    try {
      final res = await _dio.post(
        '/api/ai/example',
        data: {'word': word, 'meaning': meaning, 'uiLang': _uiLang},
      );
      if (res.statusCode == 200 && res.data['example'] != null) {
        return res.data['example'];
      }
    } catch (_) {}

    return _offlineExample(word, meaning);
  }

  Future<String> chat({
    required String message,
    List<Map<String, String>> history = const [],
  }) async {
    try {
      final res = await _dio.post(
        '/api/ai/chat',
        data: {'message': message, 'history': history, 'uiLang': _uiLang},
      );
      if (res.statusCode == 200 && res.data['reply'] != null) {
        return res.data['reply'];
      }
    } catch (_) {}

    return _offlineChat(message);
  }

  String _offlineExplain(String word, String meaning, String correct) {
    if (LangService.instance.isJapaneseUi) {
      return '"$word" means "$meaning". Correct answer: "$correct". Review it with one short example sentence.';
    }
    return '"$word"의 뜻은 "$meaning"입니다. 정답은 "$correct"입니다. 짧은 예문 하나와 함께 다시 읽어 보세요.';
  }

  String _offlineExample(String word, String meaning) {
    if (LangService.instance.isJapaneseUi) {
      return 'Example: "Please ${word.toLowerCase()} the report before Friday."\nMeaning: $meaning';
    }
    return 'Example: "Please ${word.toLowerCase()} the report before Friday."\n뜻: $meaning';
  }

  String _offlineChat(String message) {
    if (LangService.instance.isJapaneseUi) {
      return 'Offline reply: "$message"\nTry summarizing the word, example, and review point.';
    }
    return '오프라인 응답입니다: "$message"\n단어 뜻, 예문, 복습 포인트 순서로 정리해 보세요.';
  }
}
