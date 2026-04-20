import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../services/lang_service.dart';
import 'dashboard_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  void _showServerUrlDialog() {
    final urlCtrl = TextEditingController(text: ApiService.instance.baseUrl);
    bool testing = false;
    String? testResult;
    final ls = LangService.instance;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(ls.tr('server_url_title'), style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: ls.tr('server_url_hint'),
                  hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: testing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.wifi_find, color: Colors.white54),
                    onPressed: testing ? null : () async {
                      setDialogState(() { testing = true; testResult = null; });
                      final url = urlCtrl.text.trim();
                      await ApiService.instance.setServerUrl(url);
                      final ok = await ApiService.instance.testConnection();
                      setDialogState(() {
                        testing = false;
                        testResult = ok ? ls.tr('server_test_ok') : ls.tr('server_test_fail');
                      });
                    },
                  ),
                ),
              ),
              if (testResult != null) ...[
                const SizedBox(height: 12),
                Text(testResult!, style: TextStyle(
                  color: testResult!.startsWith('✅') ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 13,
                )),
              ],
              const SizedBox(height: 12),
              Text(
                ls.tr('server_url_desc'),
                style: const TextStyle(color: Colors.white38, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ls.tr('cancel')),
            ),
            FilledButton(
              onPressed: () async {
                await ApiService.instance.setServerUrl(urlCtrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(ls.tr('save')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _login() async {
    final ls = LangService.instance;
    if (_idCtrl.text.isEmpty || _pwCtrl.text.isEmpty) {
      setState(() => _error = ls.tr('login_error_empty'));
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final result = await ApiService.instance.login(_idCtrl.text, _pwCtrl.text);
      if (result['success'] == true && mounted) {
        await LangService.instance.load();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      } else {
        setState(() => _error = result['error'] ?? ls.tr('login_error_wrong'));
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final msg = e.response?.data['error'] ?? ls.tr('login_error_wrong');
        setState(() => _error = msg);
      } else {
        setState(() => _error = ls.tr('login_error_server'));
        if (mounted) _showServerUrlDialog();
      }
    } catch (e) {
      setState(() => _error = ls.tr('login_error_unknown'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ls = LangService.instance;
    return ListenableBuilder(
      listenable: ls,
      builder: (context, _) => Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // 언어 국기 토글 (우상단)
            Positioned(
              top: 8, right: 12,
              child: GestureDetector(
                onTap: () async {
                  await ls.toggleUiLang();
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(ls.uiFlag, style: const TextStyle(fontSize: 22)),
                ),
              ),
            ).animate().fadeIn(delay: 200.ms),

            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 로고
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF38BDF8), Color(0xFF818CF8)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(Icons.school, size: 40, color: Colors.white),
                    ).animate().fadeIn(duration: 600.ms).scale(delay: 200.ms),

                    const SizedBox(height: 24),

                    Text(
                      ls.tr('app_title'),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ).animate().fadeIn(delay: 300.ms),

                    const SizedBox(height: 8),
                    Text(
                      ls.tr('app_subtitle'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white54,
                      ),
                    ).animate().fadeIn(delay: 400.ms),

                    const SizedBox(height: 48),

                    // 아이디
                    TextField(
                      controller: _idCtrl,
                      decoration: InputDecoration(
                        hintText: ls.tr('login_id'),
                        prefixIcon: const Icon(Icons.person_outline),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.1),

                    const SizedBox(height: 16),

                    // 비밀번호
                    TextField(
                      controller: _pwCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: ls.tr('login_pw'),
                        prefixIcon: const Icon(Icons.lock_outline),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _login(),
                    ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.1),

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                    ],

                    const SizedBox(height: 24),

                    // 로그인 버튼
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _login,
                        child: _loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(ls.tr('login')),
                      ),
                    ).animate().fadeIn(delay: 700.ms),

                    const SizedBox(height: 16),

                    // 회원가입
                    TextButton(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen()));
                      },
                      child: Text(ls.tr('no_account'), style: const TextStyle(color: Color(0xFF38BDF8))),
                    ).animate().fadeIn(delay: 800.ms),

                    const SizedBox(height: 24),

                    // 서버 URL 설정
                    TextButton.icon(
                      onPressed: _showServerUrlDialog,
                      icon: const Icon(Icons.settings, size: 16, color: Colors.white24),
                      label: Text(
                        '${ls.tr('server_prefix')}${Uri.tryParse(ApiService.instance.baseUrl)?.host ?? ApiService.instance.baseUrl}',
                        style: const TextStyle(color: Colors.white24, fontSize: 11),
                      ),
                    ).animate().fadeIn(delay: 900.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}
