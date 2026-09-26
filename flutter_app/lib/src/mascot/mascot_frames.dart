import 'dart:typed_data';

import 'mascot_mood.dart';

/// One picture on the mascot's 9×9 dot matrix, plus how the tile around it
/// moves while the picture is up.
class MascotFrame {
  MascotFrame(
    List<String> rows, {
    this.hold = const Duration(milliseconds: 400),
    this.alert = false,
    this.shift = 0,
    this.scale = 1,
    this.rim = 0,
  }) : dots = _parse(rows);

  MascotFrame.fromDots(
    this.dots, {
    this.hold = const Duration(milliseconds: 400),
    this.alert = false,
    this.shift = 0,
    this.scale = 1,
    this.rim = 0,
  });

  static const int gridSize = 9;

  /// Brightness of each dot, row-major, 0–1.
  final Float32List dots;

  /// How long the frame stays up before the clip moves on.
  final Duration hold;

  /// Dots and rim use the alert color instead of gold.
  final bool alert;

  /// Horizontal nudge of the whole tile, in dot pitches.
  final double shift;

  /// Tile scale around its centre.
  final double scale;

  /// Glow on the tile's edge, 0–1.
  final double rim;

  /// Rows use `#` for a lit dot, `-` for half, `+` for a quarter and `.` off.
  static Float32List _parse(List<String> rows) {
    assert(rows.length == gridSize);
    final dots = Float32List(gridSize * gridSize);
    for (var y = 0; y < gridSize; y++) {
      final row = rows[y];
      assert(row.length == gridSize);
      for (var x = 0; x < gridSize; x++) {
        dots[y * gridSize + x] = switch (row[x]) {
          '#' => 1.0,
          '-' => 0.5,
          '+' => 0.25,
          _ => 0.0,
        };
      }
    }
    return dots;
  }
}

/// The frames one mood plays through.
class MascotClip {
  const MascotClip(
    this.frames, {
    this.loop = true,
    this.fade = const Duration(milliseconds: 120),
  });

  final List<MascotFrame> frames;

  /// Plays from the start again after the last frame; otherwise the last
  /// frame stays up.
  final bool loop;

  /// Cross-fade between consecutive frames.
  final Duration fade;
}

abstract final class MascotClips {
  static final MascotFrame idleFace = MascotFrame(const <String>[
    '.........',
    '.........',
    '..##.##..',
    '..##.##..',
    '..##.##..',
    '.........',
    '.........',
    '.........',
    '.........',
  ]);

  /// Played now and then while idle, then back to [idleFace].
  static final MascotClip blink = MascotClip(<MascotFrame>[
    MascotFrame(const <String>[
      '.........',
      '.........',
      '.........',
      '..##.##..',
      '..##.##..',
      '.........',
      '.........',
      '.........',
      '.........',
    ], hold: const Duration(milliseconds: 50)),
    MascotFrame(const <String>[
      '.........',
      '.........',
      '.........',
      '.........',
      '..##.##..',
      '.........',
      '.........',
      '.........',
      '.........',
    ], hold: const Duration(milliseconds: 80)),
    MascotFrame(const <String>[
      '.........',
      '.........',
      '.........',
      '..##.##..',
      '..##.##..',
      '.........',
      '.........',
      '.........',
      '.........',
    ], hold: const Duration(milliseconds: 50)),
  ], loop: false, fade: const Duration(milliseconds: 50));

  static final MascotClip glanceLeft = MascotClip(<MascotFrame>[
    MascotFrame(const <String>[
      '.........',
      '.........',
      '.##.##...',
      '.##.##...',
      '.##.##...',
      '.........',
      '.........',
      '.........',
      '.........',
    ], hold: const Duration(milliseconds: 900)),
  ], loop: false);

  static final MascotClip glanceRight = MascotClip(<MascotFrame>[
    MascotFrame(const <String>[
      '.........',
      '.........',
      '...##.##.',
      '...##.##.',
      '...##.##.',
      '.........',
      '.........',
      '.........',
      '.........',
    ], hold: const Duration(milliseconds: 900)),
  ], loop: false);

  static final MascotClip idle = MascotClip(<MascotFrame>[idleFace]);

  static final MascotClip listening = MascotClip(<MascotFrame>[
    for (final mouth in const <List<String>>[
      <String>['...#.#...', '..#####..'],
      <String>['..#.#.#..', '..#####..'],
      <String>['...###...', '..#####..'],
      <String>['....#....', '..#####..'],
      <String>['..##.##..', '..#####..'],
      <String>['....#....', '...###...'],
    ])
      MascotFrame(<String>[
        '.........',
        '.........',
        '..##.##..',
        '..##.##..',
        '..##.##..',
        '.........',
        mouth[0],
        mouth[1],
        '.........',
      ], hold: const Duration(milliseconds: 120)),
  ], fade: const Duration(milliseconds: 90));

