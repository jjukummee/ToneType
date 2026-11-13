from google.cloud import speech_v2 as speech
from google.protobuf.duration_pb2 import Duration

from app.core.google_speech_config import GoogleSpeechConfig
from app.services.speech.google_cloud import GoogleCloudSpeechTranscriber


class FakeSpeechClient:
    def __init__(self) -> None:
        self.request: speech.RecognizeRequest | None = None

    def recognize(
        self, *, request: speech.RecognizeRequest, timeout: int
    ) -> speech.RecognizeResponse:
        assert timeout == 20
        self.request = request
        return speech.RecognizeResponse(
            results=[
                speech.SpeechRecognitionResult(
                    language_code="ko-KR",
                    alternatives=[
                        speech.SpeechRecognitionAlternative(
                            transcript="오늘이라고 했어.",
                            words=[
                                speech.WordInfo(
                                    word="오늘이라고",
                                    start_offset=Duration(seconds=0),
                                    end_offset=Duration(nanos=600_000_000),
                                ),
                                speech.WordInfo(
                                    word="했어",
                                    start_offset=Duration(nanos=650_000_000),
                                    end_offset=Duration(seconds=1),
                                ),
                            ],
                        )
                    ],
                )
            ]
        )


def test_google_transcriber_requests_word_offsets_and_maps_response() -> None:
    client = FakeSpeechClient()
    config = GoogleSpeechConfig(
        project_number="123456789",
        location="asia-southeast1",
        recognizer_id="test-recognizer",
        model="chirp_3",
    )
    transcriber = GoogleCloudSpeechTranscriber(config=config, client=client)

    result = transcriber.transcribe(b"wav bytes", language="ko_KR")

    assert result.text == "오늘이라고 했어."
    assert result.language == "ko-KR"
    assert result.words[0].end == 0.6
    assert result.words[1].start == 0.65
    assert client.request is not None
    assert client.request.recognizer == config.recognizer_resource
    assert client.request.config.model == "chirp_3"
    assert client.request.config.features.enable_word_time_offsets is True


def test_google_speech_config_parses_explicit_resource(monkeypatch) -> None:
    resource = (
        "projects/123456789/locations/asia-southeast1/"
        "recognizers/production-recognizer"
    )
    monkeypatch.setenv("GOOGLE_SPEECH_RECOGNIZER", resource)

    config = GoogleSpeechConfig.from_environment()

    assert config.recognizer_resource == resource
    assert config.api_endpoint == "asia-southeast1-speech.googleapis.com"
