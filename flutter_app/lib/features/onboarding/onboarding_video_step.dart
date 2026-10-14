import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:video_player/video_player.dart';

import '../../src/theme/palette.dart';
import 'onboarding_chrome.dart';
import 'package:neoagent_flutter/src/l10n/app_language.dart';

class OnboardingVideoStep extends StatefulWidget {
  const OnboardingVideoStep({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingVideoStep> createState() => _OnboardingVideoStepState();
}

class _OnboardingVideoStepState extends State<OnboardingVideoStep> {
  /// A slow or stuck load falls back to the continue screen instead of
  /// leaving a spinner on screen indefinitely.
  static const Duration _initTimeout = Duration(seconds: 8);

  VideoPlayerController? _controller;
  bool _isInitialized = false;
  String? _errorText;
  bool _hasCompleted = false;
  Orientation? _orientation;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final orientation = MediaQuery.orientationOf(context);
    if (orientation != _orientation) {
      _orientation = orientation;
      _syncPlayback();
    }
  }

  Future<void> _initVideo() async {
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      _errorText = appStrings.theIntroIsNotAvailableOn;
      return;
    }

    final controller = VideoPlayerController.asset(
      'assets/branding/onboarding_intro.mp4',
    );
    _controller = controller;
    try {
      await controller.initialize().timeout(_initTimeout);
      if (!mounted) return;
      controller
        ..setLooping(false)
        ..setVolume(1)
        ..addListener(_videoListener);
      setState(() => _isInitialized = true);
      _syncPlayback();
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = appStrings.onboardingIntroCouldNotLoad);
    }
  }

  /// The intro only plays in landscape; portrait shows a rotate prompt, so
  /// playback follows orientation changes rather than every rebuild.
  void _syncPlayback() {
    final controller = _controller;
    if (!_isInitialized || controller == null || _hasCompleted) return;
    if (_orientation == Orientation.portrait) {
      if (controller.value.isPlaying) controller.pause();
    } else if (!controller.value.isPlaying) {
      controller.play();
    }
  }

  void _videoListener() {
    if (!mounted || _hasCompleted) return;
    if (_controller == null || !_controller!.value.isInitialized) return;
    final duration = _controller!.value.duration;
    final position = _controller!.value.position;
    // Duration can be zero until metadata is ready; treating that as "ended"
    // auto-skips the intro immediately after it appears.
    if (duration > Duration.zero && position >= duration) {
      _complete();
    }
  }

  void _complete() {
    if (_hasCompleted) return;
    _hasCompleted = true;
    _controller?.removeListener(_videoListener);
    _controller?.pause();
    widget.onComplete();
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);

    if (_errorText != null) {
      return Scaffold(
        backgroundColor: p.bgPrimary,
        body: _CenteredMessage(
          icon: Icons.play_circle_outline_rounded,
          title: appStrings.continueToSetup,
          body: _errorText!,
          action: OnboardingPrimaryButton(
            label: appStrings.continue2,
            icon: Icons.arrow_forward_rounded,
            onPressed: _complete,
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: <Widget>[
            const Center(child: CircularProgressIndicator(color: Colors.white)),
            Positioned(
              top: 28,
              right: 28,
              child: SafeArea(child: _SkipButton(onPressed: _complete)),
            ),
          ],
        ),
      );
    }

    if (_orientation == Orientation.portrait) {
      return Scaffold(
        backgroundColor: p.bgPrimary,
        body: _CenteredMessage(
          icon: Icons.screen_rotation,
          title: appStrings.rotateToContinue,
          body: appStrings.thisIntroIsDesignedForFull,
          action: OnboardingPrimaryButton(
            label: appStrings.skip,
            icon: Icons.arrow_forward_rounded,
            onPressed: _complete,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.22),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          Positioned(
            top: 28,
            right: 28,
            child: _SkipButton(
              onPressed: _complete,
            ).animate().fadeIn(duration: 280.ms, delay: 220.ms),
          ),
        ],
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OnboardingGhostButton(label: appStrings.skip, onPressed: onPressed);
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final p = paletteOf(context);
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: p.accent, size: 54),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textMuted, fontSize: 15, height: 1.5),
              ),
              const SizedBox(height: 28),
              action,
            ],
          ),
        ),
      ),
    );
  }
}
