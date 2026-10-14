import 'package:flutter/material.dart';

import '../l10n/app_language.dart';
import 'skeleton.dart';

/// The rough shape of the page that is loading, so the placeholder matches
/// what replaces it and nothing jumps when the data lands.
enum PageSkeletonLayout { chat, list, settings }

/// A shimmering stand-in for a whole page while its data loads.
class PageSkeleton extends StatelessWidget {
  const PageSkeleton({super.key, required this.layout});

  final PageSkeletonLayout layout;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final body = switch (layout) {
      PageSkeletonLayout.chat => _ChatSkeleton(compact: compact),
      PageSkeletonLayout.list => _ListSkeleton(compact: compact),
      PageSkeletonLayout.settings => _SettingsSkeleton(compact: compact),
    };
    return Semantics(
      label: appStrings.loadingNeoagent,
      liveRegion: true,
      child: ExcludeSemantics(
        child: ClipRect(child: SkeletonShimmer(child: body)),
      ),
    );
  }
}

/// Bounded so a tall placeholder clips instead of overflowing short screens.
class _ScrollFree extends StatelessWidget {
  const _ScrollFree({
    required this.padding,
    required this.child,
    this.maxWidth = 1080,
  });

  final EdgeInsets padding;
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: padding,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}

EdgeInsets _pagePadding(bool compact) => compact
    ? const EdgeInsets.fromLTRB(16, 20, 16, 16)
    : const EdgeInsets.fromLTRB(32, 32, 32, 24);

class _TitleSkeleton extends StatelessWidget {
  const _TitleSkeleton({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 20 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SkeletonBlock(width: compact ? 150 : 220, height: compact ? 22 : 30),
          const SizedBox(height: 12),
          const SkeletonLine(widthFactor: 0.55),
        ],
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton({required this.compact});

  final bool compact;

  static const List<(double, double)> _rows = <(double, double)>[
    (0.46, 0.30),
    (0.62, 0.38),
    (0.38, 0.24),
    (0.54, 0.42),
    (0.42, 0.28),
    (0.58, 0.34),
    (0.36, 0.22),
  ];

  @override
  Widget build(BuildContext context) {
    return _ScrollFree(
      padding: _pagePadding(compact),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _TitleSkeleton(compact: compact),
          const Row(
            children: <Widget>[
              Flexible(
                child: SkeletonBlock(width: 260, height: 36, radius: 10),
              ),
              SizedBox(width: 10),
              SkeletonBlock(width: 84, height: 36, radius: 10),
            ],
          ),
          const SizedBox(height: 22),
          for (final (title, detail) in _rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: <Widget>[
                  const SkeletonBlock.circle(size: 34),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SkeletonLine(widthFactor: title, height: 12),
                        const SizedBox(height: 9),
                        SkeletonLine(widthFactor: detail, height: 9),
                      ],
                    ),
                  ),
                  if (!compact) ...const <Widget>[
                    SizedBox(width: 16),
                    SkeletonBlock(width: 64, height: 22, radius: 11),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsSkeleton extends StatelessWidget {
  const _SettingsSkeleton({required this.compact});

  final bool compact;

  static const List<List<double>> _groups = <List<double>>[
    <double>[0.34, 0.26, 0.40],
    <double>[0.30, 0.44],
    <double>[0.38, 0.24, 0.32],
  ];

  @override
  Widget build(BuildContext context) {
    return _ScrollFree(
      padding: _pagePadding(compact),
      maxWidth: 820,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _TitleSkeleton(compact: compact),
          for (final group in _groups) ...<Widget>[
            const SkeletonBlock(width: 120, height: 14),
            const SizedBox(height: 8),
            const SkeletonLine(widthFactor: 0.42, height: 9),
            const SizedBox(height: 18),
            for (var index = 0; index < group.length; index += 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: SkeletonLine(
                        widthFactor: compact
                            ? group[index] * 1.6
                            : group[index],
                      ),
                    ),
                    const SizedBox(width: 16),
                    index.isEven
                        ? SkeletonBlock(
                            width: compact ? 110 : 200,
                            height: 34,
                            radius: 10,
                          )
                        : const SkeletonBlock(
                            width: 42,
                            height: 24,
                            radius: 12,
                          ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _ChatSkeleton extends StatelessWidget {
  const _ChatSkeleton({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final side = compact ? 16.0 : 28.0;
    return Column(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.fromLTRB(side, 16, side, 16),
          child: const Row(
            children: <Widget>[
              SkeletonBlock.circle(size: 30),
              SizedBox(width: 12),
              SkeletonBlock(width: 120, height: 14),
              Spacer(),
              SkeletonBlock.circle(size: 30),
            ],
          ),
        ),
        Expanded(
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.bottomCenter,
              minHeight: 0,
              maxHeight: double.infinity,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: side, vertical: 18),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 860),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _UserBubbleSkeleton(widthFactor: 0.42),
                      _ReplySkeleton(lines: <double>[0.92, 0.84, 0.58]),
                      _UserBubbleSkeleton(widthFactor: 0.28),
                      _ReplySkeleton(lines: <double>[0.88, 0.95, 0.76, 0.4]),
                      _UserBubbleSkeleton(widthFactor: 0.36),
                      _ReplySkeleton(lines: <double>[0.7, 0.48]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(side, 12, side, 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: const SkeletonBlock(height: 52, radius: 18),
          ),
        ),
      ],
    );
  }
}

class _UserBubbleSkeleton extends StatelessWidget {
  const _UserBubbleSkeleton({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: FractionallySizedBox(
        alignment: AlignmentDirectional.centerEnd,
        widthFactor: widthFactor,
        child: const SkeletonBlock(height: 40, radius: 16),
      ),
    );
  }
}

class _ReplySkeleton extends StatelessWidget {
  const _ReplySkeleton({required this.lines});

  final List<double> lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final factor in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: SkeletonLine(widthFactor: factor),
            ),
        ],
      ),
    );
  }
}
