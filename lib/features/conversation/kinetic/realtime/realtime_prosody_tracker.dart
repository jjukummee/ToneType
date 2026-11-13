import 'dart:math' as math;
import 'dart:typed_data';

import 'realtime_kinetic_types.dart';
import 'realtime_token_prosody.dart';

/// A deliberately small, on-device feature tracker for live visual feedback.
///
/// It does not replace the server's final ProsodyAnalyzer. It derives the
/// relative, short-lived signals needed to animate the mutable live tail
/// without adding a network round trip, and keeps a short rolling history of
/// analysed frames so individual recognised words can be measured rather than
/// all sharing one instantaneous reading.
class RealtimeProsodyTracker {
  RealtimeProsodyTracker({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const _sampleRate = 16000;
  static const _frameSamples = 320; // 20 ms
  static const _pitchWindowSamples = 640; // 40 ms
  static const _pitchIntervalMs = 72;
  static const _maxFrames = 1200; // 24 s of history
  static const _framesTrimBatch = 300;

  final DateTime Function() _clock;
  final RealtimeTokenProsodyAligner _aligner = RealtimeTokenProsodyAligner();

  final Float64List _pitchWindow = Float64List(_pitchWindowSamples);
  final Float64List _frameAccumulator = Float64List(_frameSamples);
  final List<ProsodyFrame> _frames = [];

  int _pitchSamples = 0;
  int _frameFill = 0;
  double _audioMs = 0;
  double _lastPitch = double.nan;

  DateTime? _lastPitchAnalysis;
  DateTime? _lastVoiceAt;
  double _level = 0.5;
  double _levelBaseline = 0.5;
  double _energy = 0.5;
  double _pitch = 0.5;
  double _pitchBaseline = 0.5;
  double _pitchSlope = 0;
  double _speed = 0.5;
  double _speedBaseline = 0.5;
  bool _hasLevelBaseline = false;
  bool _hasPitchBaseline = false;

  /// Elapsed audio measured from the samples themselves, immune to the jitter
  /// of wall-clock delivery.
  double get audioMs => _audioMs;

  void reset() {
    _pitchWindow.fillRange(0, _pitchWindow.length, 0);
    _frameAccumulator.fillRange(0, _frameAccumulator.length, 0);
    _frames.clear();
    _aligner.reset();
    _pitchSamples = 0;
    _frameFill = 0;
    _audioMs = 0;
    _lastPitch = double.nan;
    _lastPitchAnalysis = null;
    _lastVoiceAt = null;
    _level = 0.5;
    _levelBaseline = 0.5;
    _energy = 0.5;
    _pitch = 0.5;
    _pitchBaseline = 0.5;
    _pitchSlope = 0;
    _speed = 0.5;
    _speedBaseline = 0.5;
    _hasLevelBaseline = false;
    _hasPitchBaseline = false;
  }

  void addSoundLevel(double rawDecibels) {
    final now = _clock();
    final normalized = ((rawDecibels + 45) / 45).clamp(0.0, 1.0);
    _level = _ema(_level, normalized, 0.28);
    if (normalized > 0.08) {
      _lastVoiceAt = now;
      if (!_hasLevelBaseline) {
        _levelBaseline = normalized;
        _hasLevelBaseline = true;
      } else {
        _levelBaseline = _ema(_levelBaseline, normalized, 0.035);
      }
    }
  }

  void addAudio(Uint8List chunk) {
    if (chunk.length < 4) return;
    final data = ByteData.sublistView(chunk);
    final count = chunk.length ~/ 2;
    final keep = math.min(count, _pitchWindowSamples);
    if (keep < _pitchWindowSamples) {
      final shift = _pitchWindowSamples - keep;
      for (var index = 0; index < shift; index++) {
        _pitchWindow[index] = _pitchWindow[index + keep];
      }
    }
    var squareSum = 0.0;
    for (var index = 0; index < count; index++) {
      final sample = data.getInt16(index * 2, Endian.little) / 32768.0;
      squareSum += sample * sample;
      final windowIndex = index - (count - keep);
      if (windowIndex >= 0) {
        _pitchWindow[_pitchWindowSamples - keep + windowIndex] = sample;
      }
      _frameAccumulator[_frameFill++] = sample;
      if (_frameFill == _frameSamples) _closeFrame();
    }
    _pitchSamples = math.min(_pitchWindowSamples, _pitchSamples + keep);
    final rms = math.sqrt(squareSum / count);
    final normalizedEnergy = (rms * 10).clamp(0.0, 1.0);
    _energy = _ema(_energy, normalizedEnergy, 0.22);
    if (rms > 0.008) _lastVoiceAt = _clock();

    final now = _clock();
    if (_pitchSamples < _pitchWindowSamples ||
        (_lastPitchAnalysis != null &&
            now.difference(_lastPitchAnalysis!).inMilliseconds <
                _pitchIntervalMs)) {
      return;
    }
    _lastPitchAnalysis = now;
    final estimate = _estimatePitch();
    if (estimate == null) {
      _pitchSlope = _ema(_pitchSlope, 0, 0.35);
      _lastPitch = double.nan;
      return;
    }
    final previous = _pitch;
    _pitch = _ema(_pitch, estimate, 0.34);
    _lastPitch = _pitch;
    _pitchSlope = _ema(_pitchSlope, (_pitch - previous) * 5, 0.42);
    if (!_hasPitchBaseline) {
      _pitchBaseline = _pitch;
      _hasPitchBaseline = true;
    } else {
      _pitchBaseline = _ema(_pitchBaseline, _pitch, 0.025);
    }
  }

  void _closeFrame() {
    var squareSum = 0.0;
    for (var index = 0; index < _frameSamples; index++) {
      final value = _frameAccumulator[index];
      squareSum += value * value;
    }
    _audioMs += _frameSamples * 1000 / _sampleRate;
    _frames.add(
      ProsodyFrame(
        timeMs: _audioMs,
        rms: math.sqrt(squareSum / _frameSamples),
        pitch: _lastPitch,
      ),
    );
    _frameFill = 0;
    if (_frames.length > _maxFrames) {
      _frames.removeRange(0, _framesTrimBatch);
    }
  }

  RealtimeProsodySnapshot snapshot({
    required String preview,
    required String committed,
  }) {
    final now = _clock();
    // Align against what is on screen, not only against what the recogniser
    // has finalised. Waiting for finals leaves long stretches of speech with
    // no measurements at all.
    final tokens = _aligner.sync(
      text: preview.isEmpty ? committed : preview,
      frames: _frames,
      audioMs: _audioMs,
    );

    final measuredSpeed = _syllableRate();
    if (measuredSpeed != null) {
      _speed = _ema(_speed, measuredSpeed, 0.3);
      _speedBaseline = _ema(_speedBaseline, _speed, 0.03);
    }

    final pauseSeconds = _lastVoiceAt == null
        ? 0.0
        : now.difference(_lastVoiceAt!).inMilliseconds / 1000;
    return RealtimeProsodySnapshot(
      relativeLoudness: ((_level - _levelBaseline) * 3.2).clamp(-1.0, 1.0),
      pitchDeviation: ((_pitch - _pitchBaseline) * 4).clamp(-1.0, 1.0),
      pitchSlope: _pitchSlope.clamp(-1.0, 1.0),
      energy: _energy.clamp(0.0, 1.0),
      speedDeviation: ((_speed - _speedBaseline) * 3).clamp(-1.0, 1.0),
      pause: (pauseSeconds / 0.9).clamp(0.0, 1.0),
      durationAnomaly: _durationAnomaly(tokens, committed),
      tokens: tokens,
    );
  }

  /// Speech rate from energy peaks rather than from how fast text arrives.
  ///
  /// Recognised text lands in bursts after network and decoder latency, so
  /// measuring it counts delivery, not speech. Syllable nuclei show up as
  /// local maxima in short-term energy, which is what actually speeds up and
  /// slows down when someone changes pace.
  double? _syllableRate() {
    if (_frames.length < 12) return null;
    final recent = _frames.length <= 100
        ? _frames
        : _frames.sublist(_frames.length - 100);
    var peakRms = 0.0;
    for (final frame in recent) {
      peakRms = math.max(peakRms, frame.rms);
    }
    if (peakRms < 1e-4) return null;
    final threshold = peakRms * 0.34;
    var nuclei = 0;
    var lastPeakIndex = -10;
    for (var index = 1; index < recent.length - 1; index++) {
      final value = recent[index].rms;
      if (value < threshold) continue;
      if (value < recent[index - 1].rms || value < recent[index + 1].rms) {
        continue;
      }
      // 20 ms frames; 6 frames keeps two nuclei at least 120 ms apart.
      if (index - lastPeakIndex < 6) continue;
      nuclei++;
      lastPeakIndex = index;
    }
    final seconds = recent.length * _frameSamples / _sampleRate;
    if (seconds <= 0) return null;
    // Korean conversational speech sits near 4-7 syllables per second.
    return ((nuclei / seconds - 3.0) / 5.0).clamp(0.0, 1.0);
  }

  /// Drawn-out speech from measured syllable duration, with the typed tilde
  /// kept only as a secondary cue.
  double _durationAnomaly(List<TokenProsody> tokens, String committed) {
    final lastToken = RegExp(r'\S+\s*$').firstMatch(committed)?.group(0) ?? '';
    if (lastToken.contains(RegExp(r'[~～]{2,}'))) return 1;
    if (tokens.isEmpty) return 0;
    final stretch = tokens.last.stretch;
    return ((stretch - 0.58) / 0.32).clamp(0.0, 1.0);
  }

  double? _estimatePitch() {
    // Downsample to 8 kHz. Pairs are averaged rather than decimated so energy
    // above the new Nyquist limit does not fold back into the correlation.
    // A 40 ms window with lags 20...100 covers roughly 80...400 Hz.
    const sampleCount = _pitchWindowSamples ~/ 2;
    final samples = Float64List(sampleCount);
    var mean = 0.0;
    for (var index = 0; index < sampleCount; index++) {
      final value =
          (_pitchWindow[index * 2] + _pitchWindow[index * 2 + 1]) / 2;
      samples[index] = value;
      mean += value;
    }
    mean /= sampleCount;
    var energy = 0.0;
    for (var index = 0; index < sampleCount; index++) {
      samples[index] -= mean;
      energy += samples[index] * samples[index];
    }
    if (energy < 0.003) return null;

    final correlations = Float64List(101);
    var bestLag = 0;
    var bestCorrelation = 0.0;
    for (var lag = 20; lag <= 100; lag++) {
      var correlation = 0.0;
      var leftEnergy = 0.0;
      var rightEnergy = 0.0;
      for (var index = 0; index < sampleCount - lag; index++) {
        final left = samples[index];
        final right = samples[index + lag];
        correlation += left * right;
        leftEnergy += left * left;
        rightEnergy += right * right;
      }
      final denominator = math.sqrt(leftEnergy * rightEnergy);
      if (denominator <= 0) continue;
      final normalized = correlation / denominator;
      correlations[lag] = normalized;
      if (normalized > bestCorrelation) {
        bestCorrelation = normalized;
        bestLag = lag;
      }
    }
    if (bestLag == 0 || bestCorrelation < 0.38) return null;

    // Octave guard: autocorrelation peaks just as strongly one octave down, so
    // prefer the half lag whenever it is nearly as good.
    final halfLag = bestLag ~/ 2;
    if (halfLag >= 20 && correlations[halfLag] >= bestCorrelation * 0.85) {
      bestLag = halfLag;
    }

    final frequency = (_sampleRate / 2) / bestLag;
    final normalized = math.log(frequency / 80) / math.log(400 / 80);
    return normalized.clamp(0.0, 1.0);
  }

  double _ema(double current, double next, double alpha) =>
      current + (next - current) * alpha;
}
