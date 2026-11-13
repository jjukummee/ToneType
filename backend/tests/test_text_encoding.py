from app.services.speech.text_encoding import restore_utf8_byte_markers


def test_restores_korean_utf8_marker_runs() -> None:
    source = "조금 <0xEC><0xB0><0x9D><0xEC><0xB0><0x9D>한데요."
    assert restore_utf8_byte_markers(source) == "조금 찝찝한데요."


def test_preserves_invalid_and_ascii_only_marker_runs() -> None:
    assert restore_utf8_byte_markers("<0xEC><0x20>") == "<0xEC><0x20>"
    assert restore_utf8_byte_markers("<0x41><0x42>") == "<0x41><0x42>"
