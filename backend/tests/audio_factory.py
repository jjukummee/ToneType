from io import BytesIO
import wave

import numpy as np


def sine_wav(
    *,
    frequency: float = 180.0,
    duration: float = 1.0,
    amplitude: float = 0.25,
    sample_rate: int = 16_000,
) -> bytes:
    times = np.arange(round(duration * sample_rate)) / sample_rate
    envelope = np.minimum(1.0, np.minimum(times * 40, (duration - times) * 40))
    samples = amplitude * envelope * np.sin(2 * np.pi * frequency * times)
    pcm = (np.clip(samples, -1, 1) * 32767).astype("<i2")
    output = BytesIO()
    with wave.open(output, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        wav.writeframes(pcm.tobytes())
    return output.getvalue()

