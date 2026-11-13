import 'dart:math' as math;
import 'dart:typed_data';

class VoiceVisualSignal {
  const VoiceVisualSignal({
    this.amplitude = 0,
    this.pitch = 0.5,
    this.pitchConfidence = 0,
  });

  final double amplitude;
  final double pitch;
  final double pitchConfidence;
}

/// Produces a small visual-only signal from 16 kHz mono PCM.
///
/// Pitch is intentionally throttled and smoothed. It never participates in
/// recognition or the final prosody result, so visual feedback cannot reduce
/// transcription accuracy.
class VoiceVisualizationAnalyzer {
  VoiceVisualizationAnalyzer({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const _sampleRate = 16000;
  static const _windowSize = 640;
  static const _analysisIntervalMs = 64;

  final DateTime Function() _clock;
  final Float64List _window = Float64List(_windowSize);
  int _samples = 0;
  DateTime? _lastAnalysis;
  double _amplitude = 0;
  double _pitch = 0.5;
  double _confidence = 0;

  void reset() {
    _window.fillRange(0, _window.length, 0);
    _samples = 0;
    _lastAnalysis = null;
    _amplitude = 0;
    _pitch = 0.5;
    _confidence = 0;
  }

  VoiceVisualSignal? add(Uint8List chunk) {
    if (chunk.length < 4) return null;
    final data = ByteData.sublistView(chunk);
    final sampleCount = chunk.length ~/ 2;
    final keep = math.min(sampleCount, _windowSize);
    if (keep < _windowSize) {
      final remaining = _windowSize - keep;
      for (var index = 0; index < remaining; index++) {
        _window[index] = _window[index + keep];
      }
    }
    var squareSum = 0.0;
    for (var index = 0; index < keep; index++) {
      final sourceIndex = (sampleCount - keep + index) * 2;
      final sample = data.getInt16(sourceIndex, Endian.little) / 32768.0;
      _window[_windowSize - keep + index] = sample;
      squareSum += sample * sample;
    }
    _samples = math.min(_windowSize, _samples + keep);
    final rms = math.sqrt(squareSum / keep);
    final level = (rms * 8.5).clamp(0.0, 1.0);
    _amplitude += (level - _amplitude) * (level > _amplitude ? 0.48 : 0.20);

    final now = _clock();
    if (_lastAnalysis != null &&
        now.difference(_lastAnalysis!).inMilliseconds < _analysisIntervalMs) {
      return null;
    }
    _lastAnalysis = now;
    final estimate = _samples < _windowSize || rms < 0.008
        ? null
        : _estimatePitch();
    if (estimate == null) {
      _confidence *= 0.62;
      _pitch += (0.5 - _pitch) * 0.12;
    } else {
      _pitch += (estimate.$1 - _pitch) * 0.36;
      _confidence += (estimate.$2 - _confidence) * 0.42;
    }
    return VoiceVisualSignal(
      amplitude: _amplitude.clamp(0.0, 1.0),
      pitch: _pitch.clamp(0.0, 1.0),
      pitchConfidence: _confidence.clamp(0.0, 1.0),
    );
  }

  (double, double)? _estimatePitch() {
    const downsampledCount = _windowSize ~/ 2;
    final samples = Float64List(downsampledCount);
    var mean = 0.0;
    for (var index = 0; index < downsampledCount; index++) {
      final value = _window[index * 2];
      samples[index] = value;
      mean += value;
    }
    mean /= downsampledCount;
    for (var index = 0; index < downsampledCount; index++) {
      samples[index] -= mean;
    }

    var bestLag = 0;
    var bestCorrelation = 0.0;
    for (var lag = 20; lag <= 100; lag++) {
      var correlation = 0.0;
      var leftEnergy = 0.0;
      var rightEnergy = 0.0;
      for (var index = 0; index < downsampledCount - lag; index++) {
        final left = samples[index];
        final right = samples[index + lag];
        correlation += left * right;
        leftEnergy += left * left;
        rightEnergy += right * right;
      }
      final denominator = math.sqrt(leftEnergy * rightEnergy);
      if (denominator <= 0) continue;
      final normalized = correlation / denominator;
      if (normalized > bestCorrelation) {
        bestCorrelation = normalized;
        bestLag = lag;
      }
    }
    if (bestLag == 0 || bestCorrelation < 0.38) return null;
    final frequency = (_sampleRate / 2) / bestLag;
    final normalizedPitch = math.log(frequency / 80) / math.log(400 / 80);
    final confidence = ((bestCorrelation - 0.38) / 0.52).clamp(0.0, 1.0);
    return (normalizedPitch.clamp(0.0, 1.0), confidence);
  }
}
