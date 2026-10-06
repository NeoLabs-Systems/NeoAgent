part of 'main.dart';

// ---------------------------------------------------------------------------
// Memory knowledge graph: the most-mentioned entities, linked when they appear
// in the same memories and colored by cluster. Pan, pinch or ctrl/⌘-scroll to
// zoom; tap to focus an entity and load its memories.
// ---------------------------------------------------------------------------

String _entityKindLabel(String kind) {
  switch (kind) {
    case 'domain':
      return appStrings.entityKindDomain;
    case 'email':
      return appStrings.entityKindEmail;
    case 'url':
      return appStrings.entityKindLink;
    case 'file':
      return appStrings.entityKindFile;
    case 'acronym':
      return appStrings.entityKindAcronym;
    case 'identifier':
      return appStrings.entityKindIdentifier;
    case 'version':
      return appStrings.entityKindVersion;
    default:
      return appStrings.entityKindConcept;
  }
}

/// Builds the layout model lazily per canvas shape and theme, so resizing or
/// switching theme re-lays out without refetching.
class _EntityGraphModelCache {
  _EntityGraphModel? model;
  MemoryGraph? _graph;
  Color? _builtAccent;
  Brightness? _builtBrightness;

  _EntityGraphModel resolve(MemoryGraph graph, Size size) {
    final aspect = (size.width / size.height * 10).round() / 10;
    final cached = model;
    if (cached != null &&
        identical(_graph, graph) &&
        cached.aspect == aspect &&
        _builtAccent == _accent &&
        _builtBrightness == _appBrightness) {
      return cached;
    }
    _graph = graph;
    _builtAccent = _accent;
    _builtBrightness = _appBrightness;
    return model = _EntityGraphModel.build(
      graph,
      aspect: aspect,
      accent: _accent,
      brightness: _appBrightness,
    );
  }

  List<({MemoryEntity entity, int weight})> neighborsOf(String id) =>
      model?.neighborsOf(id) ?? const <({MemoryEntity entity, int weight})>[];
}

class _EntityGraphSection extends StatefulWidget {
  const _EntityGraphSection({
    required this.controller,
    required this.selectedEntity,
    required this.onEntitySelected,
  });

  final NeoAgentController controller;
  final MemoryEntity? selectedEntity;
  final ValueChanged<MemoryEntity?> onEntitySelected;

  @override
  State<_EntityGraphSection> createState() => _EntityGraphSectionState();
}

class _EntityGraphSectionState extends State<_EntityGraphSection> {
  final _EntityGraphModelCache _models = _EntityGraphModelCache();
  final TextEditingController _search = TextEditingController();
  MemoryGraph? _graph;
  Object? _error;
  String? _requestKey;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// More room shows more entities: roughly one per 6500 px², in steps of 20
  /// so small resizes do not refetch.
  static int _nodeBudget(Size size) {
    final raw = size.width * size.height / 6500;
    return ((raw / 20).round() * 20).clamp(40, 200);
  }

