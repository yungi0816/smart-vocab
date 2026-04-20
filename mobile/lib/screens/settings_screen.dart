import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/lang_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const List<int> _quotaOptions = [10, 20, 30, 50, 100];
  static const List<int> _dayQuotaOptions = [1, 2, 3, 4];

  int _dailyQuota = 20;
  int _dailyDayQuota = 1;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dailyQuota = ApiService.instance.dailyQuota;
    _dailyDayQuota = ApiService.instance.dailyDayQuota;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final profile = await ApiService.instance.getMySettings();
      if (!mounted) return;
      setState(() {
        _dailyQuota = profile['daily_quota'] ?? _dailyQuota;
        _dailyDayQuota = profile['daily_day_quota'] ?? _dailyDayQuota;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final ls = LangService.instance;
    setState(() => _saving = true);
    try {
      await ApiService.instance.updateLearningSettings(
        dailyQuota: _dailyQuota,
        dailyDayQuota: _dailyDayQuota,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ls.tr('settings_saved'))));
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ls.tr('settings_save_failed'))));
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ls = LangService.instance;
    return ListenableBuilder(
      listenable: ls,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(ls.tr('settings')),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ls.tr('signup_quota'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
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
                                onSelected: (_) => setState(() {
                                  _dailyQuota = q;
                                }),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ls.tr('daily_day_quota'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            ls.tr('daily_day_quota_desc'),
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
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
                                onSelected: (_) => setState(() {
                                  _dailyDayQuota = q;
                                }),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(ls.tr('save')),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
