#!/bin/bash
# Ralph Loop — autonomous plan-build cycle
#
# Usage:
#   ./loop.sh              # default 50 iterations
#   ./loop.sh 20           # max 20 iterations
#
# Prerequisites:
#   - thoughts/shared/specs/ must exist with spec files
#   - IMPLEMENTATION_PLAN.md must exist (seeded with Unplanned specs)
#
# State machine (driven by IMPLEMENTATION_PLAN.md):
#   Active plan with unchecked tasks → BUILD (/ralph_build)
#   Everything else                  → PLAN  (/ralph_plan)
#     - ralph_plan handles sub-states internally:
#       - Staging without research → does research, exits
#       - Staging with research    → creates plan, exits
#       - No staging, no active    → gap analysis + research, exits
#       - Active with 0 tasks      → housekeeping, then above
#
# Logs:
#   .ralph/loop.log     — structured JSONL per iteration (cost, turns, signals)
#   .ralph/raw/         — full stream-json per iteration (for debugging)

set -euo pipefail

MAX=${1:-50}
PLAN="IMPLEMENTATION_PLAN.md"
SPECS="thoughts/shared/specs"
BRANCH=$(git branch --show-current)
INTERRUPTED=false

CMD_DIR=".claude/commands"
PLAN_CMD="$CMD_DIR/ralph_plan.md"
BUILD_CMD="$CMD_DIR/ralph_build.md"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARSER="$SCRIPT_DIR/parse_stream.py"

LOG_DIR=".ralph"
LOG_FILE="$LOG_DIR/loop.log"
RAW_DIR="$LOG_DIR/raw"

cleanup() {
  :
}

handle_interrupt() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Interrupted. Stopping loop gracefully."
  echo "  Check IMPLEMENTATION_PLAN.md for progress."
  echo "  Log: $LOG_FILE"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  INTERRUPTED=true
}

trap cleanup EXIT
trap handle_interrupt INT TERM

# Ensure log directory exists
mkdir -p "$LOG_DIR" "$RAW_DIR"

