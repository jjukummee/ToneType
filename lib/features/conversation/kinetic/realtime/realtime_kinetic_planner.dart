import 'dart:math' as math;

import 'realtime_kinetic_types.dart';

/// Deterministic, stateful planner for the mutable tail of live recognition.
///
/// The basic planner is intentionally not referenced here. Live updates are
/// bounded to two short lines and run in linear time with the number of visible
/// tokens.
///
/// Composition rules, in the order they matter:
///
///  1. Every token is measured on its own audio, so size, weight and vertical
///     position describe that word rather than the moment it was displayed.
///  2. Exactly one token per line may reach peak treatment, and at most two may
///     be raised above the calm field. Contrast is what makes emphasis legible;
///     raising everything reads as noise.
///  3. The pitch contour is smoothed across neighbours, so the line traces a
///     curve instead of scattering.
///  4. A total movement budget damps every deviation proportionally when a line
///     turns out to be unusually animated.
class RealtimeKineticPlanner {
  /// The crown is chosen from where a word sits *within its own line*, not
  /// from an absolute score, so a loud sentence still has a focus and a quiet
  /// one is not forced to invent it.
  static const _peakShare = 0.74;

  /// Below this raw spread the line is genuinely uniform, so no word is
  /// crowned. Size and colour still vary, driven by absolute loudness.
  static const _contrastGuard = 0.06;

  /// Vertical travel is deliberately small. Size and colour carry emphasis;
  /// position only traces the melody, and a tight baseline is what keeps a
  /// dense composition readable.
  static const _maxContourOffset = 9.0;

  /// Share of a line that may take the accent colour.
  static const _accentShare = 0.40;

  /// How many words at the very end stay provisional.
  ///
  /// Only the newest words are genuinely unstable. Treating everything the
  /// recogniser has not finalised as provisional leaves an entire spoken
  /// paragraph unstyled, because finals can lag many seconds behind speech.
  /// Only the newest word or two stay unsettled. Draft words already carry
  /// their measured shape, so a short tail costs nothing and keeps typography
  /// appearing the moment speech is recognised.
  static const _maxProvisionalTokens = 2;

  /// How many recent words keep their typography on the live stage.
  ///
  /// Counted in words rather than lines so the window can be read straight off
  /// what has been retained, which only ever grows. Deriving it from the text
  /// the recogniser happens to be reporting made the stage collapse whenever
  /// that text was revised.
  static const _visibleTokens = 56;

  /// Characters of plain-grey history kept above the composition.
  ///
  /// Sized to about three rendered lines at body size. Older speech is dropped
  /// from the front, because the recent past is what gives the current line its
  /// context.
  static const _archivedBudget = 66;

  /// Comfortable reading width for one live line.
  static const _maxLineLength = 62;

  /// Every word that has settled during this session, keyed by its stable id.
  ///
  /// The visible stage is bounded to two lines, but the typography a speaker
  /// watched being built is the whole point of the mode. Retaining it here lets
  /// the final result reuse exactly what was on screen instead of rebuilding a
  /// plainer composition from scratch.
  final Map<int, RealtimeKineticSegment> _composition = {};

  /// The settled text seen on the previous update, used only to notice when
  /// the recogniser contradicts itself.
  String _lastCandidate = '';

  int _revision = 0;
  String _lastSignature = '';
  RealtimeKineticPlan _lastPlan = const RealtimeKineticPlan.empty();

  /// Everything styled so far this session, in spoken order.
  List<RealtimeKineticSegment> get composition {
    final keys = _composition.keys.toList()..sort();
    return [for (final key in keys) _composition[key]!];
  }

  void reset() {
    _composition.clear();
    _lastCandidate = '';
    _revision = 0;
    _lastSignature = '';
    _lastPlan = const RealtimeKineticPlan.empty();
  }

