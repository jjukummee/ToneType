class BasicKineticConfig {
  const BasicKineticConfig({
    this.acousticWeight = 0.68,
    this.linguisticWeight = 0.32,
    this.loudnessWeight = 0.35,
    this.pitchDeviationWeight = 0.25,
    this.durationWeight = 0.20,
    this.energyWeight = 0.20,
    this.mediumSalience = 0.36,
    this.strongSalience = 0.62,
    this.dominantAcousticImpact = 0.62,
    this.phrasePauseBoundary = 0.22,
    this.meaningfulPause = 0.18,
    this.dominantWordEmphasis = 0.66,
    this.dominantWordEmphasisGap = 0.14,
    this.drawnOutDuration = 0.76,
    this.drawnOutDurationRatio = 1.6,
    this.maxPhraseWords = 3,
    this.minAnimationMs = 260,
    this.maxAnimationMs = 680,
    this.maxCompressedPauseMs = 420,
  });

  final double acousticWeight;
  final double linguisticWeight;
  final double loudnessWeight;
  final double pitchDeviationWeight;
  final double durationWeight;
  final double energyWeight;
  final double mediumSalience;
  final double strongSalience;
  final double dominantAcousticImpact;
  final double phrasePauseBoundary;
  final double meaningfulPause;
  final double dominantWordEmphasis;
  final double dominantWordEmphasisGap;
  final double drawnOutDuration;
  final double drawnOutDurationRatio;
  final int maxPhraseWords;
  final int minAnimationMs;
  final int maxAnimationMs;
  final int maxCompressedPauseMs;
}
