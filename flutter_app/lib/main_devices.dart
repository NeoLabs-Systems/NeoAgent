part of 'main.dart';

// ignore_for_file: unused_element

class _OptimizedScreenshotPayload {
  const _OptimizedScreenshotPayload({
    required this.bytes,
    required this.mimeType,
    required this.resizedOrReencoded,
  });

  final Uint8List bytes;
  final String mimeType;
  final bool resizedOrReencoded;
}

class DevicesPanel extends StatefulWidget {
  const DevicesPanel({super.key, required this.controller});

  final NeoAgentController controller;

  @override
  State<DevicesPanel> createState() => _DevicesPanelState();
}

class _DevicesPanelState extends State<DevicesPanel> {
  late final TextEditingController _browserUrlController;
  late final TextEditingController _androidLaunchController;
  late final TextEditingController _desktopLaunchController;
  late final TextEditingController _textEntryController;
  Timer? _surfaceFrameTimer;
  _DeviceSurface _surface = _DeviceSurface.browser;
  _DeviceSurface? _runningSurface;

  @override
  void initState() {
    super.initState();
    _browserUrlController = TextEditingController(text: _browserUrlPlaceholder);
    _androidLaunchController = TextEditingController(
      text: _androidLaunchPlaceholder,
    );
    _desktopLaunchController = TextEditingController();
    _textEntryController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_bootstrapSurface());
    });
    _surfaceFrameTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      unawaited(_refreshSurfaceFrame());
    });
  }

  @override
  void dispose() {
    for (final controller in <TextEditingController>[
      _browserUrlController,
      _androidLaunchController,
      _desktopLaunchController,
      _textEntryController,
    ]) {
      controller.dispose();
    }
    _surfaceFrameTimer?.cancel();
    super.dispose();
  }

  bool get _isBrowser => _surface == _DeviceSurface.browser;
  bool get _isDesktop => _surface == _DeviceSurface.desktop;

  bool get _isCurrentSurfaceBusy =>
      widget.controller.isRunningDeviceAction &&
      (_runningSurface == null || _runningSurface == _surface);

  Future<T> _runOnSurface<T>(Future<T> Function() action) async {
    final surface = _surface;
    if (mounted) setState(() => _runningSurface = surface);
    try {
      return await action();
    } finally {
      if (mounted) setState(() => _runningSurface = null);
    }
  }

  bool get _androidOnline {
    final status = widget.controller.androidRuntime;
    final devices = _jsonMapList(status['devices'], fallbackToMapValues: true);
    return devices.any((device) => device['status']?.toString() == 'device');
  }

  bool get _androidStarting =>
      widget.controller.androidRuntime['starting'] == true;

  String? get _androidDeviceId {
    final status = widget.controller.androidRuntime;
    final direct = status['adbSerial']?.toString().trim();
    if (direct != null && direct.isNotEmpty) {
      return direct;
    }
    final devices = _jsonMapList(status['devices'], fallbackToMapValues: true);
    for (final device in devices) {
      if (device['status']?.toString() != 'device') {
        continue;
      }
      final serial = device['serial']?.toString().trim();
      if (serial != null && serial.isNotEmpty) {
        return serial;
      }
      final id = device['deviceId']?.toString().trim();
      if (id != null && id.isNotEmpty) {
        return id;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> get _onlineDesktopDevices => widget
      .controller
      .desktopDevices
      .where((device) => device['online'] == true)
      .toList(growable: false);

  bool get _desktopOnline => _onlineDesktopDevices.isNotEmpty;

  bool get _desktopRequiresSelection =>
      _isDesktop &&
      _onlineDesktopDevices.length > 1 &&
      (widget.controller.selectedDesktopDeviceId ?? '').isEmpty;

  bool get _extensionPreferredButOffline =>
      widget.controller.browserBackend == 'extension' &&
      !widget.controller.browserExtensionConnected;

  List<Map<String, dynamic>> get _browserExtensionDevices =>
      widget.controller.browserExtensionTokens;

  String? get _activeScreenshotPath {
    if (_isBrowser) {
      if (_extensionPreferredButOffline) return null;
      return widget.controller.browserScreenshotPath;
    }
    if (_isDesktop) {
      return widget.controller.desktopScreenshotPath;
    }
    return widget.controller.androidScreenshotPath;
  }

  Future<void> _bootstrapSurface() async {
    await widget.controller.refreshDevices();
    await _ensurePreview();
  }

  Future<void> _ensurePreview() async {
    final controller = widget.controller;
    if (_isBrowser) {
      if (_extensionPreferredButOffline) return;
      if (controller.browserRuntime['launched'] != true) {
        return;
      }
      if ((controller.browserScreenshotPath ?? '').isEmpty) {
        final currentUrl =
            controller.browserRuntime['pageInfo'] is Map<dynamic, dynamic>
            ? (controller.browserRuntime['pageInfo'] as Map)['url']?.toString()
            : null;
        if (currentUrl != null && currentUrl.isNotEmpty) {
          await controller.navigateBrowserRuntime(url: currentUrl);
        } else {
          await controller.screenshotBrowserRuntime();
        }
      }
      return;
    }

    if (_isDesktop) {
      if (_desktopRequiresSelection || !_desktopOnline) {
        return;
      }
      if ((controller.desktopScreenshotPath ?? '').isEmpty) {
        await controller.screenshotDesktopRuntime();
      }
      return;
    }

    if (_androidOnline && (controller.androidScreenshotPath ?? '').isEmpty) {
      await controller.screenshotAndroidRuntime();
    }
  }

  Future<void> _refreshSurfaceFrame() async {
    if (!mounted ||
        widget.controller.selectedSection != AppSection.devices ||
        widget.controller.isRunningDeviceAction ||
        widget.controller.isRefreshingDevices) {
      return;
    }
    if (_isBrowser) {
      if (_extensionPreferredButOffline) return;
      await widget.controller.refreshBrowserFrameRuntime();
      return;
    }
    if (_isDesktop) {
      await widget.controller.refreshDesktopFrameRuntime();
      return;
    }
    if (_androidStarting) {
      await widget.controller.refreshDevices();
      if (_androidOnline &&
          (widget.controller.androidScreenshotPath ?? '').isEmpty) {
        await widget.controller.screenshotAndroidRuntime();
      }
      return;
    }
    await widget.controller.refreshAndroidFrameRuntime();
  }

  Future<void> _selectSurface(_DeviceSurface surface) async {
    setState(() => _surface = surface);
    await _ensurePreview();
  }

  Future<void> _openPrimary() => _runOnSurface(_openPrimaryInner);

  Future<void> _openPrimaryInner() async {
    final controller = widget.controller;
    if (_isBrowser) {
      await controller.navigateBrowserRuntime(
        url: _browserUrlController.text.trim(),
      );
      return;
    }

    if (_isDesktop) {
      if (_desktopRequiresSelection) {
        final selectedId = widget.controller.selectedDesktopDeviceId;
        if ((selectedId ?? '').isEmpty && _onlineDesktopDevices.length == 1) {
          await controller.selectDesktopDeviceRuntime(
            _onlineDesktopDevices.first['deviceId']?.toString() ?? '',
          );
        } else {
          await controller.openDesktopSelectionRuntime();
        }
        return;
      }
      if (!_desktopOnline) {
        return;
      }
      final selectedId = widget.controller.selectedDesktopDeviceId;
      if ((selectedId ?? '').isEmpty && _onlineDesktopDevices.length == 1) {
        await controller.selectDesktopDeviceRuntime(
          _onlineDesktopDevices.first['deviceId']?.toString() ?? '',
        );
      }
      final raw = _desktopLaunchController.text.trim();
      if (raw.isNotEmpty) {
        await controller.launchDesktopAppRuntime(raw);
        return;
      }
      await controller.observeDesktopRuntime();
      return;
    }

    if (!_androidOnline) {
      await controller.startAndroidRuntime();
      await widget.controller.refreshDevices();
      if (_androidOnline) {
        await controller.screenshotAndroidRuntime();
      }
      return;
    }

    final raw = _androidLaunchController.text.trim();
    if (raw.isEmpty) {
      return;
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      await controller.openAndroidIntentRuntime(
        action: 'android.intent.action.VIEW',
        dataUri: raw,
      );
      return;
    }
    await controller.openAndroidAppRuntime(packageName: raw);
  }

  Future<void> _sleepPrimary() => _runOnSurface(_sleepPrimaryInner);

  Future<void> _sleepPrimaryInner() async {
    final controller = widget.controller;
    if (_isBrowser) {
      if (controller.browserRuntime['launched'] != true) {
        return;
      }
      await controller.closeBrowserRuntime();
      return;
    }
    if (_isDesktop) {
      final selectedId = widget.controller.selectedDesktopDeviceId;
      if ((selectedId ?? '').isNotEmpty) {
        await controller.pauseDesktopDeviceRuntime(selectedId!);
      }
      return;
    }
    if (!_androidOnline) {
      return;
    }
    await controller.stopAndroidRuntime();
  }

  Future<void> _sendText() => _runOnSurface(() async {
    final text = _textEntryController.text;
    if (text.trim().isEmpty) {
      return;
    }
    if (_isBrowser) {
      await widget.controller.typeBrowserTextRuntime(text, pressEnter: true);
    } else if (_isDesktop) {
      await widget.controller.typeDesktopRuntime(text, pressEnter: true);
    } else {
      await widget.controller.typeAndroidRuntime(<String, dynamic>{
        'text': text,
        'pressEnter': true,
      });
    }
  });

  void _handleHover(Offset point) {
    if (_isBrowser) {
      unawaited(widget.controller.hoverBrowserPointRuntime(
        x: point.dx.round(),
        y: point.dy.round(),
      ));
    } else if (_isDesktop) {
      if (_desktopRequiresSelection) {
        return;
      }
      unawaited(widget.controller.hoverDesktopRuntime(
        x: point.dx.round(),
        y: point.dy.round(),
      ));
    }
  }

  Future<void> _handleTap(Offset point) => _runOnSurface(() async {
    if (_isBrowser) {
      await widget.controller.clickBrowserPointRuntime(
        x: point.dx.round(),
        y: point.dy.round(),
      );
      return;
    }
    if (_isDesktop) {
      if (_desktopRequiresSelection) {
        return;
      }
      await widget.controller.clickDesktopRuntime(
        x: point.dx.round(),
        y: point.dy.round(),
      );
      return;
    }
    if (!_androidOnline) {
      await widget.controller.startAndroidRuntime();
      return;
    }
    await widget.controller.tapAndroidRuntime(<String, dynamic>{
      'x': point.dx.round(),
      'y': point.dy.round(),
    });
  });

  Future<void> _handleSwipe(Offset start, Offset end) =>
      _runOnSurface(() async {
        if (_isBrowser) {
          await widget.controller.scrollBrowserRuntime(
            deltaY: (start.dy - end.dy).round(),
          );
          return;
        }
        if (_isDesktop) {
          if (_desktopRequiresSelection) {
            return;
          }
          await widget.controller.dragDesktopRuntime(
            x1: start.dx.round(),
            y1: start.dy.round(),
            x2: end.dx.round(),
            y2: end.dy.round(),
          );
          return;
        }
        if (!_androidOnline) {
          return;
        }
        await widget.controller.swipeAndroidRuntime(<String, dynamic>{
          'x1': start.dx.round(),
          'y1': start.dy.round(),
          'x2': end.dx.round(),
          'y2': end.dy.round(),
          'durationMs': 280,
        });
      });

  Future<void> _runQuickAction(String action) => _runOnSurface(() async {
    final controller = widget.controller;
    switch (action) {
      case 'browser_refresh':
        await controller.navigateBrowserRuntime(
          url: controller.browserRuntime['pageInfo'] is Map<dynamic, dynamic>
              ? ((controller.browserRuntime['pageInfo'] as Map)['url']
                        ?.toString() ??
                    _browserUrlController.text.trim())
              : _browserUrlController.text.trim(),
        );
        break;
      case 'browser_enter':
        await controller.pressBrowserKeyRuntime('Enter');
        break;
      case 'desktop_enter':
        await controller.pressDesktopKeyRuntime('Return');
        break;
      case 'desktop_escape':
        await controller.pressDesktopKeyRuntime('Escape');
        break;
      case 'android_back':
        await controller.pressAndroidKeyRuntime('back');
        break;
      case 'android_home':
        await controller.pressAndroidKeyRuntime('home');
        break;
      case 'android_recent':
        await controller.pressAndroidKeyRuntime('app_switch');
        break;
      case 'surface_refresh':
        await _ensurePreview();
        break;
    }
  });

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final browserStatus = controller.browserRuntime;
    final prefersExtension = controller.browserBackend == 'extension';
    final extensionConnected = controller.browserExtensionConnected;
    final usingExtension = prefersExtension && extensionConnected;
    final selectedBrowserExtension = controller.browserExtensionTokens
        .where(
          (device) =>
              device['tokenId'] == controller.selectedBrowserExtensionTokenId,
        )
        .cast<Map<String, dynamic>?>()
        .firstWhere((device) => device != null, orElse: () => null);
    final browserFallbackLabel = 'cloud browser runtime';
    final browserPageInfo = browserStatus['pageInfo'] is Map<dynamic, dynamic>
        ? Map<String, dynamic>.from(browserStatus['pageInfo'] as Map)
        : const <String, dynamic>{};
    final selectedDesktopDevice = controller.desktopDevices
        .where(
          (device) => device['deviceId'] == controller.selectedDesktopDeviceId,
        )
        .cast<Map<String, dynamic>?>()
        .firstWhere((device) => device != null, orElse: () => null);
    final desktopDeviceOnline = selectedDesktopDevice?['online'] == true;
    return ListView(
      padding: _pagePadding(context),
      children: <Widget>[
        _PageTitle(
          title: 'Remote Device',
          subtitle:
              'Tap, swipe, and type directly on the live surface. Use the arrows below to switch between browser, phone, and desktop.',
          trailing: OutlinedButton.icon(
            onPressed:
                controller.isRefreshingDevices ||
                    controller.isRunningDeviceAction
                ? null
                : _bootstrapSurface,
            icon: Icon(Icons.sync),
            label: Text('Sync Surface'),
          ),
        ),
        if (controller.errorMessage case final message?)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _InlineError(message: message),
          ),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Card(
              color: _bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(color: _borderLight),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: <Widget>[
                    _DeviceSurfaceHeader(
                      surface: _surface,
                      browserStatus: browserStatus,
                      browserPageInfo: browserPageInfo,
                      androidRuntime: controller.androidRuntime,
                      androidOnline: _androidOnline,
                      desktopRuntime: controller.desktopRuntime,
                      desktopDevices: controller.desktopDevices,
                      selectedDesktopDeviceId:
                          controller.selectedDesktopDeviceId,
                      browserExtensionDevices:
                          controller.browserExtensionTokens,
                      selectedBrowserExtensionTokenId:
                          controller.selectedBrowserExtensionTokenId,
                      browserExtensionPreferred: prefersExtension,
                      browserExtensionActive: usingExtension,
                      browserFallbackLabel: browserFallbackLabel,
                    ),
                    if (_isBrowser && prefersExtension) ...<Widget>[
                      const SizedBox(height: 14),
                      if (_browserExtensionDevices.isNotEmpty) ...<Widget>[
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          initialValue: selectedBrowserExtension?['tokenId']
                              ?.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Chrome extension device',
                            prefixIcon: Icon(Icons.extension_outlined),
                          ),
                          hint: const Text('Select a paired extension'),
                          items: _browserExtensionDevices.map((device) {
                            final tokenId = device['tokenId']?.toString() ?? '';
                            final label =
                                device['name']?.toString().trim().isNotEmpty ==
                                    true
                                ? device['name'].toString()
                                : tokenId;
                            final state =
                                device['online'] == true ||
                                    device['connected'] == true
                                ? 'online'
                                : 'offline';
                            return DropdownMenuItem<String>(
                              value: tokenId,
                              child: Text(
                                '$label · $state',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                softWrap: false,
                              ),
                            );
                          }).toList(),
                          onChanged: _isCurrentSurfaceBusy
                              ? null
                              : (value) {
                                  if (value == null || value.isEmpty) {
                                    return;
                                  }
                                  unawaited(
                                    controller.selectBrowserExtensionRuntime(
                                      value,
                                    ),
                                  );
                                },
                        ),
                        const SizedBox(height: 10),
                      ],
                      _ExtensionStatusBar(
                        connected: extensionConnected,
                        onDownload: controller.downloadBrowserExtension,
                        onRefresh: controller.refreshBrowserExtensionStatus,
                      ),
                    ],
                    if (_isDesktop) ...<Widget>[
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedDesktopDevice?['deviceId']
                            ?.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Desktop device',
                          prefixIcon: Icon(Icons.computer_outlined),
                        ),
                        hint: const Text('Select a companion desktop'),
                        items: controller.desktopDevices.map((device) {
                          final deviceId = device['deviceId']?.toString() ?? '';
                          final label =
                              device['label']?.toString().trim().isNotEmpty ==
                                  true
                              ? device['label'].toString()
                              : (device['hostname']?.toString() ?? deviceId);
                          final os =
                              device['platform']?.toString() ?? 'desktop';
                          final state = device['online'] == true
                              ? (device['paused'] == true ? 'paused' : 'online')
                              : 'offline';
                          return DropdownMenuItem<String>(
                            value: deviceId,
                            child: Text(
                              '$label · $os · $state',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                            ),
                          );
                        }).toList(),
                        onChanged: _isCurrentSurfaceBusy
                            ? null
                            : (value) {
                                if (value == null || value.isEmpty) {
                                  return;
                                }
                                unawaited(
                                  controller.selectDesktopDeviceRuntime(value),
                                );
                              },
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          _DotStatus(
                            label: desktopDeviceOnline
                                ? 'Companion live'
                                : controller.desktopCompanionConnected
                                ? 'Companion live'
                                : controller.desktopCompanionConnecting
                                ? 'Connecting'
                                : 'Companion idle',
                            color: desktopDeviceOnline
                                ? _success
                                : controller.desktopCompanionConnected
                                ? _success
                                : controller.desktopCompanionConnecting
                                ? _accent
                                : _warning,
                          ),
                          if (selectedDesktopDevice != null)
                            _DotStatus(
                              label: selectedDesktopDevice['paused'] == true
                                  ? 'Paused'
                                  : (selectedDesktopDevice['online'] == true
                                        ? 'Ready'
                                        : 'Offline'),
                              color: selectedDesktopDevice['paused'] == true
                                  ? _warning
                                  : (selectedDesktopDevice['online'] == true
                                        ? _success
                                        : _textMuted),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    _DeviceLaunchBar(
                      surface: _surface,
                      controller: _isBrowser
                          ? _browserUrlController
                          : (_isDesktop
                                ? _desktopLaunchController
                                : _androidLaunchController),
                      active: _isBrowser
                          ? browserStatus['launched'] == true
                          : (_isDesktop
                                ? _desktopOnline
                                : _androidOnline || _androidStarting),
                      starting: !_isBrowser && !_isDesktop && _androidStarting,
                      busy: _isCurrentSurfaceBusy,
                      onSubmit: _openPrimary,
                      onSleep: _sleepPrimary,
                    ),
                    const SizedBox(height: 18),
                    _InteractiveSurfacePreview(
                      surface: _surface,
                      controller: controller,
                      screenshotPath: _activeScreenshotPath,
                      streamPlatform: _isBrowser && browserStatus['launched'] == true
                          ? 'browser'
                          : (_isDesktop && _desktopOnline
                              ? 'desktop'
                              : (!_isBrowser && !_isDesktop && _androidOnline
                                  ? 'android'
                                  : null)),
                      streamDeviceId: _isBrowser && browserStatus['launched'] == true
                          ? 'browser'
                          : (_isDesktop && _desktopOnline
                              ? (widget.controller.selectedDesktopDeviceId ??
                                  (_onlineDesktopDevices.isNotEmpty ? _onlineDesktopDevices.first['deviceId']?.toString() : null))
                              : (!_isBrowser && !_isDesktop && _androidOnline
                                  ? _androidDeviceId
                                  : null)),
                      busy: _isCurrentSurfaceBusy,
                      wakingUp: !_isBrowser && !_isDesktop && _androidStarting,
                      enabled: _isBrowser || _isDesktop || _androidOnline,
                      connectRequired: _isBrowser
                          ? _extensionPreferredButOffline
                          : _desktopRequiresSelection,
                      onTapPoint: _handleTap,
                      onSwipe: _handleSwipe,
                      onHover: _handleHover,
                      onWakeRequested: _openPrimary,
                    ),
                    if (!_isBrowser && !_isDesktop) ...<Widget>[
                      const SizedBox(height: 12),
                      _AndroidNavDock(
                        busy: _isCurrentSurfaceBusy,
                        androidOnline: _androidOnline,
                        onAction: _runQuickAction,
                      ),
                      if (kIsWeb) ...<Widget>[
                        const SizedBox(height: 12),
                        _AndroidActionsBox(
                          enabled: _androidOnline,
                          busy: _isCurrentSurfaceBusy,
                          onInstall: ({required filename, required bytes}) {
                            return controller.installAndroidApkRuntime(
                              filename: filename,
                              bytes: bytes,
                            );
                          },
                        ),
                      ],
                    ],
                    const SizedBox(height: 18),
                    _DeviceTypeDock(
                      controller: _textEntryController,
                      busy: _isCurrentSurfaceBusy,
                      surface: _surface,
                      onSubmit: _sendText,
                    ),
                    if (_isBrowser || _isDesktop) ...<Widget>[
                      const SizedBox(height: 14),
                      _DeviceQuickActions(
                        surface: _surface,
                        androidOnline: _androidOnline,
                        busy: _isCurrentSurfaceBusy,
                        onAction: _runQuickAction,
                      ),
                    ],
                    const SizedBox(height: 14),
                    _SurfaceSwitcher(
                      surface: _surface,
                      onSelect: _selectSurface,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _DeviceSurface { browser, android, desktop }

extension _DeviceSurfaceX on _DeviceSurface {
  String get label => switch (this) {
    _DeviceSurface.browser => 'Browser',
    _DeviceSurface.android => 'Phone',
    _DeviceSurface.desktop => 'Desktop',
  };

  String get helper => switch (this) {
    _DeviceSurface.browser => 'Tap to click. Drag to scroll.',
    _DeviceSurface.android => 'Tap to touch. Drag to swipe.',
    _DeviceSurface.desktop =>
      'Tap to click. Drag to drag windows or selections.',
  };

  IconData get icon => switch (this) {
    _DeviceSurface.browser => Icons.language_outlined,
    _DeviceSurface.android => Icons.smartphone_outlined,
    _DeviceSurface.desktop => Icons.computer_outlined,
  };
}

class _DeviceSurfaceHeader extends StatelessWidget {
  const _DeviceSurfaceHeader({
    required this.surface,
    required this.browserStatus,
    required this.browserPageInfo,
    required this.androidRuntime,
    required this.androidOnline,
    required this.desktopRuntime,
    required this.desktopDevices,
    required this.selectedDesktopDeviceId,
    required this.browserExtensionDevices,
    required this.selectedBrowserExtensionTokenId,
    required this.browserExtensionPreferred,
    required this.browserExtensionActive,
    required this.browserFallbackLabel,
  });

  final _DeviceSurface surface;
  final Map<String, dynamic> browserStatus;
  final Map<String, dynamic> browserPageInfo;
  final Map<String, dynamic> androidRuntime;
  final bool androidOnline;
  final Map<String, dynamic> desktopRuntime;
  final List<Map<String, dynamic>> desktopDevices;
  final String? selectedDesktopDeviceId;
  final List<Map<String, dynamic>> browserExtensionDevices;
  final String? selectedBrowserExtensionTokenId;
  final bool browserExtensionPreferred;
  final bool browserExtensionActive;
  final String browserFallbackLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final androidStarting = androidRuntime['starting'] == true;
        final androidVersion = _androidRuntimeVersionLabel(androidRuntime);
        final selectedDesktop = desktopDevices
            .where((device) => device['deviceId'] == selectedDesktopDeviceId)
            .cast<Map<String, dynamic>?>()
            .firstWhere((device) => device != null, orElse: () => null);
        final selectedExtension = browserExtensionDevices
            .where(
              (device) => device['tokenId'] == selectedBrowserExtensionTokenId,
            )
            .cast<Map<String, dynamic>?>()
            .firstWhere((device) => device != null, orElse: () => null);
        final extensionOnlineCount = browserExtensionDevices
            .where(
              (device) =>
                  device['online'] == true || device['connected'] == true,
            )
            .length;
        final desktopOnlineCount = desktopDevices
            .where((device) => device['online'] == true)
            .length;
        final title = switch (surface) {
          _DeviceSurface.browser =>
            browserExtensionPreferred &&
                    selectedExtension?['name']?.toString().trim().isNotEmpty ==
                        true
                ? selectedExtension!['name'].toString()
                : (browserPageInfo['title']?.toString().trim().isNotEmpty ??
                      false)
                ? browserPageInfo['title'].toString()
                : 'Live Browser',
          _DeviceSurface.android => 'Android Phone',
          _DeviceSurface.desktop =>
            selectedDesktop?['label']?.toString().trim().isNotEmpty == true
                ? selectedDesktop!['label'].toString()
                : 'Desktop Companion',
        };
        final subtitle = switch (surface) {
          _DeviceSurface.browser =>
            browserExtensionPreferred && selectedExtension == null
                ? extensionOnlineCount > 1
                      ? 'Multiple extension devices are online. Pick the browser you want to control.'
                      : 'No extension device is active. Using the $browserFallbackLabel.'
                : browserExtensionPreferred && !browserExtensionActive
                ? 'Selected extension is offline. Using the $browserFallbackLabel.'
                : (browserPageInfo['url']?.toString() ??
                      'Ready for navigation'),
          _DeviceSurface.android =>
            androidOnline
                ? androidVersion == null
                      ? 'Tap and swipe directly on the preview.'
                      : '$androidVersion · Tap and swipe directly on the preview.'
                : androidStarting
                ? (androidRuntime['startupPhase']
                              ?.toString()
                              .trim()
                              .isNotEmpty ??
                          false)
                      ? androidRuntime['startupPhase'].toString()
                      : 'Starting the phone. This can take a little while.'
                : (androidRuntime['lastLogLine']
                          ?.toString()
                          .trim()
                          .isNotEmpty ??
                      false)
                ? androidRuntime['lastLogLine'].toString()
                : androidVersion != null
                ? '$androidVersion selected. Phone is offline.'
                : 'Phone is offline. Open or start it from below.',
          _DeviceSurface.desktop =>
            selectedDesktop == null
                ? desktopOnlineCount > 1
                      ? 'Multiple desktop companions are online. Pick the machine you want to control.'
                      : desktopOnlineCount == 1
                      ? 'One desktop companion is online. Open the surface to fetch the latest frame.'
                      : 'No desktop companion is online. Enable Companion Mode on a signed-in desktop app.'
                : '${selectedDesktop['platform'] ?? 'desktop'} · ${selectedDesktop['hostname'] ?? 'unknown host'}',
        };
        final statusLabel = surface == _DeviceSurface.browser
            ? browserExtensionPreferred && selectedExtension == null
                  ? (extensionOnlineCount > 0 ? 'Select Device' : 'Fallback')
                  : browserExtensionPreferred && !browserExtensionActive
                  ? 'Fallback'
                  : browserExtensionActive
                  ? 'Extension'
                  : (browserStatus['launched'] == true ? 'Live' : 'Sleeping')
            : surface == _DeviceSurface.desktop
            ? selectedDesktop == null
                  ? (desktopOnlineCount > 0 ? 'Select Device' : 'Offline')
                  : (selectedDesktop['paused'] == true
                        ? 'Paused'
                        : (selectedDesktop['online'] == true
                              ? 'Live'
                              : 'Offline'))
            : (androidOnline
                  ? 'Live'
                  : androidStarting
                  ? 'Starting'
                  : 'Offline');
        final statusColor = surface == _DeviceSurface.browser
            ? (browserStatus['launched'] == true ? _success : _warning)
            : surface == _DeviceSurface.desktop
            ? (selectedDesktop?['paused'] == true
                  ? _warning
                  : (selectedDesktop?['online'] == true ? _success : _warning))
            : (androidOnline
                  ? _success
                  : (androidStarting ? _accent : _warning));

        final textColumn = Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _textSecondary, height: 1.4),
              ),
            ],
          ),
        );

        final statusChip = Flexible(
          child: Align(
            alignment: compact ? Alignment.centerLeft : Alignment.centerRight,
            child: _DotStatus(label: statusLabel, color: statusColor),
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _accentMuted,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(surface.icon, color: _textPrimary),
                  ),
                  const SizedBox(width: 14),
                  textColumn,
                ],
              ),
              const SizedBox(height: 12),
              statusChip,
            ],
          );
        }

        return Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _accentMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(surface.icon, color: _textPrimary),
            ),
            const SizedBox(width: 14),
            textColumn,
            const SizedBox(width: 12),
            statusChip,
          ],
        );
      },
    );
  }
}

