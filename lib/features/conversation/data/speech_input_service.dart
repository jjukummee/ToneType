import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueChanged;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../audio/voice_visualization_analyzer.dart';

enum SpeechAvailability { ready, permissionDenied, unavailable }

abstract interface class SpeechInputService {
  bool get isListening;

  Future<SpeechAvailability> initialize();

  Future<void> start({required ValueChanged<VoiceVisualSignal> onVisualSignal});

  Future<String?> stop();
  Future<void> cancel();
  Future<void> dispose();
}

class DeviceSpeechInputService implements SpeechInputService {
  DeviceSpeechInputService({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  final VoiceVisualizationAnalyzer _visualization =
      VoiceVisualizationAnalyzer();
  StreamSubscription<Uint8List>? _audioSubscription;
  RandomAccessFile? _audioFile;
  Future<void> _writeQueue = Future.value();
  String? _path;
  int _pcmBytes = 0;
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
    required ValueChanged<VoiceVisualSignal> onVisualSignal,
  }) async {
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/tonetype-${DateTime.now().microsecondsSinceEpoch}.wav';
    await _audioSubscription?.cancel();
    final file = await File(path).open(mode: FileMode.write);
    await file.writeFrom(Uint8List(44));
    _visualization.reset();
    _audioFile = file;
    _path = path;
    _pcmBytes = 0;
    _writeQueue = Future.value();
    late final Stream<Uint8List> stream;
    try {
      stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        ),
      );
    } on Object {
      await file.close();
      _audioFile = null;
      _path = null;
      await File(path).delete();
      rethrow;
    }
    _listening = true;
    _audioSubscription = stream.listen((chunk) {
      if (chunk.isEmpty) return;
      _pcmBytes += chunk.length;
      _writeQueue = _writeQueue.then((_) async {
        await file.writeFrom(chunk);
      });
      final signal = _visualization.add(chunk);
      if (signal != null) onVisualSignal(signal);
    });
  }

  @override
  Future<String?> stop() async {
    if (!_listening) return null;
    await _recorder.stop();
    _listening = false;
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    await _writeQueue;
    final path = _path;
    await _finishWav();
    return path;
  }

  @override
  Future<void> cancel() async {
    if (_listening) await _recorder.cancel();
    _listening = false;
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    try {
      await _writeQueue;
    } on Object {
      // The incomplete recording is deleted below.
    }
    await _audioFile?.close();
    _audioFile = null;
    final path = _path;
    _path = null;
    _pcmBytes = 0;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<void> dispose() async {
    await cancel();
    await _recorder.dispose();
  }

  Future<void> _finishWav() async {
    final file = _audioFile;
    if (file == null) return;
    await file.setPosition(0);
    await file.writeFrom(_wavHeader(_pcmBytes));
    await file.flush();
    await file.close();
    _audioFile = null;
    _path = null;
    _pcmBytes = 0;
  }
}

Uint8List _wavHeader(int pcmBytes) {
  const sampleRate = 16000;
  const channels = 1;
  const bitsPerSample = 16;
  const blockAlign = channels * bitsPerSample ~/ 8;
  const byteRate = sampleRate * blockAlign;
  final header = Uint8List(44);
  final data = ByteData.sublistView(header);
  header.setRange(0, 4, ascii.encode('RIFF'));
  data.setUint32(4, 36 + pcmBytes, Endian.little);
  header.setRange(8, 12, ascii.encode('WAVE'));
  header.setRange(12, 16, ascii.encode('fmt '));
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, channels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, byteRate, Endian.little);
  data.setUint16(32, blockAlign, Endian.little);
  data.setUint16(34, bitsPerSample, Endian.little);
  header.setRange(36, 40, ascii.encode('data'));
  data.setUint32(40, pcmBytes, Endian.little);
  return header;
}
