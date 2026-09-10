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
  _LiveComputerOverlay? _overlay;
  Timer? _syncTimer;
  bool _frameScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _overlay = _LiveComputerOverlay.claim(widget.url);
    _scheduleSync();
    _syncTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      _syncOverlay();
    });
  }

  @override
  void didUpdateWidget(covariant ComputerDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _overlay?.release(this);
      _overlay = _LiveComputerOverlay.claim(widget.url);
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
      _overlay?.setOwnerVisible(this, false);
      return;
    }
    _scheduleSync();
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
        !box.hasSize ||
        !_slotIsStable()) {
      overlay.setOwnerVisible(this, false);
      return;
    }
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    if (size.width < 2 || size.height < 2) {
      overlay.setOwnerVisible(this, false);
      return;
    }
    overlay.position(offset, size);
    overlay.setOwnerVisible(this, true);
  }

  bool _slotIsStable() {
    var stable = true;
    context.visitAncestorElements((element) {
      final widget = element.widget;
      if (widget is FadeTransition && widget.opacity.value < 0.999) {
        stable = false;
        return false;
      }
      if (widget is ScaleTransition && widget.scale.value < 0.999) {
        stable = false;
        return false;
      }
      if (widget is SlideTransition) {
        final offset = widget.position.value;
        if (offset.dx.abs() > 0.001 || offset.dy.abs() > 0.001) {
          stable = false;
          return false;
        }
      }
      return true;
    });
    return stable;
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _overlay?.release(this);
    _overlay = null;
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

class _LiveComputerOverlay {
  _LiveComputerOverlay._(this.url, this._overlay);

  final String url;
  final html.DivElement _overlay;
  final Set<Object> _visibleOwners = <Object>{};
  int _claims = 0;

  static _LiveComputerOverlay? _current;
  static Timer? _idleTeardown;

  static _LiveComputerOverlay claim(String url) {
    _idleTeardown?.cancel();
    final existing = _current;
    if (existing != null && existing.url == url) {
      existing._claims += 1;
      return existing;
    }
    existing?._disposeHost();
    final created = _LiveComputerOverlay._create(url).._claims = 1;
    _current = created;
    return created;
  }

  static _LiveComputerOverlay _create(String url) {
    _computerDisplayOverlayId += 1;
    final frame = html.IFrameElement()
      ..src = url
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
      ..id = 'neoagent-computer-display-$_computerDisplayOverlayId'
      ..style.position = 'fixed'
      ..style.left = '0'
      ..style.top = '0'
      ..style.width = '0'
      ..style.height = '0'
      ..style.zIndex = '20'
      ..style.overflow = 'hidden'
      ..style.borderRadius = '14px'
      ..style.backgroundColor = '#111111'
      ..style.pointerEvents = 'none'
      ..style.visibility = 'hidden'
      ..append(frame);
    html.document.body?.append(overlay);
    return _LiveComputerOverlay._(url, overlay);
  }

  void position(Offset offset, Size size) {
    _overlay.style
      ..left = '${offset.dx}px'
      ..top = '${offset.dy}px'
      ..width = '${size.width}px'
      ..height = '${size.height}px';
  }

  void setOwnerVisible(Object owner, bool visible) {
    if (visible) {
      _visibleOwners.add(owner);
    } else {
      _visibleOwners.remove(owner);
    }
    final show = _visibleOwners.isNotEmpty;
    _overlay.style.visibility = show ? 'visible' : 'hidden';
    _overlay.style.pointerEvents = show ? 'auto' : 'none';
  }

  void release(Object owner) {
    setOwnerVisible(owner, false);
    _claims -= 1;
    if (_claims > 0) return;
    _idleTeardown?.cancel();
    _idleTeardown = Timer(const Duration(minutes: 10), () {
      if (_current == this && _claims <= 0) {
        _disposeHost();
      }
    });
  }

  void _disposeHost() {
    _idleTeardown?.cancel();
    _overlay.remove();
    if (_current == this) _current = null;
  }
}
