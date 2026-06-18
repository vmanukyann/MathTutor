# AirPlay External Display Test Plan

This checklist verifies the MathTutor AirPlay / external display app flow on a real iPad. It is intentionally separate from backend testing: do not reset Supabase, change secrets, or edit the Edge Function while running these checks.

## Goal

The iPad should stay focused on observing the student's paper while the external display shows a quiet, math-only Teach Board.

Passing behavior:
- The iPad keeps the live camera session visible.
- The external screen shows only centered math steps in Teach Mode.
- The student-facing controls stay icon-only.
- The app can enter, update, and leave Teach Mode without exposing final-answer prose.
- Disconnecting the external display falls back gracefully to local iPad Teach Mode.

## Required Hardware

- iPad with MathTutor installed.
- One external display path:
  - AirPlay receiver, such as Apple TV or compatible classroom display.
  - USB-C to HDMI display adapter.
  - USB-C monitor.
- A sheet of paper with simple handwritten algebra work.
- Optional: motorized holder if holder controls are being tested.

## Preflight

1. Build and run the current app from Xcode on the iPad.
2. Confirm the app opens to the notebook-style Student Picker.
3. Confirm the iPad has camera permission.
4. Select `Demo Student` or create a test student.
5. Begin a live session.
6. Confirm the bottom live-session strip includes:
   - check work icon,
   - pause icon,
   - question icon,
   - AirPlay route icon,
   - Teach Mode icon,
   - corrected icon,
   - repeat hint icon.

## Test 1: Connect External Display Before Teach Mode

1. From the live session, tap the AirPlay route icon.
2. Select the external display.
3. Confirm the iPad top-left display status icon changes from disconnected to connected.
4. Confirm the external display shows the standby board, not the full iPad camera UI.
5. Tap Teach Mode.

Expected:
- The iPad remains on the camera/live-session surface.
- The iPad bottom strip switches to Teach controls:
  - question mark,
  - checkmark,
  - return arrow,
  - stop icon only if holder Teach mode is active.
- The external display shows math steps only, for example:

```text
3(x + 2)
= 3x + 3·2
= 3x + 6
```

Fail if:
- The external display mirrors the whole iPad UI.
- The external display shows prose explanations.
- The iPad switches away from the live camera surface.
- The OpenAI key, Supabase service role key, or any secret appears anywhere.

## Test 2: Ask For Another Step While External Teach Mode Is Active

1. Keep Teach Mode active on the external display.
2. Tap the question mark icon on the iPad.

Expected:
- The external display updates to an alternate math-only representation.
- The iPad stays on the live camera surface.
- The visible UI remains icon-only.
- Any spoken hint is short and does not give a final answer.

## Test 3: Return To Work

1. While external Teach Mode is active, tap the return arrow.

Expected:
- The external display returns to standby.
- The iPad returns to normal live-session controls.
- The camera surface remains active.
- The student can continue writing without navigating through extra screens.

## Test 4: Disconnect During Teach Mode

1. Enter Teach Mode with the external display connected.
2. Disconnect AirPlay or unplug HDMI while Teach Mode is visible.

Expected:
- The iPad falls back to local Teach Mode instead of getting stuck.
- The same math steps remain visible on the iPad.
- The same Teach controls are available.
- Tapping return exits local Teach Mode and resumes the live session.

## Test 5: Connect After Local Teach Mode Starts

1. Start a live session with no external display connected.
2. Tap Teach Mode.
3. Confirm local iPad Teach Mode appears with math-only steps.
4. Connect AirPlay or HDMI.

Expected:
- The math Teach Board moves to the external display.
- The iPad returns to the live camera surface with external Teach controls.
- No prose explanation appears on the external display.

## Test 6: App Lifecycle Refresh

1. Connect the external display.
2. Background the app.
3. Reopen the app.
4. Enter Teach Mode.

Expected:
- The app still recognizes the external display.
- Teach Mode routes to the external display.
- The iPad keeps the live camera surface.

## Test 7: End Session Cleanup

1. Enter Teach Mode on the external display.
2. Tap the end-session `x` on the iPad.

Expected:
- The session ends normally.
- The external display clears Teach Mode.
- Returning to Student Picker does not leave stale math on the external display.

## Simulator-Only Support

The simulator cannot prove real AirPlay behavior. It does include a simulator-only external display preview so the UI can be checked without hardware.

Simulator checks:
1. Run the app on an iPad simulator.
2. Enter a live session.
3. Tap the simulator preview icon.
4. Confirm the preview opens full-screen.
5. Confirm it shows the same math-only board used by the external display scene.

The simulator also has a fake camera frame path so the live-session controls remain testable without a physical camera.

## Evidence To Capture

For a research/demo handoff, capture:
- Screenshot or photo of iPad live session with external display connected.
- Photo of external display showing math-only Teach Board.
- Photo or video of question mark updating the math step display.
- Photo or video of disconnect fallback to local iPad Teach Mode.

Record the final hardware result in `docs/airplay-external-display-field-report.md`.

## Pass Criteria

The AirPlay pivot is considered hardware-verified only when all of these are true on a real iPad:

- External display receives the Teach Board.
- iPad remains the camera/control surface.
- Teach Board is math-only.
- Student controls are icon-only.
- Connect, disconnect, return-to-work, and end-session cleanup work.
- No backend secrets appear in app code, settings, logs, or UI.
