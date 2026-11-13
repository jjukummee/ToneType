# ToneType

ToneType is an iOS-first Flutter application that transcribes speech and maps
measured volume, pitch, speed, pauses, and emphasis to kinetic typography.

The translation screen offers two generation paths: deterministic `Basic`
kinetics from measured audio and `AI Hybrid` kinetics where Google Vertex AI
Gemini adds semantic direction. Hybrid requests automatically fall back to the
basic planner if the AI service is unavailable.

## Current product scope

- Korean-to-Korean is the default and fully connected speech-analysis path.
- Audio is recorded on device and uploaded to the configured ToneType API.
- The microphone supports both stop-then-analyze and live streaming modes. Live
  mode renders interim text immediately and completes prosody when stopped.
- Google Speech-to-Text V2 provides transcripts and word timestamps.
- The FastAPI service computes prosody without persisting uploaded audio.
- Completed analyses and direct text entries are stored locally as searchable
  conversation history.
- Personal terms and accessibility preferences are stored on device.
- Personal dictionary terms are supplied as recognition hints in live mode;
  Korean results also pass through a conservative on-device spelling and
  spacing normalizer.
- Anonymous local use is supported. Account and social sign-in controls never
  create synthetic accounts; connect a real identity provider before enabling
  account sync.
- Cross-language translation is intentionally unavailable until a translation
  provider is configured.

## Configuration

Debug builds default to `http://127.0.0.1:8000`. Release builds require an
absolute HTTPS API URL:

```sh
flutter run --dart-define=TONETYPE_API_URL=http://127.0.0.1:8000

flutter build ios --release \
  --dart-define=TONETYPE_API_URL=https://api.example.com
```

For a temporary LAN-only release build, explicitly opt in to insecure HTTP:

```sh
flutter build ios --release \
  --dart-define=TONETYPE_API_URL=http://192.168.0.10:8000 \
  --dart-define=ALLOW_INSECURE_API=true
```

Optional support contact:

```sh
--dart-define=SUPPORT_EMAIL=support@example.com
```

## Verify

```sh
flutter pub get
flutter analyze
flutter test
flutter build ios --simulator
```

See [backend/README.md](backend/README.md) for local API setup, required Google
Speech configuration, container deployment, and endpoint contracts.

For iOS builds on a physical device, select your own Apple development team
in Xcode. Pretendard is included under the [SIL Open Font License](assets/fonts/Pretendard-OFL.txt).
