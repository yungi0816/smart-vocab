import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../services/lang_service.dart';
import '../services/tts_service.dart';

class WordListScreen extends StatefulWidget {
  final String? initialDay;
  final String lang;

  const WordListScreen({super.key, this.initialDay, this.lang = 'ENG'});

  @override
  State<WordListScreen> createState() => _WordListScreenState();
}

class _WordListScreenState extends State<WordListScreen> {
  final SafeTts _tts = SafeTts();
  List<dynamic> _days = [];
  List<dynamic> _words = [];
  String? _selectedDay;
  bool _hideMeaning = false;
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDay;
    _initTts();
    _loadDays();
  }

  Future<void> _initTts() async {
    final locale = LangService.instance.ttsLocale;
    await _tts.configure(locale);
  }

  Future<void> _loadDays() async {
    try {
      final days = await ApiService.instance.getDays(lang: widget.lang);
      setState(() => _days = days);
      await _loadWords();
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadWords() async {
    setState(() => _loading = true);
    try {
      final words = await ApiService.instance.getWords(
        day: _selectedDay,
        lang: widget.lang,
      );
      setState(() {
        _words = words;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  List<dynamic> get _filteredWords {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return _words;
    return _words
        .where(
          (w) =>
              (w['spell']?.toString().toLowerCase().contains(q) ?? false) ||
              (w['meaning']?.toString().toLowerCase().contains(q) ?? false),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final ls = LangService.instance;
    final filtered = _filteredWords;

    return Scaffold(
      appBar: AppBar(
        title: Text(ls.tr('word_list')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              _hideMeaning ? Icons.visibility_off : Icons.visibility,
              color: const Color(0xFF38BDF8),
            ),
            onPressed: () => setState(() => _hideMeaning = !_hideMeaning),
            tooltip: _hideMeaning
                ? ls.tr('show_meaning')
                : ls.tr('hide_meaning'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Day 필터 + 검색
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: ls.tr('search_hint'),
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          // Day 칩 스크롤
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _DayChip(
                  label: ls.tr('all'),
                  selected: _selectedDay == null,
                  onTap: () {
                    setState(() => _selectedDay = null);
                    _loadWords();
                  },
                ),
                ..._days.map(
                  (d) => _DayChip(
                    label: ls.localizeDayLabel(d['day_index']?.toString()),
                    selected: _selectedDay == d['day_index']?.toString(),
                    onTap: () {
                      setState(
                        () => _selectedDay = d['day_index']?.toString(),
                      );
                      _loadWords();
                    },
                  ),
                ),
              ],
            ),
          ),

          // 단어 수
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${filtered.length}${ls.tr('word_count_suffix')}',
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          ),

          // 단어 리스트
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                ? Center(
                    child: Text(
                      ls.tr('no_results'),
                      style: const TextStyle(color: Colors.white38),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final w = filtered[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          title: Text(
                            w['spell']?.toString() ?? '',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: _hideMeaning
                              ? Text(
                                  ls.tr('tap_to_show_meaning'),
                                  style: const TextStyle(
                                    color: Colors.white24,
                                    fontSize: 13,
                                  ),
                                )
                              : Text(
                                  w['meaning']?.toString() ?? '',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14,
                                  ),
                                ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.volume_up,
                              color: Color(0xFF38BDF8),
                              size: 22,
                            ),
                            onPressed: () =>
                                _tts.speak(w['spell']?.toString()),
                          ),
                          onTap: _hideMeaning
                              ? () {
                                  showModalBottomSheet(
                                    context: context,
                                    backgroundColor: const Color(0xFF1E293B),
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                    ),
                                    builder: (_) => Padding(
                                      padding: const EdgeInsets.all(28),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            w['spell']?.toString() ?? '',
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            w['meaning']?.toString() ?? '',
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                        ],
                                      ),
                                    ),
                                  );
                                }
                              : null,
                        ),
                      ).animate().fadeIn(
                        delay: Duration(milliseconds: 30 * (index % 20)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    _searchCtrl.dispose();
    super.dispose();
  }
}

class _DayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? const Color(0xFF0F172A) : Colors.white54,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
