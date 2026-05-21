// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

int _androidApkDropZoneViewId = 0;
const Set<String> _supportedAndroidInstallExtensions = <String>{
  '.apk',
  '.apks',
};

Widget buildAndroidApkDropZone(
  BuildContext context, {
  required bool enabled,
  required bool busy,
  required Future<void> Function({
    required String filename,
    required Uint8List bytes,
  })
  onInstall,
}) {
  return _AndroidApkDropZoneWeb(
    enabled: enabled,
    busy: busy,
    onInstall: onInstall,
  );
}

class _AndroidApkDropZoneWeb extends StatefulWidget {
  const _AndroidApkDropZoneWeb({
    required this.enabled,
    required this.busy,
    required this.onInstall,
  });

  final bool enabled;
  final bool busy;
  final Future<void> Function({
    required String filename,
    required Uint8List bytes,
  })
  onInstall;

  @override
  State<_AndroidApkDropZoneWeb> createState() => _AndroidApkDropZoneWebState();
}

class _AndroidApkDropZoneWebState extends State<_AndroidApkDropZoneWeb> {
  late final String _viewType;
  late final html.DivElement _dropElement;
  late final html.FileUploadInputElement _fileInput;
  final List<StreamSubscription<dynamic>> _subscriptions =
      <StreamSubscription<dynamic>>[];
  bool _dragActive = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'neoagent-android-apk-drop-zone-${_androidApkDropZoneViewId++}';
    _dropElement = html.DivElement()
      ..setAttribute('role', 'button')
      ..setAttribute(
        'aria-label',
        'Drop an APK or APK bundle here to install it',
      )
      ..tabIndex = 0
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block'
      ..style.background = 'rgba(0, 0, 0, 0.001)'
      ..style.cursor = 'pointer';
    _fileInput = html.FileUploadInputElement()
      ..accept = '.apk,.apks'
      ..multiple = false
      ..style.display = 'none';
    _dropElement.append(_fileInput);

