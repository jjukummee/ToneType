import '../models/kinetic_segment.dart';
import '../models/prosody_result.dart';

class KineticPlannerInput {
  const KineticPlannerInput({
    required this.displayText,
    required this.prosody,
    this.debug = false,
  });

  final String displayText;
  final ProsodyAnalysisResult prosody;
  final bool debug;
}

abstract interface class KineticPlanner {
  KineticPlan plan(KineticPlannerInput input);
}
