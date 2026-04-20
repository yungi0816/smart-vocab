import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/api_service.dart';
import 'services/lang_service.dart';

void main() {
  runZonedGuarded(_bootstrap, (error, stack) {
    debugPrint('Uncaught app error: $error');
    debugPrintStack(stackTrace: stack);
  });
}

Future<void> _bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 웹에서는 Google Fonts 런타임 다운로드 비활성화 (iOS Safari + ngrok에서 CDN 차단 이슈)
  if (kIsWeb) {
    GoogleFonts.config.allowRuntimeFetching = false;
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught platform error: $error');
    debugPrintStack(stackTrace: stack);
    return true;
  };
  ErrorWidget.builder = (details) => _AppErrorFallback(details: details);

  await _safeInit('language', LangService.instance.load);
  await _safeInit('server', ApiService.instance.loadServerUrl);
  runApp(const SmartVocabApp());
}

Future<void> _safeInit(String name, Future<void> Function() load) async {
  try {
    await load();
  } catch (e, stack) {
    debugPrint('Startup $name init failed: $e');
    debugPrintStack(stackTrace: stack);
  }
}

class _AppErrorFallback extends StatelessWidget {
  final FlutterErrorDetails details;
  const _AppErrorFallback({required this.details});

  @override
  Widget build(BuildContext context) {
    debugPrint('ErrorWidget triggered: ${details.exception}');
    debugPrintStack(stackTrace: details.stack);
    return Material(
      color: const Color(0xFF0F172A),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '화면을 불러오지 못했습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const SmartVocabApp()),
                      (_) => false,
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '다시 시도',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SmartVocabApp extends StatelessWidget {
  const SmartVocabApp({super.key});

  static TextTheme _safeTextTheme() {
    try {
      return GoogleFonts.notoSansKrTextTheme(ThemeData.dark().textTheme);
    } catch (_) {
      return ThemeData.dark().textTheme;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '스마트 어학 학습',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF38BDF8),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        textTheme: _safeTextTheme(),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF38BDF8),
            foregroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: ApiService.instance.isLoggedIn(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          debugPrint('AuthGate error: ${snapshot.error}');
          return const LoginScreen();
        }
        if (snapshot.data == true) {
          return const DashboardScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
