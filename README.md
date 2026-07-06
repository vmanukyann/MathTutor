# MathTutor

MathTutor is an iPad app that observes handwritten math work, provides short
spoken hints, and can show steps on a second display.

## Project layout

- `MathTutorSwift/` — SwiftUI app and shared models
- `supabase/functions/tutor/` — tutoring requests and session logging
- `supabase/functions/tts-elevenlabs/` — ElevenLabs TTS proxy
- `tools/gepa/` — prompt optimization tools

## Backend configuration

Configure the tutoring function:

```sh
supabase secrets set OPENAI_API_KEY=...
supabase secrets set OPENAI_OBSERVE_MODEL=gpt-5.4
supabase functions deploy tutor
```

Configure text-to-speech:

```sh
supabase secrets set ELEVENLABS_API_KEY=...
supabase secrets set ELEVENLABS_VOICE_ID=...
supabase secrets set ELEVENLABS_MODEL_ID=eleven_flash_v2_5
supabase functions deploy tts-elevenlabs
```

The ElevenLabs API key is read only by the Supabase Edge Function. Do not add
it to Swift source or `AppSecrets.swift`.

The TTS function accepts `text` and optional `voice_id`, `model_id`, and
`voice_settings` fields. Swift receives a complete MP3 response and plays it
with `AVAudioPlayer`.

## Run the app

Open:

```text
MathTutorSwift/iPadApp/MathTutor/MathTutor.xcodeproj
```

Select an iPad simulator or connected iPad and run the `MathTutor` scheme.

To test the ElevenLabs path in a Debug build, add this launch argument:

```text
--run-elevenlabs-tts-diagnostic
```

## Verification

Run core checks:

```sh
cd MathTutorSwift
swift run MathTutorCoreChecks
```

Build the iPad app:

```sh
xcodebuild -project MathTutorSwift/iPadApp/MathTutor/MathTutor.xcodeproj \
  -scheme MathTutor \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

Check Supabase functions:

```sh
npx -y deno fmt --check supabase/functions
npx -y deno check --config supabase/functions/tutor/deno.json \
  supabase/functions/tutor/index.ts
npx -y deno check --config supabase/functions/tts-elevenlabs/deno.json \
  supabase/functions/tts-elevenlabs/index.ts
npx -y deno test --config supabase/functions/tutor/deno.json \
  supabase/functions/tutor/hint_utils_test.ts
```