class _DeviceLaunchBar extends StatelessWidget {
  const _DeviceLaunchBar({
    required this.surface,
    required this.controller,
    required this.active,
    required this.starting,
    required this.busy,
    required this.onSubmit,
    required this.onSleep,
  });

  final _DeviceSurface surface;
  final TextEditingController controller;
  final bool active;
  final bool starting;
  final bool busy;
  final Future<void> Function() onSubmit;
  final Future<void> Function() onSleep;

  @override
  Widget build(BuildContext context) {
    final hint = switch (surface) {
      _DeviceSurface.browser => _browserUrlPlaceholder,
      _DeviceSurface.android => _packageOrUrlHint,
      _DeviceSurface.desktop =>
        'Launch an app on the selected desktop (optional)',
    };
    final buttonLabel = switch (surface) {
      _DeviceSurface.browser => 'Open',
      _DeviceSurface.android => starting ? 'Starting...' : 'Launch',
      _DeviceSurface.desktop => 'Refresh',
    };
    final sleepLabel = switch (surface) {
      _DeviceSurface.browser => 'Sleep Browser',
      _DeviceSurface.android => 'Sleep Phone',
      _DeviceSurface.desktop => 'Pause Desktop',
    };
    final narrow = MediaQuery.sizeOf(context).width < 720;

    final input = TextField(
      controller: controller,
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(
          surface == _DeviceSurface.browser
              ? Icons.travel_explore
              : surface == _DeviceSurface.desktop
              ? Icons.apps_outlined
              : Icons.open_in_new,
        ),
      ),
    );

