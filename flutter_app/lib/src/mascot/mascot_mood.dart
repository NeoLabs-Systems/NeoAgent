/// What the NeoAgent mascot is showing.
enum MascotMood {
  idle,
  listening,
  thinking,
  working,
  waiting,
  blocked,
  done,
  asleep;

  String get semanticLabel => switch (this) {
    MascotMood.idle => 'idle',
    MascotMood.listening => 'listening',
    MascotMood.thinking => 'thinking',
    MascotMood.working => 'working',
    MascotMood.waiting => 'waiting for you',
    MascotMood.blocked => 'blocked',
    MascotMood.done => 'done',
    MascotMood.asleep => 'offline',
  };
}

/// Turns the mood read straight off live state into the mood on screen.
///
/// Live state is noisy in two ways. A run flips between reasoning and short
/// tool calls several times a second, which would strobe the face; so
/// thinking/working hold for [activityDwell] before giving way to each other
/// or to idle. And a finished or failed run stays marked that way long after
/// the moment has passed; so [MascotMood.done] and [MascotMood.blocked] play
/// once per `moment` (the run they belong to) and then settle to idle. A
/// moment that is already there on the first update happened before the
/// mascot existed and does not play.
class MascotMoodStabilizer {
  MascotMoodStabilizer({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const Duration activityDwell = Duration(milliseconds: 450);
  static const Duration doneHold = Duration(milliseconds: 2400);
  static const Duration blockedHold = Duration(seconds: 6);

  final DateTime Function() _clock;
  MascotMood _shown = MascotMood.idle;
  DateTime? _shownSince;
  bool _seen = false;
  Object? _playedMoment;
  DateTime? _oneShotUntil;

  MascotMood get mood => _shown;

  /// Feeds the latest raw mood, with [moment] identifying the occurrence for
  /// done and blocked. Returns how long until [update] should be called again
  /// to settle a pending change, or null when nothing is pending.
  Duration? update(MascotMood raw, {Object? moment}) {
    final now = _clock();
    final first = !_seen;
    _seen = true;

    if (raw == MascotMood.done || raw == MascotMood.blocked) {
      if (first) {
        _playedMoment = moment;
      } else if (moment != _playedMoment) {
        _playedMoment = moment;
        _oneShotUntil = now.add(
          raw == MascotMood.done ? doneHold : blockedHold,
        );
        _show(raw, now);
      }
      final until = _oneShotUntil;
      if (_shown == raw && until != null && now.isBefore(until)) {
        return until.difference(now);
      }
      _oneShotUntil = null;
      _show(MascotMood.idle, now);
      return null;
    }

    _oneShotUntil = null;
    final shownSince = _shownSince;
    if (raw != _shown &&
        shownSince != null &&
        _isActivity(_shown) &&
        (_isActivity(raw) || raw == MascotMood.idle)) {
      final remaining = activityDwell - now.difference(shownSince);
      if (remaining > Duration.zero) {
        return remaining;
      }
    }
    _show(raw, now);
    return null;
  }

  void _show(MascotMood mood, DateTime now) {
    if (mood == _shown && _shownSince != null) return;
    _shown = mood;
    _shownSince = now;
  }

  static bool _isActivity(MascotMood mood) =>
      mood == MascotMood.thinking || mood == MascotMood.working;
}
