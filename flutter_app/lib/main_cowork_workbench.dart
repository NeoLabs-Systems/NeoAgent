part of 'main.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Cowork — workbench (right panel)
//
// Three tabs scoped to the selected session: the computer it runs on, the
// files in its workspace folder, and the files the agent changed.
// ─────────────────────────────────────────────────────────────────────────────

class _CoworkWorkbench extends StatelessWidget {
  const _CoworkWorkbench({
    required this.controller,
    required this.tab,
    required this.onTabChanged,
    required this.onInsertReference,
    required this.onOpenFile,
    required this.onClose,
    this.fileRequest,
  });

  final NeoAgentController controller;
  final _CoworkWorkbenchTab tab;
  final ValueChanged<_CoworkWorkbenchTab> onTabChanged;
  final ValueChanged<String> onInsertReference;
  final ValueChanged<String> onOpenFile;
  final VoidCallback onClose;
  final _CoworkFileRequest? fileRequest;

  @override
  Widget build(BuildContext context) {
    final chat = controller.selectedCoworkChat;
    if (chat == null) {
      return _GlassSurface(
        borderRadius: BorderRadius.circular(AppRadius.panel),
        fillColor: _bgSecondary.withValues(alpha: 0.78),
        child: const _CoworkEmpty(
          icon: Icons.web_asset_rounded,
          title: 'Workbench',
          message: 'Select a session to see its computer, files and changes.',
        ),
      );
    }
    final thread = controller.coworkThreadFor(chat.id);
    return _GlassSurface(
      borderRadius: BorderRadius.circular(AppRadius.panel),
      fillColor: _bgSecondary.withValues(alpha: 0.78),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 8, 6),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _CoworkWorkbenchTabs(
                    value: tab,
                    changeCount: thread.changes.length,
                    onChanged: onTabChanged,
                  ),
                ),
                const SizedBox(width: 6),
                _CoworkIconChip(
                  tooltip: 'Close (⌘J)',
                  icon: Icons.close_rounded,
                  size: 32,
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (tab) {
              _CoworkWorkbenchTab.computer => _CoworkComputerPane(
                controller: controller,
                chat: chat,
              ),
              _CoworkWorkbenchTab.files => _CoworkFileExplorer(
                key: ValueKey<String>(
                  'files-${chat.id}-${chat.device.effective}-${chat.workspacePathOverride}',
                ),
                controller: controller,
                chat: chat,
                request: fileRequest,
                onInsertReference: onInsertReference,
              ),
              _CoworkWorkbenchTab.changes => _CoworkChangesPane(
                controller: controller,
                chat: chat,
                changes: thread.changes,
                onOpen: onOpenFile,
                onInsertReference: onInsertReference,
              ),
            },
          ),
        ],
      ),
    );
  }
}

class _CoworkWorkbenchTabs extends StatelessWidget {
  const _CoworkWorkbenchTabs({
    required this.value,
    required this.changeCount,
    required this.onChanged,
  });