  RealtimeKineticPlan plan({
    required String preview,
    required String committed,
    required double stability,
    required RealtimeProsodySnapshot prosody,
  }) {
    final display = preview.isEmpty ? committed : preview;
    final settledEnd = _settledEnd(display: display, committed: committed);
    final settled = display.substring(0, settledEnd);
    _reconcile(settled);
    final provisionalText = display.substring(settledEnd).trimLeft();

    final lines = _splitLines(settled);
    final lastLine = lines.isEmpty ? '' : lines.last;
    var lastLineStart = 0;
    for (var index = 0; index + 1 < lines.length; index++) {
      lastLineStart += _tokenCount(lines[index]);
    }
    final measured = _tokensForLine(
      prosody: prosody,
      from: lastLineStart,
      count: _tokenCount(lastLine),
    );
    final signature = [
      settled,
      provisionalText,
      _bucket(prosody.relativeLoudness),
      _bucket(prosody.pitchDeviation),
      _bucket(prosody.pitchSlope),
      _bucket(prosody.energy),
      _bucket(prosody.speedDeviation),
      _bucket(prosody.pause),
      for (final token in measured)
        '${_bucket(token.loudness)},${_bucket(token.pitch)},'
            '${_bucket(token.stretch)},${_bucket(token.pitchSlope)}',
    ].join('|');
    if (signature == _lastSignature) return _lastPlan;

    // Style every line, not just the visible one. The stage only ever shows the
    // last two, but a recogniser that finalises in bursts can push several
    // lines' worth of words past the stage between updates. Anything skipped
    // here would have no treatment to carry into the final result.
    var offset = 0;
    String? dominant;
    for (var index = 0; index < lines.length; index++) {
      final count = _tokenCount(lines[index]);
      final isLast = index == lines.length - 1;
      // A line counts as retained only when what was stored still reproduces it
      // exactly. A line that once ended the transcript was stored without the
      // space that later separated it from the next line, so it must be redone.
      final keys = List.generate(count, (step) => offset + step);
      final retained =
          !isLast &&
          keys.every(_composition.containsKey) &&
          keys.map((key) => _composition[key]!.text).join() == lines[index];
      if (!retained) {
        final planned = _planLine(
          text: lines[index],
          baseIndex: offset,
          measured: _tokensForLine(
            prosody: prosody,
            from: offset,
            count: count,
          ),
          prosody: prosody,
        );
        for (final segment in planned.$1) {
          final key = int.tryParse(segment.id.split('-').last);
          if (key == null) continue;
          // A word that momentarily ends the transcript is planned without the
          // space that separates it from the next one. Keep the separator we
          // already had, or a backtrack welds two words together for good.
          final held = _composition[key]?.text;
          final needsSeparator =
              held != null &&
              held.trimRight() == segment.text.trimRight() &&
              held.length > segment.text.length;
          _composition[key] = needsSeparator
              ? segment.withText(held)
              : segment;
        }
        if (isLast) dominant = planned.$2;
      }
      offset += count;
    }

    final provisional = _provisionalSegments(
      provisionalText,
      baseIndex: offset,
      stability: stability,
      prosody: prosody,
    );

    // Read the window off what has been retained. Recognition may report less
    // than this for a moment; the words are measured, on screen, and staying.
    var end = offset;
    while (_composition.containsKey(end)) {
      end++;
    }
    final start = math.max(0, end - _visibleTokens);
    final visible = <RealtimeKineticSegment>[
      for (var key = start; key < end; key++)
        if (_composition[key] != null) _composition[key]!,
    ];
    final archived = _boundedHistory([
      for (var key = 0; key < start; key++)
        if (_composition[key] != null) _composition[key]!.text,
    ].join());

    _lastSignature = signature;
    _lastPlan = RealtimeKineticPlan(
      archivedText: archived,
      committed: visible,
      provisional: provisional,
      dominantWord: (dominant?.isEmpty ?? true) ? null : dominant,
      revision: ++_revision,
    );
    return _lastPlan;
  }

