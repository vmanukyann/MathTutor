#!/usr/bin/env python3
"""Provision one repository-wide OpenAI custom voice."""

import os
import subprocess
import wave
from pathlib import Path

import httpx
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[2]
VOICE_FILE = ROOT / "voice.wav"
CONSENT_FILE = ROOT / "consent.wav"
PROJECT_REF = "zydgcutdgkgjvstzrafo"
CONSENT_PHRASE = (
    "I am the owner of this voice and I consent to OpenAI using this voice "
    "to create a synthetic voice model."
)


def validate_audio_file(path: Path) -> bytes:
    if not path.exists():
        raise SystemExit(f"Missing {path}")
    if path.stat().st_size > 10 * 1024 * 1024:
        raise SystemExit(f"{path.name} exceeds OpenAI's 10 MiB limit.")
    try:
        with wave.open(str(path), "rb") as recording:
            duration = recording.getnframes() / recording.getframerate()
    except (wave.Error, ZeroDivisionError) as error:
        raise SystemExit(f"{path.name} is not a readable WAV file: {error}") from error
    if duration > 30.0:
        raise SystemExit(f"{path.name} is {duration:.1f}s; the maximum is 30 seconds.")
    return path.read_bytes()


def main() -> None:
    load_dotenv(ROOT / ".env")
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise SystemExit("OPENAI_API_KEY is missing from the repository .env")
    consent_audio = validate_audio_file(CONSENT_FILE)
    voice_audio = validate_audio_file(VOICE_FILE)
    headers = {"Authorization": f"Bearer {api_key}"}

    print("Uploading recorded consent…")
    with httpx.Client(timeout=90) as client:
        consent_response = client.post(
            "https://api.openai.com/v1/audio/voice_consents",
            headers=headers,
            data={"name": "MathTutor owner consent", "language": "en"},
            files={"recording": ("consent.wav", consent_audio, "audio/wav")},
        )
        if not consent_response.is_success:
            raise SystemExit(
                "Consent upload failed. consent.wav must contain exactly this phrase:\n"
                f'"{CONSENT_PHRASE}"\n\n{consent_response.text}'
            )
        consent_id = consent_response.json()["id"]

        print("Creating the MathTutor voice…")
        voice_response = client.post(
            "https://api.openai.com/v1/audio/voices",
            headers=headers,
            data={"name": "MathTutor Voice", "consent": consent_id},
            files={"audio_sample": ("voice.wav", voice_audio, "audio/wav")},
        )
        if not voice_response.is_success:
            raise SystemExit(f"Voice creation failed:\n{voice_response.text}")
        voice_id = voice_response.json()["id"]

    print("Saving the app-wide voice ID in Supabase…")
    subprocess.run(
        [
            "supabase",
            "secrets",
            "set",
            f"OPENAI_TTS_VOICE={voice_id}",
            "--project-ref",
            PROJECT_REF,
        ],
        cwd=ROOT,
        check=True,
    )
    print("MathTutor will now use this voice for every tutor response.")


if __name__ == "__main__":
    main()
