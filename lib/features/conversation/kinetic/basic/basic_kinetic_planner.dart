import '../../models/kinetic_segment.dart';
import '../kinetic_planner.dart';
import 'constraint_engine.dart';
import 'kinetic_motif_selector.dart';
import 'layout_resolver.dart';
import 'linguistic_analyzer.dart';
import 'motion_resolver.dart';
import 'phrase_segmenter.dart';
import 'prosody_normalizer.dart';
import 'salience_scorer.dart';
import 'timing_scheduler.dart';
import 'tone_pattern_classifier.dart';

class BasicKineticPlanner implements KineticPlanner {
  const BasicKineticPlanner({
    this.segmenter = const PhraseSegmenter(),
    this.normalizer = const BasicProsodyNormalizer(),
    this.linguisticAnalyzer = const KoreanLinguisticAnalyzer(),
    this.salienceScorer = const SalienceScorer(),
    this.patternClassifier = const TonePatternClassifier(),
    this.motifSelector = const KineticMotifSelector(),
    this.motionResolver = const MotionResolver(),
    this.constraintEngine = const KineticConstraintEngine(),
    this.layoutResolver = const KineticLayoutResolver(),
    this.timingScheduler = const KineticTimingScheduler(),
  });

  final PhraseSegmenter segmenter;
  final BasicProsodyNormalizer normalizer;
  final KoreanLinguisticAnalyzer linguisticAnalyzer;
  final SalienceScorer salienceScorer;
  final TonePatternClassifier patternClassifier;
  final KineticMotifSelector motifSelector;
  final MotionResolver motionResolver;
  final KineticConstraintEngine constraintEngine;
  final KineticLayoutResolver layoutResolver;
  final KineticTimingScheduler timingScheduler;

  @override
  KineticPlan plan(KineticPlannerInput input) {
    if (input.displayText.isEmpty) {
      return const KineticPlan(
        mode: KineticGenerationMode.basic,
        pattern: KineticPattern.neutral,
        layout: KineticLayout.inline,
        segments: [],
      );
    }
    final phrases = segmenter.segment(
      transcript: input.displayText,
      prosody: input.prosody,
    );
    final normalized = normalizer.normalize(input.prosody);
    final linguistic = linguisticAnalyzer.analyze(phrases);
    final salience = salienceScorer.score(
      phrases: phrases,
      linguistic: linguistic,
      normalized: normalized,
    );
    final classification = patternClassifier.classify(
      transcript: input.displayText,
      prosody: input.prosody,
      phrases: salience,
    );
    final motif = motifSelector.select(classification.pattern);
    final resolved = motionResolver.resolve(
      phrases: salience,
      pattern: classification.pattern,
      motif: motif,
      prosody: input.prosody,
      debug: input.debug,
    );
    final constrained = constraintEngine.apply(resolved);
    final layout = layoutResolver.resolve(
      pattern: classification.pattern,
      segments: constrained,
    );
    final scheduled = timingScheduler.schedule(
      segments: constrained,
      phrases: salience,
      prosody: input.prosody,
    );
    final plan = KineticPlan(
      mode: KineticGenerationMode.basic,
      pattern: classification.pattern,
      layout: layout,
      segments: scheduled,
    );
    return plan.transcript == input.displayText
        ? plan
        : KineticPlan.neutral(input.displayText);
  }
}