  /// Discards retained styling the recogniser has contradicted.
  ///
  /// Interim results shrink and grow constantly, which is not a contradiction —
  /// the words are still on screen and already measured. Only text that
  /// actually diverges gives up what was retained past that point.
  void _reconcile(String candidate) {
    if (_lastCandidate.isEmpty ||
        candidate.startsWith(_lastCandidate) ||
        _lastCandidate.startsWith(candidate)) {
      _lastCandidate = candidate;
      return;
    }
    var common = 0;
    final maximum = math.min(candidate.length, _lastCandidate.length);
    while (common < maximum && candidate[common] == _lastCandidate[common]) {
      common++;
    }
    final keep = _tokenCount(candidate.substring(0, common));
    _composition.removeWhere((key, _) => key >= keep);
    _lastCandidate = candidate;
  }

  /// Trims older speech from the front of the plain-grey history.
  ///
  /// A long session would otherwise push the composition off screen behind its
  /// own transcript.
  String _boundedHistory(String text) {
    final trimmed = text.trim();
    if (trimmed.length <= _archivedBudget) return trimmed;
    final tokens = RegExp(r'\S+\s*').allMatches(trimmed).toList();
    var start = trimmed.length;
    for (var index = tokens.length - 1; index >= 0; index--) {
      if (trimmed.length - tokens[index].start > _archivedBudget) break;
      start = tokens[index].start;
    }
    if (start >= trimmed.length) return '… ${trimmed.substring(trimmed.length - _archivedBudget)}';
    return '… ${trimmed.substring(start).trim()}';
  }

  /// Splits settled speech into display lines without losing a character.
  ///
  /// Lines break at sentence endings, or once a line has grown past a
  /// comfortable reading width. Each slice keeps the whitespace that followed
  /// it, so concatenating every line reproduces the input exactly.
  List<String> _splitLines(String text) {
    final trimmed = text.trimRight();
    if (trimmed.isEmpty) return const [];
    final tokens = RegExp(r'\S+\s*').allMatches(trimmed).toList();
    if (tokens.isEmpty) return [trimmed];
    final lines = <String>[];
    var start = 0;
    var width = 0;
    for (var index = 0; index < tokens.length; index++) {
      final token = tokens[index].group(0)!;
      width += token.length;
      final endsSentence = RegExp(r'[.!?…。！？]\s*$').hasMatch(token);
      final isLast = index == tokens.length - 1;
      if (!isLast && !endsSentence && width < _maxLineLength) continue;
      final end = isLast ? trimmed.length : tokens[index].end;
      lines.add(trimmed.substring(start, end));
      start = end;
      width = 0;
    }
    return lines;
  }

  /// Runs the composition pipeline over one line.
  (List<RealtimeKineticSegment>, String?) _planLine({
    required String text,
    required int baseIndex,
    required List<TokenProsody> measured,
    required RealtimeProsodySnapshot prosody,
  }) {
    final raw = _rawSegments(
      text,
      baseIndex: baseIndex,
      measured: measured,
      prosody: prosody,
    );
    if (raw.isEmpty) return (const [], null);

    final arousal = _lineArousal(raw, prosody);
    final shares = _relativeProminence(raw);
    final emphasis = [
      for (var index = 0; index < raw.length; index++)
        _emphasisFor(raw[index], shares[index], arousal),
    ];
    final meanEmphasis = _mean(emphasis);
    final roles = _assignRoles(raw, shares);
    final tiers = _attentionTiers(emphasis);
    final contour = _contour(raw, emphasis);
    final damping = _movementDamping(raw, emphasis, arousal);
    final accentFloor = _accentFloor(emphasis, arousal);

    final segments = <RealtimeKineticSegment>[
      for (var index = 0; index < raw.length; index++)
        _resolveSegment(
          raw[index],
          role: roles[index],
          tier: tiers[index],
          emphasis: emphasis[index],
          meanEmphasis: meanEmphasis,
          contourOffset: contour[index],
          damping: damping,
          arousal: arousal,
          accentFloor: accentFloor,
          prosody: prosody,
        ),
    ];
    final peak = roles.indexOf(RealtimeEmphasisRole.peak);
    return (segments, peak < 0 ? null : segments[peak].text.trim());
  }

