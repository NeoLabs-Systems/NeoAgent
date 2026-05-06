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
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.play_circle_outline_rounded,
                  color: Colors.white70,
                  size: 56,
                ),
                const SizedBox(height: 18),
                const Text(
                  'Continue to setup',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'The intro is not available on this device.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.68),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                OnboardingPrimaryButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: widget.onComplete,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final portrait = orientation == Orientation.portrait;
    if (portrait && _controller!.value.isPlaying) {
      _controller!.pause();
    } else if (!portrait && !_controller!.value.isPlaying) {
      _controller!.play();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: portrait
          ? const _RotatePrompt()
          : Stack(
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
                  child: OnboardingGhostButton(
                    label: 'Skip',
                    onPressed: widget.onComplete,
                  ).animate().fadeIn(duration: 280.ms, delay: 220.ms),
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.screen_rotation, color: Colors.white, size: 54),
            const SizedBox(height: 18),
            const Text(
              'Rotate to continue',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'This intro is designed for full-screen landscape playback.',
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
