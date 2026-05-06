import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:video_player/video_player.dart';

import 'onboarding_chrome.dart';

class OnboardingVideoStep extends StatefulWidget {
  const OnboardingVideoStep({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingVideoStep> createState() => _OnboardingVideoStepState();
}

class _OnboardingVideoStepState extends State<OnboardingVideoStep> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _hasCompleted = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      setState(() => _hasError = true);
      return;
    }

    try {
      _controller = VideoPlayerController.asset(
        'assets/branding/onboarding_intro.mp4',
      );
      await _controller!.initialize();
      if (!mounted) return;
      _controller!
        ..setLooping(false)
        ..setVolume(1)
        ..addListener(_videoListener);
      setState(() => _isInitialized = true);
      await _controller!.play();
    } catch (_) {
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  void _videoListener() {
    if (!mounted || _hasCompleted) return;
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.position >= _controller!.value.duration) {
      _hasCompleted = true;
      _controller!.removeListener(_videoListener);
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.orientationOf(context);

    if (_hasError) {
      return OnboardingScaffold(
        step: 0,
        totalSteps: 4,
        eyebrow: 'INTRO',
        title: 'A cinematic intro belongs here.',
        description:
            'If the video asset is unavailable, the experience falls back cleanly so setup never feels broken or unfinished.',
        sidePanel: const _VideoFallbackPanel(),
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            OnboardingPrimaryButton(
              label: 'Continue',
              icon: Icons.arrow_forward_rounded,
              onPressed: widget.onComplete,
            ),
          ],
        ),
        child: const SizedBox.shrink(),
      );
    }

    if (!_isInitialized || _controller == null) {
      return OnboardingScaffold(
        step: 0,
        totalSteps: 4,
        eyebrow: 'INTRO',
        title: 'Preparing the opening sequence.',
        description:
            'The first impression should feel immediate and polished, so the transition in is staged before the rest of setup appears.',
        sidePanel: const _VideoFallbackPanel(),
        footer: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            OnboardingGhostButton(
              label: 'Skip intro',
              onPressed: widget.onComplete,
            ),
            const SizedBox.shrink(),
          ],
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final portrait = orientation == Orientation.portrait;
    if (portrait && _controller!.value.isPlaying) {
      _controller!.pause();
    } else if (!portrait && !_controller!.value.isPlaying) {
      _controller!.play();
    }

    return OnboardingScaffold(
      step: 0,
      totalSteps: 4,
      eyebrow: 'INTRO',
      title: 'See the product\nbefore you configure it.',
      description:
          'The opening sequence sets tone and expectation: quiet motion, deliberate materials, and a system that feels already alive.',
      dense: true,
      sidePanel: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: const <Widget>[
          OnboardingMetricPill(label: 'Feel', value: 'Editorial motion'),
          OnboardingMetricPill(label: 'Pacing', value: 'Fast, never rushed'),
        ],
      ).animate().fadeIn(duration: 500.ms, delay: 220.ms),
      footer: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          OnboardingGhostButton(
            label: 'Skip intro',
            onPressed: widget.onComplete,
          ),
          Text(
            'Auto-continues when the video ends',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.56),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      child: portrait
          ? const _RotatePrompt()
          : ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      color: const Color(0xFF060709),
                    ),
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.size.width,
                        height: _controller!.value.size.height,
                        child: VideoPlayer(_controller!),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: <Color>[
                            Colors.black.withValues(alpha: 0.04),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.42),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 700.ms).scaleXY(begin: 0.98, end: 1),
    );
  }
}

class _VideoFallbackPanel extends StatelessWidget {
  const _VideoFallbackPanel();

  @override
  Widget build(BuildContext context) {
    return const OnboardingPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.movie_creation_outlined, color: Colors.white, size: 30),
          SizedBox(height: 16),
          Text(
            'Fallback mode',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Paste a real `onboarding_intro.mp4` into `assets/branding/` to restore the cinematic first step.',
            style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _RotatePrompt extends StatelessWidget {
  const _RotatePrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: OnboardingPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.screen_rotation, color: Colors.white, size: 54),
            const SizedBox(height: 18),
            const Text(
              'Rotate for the full-screen intro',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'The opening video is composed for landscape so it feels cinematic instead of cramped.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
