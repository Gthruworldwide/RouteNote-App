#!/usr/bin/env python3
"""RouteNote supervisor agent — a dev-machine QA loop (safe build).

This is a DEVELOPMENT-TIME tool, not part of the Flutter app (which stays
zero-backend and offline-first). It watches a *sanitized* diagnostics file
(JSON array or JSON-lines), asks Gemini to diagnose issues against
RouteNote's constraints (zero-backend, Hive CE, Riverpod, i18n) and hands
the resulting fix instructions to a developer CLI (default: Claude Code)
without ever going through a shell.

Security properties (AGENT_SKILLS.md §2.3 applies here too):
  * No credentials in this file. GEMINI_API_KEY must come from the
    environment (put it in tool/.env, which is git-ignored).
  * The model's output never becomes shell text: it is passed to a known
    binary as a SINGLE argv element (subprocess ..., shell=False).
  * Input is redacted (API keys, tokens, emails) and truncated before it
    is sent. Raw stack traces should never be in the input in the first
    place — AppObserverService only writes sanitized events to Hive.
  * Nothing is deleted: reports go to tool/reports/, the input file is
    never modified.

Usage:
  export GEMINI_API_KEY=...                     # or use tool/.env (ignored)
  python tool/supervisor_agent.py --input routenote_diagnostics.json --check
  python tool/supervisor_agent.py --input routenote_diagnostics.json --dry-run
  python tool/supervisor_agent.py --input routenote_diagnostics.json --yes
  python tool/supervisor_agent.py --watch --interval 15 --input routenote_diagnostics.json

Environment:
  GEMINI_API_KEY           required model API key
  SUPERVISOR_GEMINI_MODEL  model id (default gemini-1.5-pro)
  DEV_AGENT_CMD            dev agent binary (default claude)
  DEV_AGENT_EXTRA_ARGS     optional JSON list of extra argv for the dev
                           agent (never contains model-generated text)
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Iterable, List, Optional, Sequence, Tuple

DEFAULT_MODEL = "gemini-1.5-pro"
DEFAULT_INPUT = "routenote_diagnostics.json"
DEFAULT_MAX_CHARS = 60_000
MAX_LINE_CHARS = 500

SYSTEM_PROMPT = (
    "You are the Autonomous Chief Quality & Architecture Agent for 'RouteNote', "
    "a Flutter app. RouteNote's hard constraints are: zero-backend / "
    "offline-first (local Hive CE persistence only), Riverpod state "
    "management, full EN/AR localization, silent Google auth, sign-out keeps "
    "local data, and a privacy rule that allows only anonymous aggregate "
    "diagnostics off-device. "
    "You are given SANITIZED app diagnostics. Tasks: "
    "1) Analyze the signs of crashes/performance/sync/parsing problems. "
    "2) Determine the most probable root cause against RouteNote's "
    "constraints — never invent data that is not in the excerpt. "
    "3) Produce a precise, step-by-step fix instruction prompt for a "
    "developer agent (Claude Code / Cursor) that names the exact file(s), "
    "the change(s), and the verification commands to run (flutter analyze, "
    "flutter test). "
    "Rules: never echo credentials or raw stack traces; keep the instruction "
    "actionable and bounded; if the excerpt is ambiguous, say so and ask for "
    "a fuller sanitized export instead of guessing."
)

# Redaction patterns (defense-in-depth on top of the app's sanitized events).
_REDACTORS: List[Tuple[re.Pattern[str], str]] = [
    (re.compile(r"AIza[0-9A-Za-z\-_]{20,}"), "[redacted:google_api_key]"),
    (re.compile(r"[Bb]earer\s+[A-Za-z0-9\-._~+/]+=*"), "[redacted:bearer]"),
    (
        re.compile(
            r"(?:x-goog-api-key|api[_-]?key|token|authorization)\s*[:=]\s*[^\s,;]+",
            re.IGNORECASE,
        ),
        "[redacted:key]",
    ),
    (re.compile(r"[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}"), "[redacted:email]"),
    (re.compile(r"[A-Za-z0-9+/]{32,}={0,2}"), "[redacted:token]"),
]


def redact(text: str) -> str:
    """Redact credential-like patterns. Best-effort, defense-in-depth."""
    for pattern, replacement in _REDACTORS:
        text = pattern.sub(replacement, text)
    return text


def make_console_utf8_safe() -> None:
    """Best-effort: never crash printing Unicode to a legacy (cp1252) console.

    The tool prints Gemini-generated text, which may contain arbitrary
    Unicode. On Windows consoles that cannot render it, a hard failure would
    abort the loop; replacing the unrenderable characters keeps the pipeline
    alive.
    """
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(errors="replace")
        except Exception:  # noqa: BLE001 - best effort, never fatal
            pass


def load_lines(path: Path) -> List[str]:
    """Read a diagnostics file as sanitizable text lines.

    Accepts either a single JSON array or one JSON object/primitive per
    line (JSON-lines). Returns one string per record.
    """
    raw = path.read_text(encoding="utf-8", errors="replace")
    stripped = raw.strip()
    if not stripped:
        return []

    try:
        parsed = json.loads(stripped)
    except json.JSONDecodeError:
        parsed = None

    if isinstance(parsed, list):
        lines: List[str] = []
        for item in parsed:
            if isinstance(item, str):
                lines.append(item)
            else:
                lines.append(json.dumps(item, ensure_ascii=False, separators=(",", ":")))
        return lines

    lines = []
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            item = json.loads(line)
        except json.JSONDecodeError:
            lines.append(line)
            continue
        if isinstance(item, list):
            for sub in item:
                if isinstance(sub, str):
                    lines.append(sub)
                else:
                    lines.append(json.dumps(sub, ensure_ascii=False, separators=(",", ":")))
        elif isinstance(item, str):
            lines.append(item)
        else:
            lines.append(json.dumps(item, ensure_ascii=False, separators=(",", ":")))
    return lines


def sanitize_lines(lines: Iterable[str]) -> List[str]:
    """Truncate line width and redact credentials."""
    return [redact(line)[:MAX_LINE_CHARS] for line in lines]


def compose_excerpt(lines: Sequence[str], max_chars: int) -> Tuple[str, int]:
    """Keep the tail of the log within max_chars. Returns (text, kept_bytes)."""
    total = 0
    kept: List[str] = []
    for line in reversed(lines):
        cost = len(line) + 1  # +1 for the newline
        if total + cost > max_chars and kept:
            break
        kept.append(line)
        total += cost
    kept.reverse()
    return "\n".join(kept), total


def check_runtime(args: argparse.Namespace) -> int:
    """Validate environment + input without any network call."""
    problems: List[str] = []
    if not os.environ.get("GEMINI_API_KEY"):
        problems.append("GEMINI_API_KEY is not set (put it in tool/.env or export it)")
    input_path = Path(args.input)
    if not input_path.exists():
        problems.append(f"input file not found: {input_path}")
    else:
        try:
            lines = sanitize_lines(load_lines(input_path))
            if not lines:
                problems.append("input file contains no diagnostics records")
        except Exception as exc:  # noqa: BLE001 - report any parse problem
            problems.append(f"could not parse input file: {exc}")
    try:
        import google.generativeai as _genai  # noqa: F401
    except ImportError:
        problems.append(
            "google.generativeai is not installed (pip install google-generativeai)"
        )
    for problem in problems:
        print(f"  ! {problem}", file=sys.stderr)
    if problems:
        print("check failed.", file=sys.stderr)
        return 1
    print("check ok: env key set, input parses, gemini SDK importable.")
    return 0


def call_gemini(excerpt: str, model_id: str) -> str:
    """Send the excerpt to Gemini and return the diagnostic text."""
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        raise RuntimeError(
            "GEMINI_API_KEY is not set — put it in tool/.env or export it first"
        )
    import google.generativeai as genai

    genai.configure(api_key=key)
    model = genai.GenerativeModel(model_name=model_id, system_instruction=SYSTEM_PROMPT)
    response = model.generate_content(
        f"SANITIZED ROUTENOTE DIAGNOSTICS\n\n{excerpt}"
    )
    return response.text


def dev_agent_argv(instructions: str) -> List[str]:
    """Build the dev-agent argv. Model text is one element, never a shell."""
    cmd = os.environ.get("DEV_AGENT_CMD", "claude")
    extra_env = os.environ.get("DEV_AGENT_EXTRA_ARGS", "[]")
    try:
        extra = json.loads(extra_env)
    except json.JSONDecodeError:
        extra = []
    if not isinstance(extra, list):
        extra = []
    return [cmd, *[str(arg) for arg in extra], instructions]


def run_dev_agent(instructions: str) -> subprocess.CompletedProcess[str]:
    argv = dev_agent_argv(instructions)
    print(f"🤖 running dev agent: {argv[0]} (prompt passed as one argv element)")
    return subprocess.run(
        argv,
        shell=False,
        check=False,
        text=True,
        capture_output=True,
    )


def write_report(reports_dir: Path, excerpt: str, instructions: str, input_name: str) -> Path:
    reports_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.now(timezone.utc).strftime("%Y%m%d_%H%M%S")
    report = reports_dir / f"supervisor_{stamp}.md"
    report.write_text(
        (
            f"# RouteNote supervisor report ({stamp})\n\n"
            f"- Input: `{input_name}`\n"
            f"- Excerpt bytes: {len(excerpt)}\n\n"
            f"## Sentinel diagnostics (sanitized)\n\n"
            f"```\n{excerpt}\n```\n\n"
            f"## Fix instructions for the dev agent\n\n{instructions}\n"
        ),
        encoding="utf-8",
    )
    return report


def process_once(path: Path, args: argparse.Namespace) -> int:
    lines = sanitize_lines(load_lines(path))
    if not lines:
        print("no diagnostics records found — nothing to do.")
        return 0

    excerpt, kept = compose_excerpt(lines, args.max_chars)
    print(
        f"⚠️ {len(lines)} diagnostic record(s) loaded; "
        f"sending {kept} characters to Gemini ({args.model})."
    )

    if not args.dry_run and not args.yes and not args.consented:
        if not sys.stdin.isatty():
            print("input is not a TTY and --yes was not given — aborting.", file=sys.stderr)
            return 2
        answer = input("Proceed? [y/N] ").strip().lower()
        if answer not in ("y", "yes"):
            print("aborted.")
            return 0
        # Grant for the rest of this run (watch mode keeps appending batches).
        args.consented = True

    if args.dry_run:
        print("\n--- dry run: composed prompt (redacted excerpt) ---\n")
        print(excerpt)
        print("\n--- end dry run ---")
        return 0

    instructions = call_gemini(excerpt, args.model)
    report = write_report(
        Path(args.reports_dir), excerpt, instructions, path.name
    )
    print(f"💡 diagnostic written to {report}")

    if args.no_run:
        print("(--no-run: not invoking the dev agent)")
        return 0

    result = run_dev_agent(instructions)
    print(f"dev agent exit code: {result.returncode}")
    if result.stdout:
        print(result.stdout)
    if result.stderr:
        print(result.stderr, file=sys.stderr)
    return 0


def watch_loop(path: Path, args: argparse.Namespace) -> int:
    """Poll for newly appended diagnostic records (like the original sketch)."""
    seen = 0
    print(f"👀 watching {path} every {args.interval}s (Ctrl+C to stop)...")
    while True:
        try:
            lines = sanitize_lines(load_lines(path))
            count = len(lines)
            if count > seen:
                if seen > 0:
                    print(f"⚠️ {count - seen} new record(s) detected.")
                seen = count
                process_once(path, args)
        except FileNotFoundError:
            pass
        except Exception as exc:  # noqa: BLE001 - keep the watcher alive
            print(f"! watch error: {exc}", file=sys.stderr)
        time.sleep(args.interval)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--input", default=DEFAULT_INPUT, help="diagnostics input file")
    parser.add_argument(
        "--model",
        default=os.environ.get("SUPERVISOR_GEMINI_MODEL", DEFAULT_MODEL),
        help="Gemini model id",
    )
    parser.add_argument("--max-chars", type=int, default=DEFAULT_MAX_CHARS)
    parser.add_argument("--reports-dir", default="tool/reports", help="report output dir")
    parser.add_argument("--yes", action="store_true", help="skip the consent prompt")
    parser.add_argument("--dry-run", action="store_true", help="compose only, call nothing")
    parser.add_argument("--no-run", action="store_true", help="analyze + report, skip dev agent")
    parser.add_argument("--check", action="store_true", help="validate env/input; no network")
    parser.add_argument("--watch", action="store_true", help="poll for new records")
    parser.add_argument("--interval", type=int, default=10, help="watch poll seconds")
    parser.set_defaults(consented=False)
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    make_console_utf8_safe()

    if args.check:
        return check_runtime(args)

    path = Path(args.input)
    if not path.exists():
        print(f"input file not found: {path}", file=sys.stderr)
        return 1

    if args.watch:
        return watch_loop(path, args)
    return process_once(path, args)


if __name__ == "__main__":
    sys.exit(main())