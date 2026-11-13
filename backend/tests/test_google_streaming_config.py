from app.core.google_speech_config import GoogleSpeechConfig
from app.services.speech.google_streaming import (
    GoogleCloudSpeechStreamingTranscriber,
)


class StubAsyncSpeechClient:
    pass


def _transcriber() -> GoogleCloudSpeechStreamingTranscriber:
    return GoogleCloudSpeechStreamingTranscriber(
        config=GoogleSpeechConfig(
            project_number="376848323636",
            location="asia-southeast1",
            recognizer_id="tonetype1",
        ),
        client=StubAsyncSpeechClient(),  # type: ignore[arg-type]
    )


def test_stream_config_enables_accuracy_features_without_network() -> None:
    request = _transcriber()._config_request(
        "ko-KR", "ko-KR", ("ToneType", "키네틱 타이포그래피")
    )
    config = request.streaming_config.config

    assert request.recognizer.endswith("/recognizers/tonetype1")
    assert config.explicit_decoding_config.sample_rate_hertz == 16_000
    assert config.explicit_decoding_config.audio_channel_count == 1
    assert config.features.enable_automatic_punctuation is True
    assert config.features.enable_word_time_offsets is True
    assert request.streaming_config.streaming_features.interim_results is True
    phrases = config.adaptation.phrase_sets[0].inline_phrase_set.phrases
    assert [phrase.value for phrase in phrases] == [
        "ToneType",
        "키네틱 타이포그래피",
    ]


def test_translation_is_only_enabled_for_different_languages() -> None:
    same = _transcriber()._config_request("ko-KR", "ko-KR", ())
    translated = _transcriber()._config_request("ko-KR", "en-US", ())

    assert not same.streaming_config.config.translation_config.target_language
    assert translated.streaming_config.config.translation_config.target_language == "en-US"