    final button = FilledButton.icon(
      onPressed: busy || starting ? null : onSubmit,
      icon: Icon(
        surface == _DeviceSurface.browser
            ? Icons.arrow_forward
            : surface == _DeviceSurface.desktop
            ? Icons.desktop_windows_outlined
            : Icons.play_arrow,
      ),
      label: Text(buttonLabel),
    );
    final sleepButton = OutlinedButton.icon(
      onPressed: busy || !active ? null : onSleep,
      icon: Icon(Icons.bedtime_outlined),
      label: Text(sleepLabel),
    );

    if (narrow) {
      return Column(
        children: <Widget>[
          input,
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(child: button),
              const SizedBox(width: 10),
              Expanded(child: sleepButton),
            ],
          ),
        ],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(child: input),
        const SizedBox(width: 10),
        sleepButton,
        const SizedBox(width: 10),
        button,
      ],
    );
  }
}

class _DeviceTypeDock extends StatelessWidget {
  const _DeviceTypeDock({
    required this.controller,
    required this.busy,
    required this.surface,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool busy;
  final _DeviceSurface surface;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    final hint = switch (surface) {
      _DeviceSurface.browser => 'Type into the currently focused field',
      _DeviceSurface.android => 'Type into the current phone field',
      _DeviceSurface.desktop => 'Type into the focused desktop field',
    };
    final narrow = MediaQuery.sizeOf(context).width < 720;

    final input = TextField(
      controller: controller,
      onSubmitted: (_) => onSubmit(),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.keyboard_outlined),
      ),
    );

