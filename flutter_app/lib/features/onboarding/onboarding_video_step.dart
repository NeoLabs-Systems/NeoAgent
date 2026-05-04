import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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
    // video_player doesn't support Windows/Linux out of the box
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      setState(() {
        _hasError = true;
      });
      return;
    }

    try {
      _controller = VideoPlayerController.asset(
        'assets/branding/onboarding_intro.mp4',
      );
      await _controller!.initialize();
      if (!mounted) return;
      _controller!.addListener(_videoListener);
      setState(() {
        _isInitialized = true;
      });
      await _controller!.play();
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      // If the asset is missing or invalid (like our dummy file), just show error/skip
      setState(() {
        _hasError = true;
      });
    }
  }

  void _videoListener() {
    if (!mounted || _hasCompleted) return;
    if (_controller == null || !_controller!.value.isInitialized) return;
    
    // When video reaches the end
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
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, color: Colors.white54, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Video placeholder. Paste real mp4 over assets/branding/onboarding_intro.mp4',
              style: TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: widget.onComplete,
              child: const Text('Skip Video'),
            ),
          ],
        ),
      );
    }

    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final isPortrait = MediaQuery.of(context).orientation == Orientation.portrait;

    if (isPortrait) {
      // Pause video while asking to rotate
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.screen_rotation, color: Colors.white, size: 64),
              const SizedBox(height: 24),
              const Text(
                'Please rotate your device',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'The intro video is exclusively formatted for landscape viewing.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 40),
              FilledButton.tonal(
                onPressed: () {
                  // If they really want to proceed without rotating
                  widget.onComplete();
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Skip Video'),
              ),
            ],
          ),
        ),
      );
    } else {
      // Ensure it resumes if they rotated back
      if (!_controller!.value.isPlaying && _isInitialized) {
        _controller!.play();
      }
    }

    return Stack(
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
        Positioned(
          bottom: 40,
          right: 40,
          child: TextButton(
            onPressed: widget.onComplete,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.5),
            ),
            child: const Text('Skip'),
          ),
        ),
      ],
    );
  }
}