  final _CoworkWorkbenchTab value;
  final int changeCount;
  final ValueChanged<_CoworkWorkbenchTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: _bgCard.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: _borderLight),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _CoworkSegPill(
              dense: true,
              selected: value == _CoworkWorkbenchTab.computer,
              icon: Icons.desktop_windows_outlined,
              label: 'Computer',
              onTap: () => onChanged(_CoworkWorkbenchTab.computer),
            ),
          ),
          Expanded(
            child: _CoworkSegPill(
              dense: true,
              selected: value == _CoworkWorkbenchTab.files,
              icon: Icons.folder_outlined,
              label: 'Files',
              onTap: () => onChanged(_CoworkWorkbenchTab.files),
            ),
          ),
          Expanded(
            child: _CoworkSegPill(
              dense: true,
              selected: value == _CoworkWorkbenchTab.changes,
              icon: Icons.difference_outlined,
              label: changeCount > 0 ? 'Changes · $changeCount' : 'Changes',
              onTap: () => onChanged(_CoworkWorkbenchTab.changes),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Computer ────────────────────────────────────────────────────────────────

class _CoworkComputerPane extends StatefulWidget {
  const _CoworkComputerPane({required this.controller, required this.chat});

  final NeoAgentController controller;
  final CoworkChat chat;

  @override
  State<_CoworkComputerPane> createState() => _CoworkComputerPaneState();
}

class _CoworkComputerPaneState extends State<_CoworkComputerPane> {
  String? _lastChatId;
  String? _lastSurfaceKey;

  NeoAgentController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    var chat = widget.chat;
    if (controller.coworkWorkSurfacePinned && _lastChatId != null) {
      for (final candidate in controller.coworkChats) {
        if (candidate.id == _lastChatId) {
          chat = candidate;
          break;
        }
      }
    } else {
      _lastChatId = chat.id;
    }
    final surfaceKey = '${chat.id}:${chat.device.effective}';
    if (_lastSurfaceKey != surfaceKey) {
      _lastSurfaceKey = surfaceKey;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(controller.refreshDevices(deviceTarget: chat.device.effective));
        }
      });
    }
    final local = chat.device.effective == 'local';
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 6, 2),
          child: Row(
            children: <Widget>[
              Icon(
                local ? Icons.laptop_mac_rounded : Icons.cloud_outlined,
                size: 16,
                color: _accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  local
                      ? 'This device · ${chat.title}'
                      : 'Cloud computer · ${chat.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              IconButton(
                tooltip: controller.coworkWorkSurfacePinned
                    ? 'Follow the selected session'
                    : 'Keep this session\'s computer visible',
                iconSize: 18,
                onPressed: () => controller.setCoworkWorkSurfacePinned(
                  !controller.coworkWorkSurfacePinned,
                ),
                icon: Icon(
                  controller.coworkWorkSurfacePinned
                      ? Icons.push_pin
                      : Icons.push_pin_outlined,
                  color: controller.coworkWorkSurfacePinned
                      ? _accent
                      : _textSecondary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: DevicesPanel(
            key: ValueKey<String>(surfaceKey),
            controller: controller,
            deviceTarget: chat.device.effective,
            showProviderPicker: false,
            computerOnly: true,
          ),
        ),
      ],
    );
  }
}

// ─── Files ───────────────────────────────────────────────────────────────────

class _CoworkFileExplorer extends StatefulWidget {
  const _CoworkFileExplorer({
    super.key,
    required this.controller,
    required this.chat,
    required this.onInsertReference,
    this.request,
  });

  final NeoAgentController controller;
  final CoworkChat chat;
  final ValueChanged<String> onInsertReference;
  final _CoworkFileRequest? request;

  @override
  State<_CoworkFileExplorer> createState() => _CoworkFileExplorerState();
}

class _CoworkFileExplorerState extends State<_CoworkFileExplorer> {
  String _path = '';
  List<CoworkWorkspaceEntry> _entries = const <CoworkWorkspaceEntry>[];
  bool _loading = false;
  String? _error;
  String? _openFile;
  String _content = '';
  bool _loadingFile = false;
  int _handledNonce = -1;

  @override
  void initState() {
    super.initState();
    unawaited(_browse(''));
    _handleRequest();
  }

  @override
  void didUpdateWidget(covariant _CoworkFileExplorer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _handleRequest();
  }

  void _handleRequest() {
    final request = widget.request;
    if (request == null || request.nonce == _handledNonce) return;
    _handledNonce = request.nonce;
    unawaited(_open(request.path));
  }

