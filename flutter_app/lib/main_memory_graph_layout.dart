part of 'main.dart';

// ---------------------------------------------------------------------------
// Memory knowledge graph model: clustering, force layout and colors. Pure
// geometry with no widgets, so the canvas only has to transform and paint.
// ---------------------------------------------------------------------------

class _GraphCluster {
  const _GraphCluster({
    required this.index,
    required this.hub,
    required this.size,
    required this.color,
  });

  /// Rank by total mentions; 0 is the largest cluster.
  final int index;
  final MemoryEntity hub;
  final int size;
  final Color color;
}

class _GraphNodeModel {
  _GraphNodeModel({
    required this.entity,
    required this.position,
    required this.weight,
    this.cluster,
  });

  final MemoryEntity entity;

  /// Position in layout space; the canvas maps it to the screen.
  final Offset position;

  /// Mention count relative to the busiest node, 0..1.
  final double weight;

  /// Null for nodes without links.
  final _GraphCluster? cluster;
}

class _EntityGraphModel {
  _EntityGraphModel._({
    required this.aspect,
    required this.nodes,
    required this.edges,
    required this.clusters,
    required this.bounds,
    required this.maxEdgeWeight,
  }) : byId = <String, _GraphNodeModel>{
         for (final node in nodes) node.entity.id: node,
       };

  final double aspect;

  /// Ordered by mention count, busiest first.
  final List<_GraphNodeModel> nodes;
  final List<MemoryGraphEdge> edges;
  final List<_GraphCluster> clusters;
  final Rect bounds;
  final int maxEdgeWeight;
  final Map<String, _GraphNodeModel> byId;

  static _EntityGraphModel build(
    MemoryGraph graph, {
    required double aspect,
    required Color accent,
    required Brightness brightness,
  }) {
    final entities = <MemoryEntity>[...graph.nodes]
      ..sort((a, b) => b.mentionCount.compareTo(a.mentionCount));
    final index = <String, int>{
      for (var i = 0; i < entities.length; i++) entities[i].id: i,
    };
    final edges = graph.edges
        .where(
          (e) => index.containsKey(e.source) && index.containsKey(e.target),
        )
        .toList(growable: false);
    final maxEdgeWeight = edges.fold<int>(
      1,
      (max, e) => math.max(max, e.weight),
    );
    final maxMentions = entities.fold<int>(
      1,
      (max, e) => math.max(max, e.mentionCount),
    );

    final labels = _propagateLabels(entities.length, edges, index);
    final clusters = _rankClusters(
      entities,
      labels,
      edges,
      index,
      accent,
      brightness,
    );
    final positions = _forceLayout(entities.length, edges, index, aspect);

    final nodes = <_GraphNodeModel>[
      for (var i = 0; i < entities.length; i++)
        _GraphNodeModel(
          entity: entities[i],
          position: positions[i],
          weight: entities[i].mentionCount / maxMentions,
          cluster: clusters[labels[i]],
        ),
    ];
    return _EntityGraphModel._(
      aspect: aspect,
      nodes: nodes,
      edges: edges,
      clusters: <_GraphCluster>{
        for (final c in clusters.values)
          if (c != null) c,
      }.toList()..sort((a, b) => a.index.compareTo(b.index)),
      bounds: _boundsOf(positions),
      maxEdgeWeight: maxEdgeWeight,
    );
  }

  /// Weighted label propagation: each node repeatedly adopts the label its
  /// neighbors carry the most link weight for. Deterministic visiting order.
  static List<int> _propagateLabels(
    int n,
    List<MemoryGraphEdge> edges,
    Map<String, int> index,
  ) {
    final labels = List<int>.generate(n, (i) => i);
    final neighbors = List<List<(int, int)>>.generate(n, (_) => <(int, int)>[]);
    for (final edge in edges) {
      final a = index[edge.source]!;
      final b = index[edge.target]!;
      neighbors[a].add((b, edge.weight));
      neighbors[b].add((a, edge.weight));
    }
    for (var round = 0; round < 24; round++) {
      var changed = false;
      for (var i = 0; i < n; i++) {
        if (neighbors[i].isEmpty) continue;
        final score = <int, int>{};
        for (final (j, weight) in neighbors[i]) {
          score[labels[j]] = (score[labels[j]] ?? 0) + weight;
        }
        var best = labels[i];
        var bestScore = score[best] ?? 0;
        for (final entry in score.entries) {
          if (entry.value > bestScore ||
              (entry.value == bestScore && entry.key < best)) {
            best = entry.key;
            bestScore = entry.value;
          }
        }
        if (best != labels[i]) {
          labels[i] = best;
          changed = true;
        }
      }
      if (!changed) break;
    }
    return labels;
  }

