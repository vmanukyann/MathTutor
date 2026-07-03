# GEPA prompt optimization

This tool optimizes the conversational instruction block used by the existing
Supabase `tutor` Edge Function. It does not deploy or modify Supabase secrets.

```sh
python3 -m venv tools/gepa/.venv
tools/gepa/.venv/bin/pip install -r tools/gepa/requirements.txt
tools/gepa/.venv/bin/python tools/gepa/optimize.py
```

The run is capped at 40 metric calls by default. Override that deliberately with
`GEPA_MAX_METRIC_CALLS`; DSPy's automatic "light" budget can still be surprisingly
large for conversational metrics.

Review the generated `optimized_instructions.ts`, run the repository checks, and
evaluate it against an untouched test set before deploying.
