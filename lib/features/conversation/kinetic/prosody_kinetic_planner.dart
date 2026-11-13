import '../models/kinetic_segment.dart';
import '../models/prosody_result.dart';
import 'basic/basic_kinetic_planner.dart';
import 'kinetic_planner.dart';

/// Backward-compatible façade for callers that only need segment tokens.
class ProsodyKineticPlanner {
  const ProsodyKineticPlanner({this.planner = const BasicKineticPlanner()});

  final BasicKineticPlanner planner;

  KineticPlan buildPlan({
    required String displayText,
    required ProsodyAnalysisResult prosody,
    bool debug = false,
  }) => planner.plan(
    KineticPlannerInput(
      displayText: displayText,
      prosody: prosody,
      debug: debug,
    ),
  );

  List<KineticSegment> plan({
    required String displayText,
    required ProsodyAnalysisResult prosody,
  }) => buildPlan(displayText: displayText, prosody: prosody).segments;
}
