import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/lang_service.dart';
import '../services/tts_service.dart';

class ReviewScreen extends StatefulWidget {
  final String lang;

  const ReviewScreen({super.key, required this.lang});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final SafeTts _tts = SafeTts();
  final TextEditingController _searchCtrl = TextEditingController();
  List<dynamic> _words = [];
  bool _loading = true;
  bool _hideMeaning = false;
  String _scope = 'today'; // today | all

  @override
  void initState() {
    super.initState();
    _initTts();
    _loadReviewWords();
  }

  Future<void> _initTts() async {
    final locale = LangService.instance.ttsLocale;
    await _tts.configure(locale);
  }

  Future<void> _loadReviewWords() async {
    setState(() => _loading = true);
    try {
      final words = await ApiService.instance.getReviewWords(
        lang: widget.lang,
        scope: _scope,
      );
      if (!mounted) return;
      setState(() {
        _words = words;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<dynamic> get _filteredWords {
    final q = _searchCtrl.text.toLowerCase();
    if (q.isEmpty) return _words;
    return _words.where((w) {
      final spell = (w['spell'] ?? '').toString().toLowerCase();
      final meaning = (w['meaning'] ?? '').toString().toLowerCase();
      final theme = (w['theme'] ?? '').toString().toLowerCase();
      return spell.contains(q) || meaning.contains(q) || theme.contains(q);
    }).toList();
  }

  void _showMeaningBottomSheet(dynamic word) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              word['spell'] ?? '',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              word['meaning'] ?? '',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              '${LangService.instance.localizeDayLabel(word['day_index']?.toString())} · ${LangService.instance.localizeThemeLabel(word['theme']?.toString())}',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tts.stop();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ls = LangService.instance;
    final filtered = _filteredWords;

    return ListenableBuilder(
      listenable: ls,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(ls.tr('review')),
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
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(ls.tr('review_today')),
                    selected: _scope == 'today',
                    selectedColor: const Color(0xFF38BDF8),
                    backgroundColor: const Color(0xFF1E293B),
                    labelStyle: TextStyle(
                      color: _scope == 'today'
                          ? const Color(0xFF0F172A)
                          : Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) {
                      setState(() => _scope = 'today');
                      _loadReviewWords();
                    },
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: Text(ls.tr('review_all')),
                    selected: _scope == 'all',
                    selectedColor: const Color(0xFF34D399),
                    backgroundColor: const Color(0xFF1E293B),
                    labelStyle: TextStyle(
                      color: _scope == 'all'
                          ? const Color(0xFF0F172A)
                          : Colors.white70,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) {
                      setState(() => _scope = 'all');
                      _loadReviewWords();
                    },
                  ),
                  const Spacer(),
                  Text(
                    '${filtered.length}${ls.tr('word_count_suffix')}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                  ? Center(
                      child: Text(
                        ls.tr('no_review_words'),
                        style: const TextStyle(color: Colors.white38),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final w = filtered[index];
                        final subtitle = _hideMeaning
                            ? ls.tr('tap_to_show_meaning')
                            : (w['meaning'] ?? '');
                        return Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            title: Text(
                              w['spell'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subtitle,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${ls.localizeDayLabel(w['day_index']?.toString())} · ${ls.localizeThemeLabel(w['theme']?.toString())}',
                                  style: const TextStyle(
                                    color: Colors.white30,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
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
                                ? () => _showMeaningBottomSheet(w)
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