    final button = FilledButton.icon(
      onPressed: busy ? null : onSubmit,
      icon: Icon(Icons.send_rounded),
      label: Text('Send'),
    );

    if (narrow) {
      return Column(
        children: <Widget>[
          input,
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: button),
        ],
      );
    }

    return Row(
      children: <Widget>[
        Expanded(child: input),
        const SizedBox(width: 10),
        button,
      ],
    );
  }
}

class _DeviceQuickActions extends StatelessWidget {
  const _DeviceQuickActions({
    required this.surface,
    required this.androidOnline,
    required this.busy,
    required this.onAction,
  });

  final _DeviceSurface surface;
  final bool androidOnline;
  final bool busy;
  final Future<void> Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    final actions = switch (surface) {
      _DeviceSurface.browser => const <MapEntry<String, IconData>>[
        MapEntry<String, IconData>('surface_refresh', Icons.refresh_rounded),
        MapEntry<String, IconData>('browser_refresh', Icons.replay_rounded),
        MapEntry<String, IconData>(
          'browser_enter',
          Icons.keyboard_return_rounded,
        ),
      ],
      _DeviceSurface.desktop => const <MapEntry<String, IconData>>[
        MapEntry<String, IconData>('surface_refresh', Icons.refresh_rounded),
        MapEntry<String, IconData>(
          'desktop_enter',
          Icons.keyboard_return_rounded,
        ),
        MapEntry<String, IconData>('desktop_escape', Icons.close_fullscreen),
      ],
      _DeviceSurface.android => const <MapEntry<String, IconData>>[
        MapEntry<String, IconData>('surface_refresh', Icons.refresh_rounded),
      ],
    };

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: actions.map((entry) {
        final disabled =
            busy ||
            (surface != _DeviceSurface.browser &&
                entry.key.startsWith('browser_')) ||
            (surface != _DeviceSurface.desktop &&
                entry.key.startsWith('desktop_')) ||
            (!androidOnline && entry.key.startsWith('android_'));
        return InkWell(
          onTap: disabled ? null : () => onAction(entry.key),
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: disabled ? _bgSecondary : _bgTertiary,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _borderLight),
            ),
            child: Icon(
              entry.value,
              color: disabled ? _textMuted : _textPrimary,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _AndroidNavDock extends StatelessWidget {
  const _AndroidNavDock({
    required this.busy,
    required this.androidOnline,
    required this.onAction,
  });

  final bool busy;
  final bool androidOnline;
  final Future<void> Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    const actions = <MapEntry<String, IconData>>[
      MapEntry<String, IconData>('surface_refresh', Icons.refresh_rounded),
      MapEntry<String, IconData>('android_back', Icons.arrow_back_rounded),
      MapEntry<String, IconData>('android_home', Icons.home_rounded),
      MapEntry<String, IconData>('android_recent', Icons.crop_square_rounded),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: actions.map((entry) {
          final disabled =
              busy || (!androidOnline && entry.key.startsWith('android_'));
          return IconButton.filledTonal(
            tooltip: entry.key.replaceAll('_', ' '),
            onPressed: disabled ? null : () => onAction(entry.key),
            icon: Icon(entry.value),
          );
        }).toList(),
      ),
    );
  }
}

/// Tiny pill shown in the top-right corner of the preview to indicate no audio.
class _MutedBadge extends StatelessWidget {
  const _MutedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.volume_off_rounded, size: 11, color: Colors.white),
    );
  }
}

