import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ai_service.dart';
import '../services/lang_service.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  static const _accent = Color(0xFF38BDF8);

  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final List<_ChatMsg> _messages = [];
  bool _loading = false;
  bool _checkingAuth = true;

  @override
  void initState() {
    super.initState();
    _checkAuthAndGreet();
  }

  Future<void> _checkAuthAndGreet() async {
    await AiService.instance.checkAuthStatus();
    if (!mounted) return;

    final ls = LangService.instance;
    setState(() {
      _checkingAuth = false;
      _messages.add(_ChatMsg(text: ls.tr('ai_chat_greeting'), isUser: false));
      if (!AiService.instance.isAuthenticated) {
        _messages.add(_ChatMsg(text: ls.tr('ai_auth_hint'), isUser: false));
      }
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _loading) return;

    setState(() {
      _messages.add(_ChatMsg(text: text, isUser: true));
      _loading = true;
    });
    _msgCtrl.clear();
    _scrollToBottom();

    final history = _messages
        .map(
          (m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text},
        )
        .toList();

    final reply = await AiService.instance.chat(
      message: text,
      history: history,
    );

    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMsg(text: reply, isUser: false));
      _loading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(100.ms, () {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: 300.ms,
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ls = LangService.instance;
    if (_checkingAuth) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(ls.tr('ai_tutor')),
        centerTitle: true,
        actions: [
          if (!AiService.instance.isAuthenticated)
            TextButton.icon(
              onPressed: _showAuthDialog,
              icon: const Icon(Icons.key, size: 18, color: Color(0xFFFBBF24)),
              label: Text(
                ls.tr('ai_auth'),
                style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(
                Icons.check_circle,
                color: Color(0xFF10B981),
                size: 20,
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: _messages.length + (_loading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) return _buildTypingIndicator();
                return _buildMessage(_messages[index]);
              },
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              8,
              8 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(top: BorderSide(color: Color(0xFF334155))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: ls.tr('ai_chat_hint'),
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    maxLines: 3,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  onPressed: _loading ? null : _send,
                  backgroundColor: _accent,
                  child: const Icon(Icons.send, size: 18, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAuthDialog() async {
    final ls = LangService.instance;
    final deviceData = await AiService.instance.startDeviceAuth();
    if (!mounted) return;
    if (deviceData == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ls.tr('server_test_fail'))));
      return;
    }

    final userCode = deviceData['user_code'] as String? ?? '';
    final verificationUri =
        deviceData['verification_uri'] as String? ??
        'https://github.com/login/device';
    final deviceCode = deviceData['device_code'] as String? ?? '';
    final interval = (deviceData['interval'] as int?) ?? 5;

    bool authComplete = false;
    Timer? pollTimer;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            pollTimer ??= Timer.periodic(Duration(seconds: interval), (
              _,
            ) async {
              final result = await AiService.instance.pollDeviceAuth(
                deviceCode,
              );
              if (result['success'] == true) {
                pollTimer?.cancel();
                authComplete = true;
                if (ctx.mounted) Navigator.of(ctx).pop();
              }
            });

            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                ls.tr('ai_auth_title'),
                style: const TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ls.tr('ai_auth_code_desc'),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: userCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(ls.tr('code_copied')),
                          duration: const Duration(seconds: 1),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _accent),
                      ),
                      child: Text(
                        userCode,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _accent,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(verificationUri),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.open_in_browser, size: 18),
                      label: Text(ls.tr('open_auth_page')),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        ls.tr('waiting_auth'),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    pollTimer?.cancel();
                    Navigator.of(ctx).pop();
                  },
                  child: Text(
                    ls.tr('cancel'),
                    style: const TextStyle(color: Colors.white54),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    pollTimer?.cancel();

    if (authComplete && mounted) {
      setState(() {
        _messages.add(_ChatMsg(text: ls.tr('ai_auth_complete'), isUser: false));
      });
    }
  }

  Widget _buildMessage(_ChatMsg msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.2),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
            border: Border.all(color: _accent.withValues(alpha: 0.3)),
          ),
          child: Text(
            msg.text,
            style: const TextStyle(color: Colors.white, height: 1.4),
          ),
        ),
      ).animate().fadeIn(duration: 200.ms);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.school, color: _accent, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Text(
              msg.text,
              style: const TextStyle(color: Colors.white, height: 1.4),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildTypingIndicator() {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(Icons.school, color: _accent, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3,
              (i) =>
                  Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: const BoxDecoration(
                          color: Colors.white38,
                          shape: BoxShape.circle,
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat())
                      .fadeIn(
                        delay: Duration(milliseconds: i * 200),
                        duration: 400.ms,
                      )
                      .fadeOut(delay: 400.ms),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatMsg {
  final String text;
  final bool isUser;
  const _ChatMsg({required this.text, required this.isUser});
}
