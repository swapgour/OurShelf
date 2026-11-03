import 'package:flutter/material.dart';

import '../../app.dart';
import '../../widgets/motion.dart';

class _FlowStep {
  const _FlowStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
}

const _flowSteps = [
  _FlowStep(
    icon: Icons.group_add_outlined,
    color: Color(0xFF6A1B9A),
    title: 'Create or join a family group',
    description:
        'Sign in, then create a group or join one with an invite code. '
        'Everything below is shared live with everyone in it.',
  ),
  _FlowStep(
    icon: Icons.playlist_add_outlined,
    color: Color(0xFF1565C0),
    title: 'Add items to the shared list',
    description:
        'Anyone adds what the household needs. It shows up for every '
        'member instantly — no "did you see my text?" needed.',
  ),
  _FlowStep(
    icon: Icons.shopping_bag_outlined,
    color: Color(0xFF00695C),
    title: 'Shop, then mark it bought',
    description:
        'Tap an item bought and record the price — or scan the receipt '
        'and OurShelf reads it and matches items automatically.',
  ),
  _FlowStep(
    icon: Icons.kitchen_outlined,
    color: Color(0xFFE8822E),
    title: 'Pantry updates itself',
    description:
        'A bought item is topped up to "Full" stock in Pantry automatically. '
        'As levels drop, low/out-of-stock items are one tap from the list again.',
  ),
  _FlowStep(
    icon: Icons.pie_chart_outline,
    color: Color(0xFFC62828),
    title: 'Track spending & who paid',
    description:
        'Expenses and the Dashboard turn every purchase into totals, '
        'category breakdowns, and a fair-share balance per member.',
  ),
  _FlowStep(
    icon: Icons.event_repeat_outlined,
    color: Color(0xFF4527A0),
    title: 'Never miss a recurring essential',
    description:
        'Set reminders for things that aren\'t really "shopping list" items '
        '— an LPG refill, a water-can delivery — on their own schedule.',
  ),
  _FlowStep(
    icon: Icons.history_rounded,
    color: Color(0xFF00838F),
    title: 'Stay in sync via Activity',
    description:
        'Every add, purchase and change lands in the Activity feed and a '
        'push notification, so the whole family sees what changed and when.',
  ),
];

/// A single scrollable "how OurShelf works" guide: an end-to-end flow of
/// the app's core loop, plus an honest look at what the upcoming Ask AI
/// assistant will do once it ships.
class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('How OurShelf Works'),
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(gradient: royalHeaderGradient),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          FadeSlideIn(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: royalHeaderGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFFE9B52E)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'One shared list, pantry and budget for the whole '
                      'family — here\'s the full loop, start to finish.',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionHeading(title: 'The end-to-end flow'),
          const SizedBox(height: 12),
          _FlowChart(steps: _flowSteps),
          const SizedBox(height: 28),
          const _SectionHeading(title: 'Ask AI — what\'s coming'),
          const SizedBox(height: 12),
          const _AskAiSection(),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: ourShelfTextPrimary),
    );
  }
}

/// A vertical chain of steps connected by a line — the mobile-friendly
/// stand-in for a flowchart: same "this leads to that" shape, readable in
/// one thumb-scroll instead of a wide diagram squeezed onto a phone screen.
class _FlowChart extends StatelessWidget {
  const _FlowChart({required this.steps});

  final List<_FlowStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          FadeSlideIn(
            delay: Duration(milliseconds: i * 70),
            child: _FlowStepTile(
              step: steps[i],
              index: i + 1,
              isLast: i == steps.length - 1,
            ),
          ),
      ],
    );
  }
}

class _FlowStepTile extends StatelessWidget {
  const _FlowStepTile({
    required this.step,
    required this.index,
    required this.isLast,
  });

  final _FlowStep step;
  final int index;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: step.color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                  border: Border.all(color: step.color.withValues(alpha: 0.4)),
                ),
                child: Icon(step.icon, color: step.color, size: 18),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: ourShelfBorder,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ourShelfBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'STEP $index',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.6,
                            color: step.color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(step.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    const SizedBox(height: 4),
                    Text(
                      step.description,
                      style: TextStyle(color: ourShelfTextSecondary, fontSize: 12.5, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamplePrompt extends StatelessWidget {
  const _ExamplePrompt({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ourShelfSeed.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ourShelfSeed.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.chat_bubble_outline, size: 16, color: ourShelfSeed),
          const SizedBox(width: 10),
          Expanded(
            child: Text('"$text"', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// Describes the Ask AI assistant honestly: what it does, what data it
/// reads, and — since it only answers questions for now — what it doesn't
/// do yet (no write actions like adding items).
class _AskAiSection extends StatelessWidget {
  const _AskAiSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ourShelfBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ourShelfAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_outlined, color: ourShelfAccent, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Ask AI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: ourShelfSuccess.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Live',
                  style: TextStyle(color: ourShelfSuccess, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Ask AI is a chat box (More → Ask AI) that answers questions '
            'about your own group\'s data — your shopping list, pantry and '
            'purchase history — instead of you digging through screens for it. '
            'For now it only answers; it can\'t add or change anything yet.',
            style: TextStyle(color: ourShelfTextSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 14),
          const Text('Try asking things like:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 10),
          const _ExamplePrompt(text: 'What\'s running low in the pantry?'),
          const _ExamplePrompt(text: 'How much did we spend on groceries this month?'),
          const _ExamplePrompt(text: 'What\'s still on the shopping list?'),
          const _ExamplePrompt(text: 'Who paid the most this month?'),
          const SizedBox(height: 14),
          const Divider(height: 1, color: ourShelfBorder),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 16, color: ourShelfTextSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Under the hood: your question, plus a live read of your own '
                  'group\'s list/pantry/purchase data, goes through a small free '
                  'proxy (the same no-Blaze-billing Cloudflare Worker pattern '
                  'used for push notifications) to an AI model — not a Firebase '
                  'Cloud Function, so it needs no billing account either. It '
                  'only ever reads your own group\'s data, never anyone else\'s.',
                  style: TextStyle(color: ourShelfTextSecondary, fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