/// Compact expandable actions box shown beneath the Android nav dock.
/// Starts with APK install; more actions can be added as tiles.
class _AndroidActionsBox extends StatelessWidget {
  const _AndroidActionsBox({
    required this.enabled,
    required this.busy,
    required this.onInstall,
  });

  final bool enabled;
  final bool busy;
  final AndroidApkInstallCallback onInstall;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            'ACTIONS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              AndroidApkTile(
                enabled: enabled,
                busy: busy,
                onInstall: onInstall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SurfaceSwitcher extends StatelessWidget {
  const _SurfaceSwitcher({required this.surface, required this.onSelect});

  final _DeviceSurface surface;
  final Future<void> Function(_DeviceSurface) onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: _DeviceSurface.values.map((s) {
            final selected = s == surface;
            return ChoiceChip(
              avatar: Icon(
                s.icon,
                size: 16,
                color: selected ? _textPrimary : _textSecondary,
              ),
              label: Text(s.label),
              selected: selected,
              onSelected: (_) => onSelect(s),
              selectedColor: _accentMuted,
              backgroundColor: _bgCard,
              side: BorderSide(
                color: selected
                    ? _accent.withValues(alpha: 0.42)
                    : _borderLight,
              ),
              labelStyle: TextStyle(
                color: selected ? _textPrimary : _textSecondary,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          surface.helper,
          textAlign: TextAlign.center,
          style: TextStyle(color: _textSecondary),
        ),
      ],
    );
  }
}

class _InteractiveSurfacePreview extends StatefulWidget {
  const _InteractiveSurfacePreview({
    required this.surface,
    required this.controller,
    required this.screenshotPath,
    required this.streamPlatform,
    required this.streamDeviceId,
    required this.busy,
    required this.wakingUp,
    required this.enabled,
    required this.connectRequired,
    required this.onTapPoint,
    required this.onSwipe,
    this.onHover,
    required this.onWakeRequested,
  });

