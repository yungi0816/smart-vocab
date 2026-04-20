import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';
import '../services/lang_service.dart';
import 'quiz_screen.dart';
import 'word_list_screen.dart';
import 'login_screen.dart';
import 'ai_chat_screen.dart';
import 'settings_screen.dart';
import 'review_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic> _todayProgress = {};
  List<dynamic> _days = [];
  List<dynamic> _reviewWords = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    LangService.instance.addListener(_onLangChanged);
    _loadData();
    _checkUpdate();
  }

  @override
  void dispose() {
    LangService.instance.removeListener(_onLangChanged);
    super.dispose();
  }

  void _onLangChanged() {
    _loadData();
  }

  Future<void> _checkUpdate() async {
    final updateInfo = await UpdateService.instance.checkForUpdate();
    if (!mounted || updateInfo == null) return;
    UpdateService.showUpdateDialog(context, updateInfo);
  }

  Future<void> _loadData() async {
    try {
      final lang = LangService.instance.studyLang;
      final today = await ApiService.instance.getTodayProgress(lang: lang);
      final days = await ApiService.instance.getDays(lang: lang);
      // 틀린 단어 Top 조회 (서버에서 최근 학습/시도 수 제공)
      final review = await ApiService.instance.getReviewWords(
        lang: lang,
        scope: 'all',
        limit: 500,
      );
      // 클라이언트에서 가장 많이 틀린 단어 순으로 정렬 (attempt_count - correct_count)
      review.sort((a, b) {
        final aw = (a['attempt_count'] ?? 0) - (a['correct_count'] ?? 0);
        final bw = (b['attempt_count'] ?? 0) - (b['correct_count'] ?? 0);
        return bw.compareTo(aw);
      });
      final topWrong = review
          .where(
            (r) => ((r['attempt_count'] ?? 0) - (r['correct_count'] ?? 0)) > 0,
          )
          .take(6)
          .toList();
      if (mounted) {
        setState(() {
          _todayProgress = today;
          _days = days;
          _reviewWords = topWrong;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showQuizPicker(BuildContext context, String lang) async {
    final ls = LangService.instance;
    final themes = _days
        .map((d) => d['theme']?.toString() ?? '')
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    String? selectedPos = 'all';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ls.tr('quiz_scope_select'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(ls.tr('select_mode_day')),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => QuizScreen(lang: lang),
                          ),
                        );
                      },
                      child: Column(
                        children: const [
                          CircleAvatar(child: Icon(Icons.layers)),
                          SizedBox(height: 6),
                          Text('All'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ..._days.asMap().entries.map((entry) {
                      final i = entry.key;
                      final d = entry.value;
                      final label = ls.localizeDayLabel(
                        d['day_index']?.toString(),
                      );
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QuizScreen(
                                  lang: lang,
                                  initialDay: d['day_index']?.toString(),
                                ),
                              ),
                            );
                          },
                          child: Column(
                            children: [
                              CircleAvatar(child: Text('${i + 1}')),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: 56,
                                child: Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(ls.tr('select_mode_topic')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QuizScreen(lang: lang),
                        ),
                      );
                    },
                    child: Chip(label: Text(ls.tr('all'))),
                  ),
                  ...themes.map(
                    (t) => GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                QuizScreen(lang: lang, initialTheme: t),
                          ),
                        );
                      },
                      child: Chip(label: Text(t)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(ls.tr('pos_filter_label')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(ls.tr('all')),
                    selected: selectedPos == 'all',
                    onSelected: (_) => selectedPos = 'all',
                  ),
                  ChoiceChip(
                    label: const Text('명사'),
                    selected: selectedPos == 'noun',
                    onSelected: (_) => selectedPos = 'noun',
                  ),
                  ChoiceChip(
                    label: const Text('동사'),
                    selected: selectedPos == 'verb',
                    onSelected: (_) => selectedPos = 'verb',
                  ),
                  ChoiceChip(
                    label: const Text('형용사'),
                    selected: selectedPos == 'adj',
                    onSelected: (_) => selectedPos = 'adj',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => QuizScreen(
                          lang: lang,
                          initialDay: null,
                          initialTheme: null,
                          initialPos: selectedPos == 'all' ? null : selectedPos,
                        ),
                      ),
                    );
                  },
                  child: Text(ls.tr('start_quiz')),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showMeaningSheet(BuildContext context, Map<String, dynamic> word) {
    final ls = LangService.instance;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              word['spell'] ?? '',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              word['meaning'] ?? ls.tr('no_meaning'),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(ls.tr('close')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ls = LangService.instance;
    final quota =
        _todayProgress['dailyQuota'] ?? ApiService.instance.dailyQuota;
    final dayQuota =
        _todayProgress['dailyDayQuota'] ?? ApiService.instance.dailyDayQuota;
    final studied = _todayProgress['studiedCount'] ?? 0;
    final studiedDays = _todayProgress['studiedDayCount'] ?? 0;
    final accuracy = _todayProgress['accuracy'] ?? 0;
    final progress = quota > 0 ? (studied / quota).clamp(0.0, 1.0) : 0.0;
    final int dayTotal = _days.isNotEmpty
        ? _days.length
        : (dayQuota > 0 ? dayQuota : 1);
    final dayProgress = dayTotal > 0
        ? (studiedDays / dayTotal).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 헤더
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${ls.tr('hello')} 👋',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${ApiService.instance.userName ?? ''}${ls.tr('greeting_suffix')}',
                                style: const TextStyle(color: Colors.white54),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // UI 언어 토글 (🇰🇷/🇯🇵)
                              GestureDetector(
                                onTap: () async {
                                  await ls.toggleUiLang();
                                },
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder: (child, anim) =>
                                      ScaleTransition(
                                        scale: anim,
                                        child: child,
                                      ),
                                  child: Text(
                                    ls.uiFlag,
                                    key: ValueKey(ls.uiLang),
                                    style: const TextStyle(fontSize: 28),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              // 학습 언어 토글 (🇺🇸/🇯🇵/🇰🇷)
                              GestureDetector(
                                onTap: () async {
                                  await ls.toggleStudyLang();
                                },
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 300),
                                  transitionBuilder: (child, anim) =>
                                      ScaleTransition(
                                        scale: anim,
                                        child: child,
                                      ),
                                  child: Text(
                                    ls.studyFlag,
                                    key: ValueKey(ls.studyLang),
                                    style: const TextStyle(fontSize: 24),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(
                                  Icons.settings,
                                  color: Colors.white54,
                                ),
                                onPressed: () async {
                                  final updated = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SettingsScreen(),
                                    ),
                                  );
                                  if (updated == true) {
                                    _loadData();
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.logout,
                                  color: Colors.white54,
                                ),
                                onPressed: () async {
                                  final navigator = Navigator.of(context);
                                  await ApiService.instance.logout();
                                  if (!mounted) return;
                                  navigator.pushAndRemoveUntil(
                                    MaterialPageRoute(
                                      builder: (_) => const LoginScreen(),
                                    ),
                                    (route) => false,
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ).animate().fadeIn(),

                      const SizedBox(height: 24),

                      // 언어 모드 표시
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: ls.isJapaneseUi
                              ? const Color(0xFFDC2626).withValues(alpha: 0.15)
                              : const Color(0xFF38BDF8).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${ls.studyFlag} ${ls.studyLabel} ${ls.tr('mode_suffix')}',
                          style: TextStyle(
                            color: ls.isJapaneseUi
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF38BDF8),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ).animate().fadeIn(delay: 150.ms),

                      const SizedBox(height: 16),

                      // 오늘의 진행률 카드
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.trending_up,
                                    color: Color(0xFF38BDF8),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    ls.tr('today_study'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '$studied / $quota',
                                    style: const TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: progress.toDouble(),
                                  minHeight: 12,
                                  backgroundColor: const Color(0xFF334155),
                                  valueColor: const AlwaysStoppedAnimation(
                                    Color(0xFF38BDF8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${ls.tr('accuracy_label')} $accuracy%',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${(progress * 100).toInt()}% ${ls.tr('complete')}',
                                    style: const TextStyle(
                                      color: Color(0xFF38BDF8),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${ls.tr('day_group_progress')} $studiedDays / $dayTotal',
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    '${(dayProgress * 100).toInt()}% ${ls.tr('complete')}',
                                    style: const TextStyle(
                                      color: Color(0xFF34D399),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value: dayProgress.toDouble(),
                                  minHeight: 8,
                                  backgroundColor: const Color(0xFF334155),
                                  valueColor: const AlwaysStoppedAnimation(
                                    Color(0xFF34D399),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                      // 펫 표시 영역
                      const SizedBox(height: 20),

                      // 빠른 실행 버튼
                      Row(
                        children: [
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.quiz,
                              label: ls.tr('quiz_start'),
                              gradient: const [
                                Color(0xFF38BDF8),
                                Color(0xFF818CF8),
                              ],
                              onTap: () =>
                                  _showQuizPicker(context, ls.studyLang),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.menu_book,
                              label: ls.tr('word_book'),
                              gradient: const [
                                Color(0xFF818CF8),
                                Color(0xFFC084FC),
                              ],
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      WordListScreen(lang: ls.studyLang),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 400.ms),

                      const SizedBox(height: 12),

                      // AI 채팅 + 설정 버튼 Row
                      Row(
                        children: [
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.refresh,
                              label: ls.tr('review'),
                              gradient: const [
                                Color(0xFF06B6D4),
                                Color(0xFF22D3EE),
                              ],
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ReviewScreen(lang: ls.studyLang),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.chat_bubble_outline,
                              label: ls.tr('ai_tutor'),
                              gradient: const [
                                Color(0xFF10B981),
                                Color(0xFF34D399),
                              ],
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AiChatScreen(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 450.ms),

                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.center_focus_strong,
                              label: ls.tr('weakness_quiz'),
                              gradient: const [
                                Color(0xFFF59E0B),
                                Color(0xFFFBBF24),
                              ],
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => QuizScreen(
                                    lang: ls.studyLang,
                                    focusMode: true,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ActionCard(
                              icon: Icons.settings_suggest,
                              label: ls.tr('settings'),
                              gradient: const [
                                Color(0xFF6366F1),
                                Color(0xFF8B5CF6),
                              ],
                              onTap: () async {
                                final updated = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SettingsScreen(),
                                  ),
                                );
                                if (updated == true) {
                                  _loadData();
                                }
                              },
                            ),
                          ),
                        ],
                      ).animate().fadeIn(delay: 500.ms),

                      const SizedBox(height: 24),

                      // 틀린 단어 Top (간단 카드뉴스)
                      if (_reviewWords.isNotEmpty) ...[
                        Text(
                          ls.tr('wrong_words_title'),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 120,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _reviewWords.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 8),
                            itemBuilder: (ctx, idx) {
                              final w = _reviewWords[idx];
                              final wrongCount =
                                  (w['attempt_count'] ?? 0) -
                                  (w['correct_count'] ?? 0);
                              final posLabel = (w['pos'] ?? '').toString();
                              final dayLabel = (w['day_index'] ?? '')
                                  .toString();
                              final meaning = (w['meaning'] ?? '').toString();

                              return InkWell(
                                onTap: () => _showMeaningSheet(context, w),
                                borderRadius: BorderRadius.circular(14),
                                child: Card(
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Container(
                                    width: 240,
                                    padding: const EdgeInsets.all(12),
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Color(0xFF0B1226),
                                          Color(0xFF0F172A),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                w['spell'] ?? '',
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEF4444),
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black26,
                                                    blurRadius: 6,
                                                    offset: Offset(0, 3),
                                                  ),
                                                ],
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '$wrongCount',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          meaning,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const Spacer(),
                                        Row(
                                          children: [
                                            if (posLabel.isNotEmpty) ...[
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white10,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  posLabel,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white10,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                dayLabel,
                                                style: const TextStyle(
                                                  color: Colors.white70,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              ls.tr('tap_to_show_meaning'),
                                              style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Day별 학습 현황
                      Text(
                        ls.tr('day_study'),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ).animate().fadeIn(delay: 500.ms),
                      const SizedBox(height: 12),

                      ..._days.asMap().entries.map((entry) {
                        final i = entry.key;
                        final d = entry.value;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF38BDF8,
                                ).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              ls.localizeThemeLabel(d['theme']?.toString()),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              '${d['word_count']}${ls.tr('word_count_suffix')}',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right,
                              color: Colors.white24,
                            ),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => WordListScreen(
                                  initialDay: d['day_index'],
                                  lang: ls.studyLang,
                                ),
                              ),
                            ),
                          ),
                        ).animate().fadeIn(
                          delay: Duration(milliseconds: 550 + i * 30),
                        );
                      }),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
