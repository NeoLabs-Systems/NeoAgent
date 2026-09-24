import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'mascot_frames.dart';
import 'mascot_mood.dart';

/// The NeoAgent mascot: a dark tile whose screen is a 9×9 dot-matrix face.
///
/// Motion is stepped, like the LED matrix it imitates. Each mood is a short
/// clip of frames advanced by timers; only the cross-fade from one frame to
/// the next runs on the ticker, so a mascot at rest schedules no frames. A
/// mood change fades from whatever is on screen, even mid-fade, so the face
/// never jumps.
class NeoMascot extends StatefulWidget {
  const NeoMascot({
    super.key,
    required this.mood,
    this.size = 40,
    this.animate = true,
  });

  final MascotMood mood;
  final double size;

  /// False shows the mood's key frame and never moves, for avatars in lists.
  final bool animate;

  @override
  State<NeoMascot> createState() => _NeoMascotState();
}

class _NeoMascotState extends State<NeoMascot>
    with SingleTickerProviderStateMixin {
  static const Duration _moodFade = Duration(milliseconds: 180);

  late final AnimationController _fade = AnimationController(
    vsync: this,
    value: 1,
  );
  late final CurvedAnimation _mix = CurvedAnimation(
    parent: _fade,
    curve: Curves.easeOutCubic,
  );
  final _MascotPicture _picture = _MascotPicture();
  late final _MascotPainter _painter = _MascotPainter(
    picture: _picture,
    mix: _mix,
  );
  final math.Random _random = math.Random();
  Timer? _stepTimer;
  Timer? _idleTimer;
  MascotClip _clip = MascotClips.idle;
  int _index = 0;
  VoidCallback? _afterClip;
  bool? _still;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = _isStill();
    if (still != _still) {
      final firstShow = _still == null;
      _still = still;
      _enter(widget.mood, firstShow ? Duration.zero : _moodFade);
    }
  }

  @override
  void didUpdateWidget(NeoMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    final still = _isStill();
    if (still != _still || oldWidget.mood != widget.mood) {
      _still = still;
      _enter(widget.mood, _moodFade);
    }
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _idleTimer?.cancel();
    _mix.dispose();
    _fade.dispose();
    _picture.dispose();
    super.dispose();
  }

  bool _isStill() => !widget.animate || MediaQuery.disableAnimationsOf(context);

  void _enter(MascotMood mood, Duration fade) {
    _stepTimer?.cancel();
    _idleTimer?.cancel();
    if (_still ?? true) {
      _show(MascotClips.keyFrame(mood), fade);
      return;
    }
    _play(MascotClips.forMood(mood), fade);
    if (mood == MascotMood.idle) {
      _scheduleIdleMove();
    }
  }

  void _play(MascotClip clip, Duration fade, {VoidCallback? then}) {
    _stepTimer?.cancel();
    _clip = clip;
    _index = 0;
    _afterClip = then;
    _show(clip.frames.first, fade);
    _scheduleStep();
  }

  void _scheduleStep() {
    final frames = _clip.frames;
    final hold = frames[_index].hold;
    if (_index == frames.length - 1 && !_clip.loop) {
      final then = _afterClip;
      if (then != null) {
        _stepTimer = Timer(hold, then);
      }
      return;
    }
    if (frames.length == 1) return;
    _stepTimer = Timer(hold, () {
      _index = (_index + 1) % frames.length;
      _show(frames[_index], _clip.fade);
      _scheduleStep();
    });
  }

  /// Every few seconds at rest: mostly a blink, sometimes a look aside.
  void _scheduleIdleMove() {
    final wait = Duration(milliseconds: 2600 + _random.nextInt(3800));
    _idleTimer = Timer(wait, () {
      final roll = _random.nextDouble();
      var move = MascotClips.blink;
      if (roll > 0.85) {
        move = MascotClips.glanceRight;
      } else if (roll > 0.7) {
        move = MascotClips.glanceLeft;
      }
      _play(
        move,
        move.fade,
        then: () {
          _play(MascotClips.idle, const Duration(milliseconds: 90));
          _scheduleIdleMove();
        },
      );
    });
  }

  void _show(MascotFrame frame, Duration fade) {
    _picture.retarget(frame, _mix.value);
    if (fade == Duration.zero) {
      _fade.value = 1;
      return;
    }
    _fade.duration = fade;
    _fade.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'NeoAgent, ${widget.mood.semanticLabel}',
      child: RepaintBoundary(
        child: CustomPaint(size: Size.square(widget.size), painter: _painter),
      ),
    );
  }
}

/// What the painter blends between: the picture on screen when the current
/// fade began, and the frame it is heading to.
class _MascotPicture extends ChangeNotifier {
  static const int _dotCount = MascotFrame.gridSize * MascotFrame.gridSize;

  final Float32List from = Float32List(_dotCount);
  final Float32List to = Float32List(_dotCount);
  double fromAlert = 0;
  double toAlert = 0;
  double fromShift = 0;
  double toShift = 0;
  double fromScale = 1;
  double toScale = 1;
  double fromRim = 0;
  double toRim = 0;

