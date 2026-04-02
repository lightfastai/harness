#!/usr/bin/env python3
"""
Stream-JSON filter for Ralph Loop.

Reads Claude's --output-format=stream-json from stdin.
Prints filtered live progress to stdout.
Appends a structured JSON summary to the log file.
Saves raw output to a per-iteration file for debugging.

Exit codes:
  0 = <done/>   — all specs satisfied
  1 = continue  — normal completion, loop should continue
  2 = <blocked> — human intervention needed
  3 = error     — Claude returned an error

Usage:
  claude ... --output-format=stream-json | python3 parse_stream.py <log_file> <iteration> <mode> [raw_dir]
"""

import json
import os
import re
import sys
import time

def main():
    if len(sys.argv) < 4:
        print("Usage: parse_stream.py <log_file> <iteration> <mode> [raw_dir]", file=sys.stderr)
        sys.exit(1)

    log_file = sys.argv[1]
    iteration = int(sys.argv[2])
    mode = sys.argv[3]
    raw_dir = sys.argv[4] if len(sys.argv) > 4 else None

    raw_lines = []
    result_data = None
    tool_calls = []
    assistant_texts = []
    turn_count = 0

    for line in sys.stdin:
        line = line.rstrip("\n")
        if not line:
            continue

        raw_lines.append(line)

        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue

        etype = event.get("type", "")

        if etype == "system":
            model = event.get("model", "?")
            print(f"  [{model}] session started")
            sys.stdout.flush()

        elif etype == "assistant":
            turn_count += 1
            msg = event.get("message", {})
            contents = msg.get("content", [])
            tools_this_turn = []
            text_this_turn = []

            for block in contents:
                if block.get("type") == "tool_use":
                    name = block.get("name", "?")
                    # Extract a brief hint from the input
                    inp = block.get("input", {})
                    hint = ""
                    if name in ("Read", "Write", "Edit", "Glob"):
                        hint = inp.get("file_path", inp.get("pattern", ""))
                        if hint:
                            hint = os.path.basename(hint)
                    elif name == "Grep":
                        hint = inp.get("pattern", "")[:40]
                    elif name == "Bash":
                        hint = inp.get("command", "")[:40]
                    elif name == "Agent":
                        hint = inp.get("description", "")[:40]

                    tools_this_turn.append(f"{name}" + (f"({hint})" if hint else ""))
                    tool_calls.append(name)

                elif block.get("type") == "text":
                    text = block.get("text", "")
                    if text.strip():
                        text_this_turn.append(text.strip())
                        assistant_texts.append(text.strip())

            if tools_this_turn:
                print(f"  > {', '.join(tools_this_turn)}")
                sys.stdout.flush()

            if text_this_turn and not tools_this_turn:
                # Only show text if it's the final answer (no tool calls in same turn)
                snippet = text_this_turn[0][:120]
                if len(text_this_turn[0]) > 120:
                    snippet += "..."
                print(f"  | {snippet}")
                sys.stdout.flush()

        elif etype == "result":
            result_data = event

    # --- Process result ---
    if not result_data:
        print("  [ERROR] no result event received")
        sys.stdout.flush()
        _write_log(log_file, iteration, mode, error="no result event")
        sys.exit(3)

    result_text = result_data.get("result", "")
    is_error = result_data.get("is_error", False)
    cost = result_data.get("total_cost_usd", 0)
    turns = result_data.get("num_turns", 0)
    duration_ms = result_data.get("duration_ms", 0)
    stop_reason = result_data.get("stop_reason", "")

    # Signal detection on the result text only (not raw stream)
    done = "<done/>" in result_text
    blocked = "<blocked" in result_text
    blocked_reason = ""
    if blocked:
        m = re.search(r'<blocked reason="([^"]*)"', result_text)
        if m:
            blocked_reason = m.group(1)

    # Summary line
    duration_s = duration_ms / 1000
    signal = ""
    if done:
        signal = " DONE"
    elif blocked:
        signal = f" BLOCKED: {blocked_reason}" if blocked_reason else " BLOCKED"
    elif is_error:
        signal = " ERROR"

    tool_summary = ""
    if tool_calls:
        from collections import Counter
        counts = Counter(tool_calls)
        parts = [f"{name}:{n}" if n > 1 else name for name, n in counts.most_common(6)]
        if len(counts) > 6:
            parts.append(f"+{len(counts)-6} more")
        tool_summary = " ".join(parts)

    print(f"  --- ${cost:.4f} | {turns} turns | {duration_s:.1f}s | {len(tool_calls)} tool calls{signal}")
    if tool_summary:
        print(f"      tools: {tool_summary}")
    sys.stdout.flush()

    # Save raw output for debugging
    if raw_dir:
        os.makedirs(raw_dir, exist_ok=True)
        raw_path = os.path.join(raw_dir, f"iter_{iteration:03d}_{mode.lower()}.jsonl")
        with open(raw_path, "w") as f:
            for raw_line in raw_lines:
                f.write(raw_line + "\n")

    # Append structured log entry
    _write_log(
        log_file, iteration, mode,
        cost=cost,
        turns=turns,
        duration_ms=duration_ms,
        tool_calls=len(tool_calls),
        stop_reason=stop_reason,
        is_error=is_error,
        done=done,
        blocked=blocked,
        blocked_reason=blocked_reason,
        result_snippet=result_text[:200] if result_text else "",
    )

    # Exit code
    if done:
        sys.exit(0)
    elif blocked:
        sys.exit(2)
    elif is_error:
        sys.exit(3)
    else:
        sys.exit(1)


def _write_log(log_file, iteration, mode, **kwargs):
    entry = {
        "iteration": iteration,
        "mode": mode,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        **kwargs,
    }
    with open(log_file, "a") as f:
        f.write(json.dumps(entry) + "\n")


if __name__ == "__main__":
    main()
