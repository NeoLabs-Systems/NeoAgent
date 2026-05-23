import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class StreamRenderer extends StatefulWidget {
  const StreamRenderer({
    super.key,
    required this.socket,
    required this.deviceId,
    required this.platform,
    this.remoteResolution,
    this.onTap,
    this.onSwipe,
    this.onType,
    this.onHover,
    this.onFirstFrame,
    this.onFrameTimeout,
    this.firstFrameTimeout = const Duration(seconds: 8),
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });

  final io.Socket socket;
  final String deviceId;
  final String platform;
  final Size? remoteResolution;
  final void Function(double x, double y)? onTap;
  final void Function(double x1, double y1, double x2, double y2)? onSwipe;
  final void Function(String text)? onType;
  final void Function(double x, double y)? onHover;
  final VoidCallback? onFirstFrame;
  final VoidCallback? onFrameTimeout;
  final Duration firstFrameTimeout;
  final BoxFit fit;
  final Alignment alignment;

  @override
  State<StreamRenderer> createState() => _StreamRendererState();
}

class _StreamRendererState extends State<StreamRenderer> {
  Uint8List? _frame;
  Size? _frameSize;
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  Offset? _dragStart;
  Offset? _dragEnd;

  Timer? _hoverThrottleTimer;
  Timer? _firstFrameTimer;
  bool _firstFrameTimedOut = false;
  Offset? _pendingHoverOffset;
  DateTime _lastHoverTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    widget.socket.on('stream:frame', _onFrame);
    widget.socket.emit('stream:subscribe', <String, Object?>{
      'deviceId': widget.deviceId,
      'platform': widget.platform,
    });
    _startFirstFrameTimer();
  }

  @override
  void didUpdateWidget(StreamRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.socket == widget.socket &&
        oldWidget.deviceId == widget.deviceId &&
        oldWidget.platform == widget.platform) {
      return;
    }
    _frameSize = null;
    _frame = null;
    _detachImageListener();
    _firstFrameTimer?.cancel();
    oldWidget.socket.off('stream:frame', _onFrame);
    oldWidget.socket.emit('stream:unsubscribe', <String, Object?>{
      'deviceId': oldWidget.deviceId,
      'platform': oldWidget.platform,
    });
    widget.socket.on('stream:frame', _onFrame);
    widget.socket.emit('stream:subscribe', <String, Object?>{
      'deviceId': widget.deviceId,
      'platform': widget.platform,
    });
    _startFirstFrameTimer();
  }

  void _startFirstFrameTimer() {
    _firstFrameTimer?.cancel();
    _firstFrameTimedOut = false;
    if (widget.onFrameTimeout == null ||
        widget.firstFrameTimeout <= Duration.zero ||
        _frame != null) {
      return;
    }
    _firstFrameTimer = Timer(widget.firstFrameTimeout, () {
      if (!mounted || _frame != null) {
        return;
      }
      _firstFrameTimedOut = true;
      widget.onFrameTimeout?.call();
    });
  }

  void _onFrame(dynamic data) {
    Object? meta;
    Object? bytes;
    if (data is List && data.length >= 2) {
      meta = data[0];
      bytes = data[1];
    }
    if (meta is Map) {
      final frameDeviceId = meta['deviceId']?.toString() ?? '';
      final framePlatform = meta['platform']?.toString() ?? '';
      if (frameDeviceId.isNotEmpty && frameDeviceId != widget.deviceId) {
        return;
      }
      if (framePlatform.isNotEmpty && framePlatform != widget.platform) {
        return;
      }
    }
    final frame = switch (bytes) {
      Uint8List value => value,
      List<int> value => Uint8List.fromList(value),
      ByteBuffer value => Uint8List.view(value),
      _ => null,
    };
    if (frame == null || frame.isEmpty || !mounted) return;
    final hadFrame = _frame != null;
    if (!hadFrame) {
      _firstFrameTimer?.cancel();
      _firstFrameTimer = null;
      if (!_firstFrameTimedOut) {
        widget.onFirstFrame?.call();
      }
    }
    if (_frameSize == null) {
      _resolveFrameSize(frame);
    }
    setState(() => _frame = frame);
  }

  void _resolveFrameSize(Uint8List frame) {
    _detachImageListener();
    final provider = MemoryImage(frame);
    final stream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener((image, _) {
      if (!mounted || _frameSize != null) return;
      setState(() {
        _frameSize = Size(
          image.image.width.toDouble(),
          image.image.height.toDouble(),
        );
      });
      _detachImageListener();
    });
    _imageStream = stream;
    _imageListener = listener;
    stream.addListener(listener);
  }

  void _detachImageListener() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    _imageStream = null;
    _imageListener = null;
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frame;
    if (frame == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return MouseRegion(
          onHover: widget.onHover == null
              ? null
              : (event) =>
                    _handleHoverEvent(event.localPosition, constraints.biggest),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: widget.onTap == null
                ? null
                : (details) => _handleTap(details, constraints.biggest),
            onPanStart: widget.onSwipe == null
                ? null
                : (details) {
                    _dragStart = details.localPosition;
                    _dragEnd = details.localPosition;
                  },
            onPanUpdate: widget.onSwipe == null
                ? null
                : (details) {
                    _dragEnd = details.localPosition;
                  },
            onPanEnd: widget.onSwipe == null
                ? null
                : (_) {
                    final start = _dragStart;
                    final end = _dragEnd;
                    _dragStart = null;
                    _dragEnd = null;
                    if (start == null ||
                        end == null ||
                        (start - end).distance < 12) {
                      return;
                    }
                    _handleSwipe(start, end, constraints.biggest);
                  },
            child: Image.memory(
              frame,
              gaplessPlayback: true,
              fit: widget.fit,
              alignment: widget.alignment,
              width: constraints.maxWidth,
              height: constraints.maxHeight,
            ),
          ),
        );
      },
    );
  }

  void _handleHoverEvent(Offset localPosition, Size boxSize) {
    if (widget.onHover == null) return;
    _pendingHoverOffset = localPosition;
    final now = DateTime.now();
    final elapsed = now.difference(_lastHoverTime);
    const throttleDuration = Duration(milliseconds: 70);

    if (elapsed >= throttleDuration) {
      _sendPendingHover(boxSize);
    } else {
      _hoverThrottleTimer ??= Timer(throttleDuration - elapsed, () {
        _hoverThrottleTimer = null;
        _sendPendingHover(boxSize);
      });
    }
  }

  void _sendPendingHover(Size boxSize) {
    final offset = _pendingHoverOffset;
    if (offset == null) return;
    _pendingHoverOffset = null;
    _lastHoverTime = DateTime.now();

    final point = _mapToRemote(offset, boxSize);
    if (point != null) {
      widget.onHover?.call(point.dx, point.dy);
    }
  }

  void _handleTap(TapDownDetails details, Size boxSize) {
    final point = _mapToRemote(details.localPosition, boxSize);
    if (point == null) {
      return;
    }
    widget.onTap?.call(point.dx, point.dy);
  }

  void _handleSwipe(Offset start, Offset end, Size boxSize) {
    final mappedStart = _mapToRemote(start, boxSize);
    final mappedEnd = _mapToRemote(end, boxSize);
    if (mappedStart == null || mappedEnd == null) {
      return;
    }
    widget.onSwipe?.call(
      mappedStart.dx,
      mappedStart.dy,
      mappedEnd.dx,
      mappedEnd.dy,
    );
  }

  Offset? _mapToRemote(Offset localPosition, Size boxSize) {
    final remote = widget.remoteResolution ?? _frameSize;
    if (remote == null ||
        remote.width <= 0 ||
        remote.height <= 0 ||
        boxSize.width <= 0 ||
        boxSize.height <= 0) {
      return null;
    }
    final remoteSize = Size(remote.width, remote.height);
    final fitted = applyBoxFit(widget.fit, remoteSize, boxSize);
    final sourceRect = widget.alignment.inscribe(
      fitted.source,
      Offset.zero & remoteSize,
    );
    final destRect = widget.alignment.inscribe(
      fitted.destination,
      Offset.zero & boxSize,
    );
    if (!destRect.contains(localPosition)) {
      return null;
    }
    final localX = localPosition.dx - destRect.left;
    final localY = localPosition.dy - destRect.top;
    return Offset(
      sourceRect.left + localX * fitted.source.width / destRect.width,
      sourceRect.top + localY * fitted.source.height / destRect.height,
    );
  }

  @override
  void dispose() {
    _hoverThrottleTimer?.cancel();
    _firstFrameTimer?.cancel();
    widget.socket.emit('stream:unsubscribe', <String, Object?>{
      'deviceId': widget.deviceId,
      'platform': widget.platform,
    });
    widget.socket.off('stream:frame', _onFrame);
    _detachImageListener();
    super.dispose();
  }
}