  final _DeviceSurface surface;
  final NeoAgentController controller;
  final String? screenshotPath;
  final String? streamPlatform;
  final String? streamDeviceId;
  final bool busy;
  final bool wakingUp;
  final bool enabled;
  final bool connectRequired;
  final Future<void> Function(Offset point) onTapPoint;
  final Future<void> Function(Offset start, Offset end) onSwipe;
  final void Function(Offset point)? onHover;
  final Future<void> Function() onWakeRequested;

  @override
  State<_InteractiveSurfacePreview> createState() =>
      _InteractiveSurfacePreviewState();
}

class _InteractiveSurfacePreviewState
    extends State<_InteractiveSurfacePreview> {
  ImageStream? _imageStream;
  ImageStreamListener? _imageListener;
  Size? _pixelSize;
  Uint8List? _imageBytes;
  Object? _imageError;
  Offset? _dragStart;
  Offset? _dragEnd;
  bool _streamStarting = false;
  String? _activeStreamKey;
  String? _streamFailedKey;

  @override
  void initState() {
    super.initState();
    unawaited(_loadImage());
    unawaited(_syncStream());
  }

  @override
  void didUpdateWidget(covariant _InteractiveSurfacePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.screenshotPath != widget.screenshotPath) {
      unawaited(_loadImage());
    }
    if (oldWidget.streamPlatform != widget.streamPlatform ||
        oldWidget.streamDeviceId != widget.streamDeviceId ||
        oldWidget.controller.streamSocket != widget.controller.streamSocket) {
      unawaited(_syncStream());
    }
  }

  @override
  void dispose() {
    unawaited(_stopActiveStream());
    _detachImageListener();
    super.dispose();
  }

  String? get _requestedStreamKey {
    final platform = widget.streamPlatform?.trim();
    final deviceId = widget.streamDeviceId?.trim();
    if (platform == null ||
        platform.isEmpty ||
        deviceId == null ||
        deviceId.isEmpty ||
        widget.controller.streamSocket == null) {
      return null;
    }
    return '$platform:$deviceId';
  }

  Future<void> _syncStream() async {
    final requested = _requestedStreamKey;
    if (_activeStreamKey == requested || _streamStarting) {
      return;
    }
    if (requested != _streamFailedKey) {
      _streamFailedKey = null;
    }
    await _stopActiveStream();
    if (requested == null) {
      return;
    }
    final parts = requested.split(':');
    _streamStarting = true;
    try {
      await widget.controller.startStreamRuntime(
        platform: parts[0],
        deviceId: parts.sublist(1).join(':'),
        fps: 10,
        quality: 70,
      );
      if (mounted && _requestedStreamKey == requested) {
        _activeStreamKey = requested;
        _streamFailedKey = null;
      } else {
        await widget.controller.stopStreamRuntime(
          platform: parts[0],
          deviceId: parts.sublist(1).join(':'),
        );
      }
    } catch (_) {
      if (mounted) {
        _streamFailedKey = requested;
      }
      if (mounted && (widget.screenshotPath ?? '').isEmpty) {
        unawaited(_loadImage());
      }
    } finally {
      _streamStarting = false;
      if (mounted &&
          _activeStreamKey != _requestedStreamKey &&
          _streamFailedKey != _requestedStreamKey) {
        unawaited(_syncStream());
      }
    }
  }

  Future<void> _stopActiveStream() async {
    final active = _activeStreamKey;
    _activeStreamKey = null;
    if (active == null) {
      return;
    }
    final parts = active.split(':');
    try {
      await widget.controller.stopStreamRuntime(
        platform: parts[0],
        deviceId: parts.sublist(1).join(':'),
      );
    } catch (_) {}
  }