  /// Per-token measurements for the visible line, falling back to the
  /// instantaneous reading when no audio has been analysed yet.
  List<TokenProsody> _tokensForLine({
    required RealtimeProsodySnapshot prosody,
    required int from,
    required int count,
  }) {
    if (count <= 0) return const [];
    final available = prosody.tokens;
    final fallback = TokenProsody(
      loudness: ((prosody.relativeLoudness + 1) / 2).clamp(0.0, 1.0),
      pitch: ((prosody.pitchDeviation + 1) / 2).clamp(0.0, 1.0),
      pitchSlope: prosody.pitchSlope,
      stretch: (0.5 + prosody.durationAnomaly * 0.5).clamp(0.0, 1.0),
      energy: prosody.energy,
      pauseAfter: prosody.pause,
    );
    // Fall back one word at a time. Discarding a whole line because its last
    // word has not been measured yet is what left the end of a long utterance
    // with no typography at all.
    return [
      for (var index = 0; index < count; index++)
        from + index < available.length ? available[from + index] : fallback,
    ];
  }

  List<_RawLiveSegment> _rawSegments(
    String text, {
    required int baseIndex,
    required List<TokenProsody> measured,
    required RealtimeProsodySnapshot prosody,
  }) {
    final matches = RegExp(r'\S+\s*').allMatches(text).toList();
    return [
      for (var index = 0; index < matches.length; index++)
        _scoreSegment(
          matches[index].group(0)!,
          id: 'live-${baseIndex + index}',
          index: index,
          count: matches.length,
          previous: index == 0 ? null : matches[index - 1].group(0),
          token: index < measured.length
              ? measured[index]
              : const TokenProsody(),
          prosody: prosody,
        ),
    ];
  }

  _RawLiveSegment _scoreSegment(
    String text, {
    required String id,
    required int index,
    required int count,
    required String? previous,
    required TokenProsody token,
    required RealtimeProsodySnapshot prosody,
  }) {
    final word = _bare(text);
    final repeated =
        previous != null && _bare(previous) == word && word.isNotEmpty;
    final punctuation = RegExp(r'[!?！？]').hasMatch(text) ? 0.10 : 0.0;
    final ellipsis = RegExp(r'(\.{2,}|…)').hasMatch(text) ? 0.06 : 0.0;
    final drawnOut = RegExp(r'[~～]{2,}').hasMatch(text) ? 0.14 : 0.0;
    final position = count == 0 ? 0.0 : (index / count) * 0.05;
    final emphasisStretch = math.max(0.0, token.stretch - 0.5) * 2;

    final acoustic =
        token.loudness * 0.44 +
        token.pitchDelta.abs() * 0.28 +
        emphasisStretch * 0.16 +
        token.energy * 0.12;
    final linguistic =
        punctuation + ellipsis + drawnOut + position + (repeated ? 0.12 : 0.0);
    final salience = (acoustic + linguistic).clamp(0.0, 1.0);

    return _RawLiveSegment(
      id: id,
      text: text,
      token: token,
      salience: salience,
      repeated: repeated,
      drawnOut: drawnOut > 0 || token.stretch >= 0.82,
      hasEllipsis: ellipsis > 0,
      phraseEnding: RegExp(r'[.!?…。！？]\s*$').hasMatch(text),
      sequenceIndex: index,
    );
  }

  /// How energetic the whole line is, 0..1.
  ///
  /// This is what separates a whispered sentence from a shouted one. It moves
  /// the entire line's type size and weight, so delivery is legible even when
  /// no single word stands out.
  double _lineArousal(
    List<_RawLiveSegment> raw,
    RealtimeProsodySnapshot prosody,
  ) {
    if (raw.isEmpty) return 0.5;
    var loudness = 0.0;
    var swing = 0.0;
    for (final segment in raw) {
      loudness += segment.token.loudness;
      swing += segment.token.pitchDelta.abs();
    }
    loudness /= raw.length;
    swing /= raw.length;
    return (loudness * 0.5 + swing * 0.2 + prosody.energy * 0.3).clamp(
      0.0,
      1.0,
    );
  }

