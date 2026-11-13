import 'package:flutter_test/flutter_test.dart';
import 'package:tonetype/features/conversation/models/conversation_state.dart';
import 'package:tonetype/features/conversation/models/prosody_result.dart';
import 'package:tonetype/features/conversation/models/speech_capture_mode.dart';

void main() {
  const prosody = ProsodyAnalysisResult(
    utterance: ProsodyUtterance(
      volume: 0.68,
      pitch: 0.55,
      speed: 0.61,
      energy: 0.7,
      pause: 0.28,
      intonation: ProsodyIntonation.flat,
    ),
    segments: [
      ProsodySegmentResult(
        text: '오늘은',
        start: 0,
        end: 0.3,
        duration: 0.3,
        relativeLoudness: 0.45,
        relativePitch: 0.82,
        pauseAfter: 0.03,
        emphasis: 0.3,
      ),
      ProsodySegmentResult(
        text: '꼭',
        start: 0.33,
        end: 0.58,
        duration: 0.25,
        relativeLoudness: 0.94,
        relativePitch: 0.72,
        pauseAfter: 0.04,
        emphasis: 0.95,
      ),
      ProsodySegmentResult(
        text: '가요',
        start: 0.62,
        end: 0.92,
        duration: 0.3,
        relativeLoudness: 0.5,
        relativePitch: 0.25,
        pauseAfter: 0.48,
        emphasis: 0.38,
      ),
      ProsodySegmentResult(
        text: '내일',
        start: 1.4,
        end: 1.68,
        duration: 0.28,
        relativeLoudness: 0.38,
        relativePitch: 0.2,
        pauseAfter: 0.03,
        emphasis: 0.24,
      ),
      ProsodySegmentResult(
        text: '다시',
        start: 1.71,
        end: 2.02,
        duration: 0.31,
        relativeLoudness: 0.56,
        relativePitch: 0.48,
        pauseAfter: 0.03,
        emphasis: 0.52,
      ),
      ProsodySegmentResult(
        text: '말해요',
        start: 2.05,
        end: 2.42,
        duration: 0.37,
        relativeLoudness: 0.72,
        relativePitch: 0.84,
        pauseAfter: 0,
        emphasis: 0.76,
      ),
    ],
  );

  test('live analysis groups acoustic evidence by sentence', () {
    final tone = ConversationToneSummary.fromProsody(
      prosody,
      transcript: '오늘은 꼭 가요. 내일 다시 말해요?',
      captureMode: SpeechCaptureMode.live,
    );

    expect(tone.analysisMode, ToneAnalysisMode.sentenceFocused);
    expect(tone.sentenceInsights, hasLength(2));
    expect(tone.sentenceInsights.first.text, '오늘은 꼭 가요.');
    expect(tone.sentenceInsights.first.peakWord, '꼭');
    expect(tone.sentenceInsights.first.intonation, ProsodyIntonation.falling);
    expect(tone.sentenceInsights.last.intonation, ProsodyIntonation.rising);
    expect(tone.sentenceInsights.last.coreSummary, contains('말해요'));
  });

  test('single analysis preserves detailed evidence for every word', () {
    final tone = ConversationToneSummary.fromProsody(
      prosody,
      transcript: '오늘은 꼭 가요. 내일 다시 말해요?',
    );

    expect(tone.analysisMode, ToneAnalysisMode.wordFocused);
    expect(tone.wordInsights, hasLength(6));
    expect(tone.wordInsights[1].text, '꼭');
    expect(tone.wordInsights[1].emphasis, 0.95);
    expect(tone.wordInsights[1].duration, closeTo(0.25, 0.001));
    expect(tone.deliverySummary, contains('“꼭”'));

    final restored = ConversationToneSummary.fromJson(tone.toJson());
    expect(restored.wordInsights, hasLength(6));
    expect(restored.sentenceInsights, hasLength(2));
    expect(restored.analysisMode, ToneAnalysisMode.wordFocused);
  });
}