  void _handleStreamFirstFrame(String streamKey) {
    if (!mounted || _requestedStreamKey != streamKey) {
      return;
    }
    if (_streamFailedKey == streamKey) {
      setState(() => _streamFailedKey = null);
    }
  }

  void _handleStreamFrameTimeout(String streamKey) {
    if (!mounted || _requestedStreamKey != streamKey) {
      return;
    }
    setState(() => _streamFailedKey = streamKey);
    unawaited(_stopActiveStream());
    if ((widget.screenshotPath ?? '').isEmpty) {
      unawaited(_refreshStaticFrame());
    }
  }

  Future<void> _refreshStaticFrame() async {
    switch (widget.surface) {
      case _DeviceSurface.browser:
        await widget.controller.screenshotBrowserRuntime();
        break;
      case _DeviceSurface.android:
        await widget.controller.screenshotAndroidRuntime();
        break;
      case _DeviceSurface.desktop:
        await widget.controller.screenshotDesktopRuntime();
        break;
    }
  }

  void _detachImageListener() {
    if (_imageStream != null && _imageListener != null) {
      _imageStream!.removeListener(_imageListener!);
    }
    _imageStream = null;
    _imageListener = null;
  }

  Future<void> _loadImage() async {
    _detachImageListener();
    final path = widget.screenshotPath;
    if (path == null || path.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pixelSize = null;
        _imageBytes = null;
        _imageError = null;
      });
      return;
    }
    try {
      final bytes = await widget.controller.fetchRuntimeAssetBytes(path);
      if (!mounted || widget.screenshotPath != path) {
        return;
      }
      setState(() {
        _imageBytes = bytes;
        _imageError = null;
        _pixelSize = null;
      });
      final provider = MemoryImage(bytes);
      final stream = provider.resolve(const ImageConfiguration());
      final listener = ImageStreamListener((image, _) {
        if (!mounted || widget.screenshotPath != path) {
          return;
        }
        setState(() {
          _pixelSize = Size(
            image.image.width.toDouble(),
            image.image.height.toDouble(),
          );
        });
      });
      _imageStream = stream;
      _imageListener = listener;
      stream.addListener(listener);
    } catch (error) {
      if (!mounted || widget.screenshotPath != path) {
        return;
      }
      setState(() {
        _imageBytes = null;
        _pixelSize = null;
        _imageError = error;
      });
    }
  }

  Offset? _mapToPixels(Offset localPosition, Size boxSize) {
    final pixelSize = _pixelSize;
    if (pixelSize == null) {
      return null;
    }
    final boxAspect = boxSize.width / boxSize.height;
    final imageAspect = pixelSize.width / pixelSize.height;
    late final double renderWidth;
    late final double renderHeight;
    late final double offsetX;
    late final double offsetY;

    if (boxAspect > imageAspect) {
      renderHeight = boxSize.height;
      renderWidth = renderHeight * imageAspect;
      offsetX = (boxSize.width - renderWidth) / 2;
      offsetY = 0;
    } else {
      renderWidth = boxSize.width;
      renderHeight = renderWidth / imageAspect;
      offsetX = 0;
      offsetY = (boxSize.height - renderHeight) / 2;
    }

    if (localPosition.dx < offsetX ||
        localPosition.dx > offsetX + renderWidth ||
        localPosition.dy < offsetY ||
        localPosition.dy > offsetY + renderHeight) {
      return null;
    }

    return Offset(
      ((localPosition.dx - offsetX) / renderWidth) * pixelSize.width,
      ((localPosition.dy - offsetY) / renderHeight) * pixelSize.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.screenshotPath;
    final hasImage = path != null && path.isNotEmpty;
    final aspectRatio = switch (widget.surface) {
      _DeviceSurface.browser => 16 / 10,
      _DeviceSurface.android => 10 / 16,
      _DeviceSurface.desktop => 16 / 10,
    };

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[_bgTertiary, _bgSecondary],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _borderLight),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: <Widget>[
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: widget.surface == _DeviceSurface.android ? 640 : 560,
            ),
            child: AspectRatio(
              aspectRatio: aspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final boxSize = Size(
                      constraints.maxWidth,
                      constraints.maxHeight,
                    );
                    final socket = widget.controller.streamSocket;
                    final streamPlatform = widget.streamPlatform;
                    final streamDeviceId = widget.streamDeviceId;
                    final streamKey = _requestedStreamKey;
                    if (socket != null &&
                        streamPlatform != null &&
                        streamPlatform.isNotEmpty &&
                        streamDeviceId != null &&
                        streamDeviceId.isNotEmpty &&
                        streamKey != _streamFailedKey) {
                      final activeStreamKey = streamKey!;
                      return Stack(
                        fit: StackFit.expand,
                        children: <Widget>[
                          Container(color: _bgSecondary),
                          StreamRenderer(
                            socket: socket,
                            deviceId: streamDeviceId,
                            platform: streamPlatform,
                            remoteResolution: _pixelSize,
                            onFirstFrame: () =>
                                _handleStreamFirstFrame(activeStreamKey),
                            onFrameTimeout: () =>
                                _handleStreamFrameTimeout(activeStreamKey),
                            onTap: widget.busy
                                ? null
                                : (x, y) => unawaited(
                                    widget.onTapPoint(Offset(x, y)),
                                  ),
                            onSwipe: widget.busy
                                ? null
                                : (x1, y1, x2, y2) => unawaited(
                                    widget.onSwipe(
                                      Offset(x1, y1),
                                      Offset(x2, y2),
                                    ),
                                  ),
                            onHover: widget.busy
                                ? null
                                : (x, y) => widget.onHover?.call(Offset(x, y)),
                          ),
                          const Positioned(
                            top: 8,
                            right: 8,
                            child: Opacity(
                              opacity: 0.45,
                              child: _MutedBadge(),
                            ),
                          ),
                          Positioned(
                            left: 12,
                            right: 12,
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xB205080D),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _borderLight),
                              ),
                              child: Text(
                                widget.surface.helper,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: _textPrimary),
                              ),
                            ),
                          ),
                          if (widget.busy)
                            const Center(child: CircularProgressIndicator()),
                        ],
                      );
                    }
                    if (!hasImage) {
                      return _EmptySurfaceState(
                        surface: widget.surface,
                        enabled: widget.enabled,
                        busy: widget.busy,
                        isLoadingPreview: widget.wakingUp,
                        connectRequired: widget.connectRequired,
                        errorMessage: _imageError?.toString(),
                        onPressed: widget.onWakeRequested,
                      );
                    }
                    final imageBytes = _imageBytes;
                    if (imageBytes == null) {
                      return _EmptySurfaceState(
                        surface: widget.surface,
                        enabled: widget.enabled,
                        busy: widget.busy,
                        isLoadingPreview: _imageError == null,
                        connectRequired: widget.connectRequired,
                        errorMessage: _imageError?.toString(),
                        onPressed: widget.onWakeRequested,
                      );
                    }
                    return Semantics(
                      button: true,
                      label:
                          'Device surface preview — tap to interact, swipe to scroll',
                      child: GestureDetector(
                        onTapUp: widget.busy
                            ? null
                            : (details) async {
                                final point = _mapToPixels(
                                  details.localPosition,
                                  boxSize,
                                );
                                if (point != null) {
                                  await widget.onTapPoint(point);
                                }
                              },
                        onPanStart: widget.busy
                            ? null
                            : (details) {
                                _dragStart = details.localPosition;
                                _dragEnd = details.localPosition;
                              },
                        onPanUpdate: widget.busy
                            ? null
                            : (details) {
                                _dragEnd = details.localPosition;
                              },
                        onPanEnd: widget.busy
                            ? null
                            : (_) async {
                                final start = _dragStart;
                                final end = _dragEnd;
                                _dragStart = null;
                                _dragEnd = null;
                                if (start == null || end == null) {
                                  return;
                                }
                                if ((start - end).distance < 12) {
                                  return;
                                }
                                final mappedStart = _mapToPixels(
                                  start,
                                  boxSize,
                                );
                                final mappedEnd = _mapToPixels(end, boxSize);
                                if (mappedStart != null && mappedEnd != null) {
                                  await widget.onSwipe(mappedStart, mappedEnd);
                                }
                              },
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            Container(color: _bgSecondary),
                            Image.memory(
                              imageBytes,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            ),
                            const Positioned(
                              top: 8,
                              right: 8,
                              child: Opacity(
                                opacity: 0.45,
                                child: _MutedBadge(),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xB205080D),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _borderLight),
                                ),
                                child: Text(
                                  widget.surface.helper,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: _textPrimary),
                                ),
                              ),
                            ),
                            if (widget.busy)
                              const Center(child: CircularProgressIndicator()),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptySurfaceState extends StatelessWidget {
  const _EmptySurfaceState({
    required this.surface,
    required this.enabled,
    required this.busy,
    required this.isLoadingPreview,
    required this.connectRequired,
    this.errorMessage,
    required this.onPressed,
  });

  final _DeviceSurface surface;
  final bool enabled;
  final bool busy;
  final bool isLoadingPreview;
  final bool connectRequired;
  final String? errorMessage;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    final label = switch (surface) {
      _DeviceSurface.browser =>
        connectRequired
            ? 'Open Settings'
            : (busy ? 'Opening Browser...' : 'Wake Browser'),
      _DeviceSurface.android =>
        busy
            ? 'Starting Phone...'
            : (enabled ? 'Refresh Phone' : 'Start Phone'),
      _DeviceSurface.desktop =>
        connectRequired
            ? 'Select Desktop'
            : (busy ? 'Refreshing Desktop...' : 'Refresh Desktop'),
    };
    final message = switch ((surface, busy, isLoadingPreview)) {
      (_DeviceSurface.browser, true, _) =>
        'Opening the browser and downloading the first preview...',
      (_DeviceSurface.browser, false, true) =>
        'Downloading the latest browser preview...',
      (_DeviceSurface.desktop, true, _) =>
        'Refreshing the selected desktop companion...',
      (_DeviceSurface.desktop, false, true) =>
        'Downloading the latest desktop preview...',
      (_DeviceSurface.android, true, _) =>
        'Waking the phone and downloading the first preview. This can take a little while.',
      (_DeviceSurface.android, false, true) =>
        'Downloading the latest phone preview...',
      _ =>
        surface == _DeviceSurface.browser
            ? connectRequired
                  ? 'Chrome extension is not connected. Use Settings to download, load, and pair the extension on the remote machine.'
                  : 'Browser is sleeping. Press Open to start it.'
            : surface == _DeviceSurface.desktop
            ? connectRequired
                  ? 'Multiple desktop companions are online. Select a machine before sending clicks or keystrokes.'
                  : (errorMessage != null && errorMessage!.trim().isNotEmpty)
                  ? errorMessage!
                  : 'No desktop frame is loaded yet. Refresh the selected machine to capture a frame.'
            : (errorMessage != null && errorMessage!.trim().isNotEmpty)
            ? errorMessage!
            : 'Phone is offline. Press Start Phone to boot it.',
    };
    return Container(
      color: _bgSecondary,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (busy || isLoadingPreview) ...<Widget>[
            const SizedBox(
              width: 38,
              height: 38,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 14),
          ] else
            Icon(surface.icon, size: 46, color: _textSecondary),
          if (!(busy || isLoadingPreview)) const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: _textSecondary),
            textAlign: TextAlign.center,
          ),
          if (errorMessage != null &&
              surface == _DeviceSurface.browser &&
              errorMessage!.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: _textMuted, fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: busy ? null : onPressed,
            icon: Icon(Icons.play_arrow_rounded),
            label: Text(label),
          ),
        ],
      ),
    );
  }
}