  /// Each word's prominence expressed as a share of this line's own range.
  ///
  /// A uniform line yields a flat neutral share rather than amplified noise;
  /// absolute loudness then supplies the variation on its own.
  List<double> _relativeProminence(List<_RawLiveSegment> raw) {
    if (raw.isEmpty) return const [];
    if (raw.length < 2) {
      return [raw.single.salience >= 0.45 ? 1.0 : 0.45];
    }
    var lowest = raw.first.salience;
    var highest = raw.first.salience;
    for (final segment in raw) {
      lowest = math.min(lowest, segment.salience);
      highest = math.max(highest, segment.salience);
    }
    final range = highest - lowest;
    if (range < _contrastGuard) {
      // Nothing stands out relative to its neighbours, so let each word speak
      // for itself. Flattening to a shared midpoint would inflate a quiet line
      // into a confident-looking one.
      return [for (final segment in raw) segment.token.loudness];
    }
    return [for (final segment in raw) (segment.salience - lowest) / range];
  }

  /// The single value every visual channel reads.
  ///
  /// Blending the within-line share with the word's own loudness keeps two
  /// things true at once: the line always has a legible shape, and a word that
  /// was genuinely quiet never inflates just because its neighbours were
  /// quieter still.
  ///
  /// How much the relative term counts rises with the line's energy. In a
  /// whisper the absolute level dominates, so the stressed word stays inside
  /// the hush rather than being normalised up into a shout.
  double _emphasisFor(_RawLiveSegment raw, double share, double arousal) {
    final relative = 0.30 + 0.40 * arousal;
    return (share * relative + raw.token.loudness * (1 - relative)).clamp(
      0.0,
      1.0,
    );
  }

  /// Where this line's accent colour begins.
  ///
  /// Two rules meet here. A minority of the line may take the accent, so the
  /// cut-off is the n-th strongest word. But a line that was never really
  /// spoken up gets no accent at all, so the cut-off can never fall below a
  /// floor that itself relaxes as the line gets louder.
  double _accentFloor(List<double> emphasis, double arousal) {
    if (emphasis.isEmpty) return 1;
    final allowed = math.max(1, (emphasis.length * _accentShare).round());
    final sorted = [...emphasis]..sort((a, b) => b.compareTo(a));
    final cutoff = sorted[math.min(allowed, sorted.length) - 1];
    return math.max(cutoff, 0.72 - 0.28 * arousal);
  }

  /// Crowns at most one word per line.
  ///
  /// Size and colour now vary continuously for every word, so the role is no
  /// longer what creates hierarchy. It marks only the single word that earns
  /// the reading badge and the underline.
  List<RealtimeEmphasisRole> _assignRoles(
    List<_RawLiveSegment> raw,
    List<double> shares,
  ) {
    final roles = [for (final _ in raw) RealtimeEmphasisRole.calm];
    if (raw.isEmpty || shares.length != raw.length) return roles;
    var peak = 0;
    for (var index = 1; index < shares.length; index++) {
      if (shares[index] > shares[peak]) peak = index;
    }
    if (shares[peak] < _peakShare) return roles;
    roles[peak] = RealtimeEmphasisRole.peak;
    return roles;
  }

