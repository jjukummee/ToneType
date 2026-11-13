import logging
from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from starlette.middleware.trustedhost import TrustedHostMiddleware

from app.api.routes.conversation import router as conversation_router
from app.api.routes.prosody import router as prosody_router
from app.core.errors import ProsodyError
from app.core.logging import configure_logging
from app.core.google_speech_config import GoogleSpeechConfig
from app.core.runtime_config import RuntimeConfig

configure_logging()
logger = logging.getLogger(__name__)

runtime = RuntimeConfig.from_environment()
app = FastAPI(
    title="ToneType Prosody API",
    version=runtime.version,
    docs_url="/docs" if runtime.docs_enabled else None,
    redoc_url="/redoc" if runtime.docs_enabled else None,
    openapi_url="/openapi.json" if runtime.docs_enabled else None,
)
app.add_middleware(TrustedHostMiddleware, allowed_hosts=list(runtime.allowed_hosts))
app.include_router(prosody_router)
app.include_router(conversation_router)


@app.middleware("http")
async def add_operational_headers(request: Request, call_next):
    request_id = request.headers.get("x-request-id") or uuid4().hex
    response = await call_next(request)
    response.headers["x-request-id"] = request_id
    response.headers["x-content-type-options"] = "nosniff"
    response.headers["cache-control"] = "no-store"
    return response


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/ready")
def ready() -> JSONResponse:
    try:
        GoogleSpeechConfig.from_environment()
    except ValueError:
        return JSONResponse(
            status_code=503,
            content={"status": "not_ready", "reason": "speech_configuration"},
        )
    return JSONResponse(content={"status": "ready"})


@app.exception_handler(ProsodyError)
async def prosody_error_handler(
    _request: Request, error: ProsodyError
) -> JSONResponse:
    logger.warning(
        "prosody_analysis_failed",
        extra={"error_type": error.code},
    )
    return JSONResponse(
        status_code=error.status_code,
        content={"error": {"code": error.code, "message": error.message}},
    )
