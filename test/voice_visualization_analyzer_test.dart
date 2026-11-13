import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tonetype/features/conversation/audio/voice_visualization_analyzer.dart';

void main() {
  test('voice visual signal follows loudness and pitch in bounded ranges', () {
    var now = DateTime(2026, 8, 19, 12);
    final lowPitch = VoiceVisualizationAnalyzer(clock: () => now);
    final highPitch = VoiceVisualizationAnalyzer(clock: () => now);
    VoiceVisualSignal? low;
    VoiceVisualSignal? high;

    for (var chunk = 0; chunk < 8; chunk++) {
      low =
          lowPitch.add(
            _sineChunk(frequency: 120, amplitude: 0.035, chunk: chunk),
          ) ??
          low;
      high =
          highPitch.add(
            _sineChunk(frequency: 280, amplitude: 0.22, chunk: chunk),
          ) ??
          high;
      now = now.add(const Duration(milliseconds: 80));
    }

    expect(low, isNotNull);
    expect(high, isNotNull);
    expect(high!.amplitude, greaterThan(low!.amplitude));
    expect(high.pitch, greaterThan(low.pitch));
    expect(high.pitchConfidence, greaterThan(0.25));
    expect(high.amplitude, inInclusiveRange(0, 1));
    expect(high.pitch, inInclusiveRange(0, 1));
  });

  test('silence does not invent a confident pitch', () {
    var now = DateTime(2026, 8, 19, 12);
    final analyzer = VoiceVisualizationAnalyzer(clock: () => now);
    VoiceVisualSignal? signal;
    for (var chunk = 0; chunk < 5; chunk++) {
      signal = analyzer.add(Uint8List(1280)) ?? signal;
      now = now.add(const Duration(milliseconds: 80));
    }

    expect(signal, isNotNull);
    expect(signal!.amplitude, lessThan(0.02));
    expect(signal.pitchConfidence, lessThan(0.05));
  });
}

Uint8List _sineChunk({
  required double frequency,
  required double amplitude,
  required int chunk,
}) {
  const samples = 640;
  final bytes = Uint8List(samples * 2);
  final data = ByteData.sublistView(bytes);
  for (var index = 0; index < samples; index++) {
    final absoluteSample = chunk * samples + index;
    final value =
        math.sin(2 * math.pi * frequency * absoluteSample / 16000) * amplitude;
    data.setInt16(index * 2, (value * 32767).round(), Endian.little);
  }
  return bytes;
}
