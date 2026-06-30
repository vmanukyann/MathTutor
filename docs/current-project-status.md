# MathTutor Current Project Status

Status date: 2026-06-26  
Branch checked: `JuneVersion`  
Latest commit observed: `69f7f00 2026-06-22T13:30:35-04:00 Live Session Fixed`

## Executive Summary

MathTutor is currently set up as a native iPadOS SwiftUI app backed by Supabase Edge Functions. The student-facing app launches, the main student flow is reachable in the iPad simulator, the Live Session screen can trigger an observe/check request, and the backend returned a valid guided hint during simulator testing.

The most important finding from this diagnostic pass is that the app did successfully analyze a simulated paper frame and display a hint:

> What do you get when you multiply 3 by both terms inside the parentheses?

That means the current solve/analyze path is not completely broken. If the app is not solving on the real iPad, the most likely remaining causes are real-device camera capture, camera permissions, handwritten-paper framing/quality, expecting automatic solving without tapping the check/viewfinder control, or expecting a final answer when the app is intentionally designed to return guided hints.

No Supabase secrets, migrations, database resets, or `AppSecrets.swift` were changed. The tutor Edge Function now has backward-compatible support for optional `teach_steps` so Teach Mode and external displays can use math steps returned by the observation response. The `tutor` function was deployed to project `zydgcutdgkgjvstzrafo` with `npx supabase functions deploy tutor`.

## Current App Shape

The app is iPad-first and organized around a teacher-like tutoring loop:

1. Choose a student.
2. Confirm consent/study mode.
3. Enter a Live Tutor Session.
4. Aim the iPad camera at the student's paper.
5. Trigger a check from the Live Session scan surface.
6. Receive a short tutor hint, not a final answer.
7. End the session and review a reflection summary.
8. Use Admin Review for professor/mentor review.

The current UI follows the flat STEM notebook direction: muted paper tones, sparse controls, camera-first scan screen, math-only Teach Mode, and minimal prose in student-facing moments.

## Major Systems Status

| System | Current status | Notes |
| --- | --- | --- |
| iPad app shell | Working in simulator | App built, installed, and launched on an iPad Air 11-inch simulator. |
| Student Picker | Working | Existing students are shown; creating a simulator-local student worked. |
| Consent / Study Mode | Working | Study logging and no-answer mode toggles are present before a session begins. |
| Live scan screen | Working in simulator | The screen opens, shows the scan frame, accepts a check trigger, and displays returned hints. |
| Camera capture | Implemented | Uses `AVFoundation` on device; simulator has a fallback fake paper frame. Real iPad camera behavior still needs physical testing. |
| Supabase observe call | Working in simulator smoke test | The app received a hint through the Supabase/OpenAI path. |
| OpenAI reasoning | Working by inference | The returned hint matches the backend's OpenAI observation flow. Supabase logs were not directly inspected in this pass. |
| Voice tutor | Implemented but not fully verified here | Simulator reported microphone input unavailable. Real iPad speech/microphone needs device testing. |
| Teach Mode | Working | Math-only fallback display is reachable from the Live Session screen. |
| Reflection | Working | Ending a session produced the Reflection screen with session counts. |
| Admin Review | Working visually | Admin notebook/research view is reachable. |
| Holder controls | Experimental/reachable | Holder/voice debug sheet is reachable; simulator mode is visible. |
| External display / AirPlay | Implemented, not physically verified | Simulator preview is reachable. Real AirPlay/HDMI still needs a physical display test. |
| Session logging | Implemented | `AppModel.finishSession` calls `tutorClient.logSession(session)` asynchronously. Failures are currently swallowed with `try?`, so remote logging failure may not be obvious in the UI. |

## Current Solve/Analyze Failure Investigation

This section answers the most likely debugging questions directly.

### Does the app capture a camera frame?

Yes by code. `LiveTutorSessionView.checkWork()` calls:

```swift
let imageData = try await camera.captureFrame()
```

`CameraObservationService.captureFrame()` uses `AVCapturePhotoOutput` on a real device. In the simulator, it returns a generated paper-frame image if no camera output exists. That simulator fallback is why the app can be tested without an iPad camera.

Real iPad status: still needs a physical test with the actual camera and permission prompt.

### Does the app call the backend observe function?

Yes. `checkWork()` creates a `TutorObservationRequest`, base64-encodes the image, and calls:

```swift
var observation = try await tutorClient.observeWork(request)
```

The simulator smoke test reached this path and returned a hint.

### Does the request include `image_base64`?

Yes. Swift creates:

```swift
TutorObservationRequest(
    imageBase64: imageData.base64EncodedString(),
    student: student,
    checkNumber: session.events.count + 1,
    noAnswerMode: true
)
```

`SupabaseTutorClient` uses `JSONEncoder.keyEncodingStrategy = .convertToSnakeCase`, so `imageBase64` is sent as `image_base64`, which is exactly what the Edge Function expects.

### Does the Edge Function receive `observe_work`?

The Edge Function supports two modes:

- `observe_work`
- `log_session`

For observation, it rejects any request that does not have:

```ts
body.mode === "observe_work"
```

The simulator returning a hint strongly indicates the Edge Function accepted the `observe_work` request.

### Does the Edge Function call OpenAI?

Yes by code. `supabase/functions/tutor/index.ts` sends a multimodal request to:

```text
https://api.openai.com/v1/responses
```

It includes:

- a tutor prompt,
- the base64 paper image as `input_image`,
- JSON output formatting,
- model default `gpt-4o-mini` unless `OPENAI_OBSERVE_MODEL` is set.

Direct Supabase Edge logs were not inspected during this pass, but the simulator returning a relevant tutoring hint is strong evidence that the deployed path is working. The local simulator app log also showed a successful `200` response from:

