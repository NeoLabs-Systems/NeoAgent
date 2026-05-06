part of 'main.dart';

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

  bool get _androidOnline {
    final status = widget.controller.androidRuntime;
    final devices = _jsonMapList(status['devices'], fallbackToMapValues: true);
    return devices.any((device) => device['status']?.toString() == 'device');
  }

  bool get _androidStarting =>
      widget.controller.androidRuntime['starting'] == true;

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

  String? get _activeScreenshotPath {
    if (_isBrowser) {
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

  Future<void> _switchSurface(int delta) async {
    final surfaces = _DeviceSurface.values;
    final currentIndex = surfaces.indexOf(_surface);
    final nextIndex = (currentIndex + delta) % surfaces.length;
    setState(
      () =>
          _surface = surfaces[nextIndex < 0 ? surfaces.length - 1 : nextIndex],
    );
    await _ensurePreview();
  }

  Future<void> _openPrimary() async {
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

  Future<void> _sleepPrimary() async {
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

  Future<void> _sendText() async {
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
  }

  Future<void> _handleTap(Offset point) async {
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
  }

  Future<void> _handleSwipe(Offset start, Offset end) async {
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
  }

  Future<void> _runQuickAction(String action) async {
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
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final browserStatus = controller.browserRuntime;
    final prefersExtension = controller.browserBackend == 'extension';
    final extensionConnected = controller.browserExtensionConnected;
    final usingExtension = prefersExtension && extensionConnected;
    final browserFallbackLabel = controller.cloudBrowserBackend == 'vm'
        ? 'cloud VM'
        : 'local host';
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
                      browserExtensionPreferred: prefersExtension,
                      browserExtensionActive: usingExtension,
                      browserFallbackLabel: browserFallbackLabel,
                    ),
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
                        onChanged: controller.isRunningDeviceAction
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
                      busy: controller.isRunningDeviceAction,
                      onSubmit: _openPrimary,
                      onSleep: _sleepPrimary,
                    ),
                    const SizedBox(height: 18),
                    _InteractiveSurfacePreview(
                      surface: _surface,
                      controller: controller,
                      screenshotPath: _activeScreenshotPath,
                      busy: controller.isRunningDeviceAction,
                      wakingUp: !_isBrowser && !_isDesktop && _androidStarting,
                      enabled: _isBrowser || _isDesktop || _androidOnline,
                      connectRequired: _desktopRequiresSelection,
                      onTapPoint: _handleTap,
                      onSwipe: _handleSwipe,
                      onWakeRequested: _openPrimary,
                    ),
                    if (!_isBrowser && !_isDesktop) ...<Widget>[
                      const SizedBox(height: 12),
                      _AndroidNavDock(
                        busy: controller.isRunningDeviceAction,
                        androidOnline: _androidOnline,
                        onAction: _runQuickAction,
                      ),
                      if (kIsWeb) ...<Widget>[
                        const SizedBox(height: 14),
                        AndroidApkDropZone(
                          enabled: _androidOnline,
                          busy: controller.isRunningDeviceAction,
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
                      busy: controller.isRunningDeviceAction,
                      surface: _surface,
                      onSubmit: _sendText,
                    ),
                    if (_isBrowser || _isDesktop) ...<Widget>[
                      const SizedBox(height: 14),
                      _DeviceQuickActions(
                        surface: _surface,
                        androidOnline: _androidOnline,
                        busy: controller.isRunningDeviceAction,
                        onAction: _runQuickAction,
                      ),
                    ],
                    const SizedBox(height: 14),
                    _SurfaceSwitcher(
                      surface: _surface,
                      onPrevious: () => _switchSurface(-1),
                      onNext: () => _switchSurface(1),
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
        final desktopOnlineCount = desktopDevices
            .where((device) => device['online'] == true)
            .length;
        final title = switch (surface) {
          _DeviceSurface.browser =>
            (browserPageInfo['title']?.toString().trim().isNotEmpty ?? false)
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
            browserExtensionPreferred && !browserExtensionActive
                ? 'No extension device is active. Using the $browserFallbackLabel browser fallback.'
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
            ? browserExtensionPreferred && !browserExtensionActive
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
            onPressed: disabled ? null : () => onAction(entry.key),
            icon: Icon(entry.value),
          );
        }).toList(),
      ),
    );
  }
}

