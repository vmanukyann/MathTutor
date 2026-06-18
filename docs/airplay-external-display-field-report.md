# AirPlay External Display Field Report

Use this report during the real iPad test. It turns the hardware check into evidence you can show your professor, a review committee, or your future self when debugging.

## Test Metadata

- Date:
- Tester:
- iPad model:
- iPadOS version:
- MathTutor branch:
- MathTutor commit:
- Xcode version:
- External display path:
  - AirPlay receiver:
  - USB-C HDMI adapter:
  - USB-C monitor:
- Classroom/network location:

## Build And Install

- App installed from Xcode: yes / no
- Camera permission granted: yes / no
- Microphone permission granted: yes / no / not tested
- Speech recognition permission granted: yes / no / not tested
- Supabase/backend unchanged during test: yes / no
- App opened to Student Picker: yes / no

Notes:

```text

```

## Evidence Checklist

Capture these before marking the AirPlay pivot verified.

- Photo of iPad live camera surface before connecting external display.
- Photo of AirPlay/HDMI display in standby board state.
- Photo of iPad live camera surface while external Teach Mode is active.
- Photo of external display showing math-only Teach Board.
- Short video of the question icon changing the external math representation.
- Short video or note confirming return-to-work clears the external board.
- Short video or note confirming disconnect fallback to local iPad Teach Mode.

Evidence file names or links:

```text

```

## Test Results

### 1. Connect External Display Before Teach Mode

Expected:
- iPad remains camera/control surface.
- External display shows standby board, not mirrored app UI.
- Status icon changes to connected.

Result: pass / fail / partial

Notes:

```text

```

### 2. Enter Teach Mode With External Display Connected

Expected:
- iPad stays on live session.
- iPad controls become icon-only Teach controls.
- External display shows centered math only.
- No prose explanation appears on external display.

Result: pass / fail / partial

Notes:

```text

```

### 3. Ask For Another Step

Expected:
- Question icon updates the external math representation.
- iPad remains live camera/control surface.
- Spoken hint, if any, stays short and does not give away the final answer.

Result: pass / fail / partial

Notes:

```text

```

### 4. Return To Work

Expected:
- External display returns to standby.
- iPad returns to normal live controls.
- Camera surface remains active.

Result: pass / fail / partial

Notes:

```text

```

### 5. Disconnect During Teach Mode

Expected:
- iPad falls back to local Teach Mode.
- Same math steps remain visible locally.
- Return button exits local Teach Mode cleanly.

Result: pass / fail / partial

Notes:

```text

```

### 6. Connect After Local Teach Mode Starts

Expected:
- Local Teach Mode moves to external display after connection.
- iPad returns to live camera surface.
- External display remains math-only.

Result: pass / fail / partial

Notes:

```text

```

### 7. App Lifecycle Refresh

Expected:
- External display remains recognized after background/reopen.
- Teach Mode routes to the external display after reopening.

Result: pass / fail / partial

Notes:

```text

```

### 8. End Session Cleanup

Expected:
- Session ends normally.
- External display clears Teach Mode.
- No stale math or student name remains visible.

Result: pass / fail / partial

Notes:

```text

```

## Secret Safety Check

During the physical test, confirm:

- OpenAI API key does not appear in Swift code, app UI, logs, screenshots, or network responses.
- Supabase service-role key does not appear in Swift code, app UI, logs, screenshots, or network responses.
- The iPad app uses only the Supabase URL and anon key.

Result: pass / fail / partial

Notes:

```text

```

## Final Decision

AirPlay pivot status:

- Not verified
- Verified with issues
- Verified

Blocking issues:

```text

```

Follow-up fixes:

```text

```