  void _ensureLoaded(int limit) {
    final stats = widget.controller.memoryOverview.stats;
    final key = '$limit:${stats.entities}:${stats.active}';
    if (key == _requestKey) return;
    _requestKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(key, limit));
  }

  Future<void> _load(String key, int limit) async {
    try {
      final graph = await widget.controller.fetchMemoryGraph(limit: limit);
      if (!mounted || key != _requestKey) return;
      setState(() {
        _graph = graph;
        _error = null;
      });
    } catch (error) {
      if (!mounted || key != _requestKey) return;
      setState(() => _error = error);
    }
  }

  void _selectById(String? id) {
    MemoryEntity? entity;
    for (final node in _graph?.nodes ?? const <MemoryEntity>[]) {
      if (node.id == id) entity = node;
    }
    widget.onEntitySelected(
      entity == null || entity.id == widget.selectedEntity?.id ? null : entity,
    );
  }

  void _selectFirstMatch(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return;
    final nodes = [...?_graph?.nodes]
      ..sort((a, b) => b.mentionCount.compareTo(a.mentionCount));
    for (final node in nodes) {
      if (node.name.toLowerCase().contains(needle)) {
        widget.onEntitySelected(node);
        return;
      }
    }
  }

  Future<void> _openFullscreen() async {
    final graph = _graph;
    if (graph == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _EntityGraphFullscreenPage(
          graph: graph,
          initialSelection: widget.selectedEntity,
          onEntitySelected: widget.onEntitySelected,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final graph = _graph;
    final selected = widget.selectedEntity;
    final legendModel = identical(_models._graph, graph) ? _models.model : null;
    final screen = MediaQuery.sizeOf(context);
    final compact = screen.width < 760;
    final canvasHeight = (screen.height * (compact ? 0.55 : 0.68)).clamp(
      380.0,
      820.0,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: _SectionTitle(appStrings.knowledgeGraph)),
            if (selected != null)
              TextButton.icon(
                onPressed: () => widget.onEntitySelected(null),
                icon: const Icon(Icons.close, size: 16),
                label: Text(appStrings.clearFilter),
              ),
            IconButton(
              tooltip: appStrings.openFullscreen,
              icon: const Icon(Icons.open_in_full, size: 18),
              onPressed: graph == null ? null : _openFullscreen,
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          appStrings.knowledgeGraphHint,
          style: TextStyle(color: _textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          onSubmitted: _selectFirstMatch,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: const Icon(Icons.search, size: 18),
            hintText: appStrings.searchEntities,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: canvasHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              _ensureLoaded(_nodeBudget(size));
              if (graph == null) {
                return _GraphPlaceholder(error: _error);
              }
              final model = _models.resolve(graph, size);
              // The legend below was built from the previous model; rebuild
              // once the canvas has laid out the new one.
              if (!identical(model, legendModel)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() {});
                });
              }
              return _EntityGraphCanvas(
                model: model,
                selectedId: selected?.id,
                query: _search.text,
                onSelect: _selectById,
              );
            },
          ),
        ),
        if (graph != null) ...<Widget>[
          const SizedBox(height: 12),
          _ClusterLegend(
            clusters: legendModel?.clusters ?? const <_GraphCluster>[],
            onSelect: widget.onEntitySelected,
          ),
        ],
        if (graph != null && selected != null) ...<Widget>[
          const SizedBox(height: 14),
          _EntityInspector(
            entity: selected,
            neighbors: _models.neighborsOf(selected.id),
            onSelect: _selectById,
          ),
        ],
      ],
    );
  }
}

class _GraphPlaceholder extends StatelessWidget {
  const _GraphPlaceholder({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: _graphSurfaceDecoration(),
      child: Center(
        child: error == null
            ? const CircularProgressIndicator()
            : Text(
                _formatCaughtError(error!),
                style: TextStyle(color: _textSecondary),
              ),
      ),
    );
  }
}

BoxDecoration _graphSurfaceDecoration() => BoxDecoration(
  gradient: RadialGradient(
    radius: 1.1,
    colors: <Color>[
      Color.alphaBlend(_accent.withValues(alpha: 0.06), _bgSecondary),
      _bgPrimary,
    ],
  ),
  borderRadius: BorderRadius.circular(16),
  border: Border.all(color: _border.withValues(alpha: 0.6)),
);

class _EntityGraphFullscreenPage extends StatefulWidget {
  const _EntityGraphFullscreenPage({
    required this.graph,
    required this.initialSelection,
    required this.onEntitySelected,
  });

  final MemoryGraph graph;
  final MemoryEntity? initialSelection;
  final ValueChanged<MemoryEntity?> onEntitySelected;

  @override
  State<_EntityGraphFullscreenPage> createState() =>
      _EntityGraphFullscreenPageState();
}