class _SurfaceSwitcher extends StatelessWidget {
  const _SurfaceSwitcher({
    required this.surface,
    required this.onPrevious,
    required this.onNext,
  });

  final _DeviceSurface surface;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final labelColumn = Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              surface.label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              surface.helper,
              textAlign: TextAlign.center,
              maxLines: compact ? 3 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _textSecondary),
            ),
          ],
        );

        if (compact) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  IconButton.filledTonal(
                    onPressed: onPrevious,
                    icon: Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const SizedBox(width: 14),
                  Flexible(child: labelColumn),
                  const SizedBox(width: 14),
                  IconButton.filledTonal(
                    onPressed: onNext,
                    icon: Icon(Icons.arrow_forward_ios_rounded),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconButton.filledTonal(
              onPressed: onPrevious,
              icon: Icon(Icons.arrow_back_ios_new_rounded),
            ),
            const SizedBox(width: 14),
            labelColumn,
            const SizedBox(width: 14),
            IconButton.filledTonal(
              onPressed: onNext,
              icon: Icon(Icons.arrow_forward_ios_rounded),
            ),
          ],
        );
      },
    );
  }
}

class _InteractiveSurfacePreview extends StatefulWidget {
  const _InteractiveSurfacePreview({
    required this.surface,
    required this.controller,
    required this.screenshotPath,
    required this.busy,
    required this.wakingUp,
    required this.enabled,
    required this.connectRequired,
    required this.onTapPoint,
    required this.onSwipe,
    required this.onWakeRequested,
  });

  final _DeviceSurface surface;
  final NeoAgentController controller;
  final String? screenshotPath;
  final bool busy;
  final bool wakingUp;
  final bool enabled;
  final bool connectRequired;
  final Future<void> Function(Offset point) onTapPoint;
  final Future<void> Function(Offset start, Offset end) onSwipe;
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

  @override
  void initState() {
    super.initState();
    unawaited(_loadImage());
  }

