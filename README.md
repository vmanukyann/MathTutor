# MathTutor

MathTutor is an iPad app that watches handwritten math work and gives short hints
without giving away the answer. It can also show steps on a second display.

## Project layout

- `MathTutorSwift/` — SwiftUI app and shared models
- `supabase/functions/tutor/` — OpenAI requests and session logging
- `tools/gepa/` — prompt optimization examples and script
- Voice playback uses native Core ML Pocket TTS through FluidAudio. `voice.wav`
  is served from Supabase Storage.

The first launch downloads the speech model. Tutor speech waits until the
custom voice is ready.

## Run the checks

```sh
cd MathTutorSwift
swift run MathTutorCoreChecks
```

Open `MathTutorSwift/iPadApp/MathTutor/MathTutor.xcodeproj` to run the iPad app.

The Supabase and OpenAI keys are not stored in the repository.