# Print cumulative stats from prior runs
total_cost() {
  if [ -f "$LOG_FILE" ]; then
    python3 -c "
import json, sys
total = 0
count = 0
for line in open(sys.argv[1]):
    try:
        d = json.loads(line)
        total += d.get('cost', 0)
        count += 1
    except: pass
if count > 0:
    print(f'  Prior runs: {count} iterations, \${total:.4f} total cost')
" "$LOG_FILE" 2>/dev/null || true
  fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Ralph Loop"
echo "  Plan index: $PLAN"
echo "  Specs:      $SPECS/"
echo "  Branch:     $BRANCH"
echo "  Max:        $MAX iterations"
echo "  Log:        $LOG_FILE"
total_cost
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Verify prerequisites
if [ ! -d "$SPECS" ]; then
  echo "Error: $SPECS/ not found. Run /create_ralph_topics first."
  exit 1
fi

if [ ! -f "$PLAN" ]; then
  echo "Error: $PLAN not found. Seed it with your unplanned specs first."
  exit 1
fi

if [ ! -f "$PLAN_CMD" ]; then
  echo "Error: $PLAN_CMD not found."
  exit 1
fi

if [ ! -f "$BUILD_CMD" ]; then
  echo "Error: $BUILD_CMD not found."
  exit 1
fi

if [ ! -f "$PARSER" ]; then
  echo "Error: $PARSER not found."
  exit 1
fi

SESSION_COST=0

for ((i=1; i<=MAX; i++)); do
  # Determine mode by checking phase-level completion markers
  # Phases look like: "## Phase N: Title" or "## Phase N: Title [DONE]"
  # We count phases NOT marked [DONE] — manual verification checkboxes are irrelevant
  ACTIVE_PLAN=$(grep '^plan:' "$PLAN" 2>/dev/null | head -1 | awk '{print $2}' || echo "")

  PHASES_REMAINING=0
  if [ -n "$ACTIVE_PLAN" ] && [ -f "$ACTIVE_PLAN" ]; then
    TOTAL_PHASES=$(grep -c '^## Phase' "$ACTIVE_PLAN" 2>/dev/null || true)
    DONE_PHASES=$(grep -c '^## Phase.*\[DONE\]' "$ACTIVE_PLAN" 2>/dev/null || true)
    PHASES_REMAINING=$((TOTAL_PHASES - DONE_PHASES))
  fi

  if [ "$PHASES_REMAINING" -gt 0 ]; then
    MODE="BUILD"
    CMD_FILE="$BUILD_CMD"
  else
    MODE="PLAN"
    CMD_FILE="$PLAN_CMD"
  fi

  # Show sub-state for PLAN mode
  SUBSTATUS=""
  if [ "$MODE" = "PLAN" ]; then
    if grep -q '^## Staging' "$PLAN" 2>/dev/null; then
      if grep -q '^research:' "$PLAN" 2>/dev/null; then
        SUBSTATUS=" (staging: has research → will create plan)"
      else
        SUBSTATUS=" (staging: needs research)"
      fi
    elif [ -n "$ACTIVE_PLAN" ]; then
      SUBSTATUS=" (housekeeping: plan complete)"
    else
      SUBSTATUS=" (gap analysis → research)"
    fi
  fi

  echo ""
  [ "$MODE" = "BUILD" ] && PHASES_INFO=" ($PHASES_REMAINING phases remaining)" || PHASES_INFO=""
  echo "━━━ Iteration $i/$MAX [$MODE]$SUBSTATUS$PHASES_INFO ━━━"
  echo "  $(date '+%H:%M:%S') starting..."

  # Run Claude, pipe through parser for filtered output + signal detection
  # Parser saves raw output, prints filtered progress, exits with signal code
  set +e
  cat "$CMD_FILE" | claude \
    --dangerously-skip-permissions \
    --output-format=stream-json \
    --model opus \
    -p 2>&1 | python3 "$PARSER" "$LOG_FILE" "$i" "$MODE" "$RAW_DIR"

  SIGNAL=$?
  set -e

  echo "  $(date '+%H:%M:%S') done."

  # Extract this iteration's cost from the log (last line)
  ITER_COST=$(tail -1 "$LOG_FILE" 2>/dev/null | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('cost',0))" 2>/dev/null || echo "0")
  SESSION_COST=$(python3 -c "print(round($SESSION_COST + $ITER_COST, 6))" 2>/dev/null || echo "$SESSION_COST")

  # Check if user interrupted
  if [ "$INTERRUPTED" = true ]; then
    echo "  Session cost so far: \$$SESSION_COST"
    exit 130
  fi

  # Act on signal from parser
  case $SIGNAL in
    0)
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "  All specs satisfied after $i iterations"
      echo "  Session cost: \$$SESSION_COST"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      exit 0
      ;;
    2)
      REASON=$(tail -1 "$LOG_FILE" 2>/dev/null | python3 -c "import json,sys; print(json.loads(sys.stdin.read()).get('blocked_reason','unknown'))" 2>/dev/null || echo "unknown")
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "  Blocked after $i iterations"
      echo "  Reason: $REASON"
      echo "  Session cost: \$$SESSION_COST"
      echo "  Resolve the issue and re-run loop.sh"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      exit 1
      ;;
    3)
      echo ""
      echo "  [WARN] Claude returned an error — continuing to next iteration"
      ;;
    1)
      # Normal completion — continue loop
      ;;
    *)
      echo "  [WARN] Unexpected exit code $SIGNAL from parser"
      ;;
  esac

  # Push after BUILD iterations only
  if [ "$MODE" = "BUILD" ]; then
    git push origin "$BRANCH" 2>/dev/null || git push -u origin "$BRANCH" 2>/dev/null || echo "  (push skipped — no remote or not needed)"
  fi

done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Reached max iterations ($MAX)"
echo "  Session cost: \$$SESSION_COST"
echo "  Check IMPLEMENTATION_PLAN.md for progress"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