  /// Pitch contour, smoothed so the line reads as a curve rather than noise.
  ///
  /// Prominent words are held closer to the baseline. A large word that also
  /// floats reads as an accident; a small one that floats reads as melody.
  List<double> _contour(List<_RawLiveSegment> raw, List<double> emphasis) {
    final rawOffsets = [
      for (var index = 0; index < raw.length; index++)
        -raw[index].token.pitchDelta *
            _maxContourOffset *
            (1 - 0.45 * emphasis[index]),
    ];
    if (rawOffsets.length < 3) {
      return [
        for (final value in rawOffsets)
          value.clamp(-_maxContourOffset, _maxContourOffset),
      ];
    }
    return [
      for (var index = 0; index < rawOffsets.length; index++)
        ((index == 0
                ? rawOffsets[0] * 0.75 + rawOffsets[1] * 0.25
                : index == rawOffsets.length - 1
                ? rawOffsets[index] * 0.75 + rawOffsets[index - 1] * 0.25
                : rawOffsets[index - 1] * 0.25 +
                      rawOffsets[index] * 0.5 +
                      rawOffsets[index + 1] * 0.25))
            .clamp(-_maxContourOffset, _maxContourOffset),
    ];
  }

  /// Keeps an unusually animated line from becoming busy.
  ///
  /// Deviation is measured against the line's own baseline, so a uniformly
  /// loud sentence is allowed to be large without spending its whole budget.
  double _movementDamping(
    List<_RawLiveSegment> raw,
    List<double> emphasis,
    double arousal,
  ) {
    if (raw.isEmpty) return 1;
    final baseline = _baselineScale(arousal);
    final mean = _mean(emphasis);
    var demand = 0.0;
    for (var index = 0; index < raw.length; index++) {
      demand += (_scaleFor(emphasis[index], mean, arousal) - baseline).abs();
    }
    // A wide spread is the point now, so the budget is generous; it exists to
    // stop a pathological line from inflating without bound.
    final budget = 0.34 + 0.20 * raw.length;
    if (demand <= budget) return 1;
    return (budget / demand).clamp(0.55, 1.0);
  }

  /// The size every word of this line is measured against.
  ///
  /// A wide range here is what makes a whisper and a shout distinguishable
  /// before a single word is read.
  double _baselineScale(double arousal) => 0.86 + 0.30 * arousal;

  double _mean(List<double> values) =>
      values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

  /// Attention tiers, capped by rank rather than by threshold.
  ///
  /// Size and colour vary continuously, so these no longer drive the visuals.
  /// They remain the engine's statement about how many words in a line may
  /// legitimately claim the reader's attention at once.
  List<RealtimeKineticIntensity> _attentionTiers(List<double> emphasis) {
    final tiers = [for (final _ in emphasis) RealtimeKineticIntensity.subtle];
    if (emphasis.isEmpty) return tiers;
    final ranked = List<int>.generate(emphasis.length, (index) => index)
      ..sort((left, right) => emphasis[right].compareTo(emphasis[left]));
    final mean = _mean(emphasis);
    if (emphasis[ranked.first] >= mean + 0.06 || emphasis.length == 1) {
      tiers[ranked.first] = RealtimeKineticIntensity.strong;
    }
    var raised = 0;
    for (final index in ranked.skip(1)) {
      if (raised >= 2) break;
      if (emphasis[index] < mean + 0.02) break;
      tiers[index] = RealtimeKineticIntensity.medium;
      raised++;
    }
    return tiers;
  }

  /// Type size, driven by how far a word departs from its own line's average.
  ///
  /// Measuring deviation rather than absolute level is what keeps the two
  /// scales from compounding: the line baseline already says how loudly the
  /// sentence was delivered, so size only has to say which words carried it.
  /// A sentence shouted evenly therefore renders large and heavy but level,
  /// while a sentence with one stressed word gets a genuine spike.
  ///
  /// The exponent below one expands small differences, which is what makes the
  /// composition sensitive to ordinary speech rather than only to extremes.
  double _scaleFor(double emphasis, double mean, double arousal) {
    final spread = 0.44 + 0.30 * arousal;
    final delta = (emphasis - mean).clamp(-1.0, 1.0);
    final shaped =
        (delta.isNegative ? -1 : 1) * math.pow(delta.abs(), 0.85).toDouble();
    final factor = 1 + spread * shaped * 1.2;
    return (_baselineScale(arousal) * factor).clamp(0.72, 1.58);
  }