class _EntityGraphFullscreenPageState
    extends State<_EntityGraphFullscreenPage> {
  final _EntityGraphModelCache _models = _EntityGraphModelCache();
  MemoryEntity? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection;
  }

  void _select(MemoryEntity? entity) {
    setState(() => _selected = entity);
    widget.onEntitySelected(entity);
  }

  void _selectById(String? id) {
    MemoryEntity? entity;
    for (final node in widget.graph.nodes) {
      if (node.id == id) entity = node;
    }
    _select(entity == null || entity.id == _selected?.id ? null : entity);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Scaffold(
      backgroundColor: _bgPrimary,
      appBar: AppBar(title: Text(appStrings.knowledgeGraph)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            children: <Widget>[
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => _EntityGraphCanvas(
                    model: _models.resolve(widget.graph, constraints.biggest),
                    selectedId: selected?.id,
                    query: '',
                    onSelect: _selectById,
                  ),
                ),
              ),
              if (selected != null) ...<Widget>[
                const SizedBox(height: 12),
                _EntityInspector(
                  entity: selected,
                  neighbors: _models.neighborsOf(selected.id),
                  onSelect: _selectById,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EntityGraphCanvas extends StatefulWidget {
  const _EntityGraphCanvas({
    required this.model,
    required this.selectedId,
    required this.query,
    required this.onSelect,
  });

  final _EntityGraphModel model;
  final String? selectedId;
  final String query;
  final ValueChanged<String?> onSelect;

  @override
  State<_EntityGraphCanvas> createState() => _EntityGraphCanvasState();
}

class _EntityGraphCanvasState extends State<_EntityGraphCanvas> {
  static const double _minZoom = 0.5;
  static const double _maxZoom = 6;

  final Map<String, TextPainter> _labelCache = <String, TextPainter>{};
  double _zoom = 1;
  Offset _pan = Offset.zero;
  double _gestureStartZoom = 1;
  String? _hoveredId;
  Size _size = Size.zero;

  @override
  void didUpdateWidget(_EntityGraphCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.model, widget.model)) _labelCache.clear();
  }

  @override
  void dispose() {
    for (final painter in _labelCache.values) {
      painter.dispose();
    }
    super.dispose();
  }

  _GraphViewport get _viewport =>
      _GraphViewport(widget.model, _size, zoom: _zoom, pan: _pan);

  void _zoomAround(Offset focal, double nextZoom) {
    final zoom = nextZoom.clamp(_minZoom, _maxZoom);
    final center = _size.center(Offset.zero);
    // Keep the layout point under the focal point fixed while scaling.
    setState(() {
      _pan = focal - center - (focal - center - _pan) * (zoom / _zoom);
      _zoom = zoom;
    });
  }

  void _resetView() => setState(() {
    _zoom = 1;
    _pan = Offset.zero;
  });

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final keyboard = HardwareKeyboard.instance;
    // Plain wheel scrolls the page; ctrl/⌘ + wheel zooms the graph.
    if (!keyboard.isControlPressed && !keyboard.isMetaPressed) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final delta = (event as PointerScrollEvent).scrollDelta.dy;
      _zoomAround(event.localPosition, _zoom * math.exp(-delta / 300));
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        final viewport = _viewport;
        return DecoratedBox(
          decoration: _graphSurfaceDecoration(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: Listener(
                    onPointerSignal: _onPointerSignal,
                    child: MouseRegion(
                      cursor: _hoveredId == null
                          ? SystemMouseCursors.grab
                          : SystemMouseCursors.click,
                      onHover: (event) {
                        final hit = viewport.hitTest(event.localPosition);
                        if (hit != _hoveredId) {
                          setState(() => _hoveredId = hit);
                        }
                      },
                      onExit: (_) => setState(() => _hoveredId = null),
                      child: GestureDetector(
                        onTapUp: (details) => widget.onSelect(
                          viewport.hitTest(details.localPosition),
                        ),
                        onScaleStart: (_) => _gestureStartZoom = _zoom,
                        onScaleUpdate: (details) {
                          setState(() => _pan += details.focalPointDelta);
                          if (details.scale != 1) {
                            _zoomAround(
                              details.localFocalPoint,
                              _gestureStartZoom * details.scale,
                            );
                          }
                        },
                        child: CustomPaint(
                          size: _size,
                          painter: _EntityGraphPainter(
                            viewport: viewport,
                            selectedId: widget.selectedId,
                            hoveredId: _hoveredId,
                            query: widget.query.trim().toLowerCase(),
                            labelCache: _labelCache,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: _GraphZoomControls(
                    onZoomIn: () =>
                        _zoomAround(_size.center(Offset.zero), _zoom * 1.4),
                    onZoomOut: () =>
                        _zoomAround(_size.center(Offset.zero), _zoom / 1.4),
                    onReset: _resetView,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GraphZoomControls extends StatelessWidget {
  const _GraphZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    Widget button(IconData icon, String tooltip, VoidCallback onPressed) =>
        IconButton(
          visualDensity: VisualDensity.compact,
          iconSize: 18,
          tooltip: tooltip,
          icon: Icon(icon, color: _textSecondary),
          onPressed: onPressed,
        );
    return _PanelSurface(
      padding: const EdgeInsets.all(2),
      borderRadius: BorderRadius.circular(12),
      fillColor: _bgCard.withValues(alpha: 0.9),
      borderColor: _borderLight,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          button(Icons.add, appStrings.zoomIn, onZoomIn),
          button(Icons.remove, appStrings.zoomOut, onZoomOut),
          button(
            Icons.center_focus_strong_outlined,
            appStrings.resetView,
            onReset,
          ),
        ],
      ),
    );
  }
}

/// Maps layout coordinates to the screen for the current size, zoom and pan.
class _GraphViewport {
  _GraphViewport(this.model, this.size, {required this.zoom, required this.pan})
    : _fit = _fitScale(model.bounds, size);

  static const double _padding = 56;

  final _EntityGraphModel model;
  final Size size;
  final double zoom;
  final Offset pan;
  final double _fit;

  static double _fitScale(Rect bounds, Size size) {
    final width = math.max(1.0, bounds.width);
    final height = math.max(1.0, bounds.height);
    return math
        .min(
          (size.width - 2 * _padding) / width,
          (size.height - 2 * _padding) / height,
        )
        .clamp(0.15, 3.0);
  }

  Offset toScreen(Offset point) =>
      (point - model.bounds.center) * (_fit * zoom) +
      size.center(Offset.zero) +
      pan;

  /// Hubs are larger; nodes grow gently with zoom so detail stays readable.
  double radiusOf(_GraphNodeModel node) =>
      (3.5 + 11 * math.sqrt(node.weight)) * math.pow(zoom, 0.35);

  String? hitTest(Offset point) {
    String? best;
    var bestDistance = double.infinity;
    for (final node in model.nodes) {
      final distance = (toScreen(node.position) - point).distance;
      if (distance <= radiusOf(node) + 6 && distance < bestDistance) {
        best = node.entity.id;
        bestDistance = distance;
      }
    }
    return best;
  }
}

class _EntityGraphPainter extends CustomPainter {
  _EntityGraphPainter({
    required this.viewport,
    required this.selectedId,
    required this.hoveredId,
    required this.query,
    required this.labelCache,
  });

  final _GraphViewport viewport;
  final String? selectedId;
  final String? hoveredId;
  final String query;
  final Map<String, TextPainter> labelCache;

  _EntityGraphModel get model => viewport.model;

  Color _colorOf(_GraphNodeModel node) => node.cluster?.color ?? _textMuted;

  @override
  void paint(Canvas canvas, Size size) {
    // The graph is refetched on resize and memory changes, so a selected or
    // hovered entity may no longer be in it.
    String? present(String? id) =>
        id != null && model.byId.containsKey(id) ? id : null;
    final focusId = present(hoveredId) ?? present(selectedId);
    final focus = <String>{
      if (focusId != null) focusId,
      if (selectedId != null) selectedId!,
    };
    if (focusId != null) {
      for (final neighbor in model.neighborsOf(focusId)) {
        focus.add(neighbor.entity.id);
      }
    }
    final matches = <String>{
      if (query.isNotEmpty)
        for (final node in model.nodes)
          if (node.entity.name.toLowerCase().contains(query)) node.entity.id,
    };
    final dimming = focusId != null || query.isNotEmpty;
    bool lit(String id) => focus.contains(id) || matches.contains(id);

    final screen = <String, Offset>{
      for (final node in model.nodes)
        node.entity.id: viewport.toScreen(node.position),
    };

    _paintEdges(canvas, screen, focusId, dimming);
    _paintNodes(canvas, screen, dimming, lit, matches);
    _paintLabels(canvas, size, screen, focusId, dimming, lit);
  }

  void _paintEdges(
    Canvas canvas,
    Map<String, Offset> screen,
    String? focusId,
    bool dimming,
  ) {
    final zoomWidth = math.pow(viewport.zoom, 0.3).toDouble();
    for (final edge in model.edges) {
      final a = screen[edge.source]!;
      final b = screen[edge.target]!;
      final source = model.byId[edge.source]!;
      final target = model.byId[edge.target]!;
      final strength = edge.weight / model.maxEdgeWeight;
      final incident = edge.source == focusId || edge.target == focusId;
      final sameCluster =
          source.cluster != null && source.cluster == target.cluster;
      final base = incident
          ? _accent
          : (sameCluster ? _colorOf(source) : _textMuted);
      final alpha = incident ? 0.9 : (dimming ? 0.04 : 0.08 + 0.32 * strength);
      // Gentle curve so parallel links stay distinguishable.
      final mid = Offset.lerp(a, b, 0.5)!;
      final normal = Offset(-(b.dy - a.dy), b.dx - a.dx) * 0.12;
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(mid.dx + normal.dx, mid.dy + normal.dy, b.dx, b.dy);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..color = base.withValues(alpha: alpha)
          ..strokeWidth =
              (0.6 + 2.4 * strength + (incident ? 0.8 : 0)) * zoomWidth,
      );
    }
  }

  void _paintNodes(
    Canvas canvas,
    Map<String, Offset> screen,
    bool dimming,
    bool Function(String id) lit,
    Set<String> matches,
  ) {
    // Busiest last, so hubs sit on top of the links and small nodes.
    for (final node in model.nodes.reversed) {
      final id = node.entity.id;
      final center = screen[id]!;
      final radius = viewport.radiusOf(node);
      final color = _colorOf(node);
      final faded = dimming && !lit(id);
      final alpha = faded ? 0.16 : 1.0;
      if (!faded && node.weight > 0.35) {
        canvas.drawCircle(
          center,
          radius * 1.9,
          Paint()
            ..color = color.withValues(alpha: 0.12)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.8),
        );
      }
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.35, -0.4),
            colors: <Color>[
              Color.lerp(color, Colors.white, 0.35)!.withValues(alpha: alpha),
              color.withValues(alpha: alpha),
            ],
          ).createShader(rect),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _bgPrimary.withValues(alpha: 0.8 * alpha),
      );
      final ringed =
          id == selectedId || id == hoveredId || matches.contains(id);
      if (ringed) {
        canvas.drawCircle(
          center,
          radius + 4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = id == selectedId ? 2.2 : 1.4
            ..color = _accent,
        );
      }
    }
  }

  /// Labels are placed greedily by priority and skipped where they would
  /// overlap one already drawn, so zooming in reveals more of them.
  void _paintLabels(
    Canvas canvas,
    Size size,
    Map<String, Offset> screen,
    String? focusId,
    bool dimming,
    bool Function(String id) lit,
  ) {
    final ordered = <_GraphNodeModel>[
      if (focusId != null) model.byId[focusId]!,
      for (final node in model.nodes)
        if (node.entity.id != focusId && (!dimming || lit(node.entity.id)))
          node,
    ];
    final placed = <Rect>[];
    final bounds = Offset.zero & size;
    for (final node in ordered) {
      final id = node.entity.id;
      final emphasized = id == focusId;
      final painter = _labelFor(node, emphasized: emphasized);
      final center = screen[id]!;
      final radius = viewport.radiusOf(node);
      final topLeft = Offset(
        center.dx - painter.width / 2,
        center.dy + radius + 5,
      );
      final box = Rect.fromLTWH(
        topLeft.dx - 6,
        topLeft.dy - 2,
        painter.width + 12,
        painter.height + 4,
      );
      if (!bounds.overlaps(box)) continue;
      if (!emphasized && placed.any((other) => other.overlaps(box))) continue;
      placed.add(box);
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(7)),
        Paint()..color = _bgCard.withValues(alpha: emphasized ? 0.95 : 0.78),
      );
      painter.paint(canvas, topLeft);
    }
  }

  TextPainter _labelFor(_GraphNodeModel node, {required bool emphasized}) {
    final key = '${node.entity.id}|$emphasized';
    return labelCache.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
          text: node.entity.name,
          style: TextStyle(
            color: emphasized ? _textPrimary : _textSecondary,
            fontSize: 11 + 3 * node.weight,
            fontWeight: emphasized || node.weight > 0.5
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 200);
    });
  }

  @override
  bool shouldRepaint(_EntityGraphPainter old) =>
      old.viewport.model != viewport.model ||
      old.viewport.zoom != viewport.zoom ||
      old.viewport.pan != viewport.pan ||
      old.viewport.size != viewport.size ||
      old.selectedId != selectedId ||
      old.hoveredId != hoveredId ||
      old.query != query;
}

