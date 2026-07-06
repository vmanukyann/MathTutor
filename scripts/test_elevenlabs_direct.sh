#!/bin/sh
set -eu

now_ms() {
  python3 -c 'import time; print(time.time_ns() // 1_000_000)'
}

if [ -z "${ELEVENLABS_API_KEY:-}" ]; then
  echo "Missing required environment variable: ELEVENLABS_API_KEY" >&2
  exit 2
fi
if [ -z "${ELEVENLABS_VOICE_ID:-}" ]; then
  echo "Missing required environment variable: ELEVENLABS_VOICE_ID" >&2
  exit 2
fi

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
ELEVENLABS_MODEL_ID=${ELEVENLABS_MODEL_ID:-eleven_flash_v2_5}
OUTPUT=${ELEVENLABS_DIRECT_OUTPUT:-$ROOT/tmp/elevenlabs_direct_test.mp3}
BODY=$(mktemp)
HEADERS=$(mktemp)
trap 'rm -f "$BODY" "$HEADERS"' EXIT
mkdir -p "$(dirname "$OUTPUT")"

PAYLOAD=$(ELEVENLABS_MODEL_ID="$ELEVENLABS_MODEL_ID" python3 - <<'PY'
import json
import os

print(json.dumps({
    "text": "Sixteen, seventeen, eighteen, nineteen, twenty. Now divide both sides by sixteen.",
    "model_id": os.environ["ELEVENLABS_MODEL_ID"],
}))
PY
)

START_MS=$(now_ms)
STATUS=$(curl --silent --show-error \
  --output "$BODY" \
  --dump-header "$HEADERS" \
  --write-out '%{http_code}' \
  --request POST \
  "https://api.elevenlabs.io/v1/text-to-speech/${ELEVENLABS_VOICE_ID}?output_format=mp3_44100_128" \
  --header 'Content-Type: application/json' \
  --header "xi-api-key: ${ELEVENLABS_API_KEY}" \
  --data "$PAYLOAD")
END_MS=$(now_ms)

if [ "$STATUS" -lt 200 ] || [ "$STATUS" -ge 300 ]; then
  echo "Direct ElevenLabs request failed with HTTP $STATUS." >&2
  sed -n '1,20p' "$BODY" >&2
  exit 1
fi

CONTENT_TYPE=$(awk 'BEGIN { IGNORECASE=1 } /^content-type:/ {
  sub(/\r$/, "", $0)
  sub(/^[^:]+:[[:space:]]*/, "", $0)
  print
}' "$HEADERS" | tail -n 1)
case "$CONTENT_TYPE" in
  audio/*) ;;
  *)
    echo "Expected audio response, received Content-Type: ${CONTENT_TYPE:-unknown}" >&2
    exit 1
    ;;
esac

mv "$BODY" "$OUTPUT"
BYTES=$(wc -c < "$OUTPUT" | tr -d ' ')

echo "Direct ElevenLabs smoke test passed."
echo "Model: $ELEVENLABS_MODEL_ID"
echo "Total request time: $((END_MS - START_MS)) ms"
echo "File size: $BYTES bytes"
echo "Output: $OUTPUT"
file "$OUTPUT"