  RealtimeKineticSegment _resolveSegment(
    _RawLiveSegment raw, {
    required RealtimeEmphasisRole role,
    required RealtimeKineticIntensity tier,
    required double emphasis,
    required double meanEmphasis,
    required double contourOffset,
    required double damping,
    required double arousal,
    required double accentFloor,
    required RealtimeProsodySnapshot prosody,
  }) {
    final token = raw.token;
    final peak = role == RealtimeEmphasisRole.peak;
    final motion = _motionFor(raw, role: role, prosody: prosody);
    final baseline = _baselineScale(arousal);
    final scale =
        baseline +
        (_scaleFor(emphasis, meanEmphasis, arousal) - baseline) * damping;

    // Weight tracks the same curve as size, one step ahead of it, so heavy
    // words are always the large ones.
    final weightAxis = (280 + 620 * math.pow(emphasis, 1.4).toDouble()).clamp(
      300.0,
      900.0,
    );

    // Colour is quantised against the line's own accent cut-off rather than a
    // fixed threshold, so roughly the top third takes the accent no matter how
    // the line was spoken.
    final accent = emphasis < accentFloor
        ? emphasis / math.max(accentFloor, 1e-3) * 0.66
        : 0.68 +
              0.32 *
                  ((emphasis - accentFloor) / math.max(1 - accentFloor, 1e-3));

    final speedFactor = ((prosody.speedDeviation + 1) / 2).clamp(0.0, 1.0);
    final pauseHold = (token.pauseAfter.clamp(0.0, 1.0) * 70).round();
    // Prominent words settle a touch faster, which reads as a stress rather
    // than a drift.
    final duration = (250 - speedFactor * 95 - emphasis * 40 + pauseHold)
        .round()
        .clamp(100, 320);

    return RealtimeKineticSegment(
      id: raw.id,
      text: raw.text,
      lifecycle: peak
          ? RealtimeWordLifecycle.emphasized
          : raw.phraseEnding
          ? RealtimeWordLifecycle.settled
          : RealtimeWordLifecycle.committed,
      motion: motion,
      intensity: tier,
      salience: raw.salience,
      role: role,
      verticalBias: contourOffset * damping,
      fontScale: scale,
      weightAxis: weightAxis,
      letterSpacing: ((token.stretch - 0.5) * 1.9 * damping).clamp(-0.6, 1.3),
      horizontalBias: 0,
      emphasis: accent.clamp(0.0, 1.0),
      toneTilt: token.pitchSlope.clamp(-1.0, 1.0),
      restingOpacity: (0.80 + 0.20 * emphasis).clamp(0.0, 1.0),
      durationMs: duration,
      sequenceIndex: raw.sequenceIndex,
    );
  }

  RealtimeKineticMotion _motionFor(
    _RawLiveSegment raw, {
    required RealtimeEmphasisRole role,
    required RealtimeProsodySnapshot prosody,
  }) {
    final token = raw.token;
    final peak = role == RealtimeEmphasisRole.peak;
    if (raw.drawnOut || prosody.durationAnomaly > 0.7) {
      return RealtimeKineticMotion.stretch;
    }
    if (raw.repeated || prosody.speedDeviation > 0.48) {
      return RealtimeKineticMotion.rush;
    }
    if (raw.hasEllipsis || prosody.pause > 0.72) {
      return RealtimeKineticMotion.hold;
    }
    if (peak && prosody.relativeLoudness > 0.12 && prosody.energy > 0.48) {
      return RealtimeKineticMotion.pulse;
    }
    if (peak && token.loudness > 0.55) return RealtimeKineticMotion.pulse;
    final slope = token.pitchSlope.abs() > 0.08
        ? token.pitchSlope
        : prosody.pitchSlope;
    if (slope > 0.15 && raw.salience >= 0.34) {
      return RealtimeKineticMotion.lift;
    }
    if (slope < -0.15 && raw.salience >= 0.34) {
      return raw.phraseEnding
          ? RealtimeKineticMotion.settle
          : RealtimeKineticMotion.drop;
    }
    if (prosody.relativeLoudness < -0.18 && prosody.energy < 0.48) {
      return RealtimeKineticMotion.breathe;
    }
    if (token.loudness < 0.28 && role == RealtimeEmphasisRole.calm) {
      return RealtimeKineticMotion.breathe;
    }
    if (raw.phraseEnding) return RealtimeKineticMotion.settle;
    return peak ? RealtimeKineticMotion.snap : RealtimeKineticMotion.neutral;
  }