class _ClusterLegend extends StatelessWidget {
  const _ClusterLegend({required this.clusters, required this.onSelect});

  final List<_GraphCluster> clusters;
  final ValueChanged<MemoryEntity> onSelect;

  @override
  Widget build(BuildContext context) {
    if (clusters.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: clusters
          .take(8)
          .map(
            (cluster) => ActionChip(
              avatar: CircleAvatar(backgroundColor: cluster.color, radius: 5),
              label: Text('${cluster.hub.name} · ${cluster.size}'),
              onPressed: () => onSelect(cluster.hub),
            ),
          )
          .toList(),
    );
  }
}

class _EntityInspector extends StatelessWidget {
  const _EntityInspector({
    required this.entity,
    required this.neighbors,
    required this.onSelect,
  });

  final MemoryEntity entity;
  final List<({MemoryEntity entity, int weight})> neighbors;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final lastSeen = entity.lastSeenAt;
    return _PanelSurface(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(14),
      fillColor: _bgCard.withValues(alpha: 0.86),
      borderColor: _borderLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                entity.name,
                style: TextStyle(
                  color: _textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _MetaPill(
                label: _entityKindLabel(entity.kind),
                icon: Icons.category_outlined,
              ),
              _MetaPill(
                label: appStrings.mentionsArg1(entity.mentionCount),
                icon: Icons.notes_outlined,
              ),
              if (lastSeen != null)
                _MetaPill(
                  label: appStrings.lastSeenArg1(_relativeTime(lastSeen)),
                  icon: Icons.schedule_outlined,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            appStrings.linkedEntities,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          if (neighbors.isEmpty)
            Text(
              appStrings.noLinkedEntities,
              style: TextStyle(color: _textMuted, fontSize: 12),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: neighbors
                  .map(
                    (neighbor) => ActionChip(
                      label: Text(
                        '${neighbor.entity.name} · ${neighbor.weight}',
                      ),
                      onPressed: () => onSelect(neighbor.entity.id),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}