  /// Freezes what is on screen at mix [t] as the new start, aims at [frame].
  void retarget(MascotFrame frame, double t) {
    for (var i = 0; i < _dotCount; i++) {
      from[i] += (to[i] - from[i]) * t;
    }
    fromAlert += (toAlert - fromAlert) * t;
    fromShift += (toShift - fromShift) * t;
    fromScale += (toScale - fromScale) * t;
    fromRim += (toRim - fromRim) * t;
    to.setAll(0, frame.dots);
    toAlert = frame.alert ? 1 : 0;
    toShift = frame.shift;
    toScale = frame.scale;
    toRim = frame.rim;
    notifyListeners();
  }
}

class _MascotPainter extends CustomPainter {
  _MascotPainter({required this.picture, required this.mix})
    : super(repaint: Listenable.merge(<Listenable>[picture, mix]));

  final _MascotPicture picture;
  final Animation<double> mix;

  static const Color _gold = Color(0xFFE1B052);
  static const Color _alert = Color(0xFFDE8A78);
  static const Color _lip = Color(0xFF040605);
  static const Color _screen = Color(0xFF030504);
  static const Color _unlit = Color(0xFF17201A);
  static const Color _edge = Color(0x24ECEFE5);
  static const LinearGradient _tile = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Color(0xFF243029), Color(0xFF0C120E)],
  );

  /// Below this the dots merge into solid pixels and the unlit grid goes, so
  /// the face still reads at sidebar and list sizes.
  static const double _smallSide = 28;

  @override
  void paint(Canvas canvas, Size size) {
    final t = mix.value;
    final p = picture;
    final side = math.min(size.width, size.height);
    final small = side < _smallSide;
    final lip = small ? 0.0 : side * 0.05;
    final tileSide = side - lip;
    final tile = Rect.fromLTWH(
      (size.width - tileSide) / 2,
      (size.height - side) / 2,
      tileSide,
      tileSide,
    );
    final screen = tile.deflate(tileSide * 0.06);
    final pitch = screen.width * 10 / 102;
    final firstDot = screen.width * 11 / 102;
    final lit = Color.lerp(_gold, _alert, lerpDouble(p.fromAlert, p.toAlert, t)!)!;
    final rim = lerpDouble(p.fromRim, p.toRim, t)!;
    final scale = lerpDouble(p.fromScale, p.toScale, t)!;
    final shift = lerpDouble(p.fromShift, p.toShift, t)! * pitch;

    canvas.save();
    final centre = tile.center;
    canvas.translate(centre.dx + shift, centre.dy);
    canvas.scale(scale);
    canvas.translate(-centre.dx, -centre.dy);

    final tileShape = RRect.fromRectAndRadius(
      tile,
      Radius.circular(tileSide * 0.33),
    );
    if (!small) {
      canvas.drawRRect(tileShape.shift(Offset(0, lip)), Paint()..color = _lip);
    }
    canvas.drawRRect(tileShape, Paint()..shader = _tile.createShader(tile));
    final edgeWidth = math.max(0.6, tileSide * 0.012);
    canvas.drawRRect(
      tileShape.deflate(edgeWidth / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = edgeWidth
        ..color = _edge,
    );
    if (rim > 0.01) {
      final rimWidth = math.max(1.0, tileSide * 0.022);
      if (!small) {
        canvas.drawRRect(
          tileShape,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = rimWidth * 2
            ..color = lit.withValues(alpha: 0.35 * rim)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, tileSide * 0.04),
        );
      }
      canvas.drawRRect(
        tileShape.deflate(rimWidth / 2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = rimWidth
          ..color = lit.withValues(alpha: 0.75 * rim),
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(screen, Radius.circular(tileSide * 0.267)),
      Paint()..color = _screen,
    );

    final dotPaint = Paint();
    final glowPaint = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, pitch * 0.32);
    const n = MascotFrame.gridSize;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        final i = y * n + x;
        final level = (p.from[i] + (p.to[i] - p.from[i]) * t).clamp(0.0, 1.0);
        final centreOfDot = Offset(
          screen.left + firstDot + x * pitch,
          screen.top + firstDot + y * pitch,
        );
        if (small) {
          if (level > 0.02) {
            dotPaint.color = lit.withValues(alpha: level);
            canvas.drawRect(
              Rect.fromCenter(
                center: centreOfDot,
                width: pitch * 1.02,
                height: pitch * 1.02,
              ),
              dotPaint,
            );
          }
          continue;
        }
        dotPaint.color = _unlit;
        canvas.drawCircle(centreOfDot, pitch * 0.21, dotPaint);
        if (level > 0.02) {
          glowPaint.color = lit.withValues(alpha: 0.55 * level);
          canvas.drawCircle(centreOfDot, pitch * 0.46, glowPaint);
          dotPaint.color = lit.withValues(alpha: level);
          canvas.drawCircle(centreOfDot, pitch * 0.36, dotPaint);
        }
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_MascotPainter oldDelegate) =>
      oldDelegate.picture != picture || oldDelegate.mix != mix;
}
