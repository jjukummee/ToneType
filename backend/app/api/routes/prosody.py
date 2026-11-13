import json

from fastapi import APIRouter, File, Form, Query, UploadFile
from pydantic import TypeAdapter, ValidationError
from starlette.concurrency import run_in_threadpool

from app.core.config import DEFAULT_CONFIG
from app.core.errors import ProsodyError
from app.schemas.prosody import ErrorResponse, ProsodyResponse, WordTimestamp
from app.services.prosody import ProsodyAnalyzer
from app.services.prosody.feature_extractor import feature_extractor_from_environment

router = APIRouter(prefix="/api/prosody", tags=["prosody"])
analyzer = ProsodyAnalyzer(feature_extractor=feature_extractor_from_environment())
word_list_adapter = TypeAdapter(list[WordTimestamp])


@router.post(
    "/analyze",
    response_model=ProsodyResponse,
    responses={400: {"model": ErrorResponse}, 413: {"model": ErrorResponse}, 422: {"model": ErrorResponse}},
)
async def analyze_prosody(
    audio: UploadFile = File(...),
    language: str = Form(default="ko-KR", max_length=20),
    timestamps: str | None = Form(default=None),
    debug: bool = Query(default=False),
) -> ProsodyResponse:
    content = await audio.read(DEFAULT_CONFIG.max_upload_bytes + 1)
    await audio.close()
    words: list[WordTimestamp] = []
    if timestamps:
        try:
            words = word_list_adapter.validate_python(json.loads(timestamps))
        except (json.JSONDecodeError, ValidationError) as exc:
            raise ProsodyError(
                "invalid_timestamps",
                "timestamps must be a JSON array of text/start/end objects.",
                422,
            ) from exc

    return await run_in_threadpool(
        analyzer.analyze,
        content,
        filename=audio.filename,
        language=language,
        words=words,
        debug=debug,
    )
