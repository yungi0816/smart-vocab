import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../services/ai_service.dart';
import '../services/lang_service.dart';
import '../services/tts_service.dart';
import 'review_screen.dart';

class QuizScreen extends StatefulWidget {
  final String lang;
  final String? initialDay;
  final String? initialTheme;
  final String? initialPos;
  final bool focusMode;
  const QuizScreen({
    super.key,
    this.lang = 'ENG',
    this.initialDay,
    this.initialTheme,
    this.initialPos,
    this.focusMode = false,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  final SafeTts _tts = SafeTts();
  Map<String, dynamic>? _quiz;
  Map<String, dynamic> _session = {};
  List<dynamic> _scopes = [];
  String? _selectedDay;
  String? _selectedTheme;
  String? _selectedPos;
  bool _allowExtraAfterQuota = false;
  bool _quotaCompleted = false;
  String? _quotaMessage;
  int? _selectedIdx;
  bool _answered = false;
  bool _correct = false;
  bool _loading = true;
  int _score = 0;
  int _total = 0;
  String? _answerMessage;
  String? _explanation;
  bool _loadingExplanation = false;

  @override
  void initState() {
    super.initState();
    _initTts();
    // apply any initial scope passed from caller
    _selectedDay = widget.initialDay;
    _selectedTheme = widget.initialTheme;
    _selectedPos = widget.initialPos;
    _loadScopes();
  }

  Future<void> _initTts() async {
    final locale = LangService.instance.ttsLocale;
    await _tts.configure(locale);
  }

  Future<void> _loadScopes() async {
    try {
      final days = await ApiService.instance.getDays(lang: widget.lang);
      if (!mounted) return;
      setState(() => _scopes = days);
    } catch (_) {
      // ignore
    }
    await _loadQuiz();
  }

  List<String> get _dayOptions {
    final ordered = <String>[];
    final seen = <String>{};
    for (final row in _scopes) {
      final day = row['day_index']?.toString();
      if (day == null || day.isEmpty || seen.contains(day)) continue;
      seen.add(day);
      ordered.add(day);
    }
    return ordered;
  }

  List<String> get _themeOptions {
    final ordered = <String>[];
    final seen = <String>{};
    for (final row in _scopes) {
      final day = row['day_index']?.toString();
      if (_selectedDay != null && day != _selectedDay) continue;
      final theme = row['theme']?.toString();
      if (theme == null || theme.isEmpty || seen.contains(theme)) continue;
      seen.add(theme);
      ordered.add(theme);
    }
    return ordered;
  }

  Future<void> _onDayChanged(String? day) async {
    setState(() {
      _selectedDay = day;
      _selectedTheme = null;
      _allowExtraAfterQuota = false;
    });
    await _loadQuiz();
  }

  Future<void> _onThemeChanged(String? theme) async {
    setState(() {
      _selectedTheme = theme;
      _allowExtraAfterQuota = false;
    });
    await _loadQuiz();
  }

  Future<void> _resetScope() async {
    setState(() {
      _selectedDay = null;
      _selectedTheme = null;
      _allowExtraAfterQuota = false;
    });
    await _loadQuiz();
  }

  Future<void> _loadQuiz() async {
    setState(() {
      _loading = true;
      _answered = false;
      _selectedIdx = null;
      _answerMessage = null;
      _explanation = null;
    });
    try {
      final quiz = await ApiService.instance.getQuiz(
        lang: widget.lang,
        day: _selectedDay,
        theme: _selectedTheme,
        allowExtra: _allowExtraAfterQuota,
        focusMode: widget.focusMode,
        pos: _selectedPos,
      );
      if (quiz['status'] == 'quota_completed') {
        if (!mounted) return;
        setState(() {
          _quiz = null;
          _session = Map<String, dynamic>.from(quiz['session'] ?? {});
          _quotaCompleted = true;
          _quotaMessage = quiz['message']?.toString();
          _loading = false;
        });
        return;
      }

      final stage = quiz['session']?['stage']?.toString();
      String? quotaMessage;
      if (stage == 'wrong_review') {
        quotaMessage = LangService.instance.tr('wrong_review_mode');
      } else if (stage == 'extra_new') {
        quotaMessage = LangService.instance.tr('extra_study_mode');
      } else if (stage == 'focus_review') {
        quotaMessage = LangService.instance.tr('focus_review_mode');
      }

      setState(() {
        _quiz = quiz;
        _session = Map<String, dynamic>.from(quiz['session'] ?? {});
        _quotaCompleted = false;
        _quotaMessage = quotaMessage;
        _loading = false;
      });

      // 영→한 모드이면 질문(영어 단어) 자동 TTS
      if (quiz['quizType'] == 'SPELL_TO_MEANING') {
        await _tts.speak(quiz['question']?.toString(), userInitiated: false);
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _selectAnswer(int idx) async {
    if (_answered) return;

    final choices = _quiz!['choices'] as List;
    final selectedWordId = choices[idx]['wordId'];
    final correctWordId = _quiz!['correctWordId'];
    final isCorrect = selectedWordId == correctWordId;

    setState(() {
      _selectedIdx = idx;
      _answered = true;
      _correct = isCorrect;
      _total++;
      if (isCorrect) _score++;
      _answerMessage = isCorrect
          ? LangService.instance.tr('quiz_correct_basic')
          : LangService.instance.tr('quiz_wrong_basic');
    });

    // 서버에 기록
    try {
      await ApiService.instance.recordProgress(correctWordId, isCorrect);
    } catch (_) {
      // Progress sync failure should not break the quiz UI.
    }

    // 틀렸으면 AI 해설 요청
    if (!isCorrect) {
      setState(() => _loadingExplanation = true);
      final correctChoice = choices.firstWhere(
        (c) => c['wordId'] == correctWordId,
        orElse: () => {'label': ''},
      );
      final explanation = await AiService.instance.explainWord(
        word: _quiz!['question']?.toString() ?? '',
        meaning: _quiz!['quizType'] == 'SPELL_TO_MEANING'
            ? correctChoice['label']?.toString() ?? ''
            : _quiz!['question']?.toString() ?? '',
        userAnswer: choices[idx]['label']?.toString() ?? '',
        correctAnswer: correctChoice['label']?.toString() ?? '',
      );
      if (mounted) {
        setState(() {
          _explanation = explanation;
          _loadingExplanation = false;
        });
      }
    }
  }

  Color _getChoiceColor(int idx) {
    if (!_answered) return const Color(0xFF1E293B);

    final choices = _quiz!['choices'] as List;
    final isCorrectChoice = choices[idx]['wordId'] == _quiz!['correctWordId'];

    if (isCorrectChoice) return const Color(0xFF065F46); // 초록
    if (idx == _selectedIdx && !_correct) return const Color(0xFF7F1D1D); // 빨강
    return const Color(0xFF1E293B);
  }

  @override
  Widget build(BuildContext context) {
    final ls = LangService.instance;
    final dailyQuota = _session['dailyQuota'] ?? ApiService.instance.dailyQuota;
    final studiedCount = _session['studiedCount'] ?? 0;
    final studiedDayCount = _session['studiedDayCount'] ?? 0;
    final wordProgress = dailyQuota > 0
        ? (studiedCount / dailyQuota).clamp(0.0, 1.0)
        : 0.0;

    // total available day groups (used to show e.g. 5/31)
    final int dayTotal = _dayOptions.isNotEmpty ? _dayOptions.length : 31;
    final dayProgress = dayTotal > 0
        ? (studiedDayCount / dayTotal).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(ls.tr('quiz')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '$_score / $_total',
                style: const TextStyle(
                  color: Color(0xFF38BDF8),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white54),
            onPressed: _loadQuiz,
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey(
                                      'day_${_selectedDay ?? '__all__'}',
                                    ),
                                    initialValue: _selectedDay ?? '__all__',
                                    decoration: InputDecoration(
                                      labelText: ls.tr('quiz_scope_day'),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: '__all__',
                                        child: Text(ls.tr('all')),
                                      ),
                                      ..._dayOptions.map((day) {
                                        return DropdownMenuItem(
                                          value: day,
                                          child: Text(
                                            ls.localizeDayLabel(day),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }),
                                    ],
                                    onChanged: (value) {
                                      _onDayChanged(
                                        value == null || value == '__all__'
                                            ? null
                                            : value,
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    key: ValueKey(
                                      'theme_${_selectedTheme ?? '__all__'}',
                                    ),
                                    initialValue: _selectedTheme ?? '__all__',
                                    decoration: InputDecoration(
                                      labelText: ls.tr('quiz_scope_theme'),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    items: [
                                      DropdownMenuItem(
                                        value: '__all__',
                                        child: Text(ls.tr('all')),
                                      ),
                                      ..._themeOptions.map((theme) {
                                        return DropdownMenuItem(
                                          value: theme,
                                          child: Text(
                                            ls.localizeThemeLabel(theme),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }),
                                    ],
                                    onChanged: (value) {
                                      _onThemeChanged(
                                        value == null || value == '__all__'
                                            ? null
                                            : value,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            if (_selectedDay != null || _selectedTheme != null)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: _resetScope,
                                  icon: const Icon(Icons.clear, size: 16),
                                  label: Text(ls.tr('quiz_scope_reset')),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Text(
                                  '${ls.tr('today_study')} $studiedCount / $dailyQuota',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${(wordProgress * 100).toInt()}%',
                                  style: const TextStyle(
                                    color: Color(0xFF38BDF8),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: wordProgress.toDouble(),
                                minHeight: 8,
                                backgroundColor: const Color(0xFF334155),
                                valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFF38BDF8),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Text(
                                  '${ls.tr('day_group_progress')} $studiedDayCount / $dayTotal',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${(dayProgress * 100).toInt()}%',
                                  style: const TextStyle(
                                    color: Color(0xFF34D399),
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
                            if (_quotaMessage != null) ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFF59E0B,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _quotaMessage!,
                                    style: const TextStyle(
                                      color: Color(0xFFFBBF24),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_quotaCompleted)
                      Expanded(
                        child: Center(
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.emoji_events,
                                    color: Color(0xFFFBBF24),
                                    size: 44,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _quotaMessage ?? ls.tr('quota_completed'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ReviewScreen(lang: widget.lang),
                                        ),
                                      ),
                                      icon: const Icon(Icons.refresh),
                                      label: Text(ls.tr('review')),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _allowExtraAfterQuota = true;
                                          _quotaCompleted = false;
                                          _quotaMessage = ls.tr(
                                            'extra_study_mode',
                                          );
                                        });
                                        _loadQuiz();
                                      },
                                      icon: const Icon(Icons.auto_stories),
                                      label: Text(ls.tr('continue_new_words')),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    else if (_quiz == null)
                      Expanded(
                        child: Center(child: Text(ls.tr('quiz_no_load'))),
                      )
                    else
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF818CF8,
                                  ).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${ls.localizeDayLabel(_quiz!['dayIndex']?.toString())} · ${ls.localizeThemeLabel(_quiz!['theme']?.toString())}',
                                  style: const TextStyle(
                                    color: Color(0xFF818CF8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ).animate().fadeIn(),
                              const SizedBox(height: 18),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(22),
                                  child: Column(
                                    children: [
                                      Text(
                                        _quiz!['quizType'] == 'SPELL_TO_MEANING'
                                            ? ls.tr('spell_to_meaning')
                                            : ls.tr('meaning_to_spell'),
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _quiz!['question'],
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      if (_quiz!['quizType'] ==
                                          'SPELL_TO_MEANING') ...[
                                        const SizedBox(height: 12),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.volume_up,
                                            color: Color(0xFF38BDF8),
                                            size: 28,
                                          ),
                                          onPressed: () => _tts.speak(
                                            _quiz!['question']?.toString(),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ).animate().fadeIn(delay: 100.ms),
                              const SizedBox(height: 16),
                              ...(_quiz!['choices'] as List).asMap().entries.map((
                                entry,
                              ) {
                                final idx = entry.key;
                                final choice = entry.value;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _getChoiceColor(idx),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                            horizontal: 20,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            side: BorderSide(
                                              color:
                                                  _answered &&
                                                      (_quiz!['choices']
                                                              as List)[idx]['wordId'] ==
                                                          _quiz!['correctWordId']
                                                  ? const Color(0xFF10B981)
                                                  : Colors.transparent,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                        onPressed: () => _selectAnswer(idx),
                                        child: Text(
                                          choice['label'],
                                          style: const TextStyle(fontSize: 15),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              if (_answered) ...[
                                const SizedBox(height: 10),
                                Text(
                                  _answerMessage ??
                                      (_correct
                                          ? ls.tr('quiz_correct_basic')
                                          : ls.tr('quiz_wrong_basic')),
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: _correct
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444),
                                  ),
                                ).animate().fadeIn().scale(),
                                if (_loadingExplanation)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 12),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                if (_explanation != null) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFF334155),
                                      ),
                                    ),
                                    child: Text(
                                      _explanation!,
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        height: 1.5,
                                      ),
                                    ),
                                  ).animate().fadeIn(delay: 200.ms),
                                ],
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _loadQuiz,
                                    child: Text(ls.tr('next_quiz')),
                                  ),
                                ).animate().fadeIn(delay: 200.ms),
                              ],
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
