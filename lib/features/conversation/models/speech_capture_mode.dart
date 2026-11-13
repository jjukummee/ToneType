enum SpeechCaptureMode {
  single,
  live;

  String get label => switch (this) {
    SpeechCaptureMode.single => '한 번',
    SpeechCaptureMode.live => '실시간',
  };

  String get title => switch (this) {
    SpeechCaptureMode.single => '말한 뒤 분석',
    SpeechCaptureMode.live => '실시간 번역',
  };

  String get description => switch (this) {
    SpeechCaptureMode.single => '말을 마친 뒤 말투와 키네틱 결과를 한 번에 완성해요.',
    SpeechCaptureMode.live => '말하는 동안 인식 문장을 바로 보여주고, 멈추면 말투 분석을 완성해요.',
  };

  static SpeechCaptureMode fromName(String? value) => values.firstWhere(
    (mode) => mode.name == value,
    orElse: () => SpeechCaptureMode.single,
  );
}
