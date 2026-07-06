#!/bin/sh
set -eu

now_ms() {
  python3 -c 'import time; print(time.time_ns() // 1_000_000)'
}

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
MODE=${SUPABASE_TTS_MODE:-deployed}
OUTPUT=${SUPABASE_TTS_OUTPUT:-$ROOT/tmp/elevenlabs_supabase_test.mp3}
ERROR_OUTPUT=${SUPABASE_TTS_ERROR_OUTPUT:-$ROOT/tmp/elevenlabs_supabase_error.txt}
DEFAULT_DEPLOYED_URL="https://zydgcutdgkgjvstzrafo.supabase.co/functions/v1/tts-elevenlabs"

case "$MODE" in
  local)
    BASE_URL=${SUPABASE_URL:-http://127.0.0.1:54321}
    FUNCTION_URL=${SUPABASE_TTS_URL:-${BASE_URL%/}/functions/v1/tts-elevenlabs}
    echo "Testing local Supabase function: $FUNCTION_URL"
    echo "The local function server must have ELEVENLABS_API_KEY and ELEVENLABS_VOICE_ID."
    ;;
  deployed)
    if [ -n "${SUPABASE_TTS_URL:-}" ]; then
      FUNCTION_URL=$SUPABASE_TTS_URL
    elif [ -n "${SUPABASE_URL:-}" ]; then
      FUNCTION_URL="${SUPABASE_URL%/}/functions/v1/tts-elevenlabs"
    else
      FUNCTION_URL=$DEFAULT_DEPLOYED_URL
    fi
    echo "Testing deployed Supabase function: $FUNCTION_URL"
    ;;
  *)
    echo "SUPABASE_TTS_MODE must be 'local' or 'deployed'." >&2
    exit 2
    ;;
esac

BODY=$(mktemp)
HEADERS=$(mktemp)
trap 'rm -f "$BODY" "$HEADERS"' EXIT
mkdir -p "$(dirname "$OUTPUT")"
rm -f "$OUTPUT" "$ERROR_OUTPUT"

PAYLOAD=$(python3 - <<'PY'
import json
import os

body = {
    "text": "Sixteen, seventeen, eighteen, nineteen, twenty. Now divide both sides by sixteen."
}
model_id = os.environ.get("ELEVENLABS_MODEL_ID", "").strip()
if model_id:
    body["model_id"] = model_id
print(json.dumps(body))
PY
)

START_MS=$(now_ms)
if [ -n "${SUPABASE_ANON_KEY:-}" ]; then
  echo "Auth: using SUPABASE_ANON_KEY headers."
  STATUS=$(curl --silent --show-error \
    --output "$BODY" \
    --dump-header "$HEADERS" \
    --write-out '%{http_code}' \
    --request POST \
    "$FUNCTION_URL" \
    --header 'Content-Type: application/json' \
    --header "apikey: ${SUPABASE_ANON_KEY}" \
    --header "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
    --data "$PAYLOAD")
else
  echo "Auth: no client key (function is configured with verify_jwt=false)."
  STATUS=$(curl --silent --show-error \
    --output "$BODY" \
    --dump-header "$HEADERS" \
    --write-out '%{http_code}' \
    --request POST \
    "$FUNCTION_URL" \
    --header 'Content-Type: application/json' \
    --data "$PAYLOAD")
fi
END_MS=$(now_ms)
ELAPSED_MS=$((END_MS - START_MS))

if [ "$STATUS" -lt 200 ] || [ "$STATUS" -ge 300 ]; then
  mv "$BODY" "$ERROR_OUTPUT"
  echo "Supabase TTS request failed." >&2
  echo "HTTP status: $STATUS" >&2
  echo "Total request time: $ELAPSED_MS ms" >&2
  echo "Error body: $ERROR_OUTPUT" >&2
  if { [ "$STATUS" -eq 401 ] || [ "$STATUS" -eq 403 ]; } &&
    [ -z "${SUPABASE_ANON_KEY:-}" ]; then
    echo "Set SUPABASE_ANON_KEY from:" >&2
    echo "Supabase Dashboard -> Project Settings -> API -> Project API keys -> anon public" >&2
    echo 'Then run: export SUPABASE_ANON_KEY="..."' >&2
  fi
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
    mv "$BODY" "$ERROR_OUTPUT"
    echo "Supabase TTS response was not audio." >&2
    echo "HTTP status: $STATUS" >&2
    echo "Content-Type: ${CONTENT_TYPE:-unknown}" >&2
    echo "Total request time: $ELAPSED_MS ms" >&2
    echo "Error body: $ERROR_OUTPUT" >&2
    exit 1
    ;;
esac

MODEL_ID=$(awk 'BEGIN { IGNORECASE=1 } /^x-tts-model-id:/ {
  sub(/\r$/, "", $0)
  sub(/^[^:]+:[[:space:]]*/, "", $0)
  print
}' "$HEADERS" | tail -n 1)
mv "$BODY" "$OUTPUT"
BYTES=$(wc -c < "$OUTPUT" | tr -d ' ')

echo "Supabase ElevenLabs smoke test passed."
echo "Model: ${MODEL_ID:-not reported by deployed function}"
echo "HTTP status: $STATUS"
echo "Total request time: $ELAPSED_MS ms"
echo "File size: $BYTES bytes"
echo "Output: $OUTPUT"
file "$OUTPUT"
