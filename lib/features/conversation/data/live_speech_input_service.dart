import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueChanged;
import 'package:record/record.dart';

import 'speech_input_service.dart';

abstract interface class LiveSpeechInputService {
  bool get isListening;

  Future<SpeechAvailability> initialize();

  Future<void> start({
    required ValueChanged<Uint8List> onAudioChunk,
    required ValueChanged<double> onSoundLevel,
    required ValueChanged<Object> onError,
  });

  Future<void> stop();
  Future<void> cancel();
  Future<void> dispose();
}

class DeviceLiveSpeechInputService implements LiveSpeechInputService {
  DeviceLiveSpeechInputService({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  bool _listening = false;

  @override
  bool get isListening => _listening;

  @override
  Future<SpeechAvailability> initialize() async {
    try {
      return await _recorder.hasPermission()
          ? SpeechAvailability.ready
          : SpeechAvailability.permissionDenied;
    } on Object {
      return SpeechAvailability.unavailable;
    }
  }

  @override
  Future<void> start({
    required ValueChanged<Uint8List> onAudioChunk,
    required ValueChanged<double> onSoundLevel,
    required ValueChanged<Object> onError,
  }) async {
    await _audioSubscription?.cancel();
    await _amplitudeSubscription?.cancel();
    final audio = await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
        // About 64 ms of mono PCM at 16 kHz. Smaller streaming frames reach
        // interim recognition sooner without reducing the audio quality.
        streamBufferSize: 2048,
      ),
    );
    _listening = true;
    _audioSubscription = audio.listen(
      onAudioChunk,
      onError: (Object error, StackTrace _) {
        _listening = false;
        onError(error);
      },
    );
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 80))
        .listen(
          (amplitude) => onSoundLevel(amplitude.current),
          onError: (Object _, StackTrace _) {},
        );
  }

  @override
  Future<void> stop() async {
    if (_listening) await _recorder.stop();
    _listening = false;
    await _audioSubscription?.cancel();
    await _amplitudeSubscription?.cancel();
    _audioSubscription = null;
    _amplitudeSubscription = null;
  }

  @override
  Future<void> cancel() async {
    if (_listening) await _recorder.cancel();
    _listening = false;
    await _audioSubscription?.cancel();
    await _amplitudeSubscription?.cancel();
    _audioSubscription = null;
    _amplitudeSubscription = null;
  }

  @override
  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }
}