  /// Draft words, already shaped by their own measurements.
  ///
  /// Rendering them as flat grey until the recogniser finalises made the whole
  /// opening of an utterance look unstyled. They keep their size, weight and
  /// contour and are simply held below the accent band and dimmed, so the
  /// composition is visible immediately and only settles as it stabilises.
  List<RealtimeKineticSegment> _provisionalSegments(
    String text, {
    required int baseIndex,
    required double stability,
    required RealtimeProsodySnapshot prosody,
  }) {
    if (text.trim().isEmpty) return const [];
    final count = _tokenCount(text);
    final shaped = _planLine(
      text: text,
      baseIndex: baseIndex,
      measured: _tokensForLine(
        prosody: prosody,
        from: baseIndex,
        count: count,
      ),
      prosody: prosody,
    ).$1;
    final motion = prosody.relativeLoudness < -0.2
        ? RealtimeKineticMotion.breathe
        : RealtimeKineticMotion.glide;
    final duration = prosody.speedDeviation > 0.35 ? 105 : 145;
    return [
      for (final segment in shaped)
        RealtimeKineticSegment(
          id: segment.id,
          text: segment.text,
          lifecycle: RealtimeWordLifecycle.provisional,
          motion: motion,
          intensity: RealtimeKineticIntensity.subtle,
          salience: (stability * 0.35).clamp(0.0, 0.35),
          role: RealtimeEmphasisRole.calm,
          verticalBias: segment.verticalBias * 0.6,
          fontScale: segment.fontScale,
          weightAxis: segment.weightAxis,
          letterSpacing: segment.letterSpacing,
          horizontalBias: 0,
          // Held below the accent band: a word still being revised should
          // never claim the strongest colour on screen.
          emphasis: (segment.emphasis * 0.5).clamp(0.0, 0.6),
          toneTilt: segment.toneTilt,
          restingOpacity: 1,
          durationMs: duration,
          sequenceIndex: segment.sequenceIndex,
        ),
    ];
  }

  /// Where the settled part of the display text ends.
  ///
  /// Everything the recogniser has finalised is settled, plus any interim text
  /// older than the last couple of words.
  int _settledEnd({required String display, required String committed}) {
    var start = 0;
    if (committed.isNotEmpty && display.startsWith(committed)) {
      start = committed.length;
    } else {
      final maximum = math.min(display.length, committed.length);
      while (start < maximum && display[start] == committed[start]) {
        start++;
      }
    }
    final tail = RegExp(
      r'\S+\s*',
    ).allMatches(display.substring(start)).toList();
    if (tail.length <= _maxProvisionalTokens) return start;
    return start + tail[tail.length - _maxProvisionalTokens].start;
  }

  String _bare(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[\s,.!?…。！？~～]'), '');
  int _tokenCount(String value) => RegExp(r'\S+').allMatches(value).length;
  int _bucket(double value) => (value * 8).round();
}

class _RawLiveSegment {
  const _RawLiveSegment({
    required this.id,
    required this.text,
    required this.token,
    required this.salience,
    required this.repeated,
    required this.drawnOut,
    required this.hasEllipsis,
    required this.phraseEnding,
    required this.sequenceIndex,
  });

  final String id;
  final String text;
  final TokenProsody token;
  final double salience;
  final bool repeated;
  final bool drawnOut;
  final bool hasEllipsis;
  final bool phraseEnding;
  final int sequenceIndex;
}
