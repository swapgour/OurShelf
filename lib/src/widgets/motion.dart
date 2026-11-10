import 'package:flutter/material.dart';

/// Fades and slides [child] up into place, optionally after [delay] — used
/// to stagger a list/grid of cards so the screen feels like it's "arriving"
/// rather than popping in all at once.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<Offset> _offset = Tween<Offset>(
    begin: const Offset(0, 0.14),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

/// A gently "breathing" wrapper — gives an icon badge a slow, continuous
/// pulse so the screen reads as alive rather than a static mockup.
class PulseIcon extends StatefulWidget {
  const PulseIcon({
    super.key,
    required this.child,
    this.minScale = 0.94,
    this.maxScale = 1.08,
    this.duration = const Duration(milliseconds: 1600),
  });

  final Widget child;
  final double minScale;
  final double maxScale;
  final Duration duration;

  @override
  State<PulseIcon> createState() => _PulseIconState();
}

class _PulseIconState extends State<PulseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..repeat(reverse: true);
  late final Animation<double> _scale = Tween<double>(
    begin: widget.minScale,
    end: widget.maxScale,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _scale, child: widget.child);
  }
}

/// A small back-and-forth wiggle — used on emoji/accent icons that should
/// draw a little attention without looping forever at full speed.
class WiggleIcon extends StatefulWidget {
  const WiggleIcon({super.key, required this.child});

  final Widget child;

  @override
  State<WiggleIcon> createState() => _WiggleIconState();
}

class _WiggleIconState extends State<WiggleIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);
  late final Animation<double> _angle = Tween<double>(
    begin: -0.12,
    end: 0.12,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _angle,
      builder: (context, child) =>
          Transform.rotate(angle: _angle.value, child: child),
      child: widget.child,
    );
  }
}

/// Counts up from 0 to [value] once, the way a premium dashboard animates
/// its headline numbers instead of just printing them.
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.duration = const Duration(milliseconds: 900),
  });

  final double value;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) =>
          Text('$prefix${v.toStringAsFixed(0)}$suffix', style: style),
    );
  }
}

/// A horizontally-scrolling row of chips that gives itself a brief, one-time
/// "peek" scroll (right a bit, then back) right after it first appears —
/// so a user who's never used the screen before actually sees that there's
/// more to scroll to, instead of a static row that looks complete at a
/// glance. Only peeks once per time this widget is mounted (e.g. once per
/// screen visit), and does nothing if there's nothing to scroll to.
class AutoPeekScrollRow extends StatefulWidget {
  const AutoPeekScrollRow({
    super.key,
    required this.children,
    this.height = 40,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.spacing = 8,
  });

  final List<Widget> children;
  final double height;
  final EdgeInsets padding;
  final double spacing;

  @override
  State<AutoPeekScrollRow> createState() => _AutoPeekScrollRowState();
}

class _AutoPeekScrollRowState extends State<AutoPeekScrollRow> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _peek());
  }

  Future<void> _peek() async {
    if (!mounted || !_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    if (max <= 0) return;
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    await _controller.animateTo(
      max < 140 ? max : 140,
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
    );
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    await _controller.animateTo(
      0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: widget.padding,
        itemCount: widget.children.length,
        separatorBuilder: (_, _) => SizedBox(width: widget.spacing),
        itemBuilder: (_, i) => widget.children[i],
      ),
    );
  }
}
