/// Decibel data from audio capture.
///
/// This class represents a single decibel reading with its timestamp.
/// Used by both microphone and system audio capture to provide volume level
/// information.
///
/// Example:
/// ```dart
/// // From stream
/// capture.decibelStream?.listen((data) {
///   print('Decibel: ${data.decibel} dB');
///   print('Time: ${DateTime.fromMillisecondsSinceEpoch((data.timestamp * 1000).toInt())}');
/// });
///
/// // Create manually
/// final data = DecibelData(
///   decibel: -45.5,
///   timestamp: DateTime.now().millisecondsSinceEpoch / 1000.0,
/// );
///
/// // Convert to/from map
/// final map = data.toMap();
/// final restored = DecibelData.fromMap(map);
/// ```
class DecibelData {
  /// Decibel value in dB, typically ranging from -120 to 0 dB.
  ///
  /// - -120 dB: silence or very quiet
  /// - -60 dB: quiet background noise
  /// - -40 dB: normal speech
  /// - -20 dB: loud speech
  /// - 0 dB: maximum level
  final double decibel;

  /// Unix timestamp in seconds (not milliseconds).
  ///
  /// This represents when the decibel reading was taken.
  final double timestamp;

  /// Creates a new [DecibelData] instance.
  ///
  /// [decibel] should be in the range -120 to 0 dB.
  /// [timestamp] should be a Unix timestamp in seconds.
  ///
  /// Example:
  /// ```dart
  /// final data = DecibelData(
  ///   decibel: -45.0,
  ///   timestamp: DateTime.now().millisecondsSinceEpoch / 1000.0,
  /// );
  /// ```
  const DecibelData({
    required this.decibel,
    required this.timestamp,
  });

  /// Creates a [DecibelData] instance from a map.
  ///
  /// The map should contain:
  /// - `decibel`: num (will be converted to double)
  /// - `timestamp`: num (will be converted to double)
  ///
  /// If values are missing, defaults to -120.0 dB and current timestamp.
  ///
  /// Example:
  /// ```dart
  /// final map = {
  ///   'decibel': -45.5,
  ///   'timestamp': 1234567890.0,
  /// };
  /// final data = DecibelData.fromMap(map);
  /// ```
  factory DecibelData.fromMap(Map<String, dynamic> map) {
    return DecibelData(
      decibel: (map['decibel'] as num?)?.toDouble() ?? -120.0,
      timestamp: (map['timestamp'] as num?)?.toDouble() ??
          DateTime.now().millisecondsSinceEpoch / 1000.0,
    );
  }

  /// Converts this [DecibelData] instance to a map.
  ///
  /// Returns a map containing:
  /// - `decibel`: double
  /// - `timestamp`: double
  ///
  /// Example:
  /// ```dart
  /// final data = DecibelData(
  ///   decibel: -45.0,
  ///   timestamp: 1234567890.0,
  /// );
  /// final map = data.toMap();
  /// // map = {'decibel': -45.0, 'timestamp': 1234567890.0}
  /// ```
  Map<String, dynamic> toMap() {
    return {
      'decibel': decibel,
      'timestamp': timestamp,
    };
  }

  @override
  String toString() =>
      'DecibelData(decibel: ${decibel.toStringAsFixed(1)} dB, timestamp: $timestamp)';
}
