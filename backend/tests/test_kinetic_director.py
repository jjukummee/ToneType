from app.schemas.kinetic import GeminiKineticDirective
from app.schemas.prosody import ProsodyResponse, SegmentProsody, UtteranceProsody
from app.services.kinetic.google_gemini import _compose_segments


def test_hybrid_plan_preserves_transcript_and_measured_emphasis() -> None:
    prosody = ProsodyResponse(
        utterance=UtteranceProsody(
            volume=0.7,
            pitch=0.5,
            speed=0.4,
            energy=0.7,
            pause=0.1,
            intonation="falling",
        ),
        segments=[
            SegmentProsody(
                text="오늘은",
                start=0,
                end=0.4,
                duration=0.4,
                relative_loudness=0.5,
                relative_pitch=0.5,
                pause_after=0,
                emphasis=0.2,
            ),
            SegmentProsody(
                text="중요해요.",
                start=0.45,
                end=1,
                duration=0.55,
                relative_loudness=1,
                relative_pitch=0.8,
                pause_after=0,
                emphasis=0.9,
            ),
        ],
    )
    directives = {
        0: GeminiKineticDirective(
            word_index=0,
            motion="soft",
            intensity="medium",
        ),
        1: GeminiKineticDirective(
            word_index=1,
            motion="whisper",
            intensity="subtle",
        ),
    }

    segments = _compose_segments("오늘은 중요해요.", prosody, directives)

    assert "".join(segment.text for segment in segments) == "오늘은 중요해요."
    assert segments[0].motion == "soft"
    assert segments[0].intensity == "medium"
    assert segments[-1].motion == "impact"
    assert segments[-1].intensity == "strong"
