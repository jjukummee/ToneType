# ToneType Prosody API

FastAPI service for Google Speech-to-Text V2 transcription and CPU-based
prosody analysis. Uploaded audio is validated before the billable STT call and
is processed in memory without application-level persistence.

## Local setup

```sh
python3.13 -m venv .venv
.venv/bin/pip install -e '.[dev,praat]'
gcloud auth application-default login
gcloud auth application-default set-quota-project YOUR_PROJECT_ID
```

Configure the recognizer through environment variables. Do not place service
account key files in source control or mobile app bundles.

```sh
export GOOGLE_CLOUD_PROJECT_NUMBER=YOUR_PROJECT_NUMBER
export GOOGLE_CLOUD_LOCATION=YOUR_RECOGNIZER_REGION
export GOOGLE_SPEECH_RECOGNIZER_ID=YOUR_RECOGNIZER_ID
export GOOGLE_GENAI_API_KEY=YOUR_SERVER_SIDE_GEMINI_API_KEY
export GOOGLE_GENAI_PROJECT=YOUR_GOOGLE_CLOUD_PROJECT_ID
export GOOGLE_GENAI_LOCATION=global
export GOOGLE_GENAI_MODEL=gemini-2.5-flash

.venv/bin/uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Alternatively set the complete resource name:

```sh
export GOOGLE_SPEECH_RECOGNIZER=projects/PROJECT_NUMBER/locations/REGION/recognizers/RECOGNIZER_ID
```

Requests with `kinetic_mode=hybrid` use Gemini. A server-side API key uses the
Gemini Developer API. If the key is omitted, the service uses Vertex AI; enable
`aiplatform.googleapis.com` and grant the ADC identity the Vertex AI User role.
If this configuration or the model call is unavailable, the endpoint still
returns the speech analysis with `kinetic_fallback=true`, allowing the app to
use its deterministic planner.

See [.env.example](.env.example) for production runtime settings.

## Endpoints

- `GET /health` — process liveness
- `GET /ready` — required speech configuration readiness
- `POST /api/conversations/analyze` — transcription, prosody, and optional
  hybrid kinetic direction
- `WS /api/conversations/stream` — 16 kHz mono PCM live transcription with
  interim/final messages and final prosody analysis
- `POST /api/prosody/analyze` — prosody analysis for supplied timestamps

The conversation endpoint currently accepts same-language source and target
codes. It returns a structured `translation_not_configured` error for
cross-language requests rather than fabricating a translation.

The streaming endpoint expects a JSON `start` message, binary PCM chunks no
larger than 15 KiB, and a JSON `stop` message. It enables Google automatic
punctuation, word timestamps, and optional inline phrase hints. Only the most
recent 90 seconds of PCM are retained in memory for the final prosody pass,
matching `AnalysisConfig.max_duration_seconds`. Speech before that window
still appears in the transcript but carries no measured prosody.

## Verify

```sh
.venv/bin/pytest
```

## Container

```sh
docker build -t tonetype-api .
docker run --rm -p 8080:8080 --env-file .env tonetype-api
```

For Google Cloud Run, attach a dedicated user-managed service account with the
minimum Speech-to-Text permissions. Prefer the attached service identity and
ADC; do not set `GOOGLE_APPLICATION_CREDENTIALS` or bake a JSON key into the
container.

Production deployments should use HTTPS, restricted hosts, request throttling
at the gateway, application authentication/App Check, centralized logs, and a
published privacy policy before public traffic is enabled.
