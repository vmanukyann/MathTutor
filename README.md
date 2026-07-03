# MathTutor

MathTutor is an iPad app that watches handwritten math work and gives short hints
without giving away the answer. It can also show steps on a second display.

## Project layout

- `MathTutorSwift/` — SwiftUI app and shared models
- `supabase/functions/tutor/` — OpenAI requests and session logging
- `tools/gepa/` — prompt optimization examples and script
- `tools/voice/` — custom voice setup (requires OpenAI account access)

## Run the checks

```sh
cd MathTutorSwift
swift run MathTutorCoreChecks
```

Open `MathTutorSwift/iPadApp/MathTutor/MathTutor.xcodeproj` to run the iPad app.

The Supabase and OpenAI keys are not stored in the repository.