  @override
  void didUpdateWidget(covariant _InteractiveSurfacePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.screenshotPath != widget.screenshotPath) {
      unawaited(_loadImage());
    }
  }

  @override
  void dispose() {
    _detachImageListener();
    super.dispose();
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
                    return GestureDetector(
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
                              final mappedStart = _mapToPixels(start, boxSize);
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

// ignore: unused_element
class _RuntimeControlCard extends StatelessWidget {
  const _RuntimeControlCard({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget status;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(color: _textSecondary, height: 1.5),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                status,
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _BrowserControls extends StatelessWidget {
  const _BrowserControls({
    required this.controller,
    required this.browserStatus,
    required this.browserPageInfo,
    required this.urlController,
    required this.waitForController,
    required this.clickSelectorController,
    required this.clickTextController,
    required this.fillSelectorController,
    required this.fillValueController,
  });

  final NeoAgentController controller;
  final Map<String, dynamic> browserStatus;
  final Map<String, dynamic> browserPageInfo;
  final TextEditingController urlController;
  final TextEditingController waitForController;
  final TextEditingController clickSelectorController;
  final TextEditingController clickTextController;
  final TextEditingController fillSelectorController;
  final TextEditingController fillValueController;

  @override
  Widget build(BuildContext context) {
    final launched = browserStatus['launched'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _MetaPill(
              label: launched ? 'Launched' : 'Idle',
              icon: Icons.language_outlined,
            ),
            _MetaPill(
              label: 'Pages ${browserStatus['pages'] ?? 0}',
              icon: Icons.filter_none_outlined,
            ),
            _MetaPill(
              label: browserStatus['headless'] == false
                  ? 'Visible window'
                  : 'Headless',
              icon: Icons.visibility_outlined,
            ),
          ],
        ),
        if ((browserPageInfo['url']?.toString().isNotEmpty ?? false) ||
            (browserPageInfo['title']?.toString().isNotEmpty ??
                false)) ...<Widget>[
          const SizedBox(height: 14),
          SelectableText(
            '${browserPageInfo['title'] ?? 'Untitled'}\n${browserPageInfo['url'] ?? ''}',
            style: TextStyle(color: _textSecondary, height: 1.5),
          ),
        ],
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'URL',
              child: TextField(controller: urlController),
            ),
            _DeviceField(
              label: 'Wait For Selector',
              child: TextField(controller: waitForController),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            FilledButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.launchBrowserRuntime,
              icon: Icon(Icons.rocket_launch_outlined),
              label: Text('Launch'),
            ),
            FilledButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : () => controller.navigateBrowserRuntime(
                      url: urlController.text.trim(),
                      waitFor: waitForController.text.trim(),
                    ),
              icon: Icon(Icons.open_in_browser_outlined),
              label: Text('Navigate'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.screenshotBrowserRuntime,
              icon: Icon(Icons.photo_camera_back_outlined),
              label: Text('Screenshot'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.closeBrowserRuntime,
              icon: Icon(Icons.close),
              label: Text('Close'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Click Selector',
              child: TextField(controller: clickSelectorController),
            ),
            _DeviceField(
              label: 'Click Text',
              child: TextField(controller: clickTextController),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            OutlinedButton(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : () => controller.clickBrowserRuntime(
                      selector: clickSelectorController.text.trim(),
                    ),
              child: Text('Click Selector'),
            ),
            OutlinedButton(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : () => controller.clickBrowserRuntime(
                      text: clickTextController.text.trim(),
                    ),
              child: Text('Click Text'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Type Selector',
              child: TextField(controller: fillSelectorController),
            ),
            _DeviceField(
              label: 'Value',
              child: TextField(controller: fillValueController),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: controller.isRunningDeviceAction
              ? null
              : () => controller.fillBrowserRuntime(
                  selector: fillSelectorController.text.trim(),
                  value: fillValueController.text,
                ),
          icon: Icon(Icons.keyboard_outlined),
          label: Text('Type Into Field'),
        ),
        const SizedBox(height: 18),
        _RuntimePreview(
          title: 'Latest Browser Screenshot',
          screenshotPath: controller.browserScreenshotPath,
          controller: controller,
        ),
        if (controller.browserLastResult?.trim().isNotEmpty ??
            false) ...<Widget>[
          const SizedBox(height: 14),
          _ResultBlock(
            label: 'Last browser result',
            value: controller.browserLastResult!,
          ),
        ],
      ],
    );
  }
}

// ignore: unused_element
class _AndroidControls extends StatelessWidget {
  const _AndroidControls({
    required this.controller,
    required this.androidStatus,
    required this.androidDevices,
    required this.packageController,
    required this.activityController,
    required this.intentActionController,
    required this.intentDataController,
    required this.tapTextController,
    required this.tapDescriptionController,
    required this.tapResourceIdController,
    required this.tapXController,
    required this.tapYController,
    required this.typeTextController,
    required this.typeFieldTextController,
    required this.typeFieldDescriptionController,
    required this.waitTextController,
    required this.keyController,
    required this.swipeX1Controller,
    required this.swipeY1Controller,
    required this.swipeX2Controller,
    required this.swipeY2Controller,
    required this.toInt,
  });

  final NeoAgentController controller;
  final Map<String, dynamic> androidStatus;
  final List<Map<String, dynamic>> androidDevices;
  final TextEditingController packageController;
  final TextEditingController activityController;
  final TextEditingController intentActionController;
  final TextEditingController intentDataController;
  final TextEditingController tapTextController;
  final TextEditingController tapDescriptionController;
  final TextEditingController tapResourceIdController;
  final TextEditingController tapXController;
  final TextEditingController tapYController;
  final TextEditingController typeTextController;
  final TextEditingController typeFieldTextController;
  final TextEditingController typeFieldDescriptionController;
  final TextEditingController waitTextController;
  final TextEditingController keyController;
  final TextEditingController swipeX1Controller;
  final TextEditingController swipeY1Controller;
  final TextEditingController swipeX2Controller;
  final TextEditingController swipeY2Controller;
  final int? Function(String text) toInt;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            _MetaPill(
              label: androidStatus['bootstrapped'] == true
                  ? 'SDK Ready'
                  : 'Bootstrap Needed',
              icon: Icons.adb_outlined,
            ),
            _MetaPill(
              label: androidStatus['serial']?.toString().isNotEmpty == true
                  ? androidStatus['serial'].toString()
                  : 'No active serial',
              icon: Icons.phone_android_outlined,
            ),
            _MetaPill(
              label: '${androidDevices.length} device(s)',
              icon: Icons.devices_other_outlined,
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            FilledButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.startAndroidRuntime,
              icon: Icon(Icons.play_arrow_outlined),
              label: Text('Start Emulator'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.stopAndroidRuntime,
              icon: Icon(Icons.stop_circle_outlined),
              label: Text('Stop'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.screenshotAndroidRuntime,
              icon: Icon(Icons.photo_camera_outlined),
              label: Text('Screenshot'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.dumpAndroidUiRuntime,
              icon: Icon(Icons.data_object_outlined),
              label: Text('Dump UI'),
            ),
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : controller.refreshAndroidApps,
              icon: Icon(Icons.apps_outlined),
              label: Text('Load Apps'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Package',
              child: TextField(controller: packageController),
            ),
            _DeviceField(
              label: 'Activity',
              child: TextField(controller: activityController),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            OutlinedButton.icon(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : () => controller.openAndroidAppRuntime(
                      packageName: packageController.text.trim(),
                      activity: activityController.text.trim(),
                    ),
              icon: Icon(Icons.apps),
              label: Text('Open App'),
            ),
            if (controller.androidInstalledApps.isNotEmpty)
              SizedBox(width: 1, height: 1, child: Container()),
          ],
        ),
        if (controller.androidInstalledApps.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: controller.androidInstalledApps.take(10).map((appId) {
              return ActionChip(
                label: Text(appId),
                onPressed: () => packageController.text = appId,
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Intent Action',
              child: TextField(controller: intentActionController),
            ),
            _DeviceField(
              label: 'Intent Data',
              child: TextField(controller: intentDataController),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: controller.isRunningDeviceAction
              ? null
              : () => controller.openAndroidIntentRuntime(
                  action: intentActionController.text.trim(),
                  dataUri: intentDataController.text.trim(),
                  packageName: packageController.text.trim(),
                ),
          icon: Icon(Icons.route_outlined),
          label: Text('Open Intent'),
        ),
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Wait For Text',
              child: TextField(controller: waitTextController),
            ),
            _DeviceField(
              label: 'Key',
              child: TextField(controller: keyController),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            OutlinedButton(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : () => controller.waitForAndroidRuntime(<String, dynamic>{
                      'text': waitTextController.text.trim(),
                      'timeoutMs': 20000,
                      'intervalMs': 1200,
                    }),
              child: Text('Wait For UI'),
            ),
            OutlinedButton(
              onPressed: controller.isRunningDeviceAction
                  ? null
                  : () => controller.pressAndroidKeyRuntime(
                      keyController.text.trim(),
                    ),
              child: Text('Press Key'),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Tap Text',
              child: TextField(controller: tapTextController),
            ),
            _DeviceField(
              label: 'Tap Description',
              child: TextField(controller: tapDescriptionController),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Tap Resource Id',
              child: TextField(controller: tapResourceIdController),
            ),
            _DeviceField(
              label: 'Tap X / Y',
              child: Row(
                children: <Widget>[
                  Expanded(child: TextField(controller: tapXController)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: tapYController)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: controller.isRunningDeviceAction
              ? null
              : () => controller.tapAndroidRuntime(<String, dynamic>{
                  if (tapTextController.text.trim().isNotEmpty)
                    'text': tapTextController.text.trim(),
                  if (tapDescriptionController.text.trim().isNotEmpty)
                    'description': tapDescriptionController.text.trim(),
                  if (tapResourceIdController.text.trim().isNotEmpty)
                    'resourceId': tapResourceIdController.text.trim(),
                  if (toInt(tapXController.text) != null)
                    'x': toInt(tapXController.text),
                  if (toInt(tapYController.text) != null)
                    'y': toInt(tapYController.text),
                }),
          icon: Icon(Icons.touch_app_outlined),
          label: Text('Tap'),
        ),
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Type Text',
              child: TextField(controller: typeTextController),
            ),
            _DeviceField(
              label: 'Focus Field Text / Description',
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(controller: typeFieldTextController),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: typeFieldDescriptionController,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: controller.isRunningDeviceAction
              ? null
              : () => controller.typeAndroidRuntime(<String, dynamic>{
                  'text': typeTextController.text,
                  if (typeFieldTextController.text.trim().isNotEmpty)
                    'textSelector': typeFieldTextController.text.trim(),
                  if (typeFieldDescriptionController.text.trim().isNotEmpty)
                    'description': typeFieldDescriptionController.text.trim(),
                  'pressEnter': true,
                }),
          icon: Icon(Icons.keyboard_outlined),
          label: Text('Type'),
        ),
        const SizedBox(height: 18),
        _DeviceFieldRow(
          children: <Widget>[
            _DeviceField(
              label: 'Swipe X1 / Y1',
              child: Row(
                children: <Widget>[
                  Expanded(child: TextField(controller: swipeX1Controller)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: swipeY1Controller)),
                ],
              ),
            ),
            _DeviceField(
              label: 'Swipe X2 / Y2',
              child: Row(
                children: <Widget>[
                  Expanded(child: TextField(controller: swipeX2Controller)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: swipeY2Controller)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: controller.isRunningDeviceAction
              ? null
              : () => controller.swipeAndroidRuntime(<String, dynamic>{
                  'x1': toInt(swipeX1Controller.text),
                  'y1': toInt(swipeY1Controller.text),
                  'x2': toInt(swipeX2Controller.text),
                  'y2': toInt(swipeY2Controller.text),
                }),
          icon: Icon(Icons.swipe_outlined),
          label: Text('Swipe'),
        ),
        const SizedBox(height: 18),
        _RuntimePreview(
          title: 'Latest Android Screenshot',
          screenshotPath: controller.androidScreenshotPath,
          controller: controller,
        ),
        if (controller.androidUiPreview.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          Text(
            'Latest UI dump preview',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          ...controller.androidUiPreview.take(6).map((node) {
            final title = node['text']?.toString().trim().isNotEmpty == true
                ? node['text'].toString()
                : node['description']?.toString().trim().isNotEmpty == true
                ? node['description'].toString()
                : node['resourceId']?.toString().trim().isNotEmpty == true
                ? node['resourceId'].toString()
                : node['className']?.toString() ?? 'node';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bgSecondary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: Text(
                '$title\n${node['packageName'] ?? ''}',
                style: TextStyle(color: _textSecondary, height: 1.5),
              ),
            );
          }),
        ],
        if (controller.androidLastResult?.trim().isNotEmpty ??
            false) ...<Widget>[
          const SizedBox(height: 14),
          _ResultBlock(
            label: 'Last Android result',
            value: controller.androidLastResult!,
          ),
        ],
      ],
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
