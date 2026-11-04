import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

import '../../ai/ask_ai_client.dart';
import '../../app.dart';
import '../../widgets/motion.dart';

class _Message {
  const _Message({required this.role, required this.text, this.isError = false});

  final String role; // 'user' | 'assistant'
  final String text;
  final bool isError;
}

const _examplePrompts = [
  "What's running low in the pantry?",
  'How much did we spend this month?',
  "What's still on the shopping list?",
  'Who paid the most this month?',
];

/// A chat screen for the family's own data: shopping list, pantry and
/// purchase history, read live from Firestore by the notify Worker and
/// handed to a Groq model so answers are grounded in this household's
/// actual data — never invented.
class AskAiScreen extends StatefulWidget {
  const AskAiScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<AskAiScreen> createState() => _AskAiScreenState();
}

class _AskAiScreenState extends State<AskAiScreen> {
  final _client = AskAiClient();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_Message> _messages = [];
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? presetText]) async {
    final text = (presetText ?? _controller.text).trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(_Message(role: 'user', text: text));
      _sending = true;
      _controller.clear();
    });
    _scrollToEnd();

    // Prior turns only (exclude the question just appended), capped to the
    // last few exchanges so the context sent to the model stays small.
    final prior = _messages.sublist(0, _messages.length - 1).where((m) => !m.isError).toList();
    final recent = prior.length > 6 ? prior.sublist(prior.length - 6) : prior;
    final history = recent.map((m) => ChatTurn(role: m.role, content: m.text)).toList();

    try {
      final answer = await _client.ask(
        groupId: widget.groupId,
        question: text,
        history: history,
      );
      if (!mounted) return;
      setState(() => _messages.add(_Message(role: 'assistant', text: answer)));
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _messages.add(
          _Message(
            role: 'assistant',
            text: "Couldn't reach Ask AI right now. ${e.toString()}",
            isError: true,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ask AI'),
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(gradient: royalHeaderGradient),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty ? const _EmptyState() : _buildMessageList(),
          ),
          if (_messages.isEmpty) _buildPrompts(),
          if (_sending)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: ourShelfSeed),
                  ),
                  const SizedBox(width: 10),
                  Text('Thinking…', style: TextStyle(color: ourShelfTextSecondary, fontSize: 12.5)),
                ],
              ),
            ),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Ask about your list, pantry or spending…',
                      filled: true,
                      fillColor: ourShelfCard,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: ourShelfBorder),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : () => _send(),
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrompts() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final prompt in _examplePrompts)
            ActionChip(
              label: Text(prompt, style: const TextStyle(fontSize: 12.5)),
              backgroundColor: ourShelfSeed.withValues(alpha: 0.07),
              side: BorderSide(color: ourShelfSeed.withValues(alpha: 0.18)),
              onPressed: _sending ? null : () => _send(prompt),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final msg = _messages[i];
        final isUser = msg.role == 'user';
        return FadeSlideIn(
          child: Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * (isUser ? 0.78 : 0.92),
              ),
              decoration: BoxDecoration(
                gradient: isUser ? royalHeaderGradient : null,
                color: isUser
                    ? null
                    : (msg.isError ? ourShelfError.withValues(alpha: 0.08) : ourShelfCard),
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isUser ? const Radius.circular(4) : null,
                  bottomLeft: !isUser ? const Radius.circular(4) : null,
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: msg.isError
                            ? ourShelfError.withValues(alpha: 0.3)
                            : ourShelfBorder,
                      ),
              ),
              child: isUser || msg.isError
                  ? Text(
                      msg.text,
                      style: TextStyle(
                        color: isUser ? Colors.white : ourShelfError,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    )
                  : MarkdownBody(
                      data: msg.text,
                      selectable: true,
                      extensionSet: md.ExtensionSet.gitHubWeb,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(color: ourShelfTextPrimary, fontSize: 13.5, height: 1.4),
                        strong: const TextStyle(fontWeight: FontWeight.bold),
                        em: const TextStyle(fontStyle: FontStyle.italic),
                        listBullet: TextStyle(color: ourShelfTextPrimary, fontSize: 13.5),
                        h1: TextStyle(color: ourShelfTextPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                        h2: TextStyle(color: ourShelfTextPrimary, fontSize: 15.5, fontWeight: FontWeight.bold),
                        h3: TextStyle(color: ourShelfTextPrimary, fontSize: 14.5, fontWeight: FontWeight.bold),
                        code: TextStyle(
                          color: ourShelfTextPrimary,
                          backgroundColor: ourShelfBorder.withValues(alpha: 0.4),
                          fontSize: 12.5,
                        ),
                        tableHead: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        tableBody: TextStyle(color: ourShelfTextPrimary, fontSize: 12.5),
                        tableBorder: TableBorder.all(color: ourShelfBorder),
                        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        tableColumnWidth: const FlexColumnWidth(),
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulseIcon(
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: ourShelfAccent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_awesome, size: 40, color: ourShelfAccent),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Ask about your group',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              "I can only see this group's own shopping list, pantry and "
              "purchase history — nothing else.",
              textAlign: TextAlign.center,
              style: TextStyle(color: ourShelfTextSecondary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
