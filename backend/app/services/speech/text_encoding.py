import re

_MARKER_RUN = re.compile(r"(?:<0x[0-9A-Fa-f]{2}>){2,}", re.IGNORECASE)
_MARKER = re.compile(r"<0x([0-9A-Fa-f]{2})>", re.IGNORECASE)


def restore_utf8_byte_markers(text: str) -> str:
    """Restore valid non-ASCII UTF-8 sequences exposed as debug markers."""

    if "<0x" not in text and "<0X" not in text:
        return text

    def replace(match: re.Match[str]) -> str:
        source = match.group(0)
        values = bytes(int(item, 16) for item in _MARKER.findall(source))
        if not any(value >= 0x80 for value in values):
            return source
        try:
            restored = values.decode("utf-8")
        except UnicodeDecodeError:
            return source
        if any(
            ord(character) < 0x20 and character not in "\t\n\r"
            for character in restored
        ):
            return source
        return restored

    return _MARKER_RUN.sub(replace, text)
