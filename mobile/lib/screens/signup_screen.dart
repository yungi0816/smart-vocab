import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:dio/dio.dart';
import '../services/api_service.dart';
import '../services/lang_service.dart';
import 'dashboard_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  int _dailyQuota = 20;
  int _dailyDayQuota = 1;
  bool _loading = false;
  String? _error;

  final List<int> _quotaOptions = [10, 20, 30, 50, 100];
  final List<int> _dayQuotaOptions = [1, 2, 3, 4];

  Future<void> _signup() async {
    final ls = LangService.instance;
    if (_idCtrl.text.isEmpty ||
        _pwCtrl.text.isEmpty ||
        _nameCtrl.text.isEmpty) {
      setState(() => _error = ls.tr('signup_error_empty'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiService.instance.signup(
        _idCtrl.text,
        _pwCtrl.text,
        _nameCtrl.text,
        _dailyQuota,
        dailyDayQuota: _dailyDayQuota,
      );
      if (result['success'] == true && mounted) {
        await LangService.instance.load();
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
          (route) => false,
        );
      }
    } on DioException catch (e) {
      if (e.response != null) {
        final msg = e.response?.data['error'] ?? ls.tr('signup_error_empty');
        setState(() => _error = msg);
      } else {
        setState(() => _error = ls.tr('signup_error_server'));
      }
    } catch (e) {
      setState(() => _error = ls.tr('signup_error_unknown'));
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
        appBar: AppBar(
          title: Text(ls.tr('signup')),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ls.tr('signup_welcome'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ).animate().fadeIn(),
                const SizedBox(height: 8),
                Text(
                  ls.tr('signup_desc'),
                  style: const TextStyle(color: Colors.white54),
                ).animate().fadeIn(delay: 100.ms),

                const SizedBox(height: 32),

                _buildField(
                  ls.tr('signup_name'),
                  _nameCtrl,
                  Icons.badge_outlined,
                  300,
                ),
                const SizedBox(height: 16),
                _buildField(
                  ls.tr('login_id'),
                  _idCtrl,
                  Icons.person_outline,
                  400,
                ),
                const SizedBox(height: 16),
                _buildField(
                  ls.tr('login_pw'),
                  _pwCtrl,
                  Icons.lock_outline,
                  500,
                  obscure: true,
                ),

                const SizedBox(height: 28),

                // 하루 할당량 선택
                Text(
                  ls.tr('signup_quota'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ).animate().fadeIn(delay: 600.ms),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  children: _quotaOptions.map((q) {
                    final selected = q == _dailyQuota;
                    return ChoiceChip(
                      label: Text('$q ${ls.tr('words_per_day')}'),
                      selected: selected,
                      selectedColor: const Color(0xFF38BDF8),
                      backgroundColor: const Color(0xFF1E293B),
                      labelStyle: TextStyle(
                        color: selected
                            ? const Color(0xFF0F172A)
                            : Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setState(() => _dailyQuota = q),
                    );
                  }).toList(),
                ).animate().fadeIn(delay: 700.ms),

                const SizedBox(height: 18),
                Text(
                  ls.tr('daily_day_quota'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ).animate().fadeIn(delay: 730.ms),
                const SizedBox(height: 6),
                Text(
                  ls.tr('daily_day_quota_desc'),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ).animate().fadeIn(delay: 760.ms),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  children: _dayQuotaOptions.map((q) {
                    final selected = q == _dailyDayQuota;
                    return ChoiceChip(
                      label: Text('${ls.tr('day_group_prefix')} $q'),
                      selected: selected,
                      selectedColor: const Color(0xFF34D399),
                      backgroundColor: const Color(0xFF1E293B),
                      labelStyle: TextStyle(
                        color: selected
                            ? const Color(0xFF0F172A)
                            : Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                      onSelected: (_) => setState(() => _dailyDayQuota = q),
                    );
                  }).toList(),
                ).animate().fadeIn(delay: 800.ms),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13,
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _signup,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(ls.tr('signup')),
                  ),
                ).animate().fadeIn(delay: 800.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    String hint,
    TextEditingController ctrl,
    IconData icon,
    int delayMs, {
    bool obscure = false,
  }) {
    return TextField(
          controller: ctrl,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delayMs))
        .slideX(begin: -0.1);
  }
}
