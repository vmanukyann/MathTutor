# App-wide MathTutor voice

Place `consent.wav` and `voice.wav` in the repository root, then run:

```sh
python3 -m venv tools/voice/.venv
tools/voice/.venv/bin/pip install -r tools/voice/requirements.txt
tools/voice/.venv/bin/python tools/voice/provision.py
```

`consent.wav` must contain exactly this sentence:

> I am the owner of this voice and I consent to OpenAI using this voice to
> create a synthetic voice model.

`voice.wav` should contain the natural 10–30 second tutoring sample. Both files
must be 30 seconds or less and 10 MiB or less. The tool creates one custom voice
and stores its ID as the `OPENAI_TTS_VOICE` Supabase secret. The recordings are
ignored by Git and are never shipped in the app.
