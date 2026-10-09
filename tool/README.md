# RouteNote supervisor agent (dev-machine tool)

`supervisor_agent.py` is a **development-time** QA loop. It reads a
*sanitized* diagnostics file, asks Gemini to diagnose issues against
RouteNote's constraints, and hands the fix instructions to a developer CLI
(Claude Code / Cursor). It is **not** part of the app — RouteNote itself stays
zero-backend and offline-first; nothing here ships to devices.

## Quick start

```bash
pip install google-generativeai
echo 'GEMINI_API_KEY=...' > tool/.env        # .env is git-ignored
export GEMINI_API_KEY="$(cat tool/.env | cut -d= -f2)"   # or your shell's dotenv

python tool/supervisor_agent.py --input routenote_diagnostics.json --check
python tool/supervisor_agent.py --input routenote_diagnostics.json --dry-run
python tool/supervisor_agent.py --input routenote_diagnostics.json --yes --no-run
python tool/supervisor_agent.py --input routenote_diagnostics.json --yes
python tool/supervisor_agent.py --watch --interval 15 --input routenote_diagnostics.json
```

## Input contract

`--input` accepts either **one JSON array** of records or **JSON-lines**
(one record per line — the shape the app's `HealthEvent.toMap()` produces
when exported). The tool does not care about field names: each record is
flattened to text and analyzed. Records are truncated to 500 chars each and
the excerpt sent to Gemini is capped (`--max-chars`, default 60 000).

How to get a sanitized export from the app: the diagnostics live in the Hive
`health_events` key (bounded, sanitized events — `AppObserverService` never
writes raw errors or stack traces). Export them via an adb-backed debug
helper or a future debug screen; do **not** paste crash dumps with stack
traces into the input file.

## Safety (why it works this way)

- **No credentials in the repo.** `GEMINI_API_KEY` comes from the
  environment. `tool/.env` is git-ignored.
- **No shell injection.** The model's output is passed to the dev agent as a
  single argv element (`subprocess.run(..., shell=False)`). `DEV_AGENT_CMD`
  (default `claude`) and `DEV_AGENT_EXTRA_ARGS` (a JSON list) choose the
  binary and its fixed flags — model text is never split or parsed as shell.
- **Defense-in-depth redaction.** Inputs are run through a redactor
  (Google API keys, `Bearer`/`api_key`/`authorization` values, long
  tokens, emails) before anything leaves the machine.
- **Consent + audit trail.** TTY runs ask before sending; CI needs `--yes`.
  Reports (including the exact excerpt sent and the fix prompt) go to
  `tool/reports/`; the input file is never modified or truncated.
- **`--dry-run`** composes without calling Gemini or running any binary.

## Environment

| Variable | Default | Meaning |
| --- | --- | --- |
| `GEMINI_API_KEY` | — (required) | Gemini API key |
| `SUPERVISOR_GEMINI_MODEL` | `gemini-1.5-pro` | Model id |
| `DEV_AGENT_CMD` | `claude` | Dev-agent binary (must be installed) |
| `DEV_AGENT_EXTRA_ARGS` | `[]` | JSON list of fixed argv, e.g. `["-p","--output-format","text"]` |

## Related

- App-side diagnostics: `AppObserverService` / `AppHealthLogger`
  (`lib/src/services/`) — records sanitized events; this tool only consumes
  an exported snapshot of them.
- Standards: `AGENT_SKILLS.md` §2.3 (secrets hygiene) applies here too.