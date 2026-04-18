abstract class AudioStatus {
  final bool isActive;

  const AudioStatus({
    required this.isActive,
  });

  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AudioStatus && other.isActive == isActive;
  }

  @override
  int get hashCode => isActive.hashCode;
}

class MicAudioStatus extends AudioStatus {
  final String? deviceName;

  const MicAudioStatus({
    required super.isActive,
    this.deviceName,
  });

  MicAudioStatus copyWith({
    bool? isActive,
    String? deviceName,
  }) {
    return MicAudioStatus(
      isActive: isActive ?? this.isActive,
      deviceName: deviceName ?? this.deviceName,
    );
  }

  factory MicAudioStatus.fromJson(Map<String, dynamic> json) {
    return MicAudioStatus(
      isActive: json['isActive'],
      deviceName: json['deviceName'],
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'isActive': isActive,
      'deviceName': deviceName,
    };
  }

  @override
  String toString() =>
      '''MicAudioStatus(isActive: $isActive, deviceName: $deviceName)''';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is MicAudioStatus && other.deviceName == deviceName;
  }

  @override
  int get hashCode => deviceName.hashCode;
}

class SystemAudioStatus extends AudioStatus {
  SystemAudioStatus({required super.isActive});

  SystemAudioStatus copyWith({
    bool? isActive,
  }) {
    return SystemAudioStatus(isActive: isActive ?? this.isActive);
  }

  factory SystemAudioStatus.fromJson(Map<String, dynamic> json) {
    return SystemAudioStatus(isActive: json['isActive']);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'isActive': isActive,
    };
  }

  @override
  String toString() => '''SystemAudioStatus(isActive: $isActive)''';
}
