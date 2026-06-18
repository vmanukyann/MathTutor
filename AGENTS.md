# MathTutor Agent Guide

## Project Summary
MathTutor is an iPad-first SwiftUI research prototype for an AI math tutor. The iPad observes handwritten math on paper with the camera, the teacher controls the app hands-free by voice, and the main Teach Board path is shifting to AirPlay/external display.

## Key Paths
- Main app: `MathTutorSwift/iPadApp/MathTutor/MathTutor.xcodeproj`
- Core Swift package: `MathTutorSwift/`

## Product Direction
- iPad observes paper.
- Voice controls the app.
- AirPlay/external display shows a math-only Teach Board.
- The motorized holder remains optional experimental mode.

## Backend And Secrets
- Backend is already configured and verified. Do not change backend setup.
- Supabase project ref: `zydgcutdgkgjvstzrafo`
- Edge Function: `https://zydgcutdgkgjvstzrafo.supabase.co/functions/v1/tutor`
- Confirmed tables: `teacher_students`, `teacher_sessions`, `teacher_events`
- Supabase secrets are already set: `OPENAI_API_KEY`, `OPENAI_OBSERVE_MODEL=gpt-4o-mini`, and the Supabase-managed `SUPABASE_SERVICE_ROLE_KEY`.
- `AppSecrets.swift` should contain only the Supabase URL and anon key.
- Never commit service role keys, OpenAI keys, local env files, or generated secret dumps.

## UI Rules
- Use a flat STEM notebook style.
- No gradients, glassmorphism, decorative animations, or heavy marketing copy.
- Keep text minimal and controls icon-first.
- Teach Mode and external board views must stay math-only.

## Verification
```sh
cd MathTutorSwift && swift run MathTutorCoreChecks
```

```sh
cd /Users/vmanukya/Documents/GitHub/MathTutor
xcodebuild -project MathTutorSwift/iPadApp/MathTutor/MathTutor.xcodeproj -scheme MathTutor -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

## Definition Of Done
- Builds pass.
- Backend and secrets are untouched.
- Voice control still works.
- Holder experimental mode is preserved.
- README is updated only when behavior changes.
