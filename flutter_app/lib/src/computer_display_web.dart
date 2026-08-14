// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

int _computerDisplayOverlayId = 0;

class ComputerDisplay extends StatefulWidget {
  const ComputerDisplay({super.key, required this.url});

  final String url;

  @override
  State<ComputerDisplay> createState() => _ComputerDisplayState();
}

class _ComputerDisplayState extends State<ComputerDisplay>
    with WidgetsBindingObserver {
  final GlobalKey _slotKey = GlobalKey();
  late final String _overlayId;
  html.DivElement? _overlay;
  html.IFrameElement? _frame;
  Timer? _syncTimer;
  bool _frameScheduled = false;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _overlayId = 'neoagent-computer-display-${_computerDisplayOverlayId++}';
    WidgetsBinding.instance.addObserver(this);
    _mountOverlay();
    _scheduleSync();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _syncOverlay();
    });
  }

  @override
  void didUpdateWidget(covariant ComputerDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _frame?.src = widget.url;
    }
    _scheduleSync();
  }

  @override
  void didChangeMetrics() {
    _scheduleSync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _setOverlayVisible(false);
      return;
    }
    _scheduleSync();
  }

  void _mountOverlay() {
    final frame = html.IFrameElement()
      ..src = widget.url
      ..title = 'NeoAgent Linux computer'
      ..tabIndex = 0
      ..allowFullscreen = true
      ..allow = 'clipboard-read; clipboard-write; fullscreen'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = '0'
      ..style.backgroundColor = '#111111'
      ..style.pointerEvents = 'auto'
      ..setAttribute('referrerpolicy', 'same-origin');
    final overlay = html.DivElement()
      ..id = _overlayId
      ..style.position = 'fixed'
      ..style.left = '0'
      ..style.top = '0'
      ..style.width = '0'
      ..style.height = '0'
      ..style.zIndex = '20'
      ..style.overflow = 'hidden'
      ..style.borderRadius = '14px'
      ..style.backgroundColor = '#111111'
      ..style.pointerEvents = 'auto'
      ..style.visibility = 'hidden'
      ..append(frame);
    html.document.body?.append(overlay);
    _frame = frame;
    _overlay = overlay;
  }

  void _scheduleSync() {
    if (_frameScheduled || !mounted) return;
    _frameScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      _syncOverlay();
    });
  }

  void _syncOverlay() {
    final overlay = _overlay;
    if (!mounted || overlay == null) return;
    final route = ModalRoute.of(context);
    final box = _slotKey.currentContext?.findRenderObject() as RenderBox?;
    if (route?.isCurrent != true ||
        box == null ||
        !box.attached ||
        !box.hasSize) {
      _setOverlayVisible(false);
      return;
    }
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    if (size.width < 2 || size.height < 2) {
      _setOverlayVisible(false);
      return;
    }
    overlay.style
      ..left = '${offset.dx}px'
      ..top = '${offset.dy}px'
      ..width = '${size.width}px'
      ..height = '${size.height}px';
    _setOverlayVisible(true);
  }

  void _setOverlayVisible(bool visible) {
    if (_visible == visible) return;
    _visible = visible;
    final overlay = _overlay;
    if (overlay == null) return;
    overlay.style.visibility = visible ? 'visible' : 'hidden';
    overlay.style.pointerEvents = visible ? 'auto' : 'none';
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _overlay?.remove();
    _overlay = null;
    _frame = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleSync();
    return ColoredBox(
      key: _slotKey,
      color: const Color(0xFF111111),
      child: const SizedBox.expand(),
    );
  }
}
