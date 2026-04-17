Map<String, dynamic> buildWebScreenAndMicRecordingPayload() {
  return <String, dynamic>{
    'platform': 'web',
    'screenAnalysisReady': true,
    'sources': const <Map<String, dynamic>>[
      <String, dynamic>{
        'sourceKey': 'screen',
        'sourceKind': 'screen-share',
        'mediaKind': 'video',
        'mimeType': 'video/webm',
        'metadata': <String, dynamic>{
          'analysisReady': true,
          'transcribe': false,
        },
      },
      <String, dynamic>{
        'sourceKey': 'microphone',
        'sourceKind': 'microphone',
        'mediaKind': 'audio',
        'mimeType': 'audio/webm',
      },
    ],
  };
}

Map<String, dynamic> buildWebMicrophoneRecordingPayload() {
  return <String, dynamic>{
    'platform': 'web',
    'screenAnalysisReady': false,
    'sources': const <Map<String, dynamic>>[
      <String, dynamic>{
        'sourceKey': 'microphone',
        'sourceKind': 'microphone',
        'mediaKind': 'audio',
        'mimeType': 'audio/webm',
      },
    ],
  };
}

Map<String, dynamic> buildAndroidBackgroundRecordingPayload() {
  return <String, dynamic>{
    'platform': 'android',
    'screenAnalysisReady': false,
    'sources': const <Map<String, dynamic>>[
      <String, dynamic>{
        'sourceKey': 'microphone',
        'sourceKind': 'microphone',
        'mediaKind': 'audio',
        'mimeType': 'audio/wav',
        'metadata': <String, dynamic>{'backgroundCapable': true},
      },
    ],
  };
}

Map<String, dynamic> buildDesktopRecordingPayload() {
  return <String, dynamic>{
    'platform': 'desktop',
    'screenAnalysisReady': false,
    'sources': const <Map<String, dynamic>>[
      <String, dynamic>{
        'sourceKey': 'microphone',
        'sourceKind': 'microphone',
        'mediaKind': 'audio',
        'mimeType': 'audio/wav',
        'metadata': <String, dynamic>{
          'backgroundCapable': true,
          'foregroundRole': 'user',
        },
      },
      <String, dynamic>{
        'sourceKey': 'system',
        'sourceKind': 'system-audio',
        'mediaKind': 'audio',
        'mimeType': 'audio/wav',
        'metadata': <String, dynamic>{
          'backgroundCapable': true,
          'floatingToolbarCapable': true,
          'globalHotkeyReady': true,
        },
      },
    ],
    'capturePlan': 'desktop-dual-source',
  };
}