  Future<void> _browse(String path) async {
    setState(() {
      _loading = true;
      _error = null;
      _openFile = null;
    });
    try {
      final entries = await widget.controller.browseCoworkWorkspace(
        widget.chat,
        path,
      );
      if (!mounted) return;
      setState(() {
        _path = path;
        _entries = entries;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(String path) async {
    final normalized = path.replaceAll('\\', '/').replaceFirst(RegExp(r'^\./'), '');
    setState(() {
      _openFile = normalized;
      _loadingFile = true;
      _content = '';
      _error = null;
    });
    try {
      final content = await widget.controller.readCoworkWorkspaceFile(
        widget.chat,
        normalized,
      );
      if (!mounted || _openFile != normalized) return;
      setState(() => _content = content);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loadingFile = false);
    }
  }

  void _closeFile() {
    final file = _openFile;
    setState(() {
      _openFile = null;
      _content = '';
      _error = null;
    });
    if (file != null) {
      final directory = file.contains('/')
          ? file.substring(0, file.lastIndexOf('/'))
          : '';
      if (directory != _path) unawaited(_browse(directory));
    }
  }

  Future<void> _reveal(String path) async {
    final absolute = _coworkLocalAbsolutePath(widget.chat, path);
    if (absolute == null) return;
    await url_launcher.launchUrl(
      Uri.file(absolute),
      mode: url_launcher.LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = _openFile;
    if (file != null) {
      return _CoworkFilePreview(
        path: file,
        content: _content,
        loading: _loadingFile,
        error: _error,
        canReveal: widget.chat.isLocal,
        onBack: _closeFile,
        onInsertReference: () => widget.onInsertReference(file),
        onReveal: () => _reveal(file),
      );
    }
    final crumbs = _path.split('/').where((part) => part.isNotEmpty).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
          child: Row(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: Row(
                    children: <Widget>[
                      _CoworkCrumb(
                        label: widget.chat.workspaceLabel,
                        icon: Icons.folder_rounded,
                        active: crumbs.isEmpty,
                        onTap: () => _browse(''),
                      ),
                      for (var index = 0; index < crumbs.length; index++) ...<Widget>[
                        Icon(Icons.chevron_right_rounded, size: 16, color: _textMuted),
                        _CoworkCrumb(
                          label: crumbs[index],
                          active: index == crumbs.length - 1,
                          onTap: () => _browse(crumbs.sublist(0, index + 1).join('/')),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                iconSize: 18,
                onPressed: _loading ? null : () => _browse(_path),
                icon: Icon(Icons.refresh_rounded, color: _textSecondary),
              ),
            ],
          ),
        ),
        Expanded(
          child: _error != null
              ? _CoworkEmpty(
                  icon: Icons.folder_off_outlined,
                  title: 'Folder unavailable',
                  message: _error!,
                  action: OutlinedButton(
                    onPressed: () => _browse(_path),
                    child: const Text('Retry'),
                  ),
                )
              : _loading && _entries.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _entries.isEmpty
              ? const _CoworkEmpty(
                  icon: Icons.folder_open_outlined,
                  title: 'Empty folder',
                  message: 'Nothing here yet.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    return _CoworkFileRow(
                      entry: entry,
                      onTap: () =>
                          entry.isDirectory ? _browse(entry.path) : _open(entry.path),
                      onInsertReference: () => widget.onInsertReference(entry.path),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CoworkCrumb extends StatelessWidget {
  const _CoworkCrumb({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: active ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 14, color: _accentHover),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? _textPrimary : _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoworkFileRow extends StatelessWidget {
  const _CoworkFileRow({
    required this.entry,
    required this.onTap,
    required this.onInsertReference,
  });

  final CoworkWorkspaceEntry entry;
  final VoidCallback onTap;
  final VoidCallback onInsertReference;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
          child: Row(
            children: <Widget>[
              Icon(
                entry.isDirectory
                    ? Icons.folder_rounded
                    : _coworkFileIcon(entry.name),
                size: 17,
                color: entry.isDirectory ? _accentHover : _textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: entry.isDirectory ? FontWeight.w600 : FontWeight.w500,
                    color: _textPrimary,
                  ),
                ),
              ),
              if (!entry.isDirectory && entry.sizeBytes != null)
                Text(
                  _coworkFormatBytes(entry.sizeBytes!),
                  style: GoogleFonts.geistMono(fontSize: 10.5, color: _textMuted),
                ),
              const SizedBox(width: 4),
              Tooltip(
                message: 'Add to prompt',
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: onInsertReference,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.alternate_email_rounded,
                      size: 15,
                      color: _textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoworkFilePreview extends StatelessWidget {
  const _CoworkFilePreview({
    required this.path,
    required this.content,
    required this.loading,
    required this.error,
    required this.canReveal,
    required this.onBack,
    required this.onInsertReference,
    required this.onReveal,
  });

  final String path;
  final String content;
  final bool loading;
  final String? error;
  final bool canReveal;
  final VoidCallback onBack;
  final VoidCallback onInsertReference;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    final lines = content.isEmpty ? const <String>[] : content.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 2, 6, 4),
          child: Row(
            children: <Widget>[
              IconButton(
                tooltip: 'Back to folder',
                iconSize: 18,
                onPressed: onBack,
                icon: Icon(Icons.arrow_back_rounded, color: _textSecondary),
              ),
              Icon(_coworkFileIcon(path), size: 16, color: _textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message: path,
                  child: Text(
                    path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.geistMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Add to prompt',
                iconSize: 18,
                onPressed: onInsertReference,
                icon: Icon(Icons.alternate_email_rounded, color: _textSecondary),
              ),
              if (canReveal)
                IconButton(
                  tooltip: 'Open with the default app',
                  iconSize: 18,
                  onPressed: onReveal,
                  icon: Icon(Icons.open_in_new_rounded, color: _textSecondary),
                ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            decoration: BoxDecoration(
              color: _bgTertiary.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: error != null
                ? _CoworkEmpty(
                    icon: Icons.broken_image_outlined,
                    title: 'Cannot preview',
                    message: error!,
                  )
                : loading
                ? const Center(child: CircularProgressIndicator())
                : lines.isEmpty
                ? const _CoworkEmpty(
                    icon: Icons.description_outlined,
                    title: 'Empty file',
                    message: 'This file has no content.',
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SelectionArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            for (var index = 0; index < lines.length; index++)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  SizedBox(
                                    width: 40,
                                    child: Text(
                                      '${index + 1}',
                                      textAlign: TextAlign.right,
                                      style: GoogleFonts.geistMono(
                                        fontSize: 11.5,
                                        height: 1.45,
                                        color: _textMuted,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    lines[index],
                                    style: GoogleFonts.geistMono(
                                      fontSize: 11.5,
                                      height: 1.45,
                                      color: _textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

// ─── Changes ─────────────────────────────────────────────────────────────────

class _CoworkChangesPane extends StatelessWidget {
  const _CoworkChangesPane({
    required this.controller,
    required this.chat,
    required this.changes,
    required this.onOpen,
    required this.onInsertReference,
  });

  final NeoAgentController controller;
  final CoworkChat chat;
  final List<CoworkChangedFile> changes;
  final ValueChanged<String> onOpen;
  final ValueChanged<String> onInsertReference;

  @override
  Widget build(BuildContext context) {
    if (changes.isEmpty) {
      return _CoworkEmpty(
        icon: Icons.difference_outlined,
        title: 'No changes yet',
        message: chat.mode == CoworkInteractionMode.plan
            ? 'Plan mode inspects only. Switch to Agent mode to let NeoAgent edit files.'
            : 'Files NeoAgent writes or edits in this session show up here.',
        action: OutlinedButton.icon(
          onPressed: () => controller.refreshCoworkChanges(chat.id),
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Refresh'),
        ),
      );
    }
    final written = changes.where((change) => change.action == 'written').length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 6, 2),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${changes.length} ${changes.length == 1 ? 'file' : 'files'} changed'
                  '${written > 0 ? ' · $written new' : ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              IconButton(
                tooltip: 'Refresh',
                iconSize: 18,
                onPressed: () => controller.refreshCoworkChanges(chat.id),
                icon: Icon(Icons.refresh_rounded, color: _textSecondary),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
            itemCount: changes.length,
            itemBuilder: (context, index) {
              final change = changes[index];
              final created = change.action == 'written';
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onOpen(change.path),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 7, 4, 7),
                    child: Row(
                      children: <Widget>[
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: (created ? _success : _warning).withValues(
                              alpha: 0.16,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            created ? 'A' : 'M',
                            style: GoogleFonts.geistMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: created ? _success : _warning,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                change.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                <String>[
                                  if (change.directory.isNotEmpty) change.directory,
                                  '${change.edits} ${change.edits == 1 ? 'edit' : 'edits'}',
                                  _coworkRelativeTime(change.changedAt),
                                ].join(' · '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.geistMono(
                                  fontSize: 10.5,
                                  color: _textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Tooltip(
                          message: 'Add to prompt',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => onInsertReference(change.path),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.alternate_email_rounded,
                                size: 15,
                                color: _textMuted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

/// Absolute path of a workspace-relative file on this machine, or null when
/// the session runs on the cloud computer.
String? _coworkLocalAbsolutePath(CoworkChat chat, String relativePath) {
  if (!chat.isLocal) return null;
  final root =
      chat.workspacePathOverride ??
      '${Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? ''}/NeoAgent Workspace';
  final separator = root.endsWith('/') ? '' : '/';
  return '$root$separator$relativePath';
}

String _coworkFormatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

IconData _coworkFileIcon(String name) {
  switch (name.split('.').last.toLowerCase()) {
    case 'dart' || 'js' || 'ts' || 'tsx' || 'jsx' || 'py' || 'go' || 'rs' ||
        'java' || 'kt' || 'swift' || 'c' || 'cc' || 'cpp' || 'h' || 'rb' || 'php' ||
        'sh' || 'zsh':
      return Icons.code_rounded;
    case 'json' || 'yaml' || 'yml' || 'toml' || 'xml' || 'plist' || 'env':
      return Icons.data_object_rounded;
    case 'md' || 'txt' || 'rst':
      return Icons.article_outlined;
    case 'png' || 'jpg' || 'jpeg' || 'gif' || 'webp' || 'svg':
      return Icons.image_outlined;
    case 'pdf':
      return Icons.picture_as_pdf_outlined;
    case 'lock':
      return Icons.lock_outline_rounded;
    default:
      return Icons.insert_drive_file_outlined;
  }
}
