import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SafeTts {
  FlutterTts? _tts;
  bool _ready = false;
  bool _disabled = false;
  String? _locale;

  Future<void> configure(String locale) async {
    _locale = locale;
    _ready = false;
    if (_disabled) return;

    try {
      final tts = _tts ??= FlutterTts();
      await tts.setLanguage(locale);
      await tts.setSpeechRate(0.45);
      await tts.setVolume(1.0);
      _ready = true;
    } catch (_) {
      _disabled = true;
    }
  }

  Future<void> speak(String? text, {bool userInitiated = true}) async {
    final value = text?.trim();
    if (value == null || value.isEmpty || _disabled) return;

    // Mobile Safari commonly blocks speech started without a user gesture.
    if (kIsWeb && !userInitiated) return;

    try {
      final tts = _tts ??= FlutterTts();
      if (!_ready && _locale != null) {
        await configure(_locale!);
      }
      if (_disabled) return;
      await tts.speak(value);
    } catch (_) {
      _disabled = true;
    }
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {
      // Ignore platform TTS shutdown errors.
    }
  }
}
