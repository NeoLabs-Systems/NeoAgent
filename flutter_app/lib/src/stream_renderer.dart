import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class StreamRenderer extends StatefulWidget {
  const StreamRenderer({
    super.key,
    required this.socket,
    required this.deviceId,
    required this.platform,
    required this.remoteResolution,
    this.onTap,
    this.onType,
    this.fit = BoxFit.contain,
  });

  final io.Socket socket;
  final String deviceId;
  final String platform;
  final Size remoteResolution;
  final void Function(double x, double y)? onTap;
  final void Function(String text)? onType;
  final BoxFit fit;

  @override
  State<StreamRenderer> createState() => _StreamRendererState();
}

class _StreamRendererState extends State<StreamRenderer> {
  Uint8List? _frame;

  @override
  void initState() {
    super.initState();
    widget.socket.on('stream:frame', _onFrame);
    widget.socket.emit('stream:subscribe', <String, Object?>{
      'deviceId': widget.deviceId,
      'platform': widget.platform,
    });
  }

  @override
  void didUpdateWidget(StreamRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.socket == widget.socket &&
        oldWidget.deviceId == widget.deviceId &&
        oldWidget.platform == widget.platform) {
      return;
    }
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
    setState(() => _frame = frame);
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frame;
    if (frame == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: widget.onTap == null
              ? null
              : (details) => _handleTap(details, constraints.biggest),
          child: Image.memory(
            frame,
            gaplessPlayback: true,
            fit: widget.fit,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
          ),
        );
      },
    );
  }

  void _handleTap(TapDownDetails details, Size boxSize) {
    final remote = widget.remoteResolution;
    if (remote.width <= 0 || remote.height <= 0 || boxSize.width <= 0 || boxSize.height <= 0) {
      return;
    }
    final imageAspect = remote.width / remote.height;
    final boxAspect = boxSize.width / boxSize.height;
    double renderWidth;
    double renderHeight;
    double offsetX = 0;
    double offsetY = 0;
    if (boxAspect > imageAspect) {
      renderHeight = boxSize.height;
      renderWidth = renderHeight * imageAspect;
      offsetX = (boxSize.width - renderWidth) / 2;
    } else {
      renderWidth = boxSize.width;
      renderHeight = renderWidth / imageAspect;
      offsetY = (boxSize.height - renderHeight) / 2;
    }
    final localX = details.localPosition.dx - offsetX;
    final localY = details.localPosition.dy - offsetY;
    if (localX < 0 || localY < 0 || localX > renderWidth || localY > renderHeight) {
      return;
    }
    widget.onTap?.call(
      localX * remote.width / renderWidth,
      localY * remote.height / renderHeight,
    );
  }

  @override
  void dispose() {
    widget.socket.emit('stream:unsubscribe', <String, Object?>{
      'deviceId': widget.deviceId,
      'platform': widget.platform,
    });
    widget.socket.off('stream:frame', _onFrame);
    super.dispose();
  }
}