  /// Clusters of two or more nodes, ranked by total mentions and colored by
  /// rotating the theme accent's hue; singleton labels map to null.
  static Map<int, _GraphCluster?> _rankClusters(
    List<MemoryEntity> entities,
    List<int> labels,
    List<MemoryGraphEdge> edges,
    Map<String, int> index,
    Color accent,
    Brightness brightness,
  ) {
    final members = <int, List<int>>{};
    for (var i = 0; i < labels.length; i++) {
      members.putIfAbsent(labels[i], () => <int>[]).add(i);
    }
    final ranked =
        members.entries.where((entry) => entry.value.length > 1).toList()..sort(
          (a, b) => _mentionsOf(
            entities,
            b.value,
          ).compareTo(_mentionsOf(entities, a.value)),
        );
    final base = HSLColor.fromColor(accent);
    final saturation = base.saturation.clamp(0.4, 0.7);
    final lightness = brightness == Brightness.dark ? 0.64 : 0.46;
    final result = <int, _GraphCluster?>{
      for (final label in members.keys) label: null,
    };
    for (var rank = 0; rank < ranked.length; rank++) {
      final memberIndexes = ranked[rank].value;
      result[ranked[rank].key] = _GraphCluster(
        index: rank,
        // Members are in mention order, so the first is the busiest.
        hub: entities[memberIndexes.first],
        size: memberIndexes.length,
        color: HSLColor.fromAHSL(
          1,
          (base.hue + rank * 137.508) % 360,
          saturation,
          lightness,
        ).toColor(),
      );
    }
    return result;
  }

  static int _mentionsOf(List<MemoryEntity> entities, List<int> members) =>
      members.fold<int>(0, (sum, i) => sum + entities[i].mentionCount);

  /// Fruchterman–Reingold with a pull toward the center so unlinked nodes stay
  /// in view; the pull is stronger along the shorter axis so the result fills
  /// a canvas of the given aspect ratio. Seeded on a golden-angle spiral with
  /// busy nodes in the middle, so the result is deterministic.
  static List<Offset> _forceLayout(
    int n,
    List<MemoryGraphEdge> edges,
    Map<String, int> index,
    double aspect,
  ) {
    final xs = List<double>.filled(n, 0);
    final ys = List<double>.filled(n, 0);
    const golden = 2.399963229728653;
    for (var i = 0; i < n; i++) {
      final r = 30 * math.sqrt(i + 1);
      xs[i] = r * math.cos(i * golden) * math.sqrt(aspect);
      ys[i] = r * math.sin(i * golden) / math.sqrt(aspect);
    }
    if (n < 2) return <Offset>[for (var i = 0; i < n; i++) Offset.zero];

    final maxWeight = edges.fold<int>(1, (max, e) => math.max(max, e.weight));
    const k = 55.0;
    const gravityX = 0.8;
    final gravityY = gravityX * aspect;
    const iterations = 300;
    final dx = List<double>.filled(n, 0);
    final dy = List<double>.filled(n, 0);
    for (var step = 0; step < iterations; step++) {
      final temperature = 40.0 * (1 - step / iterations) + 0.5;
      dx.fillRange(0, n, 0);
      dy.fillRange(0, n, 0);
      for (var i = 0; i < n; i++) {
        for (var j = i + 1; j < n; j++) {
          var ddx = xs[i] - xs[j];
          var ddy = ys[i] - ys[j];
          var dist = math.sqrt(ddx * ddx + ddy * ddy);
          if (dist < 0.01) {
            ddx = 0.01 * (i - j);
            ddy = 0.01;
            dist = 0.015;
          }
          final push = k * k / (dist * dist);
          dx[i] += ddx * push;
          dy[i] += ddy * push;
          dx[j] -= ddx * push;
          dy[j] -= ddy * push;
        }
      }
      for (final edge in edges) {
        final a = index[edge.source]!;
        final b = index[edge.target]!;
        final ddx = xs[a] - xs[b];
        final ddy = ys[a] - ys[b];
        final dist = math.max(0.01, math.sqrt(ddx * ddx + ddy * ddy));
        final pull = dist / k * (0.5 + edge.weight / maxWeight);
        dx[a] -= ddx * pull;
        dy[a] -= ddy * pull;
        dx[b] += ddx * pull;
        dy[b] += ddy * pull;
      }
      for (var i = 0; i < n; i++) {
        dx[i] -= xs[i] * gravityX;
        dy[i] -= ys[i] * gravityY;
        final len = math.sqrt(dx[i] * dx[i] + dy[i] * dy[i]);
        if (len < 0.001) continue;
        final move = math.min(len, temperature);
        xs[i] += dx[i] / len * move;
        ys[i] += dy[i] / len * move;
      }
    }
    return <Offset>[for (var i = 0; i < n; i++) Offset(xs[i], ys[i])];
  }

  static Rect _boundsOf(List<Offset> points) {
    if (points.isEmpty) return Rect.zero;
    var rect = Rect.fromPoints(points.first, points.first);
    for (final p in points) {
      rect = rect.expandToInclude(Rect.fromPoints(p, p));
    }
    return rect;
  }

  List<({MemoryEntity entity, int weight})> neighborsOf(String id) {
    final result = <({MemoryEntity entity, int weight})>[];
    for (final edge in edges) {
      final other = edge.source == id
          ? edge.target
          : (edge.target == id ? edge.source : null);
      if (other == null) continue;
      result.add((entity: byId[other]!.entity, weight: edge.weight));
    }
    result.sort((a, b) => b.weight.compareTo(a.weight));
    return result;
  }
}