```text
https://zydgcutdgkgjvstzrafo.supabase.co/functions/v1/tutor
```

### Does the function return a `TutorObservation`?

Yes in the simulator test. The app decoded the response and changed the Live Session state to `Hint ready`.

The displayed hint was:

```text
What do you get when you multiply 3 by both terms inside the parentheses?
```

### Does the app display the result?

Yes. After the check completed, the Live Session screen displayed the hint in the scan overlay.

The app does not show final answers in normal mode. That is intentional and consistent with the project goal.

### Does the app speak the result?

The code calls `voice.speak(...)` only if `TutorPolicy.shouldInterrupt(for:)` says the tutor should interrupt. In simulator testing, microphone input was unavailable, so real voice behavior should be tested on the physical iPad.

### Are backend errors visible?

Partially. If `observeWork` throws, the Live Session screen sets:

```swift
errorMessage = error.localizedDescription
latestHint = "Try steadying the iPad and checking again."
status = .watching
```

However, session logging errors are currently not visible because `AppModel.finishSession` uses:

```swift
try? await tutorClient.logSession(session)
```

That means a failed remote session log can fail silently while the local app still appears to work.

### Likely reason the real iPad may not appear to solve/analyze

Based on the simulator smoke test, the backend path is probably not the main issue. The most likely causes are:

1. The student must manually trigger a check from the Live Session scan surface. The app does not continuously solve every camera frame.
2. The app returns hints, not final answers. A successful result may look like a teacher question instead of a solved equation.
3. Real iPad camera permission or camera capture may be failing.
4. The paper may not be framed clearly enough for the model.
5. The handwritten work may need stronger contrast, better lighting, or less page angle.
6. Speech may not work until microphone/speech permissions are granted on the real iPad.
7. Remote session logging could fail silently after the session even if observe/analyze works.

## Screens Verified

Screenshots from the simulator are stored in:

```text
docs/media/current-ui/
```

The full gallery is documented in:

```text
docs/current-ui-gallery.md
```

Captured screens:

- Student Picker
- New Student sheet
- Consent / Study Mode
- Live scan screen
- Live scan screen with labeled controls
- Live scan after check/hint
- Teach Mode from the latest observation
- Teach Mode using backend `teach_steps`
- Teach Mode fallback
- External Display Preview from the latest observation
- External Display Preview using backend `teach_steps`
- Reflection
- Admin Review
- Holder / Voice Debug sheet
- External Display Preview

## Verification Commands

These commands were used during this diagnostic pass.

### Core package checks

```zsh
cd /Users/vmanukya/Documents/GitHub/MathTutor/MathTutorSwift
swift run MathTutorCoreChecks
```

Result: passed.

### Generic iOS build

```zsh
cd /Users/vmanukya/Documents/GitHub/MathTutor
xcodebuild -project MathTutorSwift/iPadApp/MathTutor/MathTutor.xcodeproj \
  -scheme MathTutor \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Result: passed.

### iPad simulator build

```zsh
cd /Users/vmanukya/Documents/GitHub/MathTutor
xcodebuild -project MathTutorSwift/iPadApp/MathTutor/MathTutor.xcodeproj \
  -scheme MathTutor \
  -destination 'platform=iOS Simulator,name=iPad Air 11-inch (M4)' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Result: passed.

### Whitespace / patch check

```zsh
cd /Users/vmanukya/Documents/GitHub/MathTutor
git diff --check
```

Result: passed.

### Simulator launch

The app was installed and launched on an iPad Air 11-inch simulator. The bundle launched successfully and stayed open through the Student Picker, Consent, Live Session, Teach Mode, Admin Review, and Reflection flows.

### Simulator app log

```zsh
xcrun simctl spawn 765BBAE3-00E7-41F3-B169-542F1D3F7347 \
  log show --style compact --last 20m --predicate 'process == "MathTutor"'
```

Result: no app crash was found in the inspected tail. The log showed a `200` response from the Supabase tutor Edge Function URL. The log also showed simulator audio/microphone limitations, which matches the Voice Debug screen showing microphone input unavailable in simulator.

## Manual Real-iPad Test Plan

Use this exact test to identify whether the remaining issue is camera, backend, UI flow, or expectations.

1. Connect the iPad to the Mac Studio.
2. Open the Xcode project at:

   ```text
   /Users/vmanukya/Documents/GitHub/MathTutor/MathTutorSwift/iPadApp/MathTutor/MathTutor.xcodeproj
   ```

3. Select the physical iPad as the run destination.
4. Run the app from Xcode.
5. Approve camera and microphone permissions if prompted.
6. Create or choose a student.
7. Enter Live Tutor Session.
8. Put a clear handwritten example under the camera:

   ```text
   3(x + 2)
   ```

9. Tap the Live Session check/viewfinder control once.
10. Confirm the status changes to `Checking`.
11. Wait for either `Hint ready` or an error message.
12. If an error appears, take a screenshot and copy the Xcode console error.
13. End the session and verify the Reflection screen updates.
14. Open Admin Review and check whether the session appears.

Expected successful behavior:

- The app should not give `3x + 6` as a final-answer explanation.
- It should ask a guiding question such as checking distribution or multiplying both terms.
- It may speak the hint if interruption policy and device audio allow it.

## What Not To Change Yet

Until the real iPad test is done, avoid changing:

- Supabase project configuration,
- Edge Function secrets,
- `AppSecrets.swift`,
- migrations,
- the OpenAI model,
- the tutor policy,
- the UI design direction.

The next useful change, if real-device testing shows trouble, would be a tiny diagnostic improvement: show whether the last failure was camera capture, network/backend, response decoding, or speech. That would make the iPad test much easier without changing the teaching experience.