    _subscriptions.addAll(<StreamSubscription<dynamic>>[
      _dropElement.onClick.listen((_) => _openPicker()),
      _dropElement.onKeyDown.listen((event) {
        if (event.key == 'Enter' || event.key == ' ') {
          event.preventDefault();
          _openPicker();
        }
      }),
      _dropElement.onDragEnter.listen((event) {
        event.preventDefault();
        if (!_dragActive && mounted) {
          setState(() => _dragActive = true);
        }
      }),
      _dropElement.onDragOver.listen((event) {
        event.preventDefault();
        event.dataTransfer.dropEffect = 'copy';
        if (!_dragActive && mounted) {
          setState(() => _dragActive = true);
        }
      }),
      _dropElement.onDragLeave.listen((event) {
        event.preventDefault();
        if (_dragActive && mounted) {
          setState(() => _dragActive = false);
        }
      }),
      _dropElement.onDrop.listen((event) {
        event.preventDefault();
        if (_dragActive && mounted) {
          setState(() => _dragActive = false);
        }
        final files = event.dataTransfer.files;
        if (files == null || files.isEmpty) {
          return;
        }
        unawaited(_handleFile(files.first));
      }),
      _fileInput.onChange.listen((_) {
        final files = _fileInput.files;
        if (files == null || files.isEmpty) {
          return;
        }
        unawaited(_handleFile(files.first));
      }),
    ]);

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) {
      return _dropElement;
    });
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _dropElement.remove();
    super.dispose();
  }

  void _openPicker() {
    if (!widget.enabled || widget.busy) {
      return;
    }
    _fileInput.value = '';
    _fileInput.click();
  }

  Future<void> _handleFile(html.File file) async {
    if (!widget.enabled || widget.busy) {
      return;
    }
    if (!_isSupportedInstallFile(file.name)) {
      _showError('Only .apk or .apks files can be installed.');
      return;
    }
    try {
      final bytes = await _readFileBytes(file);
      if (!mounted) {
        return;
      }
      await widget.onInstall(filename: file.name, bytes: bytes);
    } catch (error) {
      _showError(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<Uint8List> _readFileBytes(html.File file) {
    final completer = Completer<Uint8List>();
    final reader = html.FileReader();
    reader.onLoad.listen((_) {
      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(Uint8List.view(result));
        return;
      }
      if (result is Uint8List) {
        completer.complete(result);
        return;
      }
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Could not read the Android app package.'),
        );
      }
    });
    reader.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          reader.error ?? StateError('Could not read the Android app package.'),
        );
      }
    });
    reader.readAsArrayBuffer(file);
    return completer.future;
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final cardColor = theme.cardTheme.color ?? colorScheme.surface;
    final onSurface = colorScheme.onSurface;
    final outline = colorScheme.outlineVariant;
    final primary = colorScheme.primary;
    final activeBorderColor = _dragActive ? primary : outline;
    final background = _dragActive
        ? primary.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.14 : 0.10,
          )
        : widget.enabled
        ? cardColor
        : colorScheme.surfaceContainerHighest.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.84 : 0.92,
          );
    final iconBackground = _dragActive
        ? primary.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.18 : 0.14,
          )
        : colorScheme.surfaceContainerHighest.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.72 : 0.92,
          );
    final titleColor = onSurface;
    final subtitleColor = colorScheme.onSurfaceVariant;
    final dropZoneBorderColor = _dragActive ? primary : outline;
    final dropZoneBackground = _dragActive
        ? primary.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.10 : 0.08,
          )
        : colorScheme.surface.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.18 : 0.72,
          );
    final subtitle = widget.busy
        ? 'Installing app package on the phone...'
        : widget.enabled
        ? 'Drag and drop a .apk or .apks file here, or click to browse.'
        : 'Start the Android phone first, then drop a .apk or .apks file here.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: activeBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.install_mobile_outlined,
                  color: _dragActive ? primary : titleColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Install APK / Bundle',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: subtitleColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 92,
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: dropZoneBorderColor),
                      color: dropZoneBackground,
                    ),
                    child: Center(
                      child: Text(
                        widget.busy
                            ? 'Installing...'
                            : _dragActive
                            ? 'Release to install this package'
                            : 'Drop APK or .apks Here',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: HtmlElementView(viewType: _viewType),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

bool _isSupportedInstallFile(String filename) {
  final normalized = filename.toLowerCase();
  return _supportedAndroidInstallExtensions.any(normalized.endsWith);
}

// ─────────────────────────────────────────────────────────────────────────────
// Compact tile variant — used inside the Android actions box.
// Same file-picker / drag-and-drop logic but rendered as a small square tile
// that fits neatly alongside other action tiles.
// ─────────────────────────────────────────────────────────────────────────────

int _androidApkTileViewId = 0;

Widget buildAndroidApkTile(
  BuildContext context, {
  required bool enabled,
  required bool busy,
  required Future<void> Function({
    required String filename,
    required Uint8List bytes,
  })
  onInstall,
}) {
  return _AndroidApkTileWeb(enabled: enabled, busy: busy, onInstall: onInstall);
}

class _AndroidApkTileWeb extends StatefulWidget {
  const _AndroidApkTileWeb({
    required this.enabled,
    required this.busy,
    required this.onInstall,
  });

  final bool enabled;
  final bool busy;
  final Future<void> Function({required String filename, required Uint8List bytes}) onInstall;

  @override
  State<_AndroidApkTileWeb> createState() => _AndroidApkTileWebState();
}

class _AndroidApkTileWebState extends State<_AndroidApkTileWeb> {
  late final String _viewType;
  late final html.DivElement _dropElement;
  late final html.FileUploadInputElement _fileInput;
  final List<StreamSubscription<dynamic>> _subs = [];
  bool _dragActive = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'neoagent-android-apk-tile-${_androidApkTileViewId++}';
    _dropElement = html.DivElement()
      ..setAttribute('role', 'button')
      ..setAttribute('aria-label', 'Install APK — click or drop a .apk file')
      ..tabIndex = 0
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block'
      ..style.background = 'rgba(0,0,0,0.001)'
      ..style.cursor = 'pointer';
    _fileInput = html.FileUploadInputElement()
      ..accept = '.apk,.apks'
      ..multiple = false
      ..style.display = 'none';
    _dropElement.append(_fileInput);

    _subs.addAll([
      _dropElement.onClick.listen((_) => _openPicker()),
      _dropElement.onKeyDown.listen((e) {
        if (e.key == 'Enter' || e.key == ' ') {
          e.preventDefault();
          _openPicker();
        }
      }),
      _dropElement.onDragEnter.listen((e) {
        e.preventDefault();
        if (!_dragActive && mounted) setState(() => _dragActive = true);
      }),
      _dropElement.onDragOver.listen((e) {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'copy';
        if (!_dragActive && mounted) setState(() => _dragActive = true);
      }),
      _dropElement.onDragLeave.listen((e) {
        e.preventDefault();
        if (_dragActive && mounted) setState(() => _dragActive = false);
      }),
      _dropElement.onDrop.listen((e) {
        e.preventDefault();
        if (_dragActive && mounted) setState(() => _dragActive = false);
        final files = e.dataTransfer.files;
        if (files != null && files.isNotEmpty) unawaited(_handleFile(files.first));
      }),
      _fileInput.onChange.listen((_) {
        final files = _fileInput.files;
        if (files != null && files.isNotEmpty) unawaited(_handleFile(files.first));
      }),
    ]);

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int _) => _dropElement);
  }

  @override
  void dispose() {
    for (final s in _subs) s.cancel();
    _dropElement.remove();
    super.dispose();
  }

  void _openPicker() {
    if (!widget.enabled || widget.busy) return;
    _fileInput.value = '';
    _fileInput.click();
  }

  Future<void> _handleFile(html.File file) async {
    if (!widget.enabled || widget.busy) return;
    if (!_isSupportedInstallFile(file.name)) {
      _showError('Only .apk or .apks files can be installed.');
      return;
    }
    try {
      final bytes = await _readFileBytes(file);
      if (mounted) await widget.onInstall(filename: file.name, bytes: bytes);
    } catch (e) {
      _showError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<Uint8List> _readFileBytes(html.File file) {
    final completer = Completer<Uint8List>();
    final reader = html.FileReader();
    reader.onLoad.listen((_) {
      final result = reader.result;
      if (result is ByteBuffer) { completer.complete(Uint8List.view(result)); return; }
      if (result is Uint8List) { completer.complete(result); return; }
      if (!completer.isCompleted) completer.completeError(StateError('Could not read the APK.'));
    });
    reader.onError.listen((_) {
      if (!completer.isCompleted) completer.completeError(reader.error ?? StateError('Read error'));
    });
    reader.readAsArrayBuffer(file);
    return completer.future;
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = _dragActive ? cs.primary : cs.outlineVariant;
    final bgColor = _dragActive
        ? cs.primary.withValues(alpha: isDark ? 0.16 : 0.10)
        : widget.enabled
            ? cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.50 : 0.70)
            : cs.surfaceContainerHighest.withValues(alpha: isDark ? 0.28 : 0.44);
    final iconColor = _dragActive
        ? cs.primary
        : widget.enabled
            ? cs.onSurface
            : cs.onSurface.withValues(alpha: 0.38);
    final labelColor = _dragActive ? cs.primary : cs.onSurfaceVariant;

    return SizedBox(
      width: 80,
      height: 72,
      child: Stack(
        children: [
          // Visual tile
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.busy
                        ? Icons.hourglass_top_rounded
                        : Icons.install_mobile_outlined,
                    size: 20,
                    color: iconColor,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.busy ? 'Installing…' : 'Install APK',
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: labelColor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
          // Transparent HTML element captures all drag / click events
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: HtmlElementView(viewType: _viewType),
            ),
          ),
        ],
      ),
    );
  }
}