  static final MascotClip thinking = MascotClip(<MascotFrame>[
    for (final dots in const <String>[
      '...#++...',
      '...+#+...',
      '...++#...',
      '...+++...',
    ])
      MascotFrame(<String>[
        '.........',
        '...##.##.',
        '...##.##.',
        '...##.##.',
        '.........',
        '.........',
        dots,
        '.........',
        '.........',
      ], hold: const Duration(milliseconds: 280)),
  ]);

  /// Underscore eyes with a comet running round the edge of the screen.
  static final MascotClip working = MascotClip(
    _cometFrames(),
    fade: const Duration(milliseconds: 60),
  );

  static final MascotClip waiting = MascotClip(<MascotFrame>[
    MascotFrame(const <String>[
      '.........',
      '..##.##..',
      '..##.##..',
      '..##.##..',
      '..##.##..',
      '.........',
      '.........',
      '...###...',
      '.........',
    ], hold: const Duration(milliseconds: 530), rim: 1),
    MascotFrame(const <String>[
      '.........',
      '..##.##..',
      '..##.##..',
      '..##.##..',
      '..##.##..',
      '.........',
      '.........',
      '.........',
      '.........',
    ], hold: const Duration(milliseconds: 530), rim: 0.35),
  ], fade: const Duration(milliseconds: 160));

  static const List<String> _blockedRows = <String>[
    '.........',
    '.........',
    '.#.#.#.#.',
    '..#...#..',
    '.#.#.#.#.',
    '.........',
    '....#....',
    '...#.#...',
    '.........',
  ];

  static final MascotClip blocked = MascotClip(<MascotFrame>[
    for (final shift in const <double>[-0.6, 0.6, -0.4])
      MascotFrame(
        _blockedRows,
        hold: const Duration(milliseconds: 60),
        alert: true,
        shift: shift,
        rim: 0.6,
      ),
    MascotFrame(
      _blockedRows,
      hold: const Duration(milliseconds: 2200),
      alert: true,
      rim: 0.6,
    ),
  ], fade: const Duration(milliseconds: 60));

  static const List<String> _doneRows = <String>[
    '.........',
    '.........',
    '..#...#..',
    '.#.#.#.#.',
    '.........',
    '.........',
    '..#...#..',
    '...###...',
    '.........',
  ];

  static final MascotClip done = MascotClip(<MascotFrame>[
    MascotFrame(
      _doneRows,
      hold: const Duration(milliseconds: 110),
      scale: 1.12,
    ),
    MascotFrame(
      _doneRows,
      hold: const Duration(milliseconds: 110),
      scale: 0.96,
    ),
    MascotFrame(_doneRows),
  ], loop: false, fade: const Duration(milliseconds: 110));

  static final MascotClip asleep = MascotClip(<MascotFrame>[
    MascotFrame(const <String>[
      '......---',
      '.......-.',
      '......---',
      '.........',
      '..--.--..',
      '.........',
      '.........',
      '.........',
      '.........',
    ], hold: const Duration(milliseconds: 1600)),
    MascotFrame(const <String>[
      '.........',
      '.........',
      '.........',
      '.........',
      '..--.--..',
      '.........',
      '.........',
      '.........',
      '.........',
    ], hold: const Duration(milliseconds: 1600)),
  ], fade: const Duration(milliseconds: 600));

  static MascotClip forMood(MascotMood mood) => switch (mood) {
    MascotMood.idle => idle,
    MascotMood.listening => listening,
    MascotMood.thinking => thinking,
    MascotMood.working => working,
    MascotMood.waiting => waiting,
    MascotMood.blocked => blocked,
    MascotMood.done => done,
    MascotMood.asleep => asleep,
  };

  /// The single frame that stands for a mood when nothing may move.
  static MascotFrame keyFrame(MascotMood mood) {
    final frames = forMood(mood).frames;
    return switch (mood) {
      MascotMood.listening => frames[2],
      MascotMood.working => frames[4],
      MascotMood.blocked || MascotMood.done => frames.last,
      _ => frames.first,
    };
  }

  static List<MascotFrame> _cometFrames() {
    const n = MascotFrame.gridSize;
    final ring = <int>[
      for (var x = 0; x < n; x++) x,
      for (var y = 1; y < n; y++) y * n + n - 1,
      for (var x = n - 2; x >= 0; x--) (n - 1) * n + x,
      for (var y = n - 2; y >= 1; y--) y * n,
    ];
    final eyes = MascotFrame(const <String>[
      '.........',
      '.........',
      '.........',
      '.........',
      '.###.###.',
      '.........',
      '.........',
      '.........',
      '.........',
    ]).dots;
    return <MascotFrame>[
      for (var head = 0; head < ring.length; head++)
        MascotFrame.fromDots(
          Float32List.fromList(eyes)
            ..[ring[head]] = 1
            ..[ring[(head - 1) % ring.length]] = 0.5
            ..[ring[(head - 2) % ring.length]] = 0.2,
          hold: const Duration(milliseconds: 45),
        ),
    ];
  }
}
