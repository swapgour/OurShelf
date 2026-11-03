import 'package:flutter/material.dart';

import '../app.dart';

/// A gently pulsing placeholder block — used in place of a bare spinner so
/// a loading screen hints at the shape of the content that's coming,
/// instead of a blank center with a circle.
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = 8,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);
  late final Animation<double> _opacity = Tween<double>(
    begin: 0.5,
    end: 1,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: ourShelfBorder,
          borderRadius: BorderRadius.circular(widget.borderRadius),
        ),
      ),
    );
  }
}

/// A row-shaped skeleton mimicking a list tile: a round "icon", two text
/// lines of placeholder blocks — used for list screens while data loads.
class LoadingSkeletonTile extends StatelessWidget {
  const LoadingSkeletonTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ourShelfBorder),
      ),
      child: Row(
        children: [
          const LoadingSkeleton(width: 36, height: 36, borderRadius: 10),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoadingSkeleton(width: MediaQuery.of(context).size.width * 0.4),
                const SizedBox(height: 8),
                LoadingSkeleton(width: MediaQuery.of(context).size.width * 0.25, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A short stack of [LoadingSkeletonTile]s — drop in place of a bare
/// CircularProgressIndicator for any list-shaped loading state.
class LoadingSkeletonList extends StatelessWidget {
  const LoadingSkeletonList({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(count, (_) => const LoadingSkeletonTile()),
      ),
    );
  }
}
