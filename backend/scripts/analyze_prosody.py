#!/usr/bin/env python3
import argparse
import json
from pathlib import Path

from app.services.prosody import ProsodyAnalyzer


def main() -> None:
    parser = argparse.ArgumentParser(description="Analyze a local audio file.")
    parser.add_argument("audio", type=Path)
    parser.add_argument("--language", default="ko-KR")
    parser.add_argument("--debug", action="store_true")
    args = parser.parse_args()

    result = ProsodyAnalyzer().analyze(
        args.audio.read_bytes(),
        filename=args.audio.name,
        language=args.language,
        debug=args.debug,
    )
    print(json.dumps(result.model_dump(exclude_none=True), indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()