class _DeviceFieldRow extends StatelessWidget {
  const _DeviceFieldRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    final stacked = MediaQuery.sizeOf(context).width < 860;
    if (stacked) {
      return Column(
        children: children
            .map(
              (child) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: child,
              ),
            )
            .toList(),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (var index = 0; index < children.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(width: 12),
          Expanded(child: children[index]),
        ],
      ],
    );
  }
}

class _DeviceField extends StatelessWidget {
  const _DeviceField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: _textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _RuntimePreview extends StatelessWidget {
  const _RuntimePreview({
    required this.title,
    required this.screenshotPath,
    required this.controller,
  });

  final String title;
  final String? screenshotPath;
  final NeoAgentController controller;

  @override
  Widget build(BuildContext context) {
    if (screenshotPath == null || screenshotPath!.isEmpty) {
      return _EmptyCard(
        title: title,
        subtitle:
            'Run a screenshot-capable action to preview the live runtime.',
      );
    }

    final uri = controller.resolveRuntimeAsset(screenshotPath!);
    return Card(
      color: _bgSecondary,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              screenshotPath!,
              style: TextStyle(color: _textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                uri.toString(),
                headers: controller.authenticatedImageHeaders,
                fit: BoxFit.cover,
                errorBuilder: (context, _, __) {
                  return Container(
                    height: 220,
                    color: _bgCard,
                    alignment: Alignment.center,
                    child: Text(
                      'Could not load preview image',
                      style: TextStyle(color: _textSecondary),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtensionStatusBar extends StatelessWidget {
  const _ExtensionStatusBar({
    required this.connected,
    required this.onDownload,
    required this.onRefresh,
  });

  final bool connected;
  final Future<void> Function() onDownload;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderLight),
      ),
      child: Row(
        children: <Widget>[
          _DotStatus(
            label: connected
                ? 'Extension connected'
                : 'Extension not connected',
            color: connected ? _success : _warning,
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: onDownload,
            icon: const Icon(Icons.download_outlined, size: 18),
            label: const Text('Download'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.sync, size: 18),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultBlock extends StatelessWidget {
  const _ResultBlock({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _bgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          SelectableText(
            value,
            style: TextStyle(
              fontFamily: GoogleFonts.jetBrainsMono().fontFamily,
              fontSize: 12,
              color: _textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
