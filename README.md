# Harness

An autonomous plan-build loop for Claude Code. Harness takes behavioral specs and autonomously researches, plans, implements, verifies, and commits — one phase at a time.

## What's Inside

```
harness/
├── loop.sh                    # Orchestrator — runs the plan/build state machine
├── parse_stream.py            # Stream parser — filters Claude output, detects signals
├── IMPLEMENTATION_PLAN.md     # State index — tracks active/staging/completed work
├── SPEC_core.md               # Spec template — language-agnostic service specification
├── SPEC_language.md           # Spec language guide — how to word specifications
├── SPEC_shell.md              # Spec example — filled-in spec for reference
├── .claude/
│   ├── settings.json          # Claude Code project settings
│   ├── commands/              # Slash commands (skills)
│   │   ├── ralph_plan.md      # Planning state machine (PLAN mode)
│   │   ├── ralph_build.md     # Build executor (BUILD mode)
│   │   ├── create_jtbd.md     # Jobs to Be Done document creation
│   │   ├── create_plan.md     # Implementation plan creation
│   │   ├── create_ralph_topics.md  # JTBD → spec decomposition
│   │   ├── implement_plan.md  # Phase-by-phase implementation
│   │   ├── iterate_plan.md    # Plan iteration/updates
│   │   ├── research_codebase.md        # Full codebase research
│   │   ├── research_codebase_lightweight.md  # Quick followup research
│   │   └── commit.md          # Git commit helper
│   └── agents/                # Subagent definitions
│       ├── codebase-analyzer.md       # HOW code works
│       ├── codebase-locator.md        # WHERE code lives
│       ├── codebase-pattern-finder.md # Existing patterns + examples
│       ├── open-questions-evaluator.md # Research question triage
│       ├── thoughts-analyzer.md       # Extract insights from docs
│       ├── thoughts-locator.md        # Find docs in thoughts/
│       └── web-search-researcher.md   # Web research
└── thoughts/shared/           # Durable knowledge store
    ├── jtbd/                  # Jobs to Be Done documents
    ├── specs/                 # Behavioral spec files
    ├── plans/                 # Implementation plans
    └── research/              # Research documents
```

## Quick Start

### 1. Copy harness into your project

```bash
# From your project root
git clone https://github.com/lightfastai/harness.git /tmp/harness-src

# Copy the harness files
cp /tmp/harness-src/loop.sh .
cp /tmp/harness-src/parse_stream.py .
cp /tmp/harness-src/IMPLEMENTATION_PLAN.md .
cp /tmp/harness-src/.gitignore .  # or merge with your existing one
cp -r /tmp/harness-src/.claude .
cp -r /tmp/harness-src/thoughts .

# Optional: copy spec templates
cp /tmp/harness-src/SPEC_core.md .
cp /tmp/harness-src/SPEC_language.md .

chmod +x loop.sh

rm -rf /tmp/harness-src
```

### 2. Write your SPEC.md

Create a `SPEC.md` in your project root. Use `SPEC_core.md` as a template and `SPEC_language.md` for style guidance.

### 3. Create a JTBD document

```
claude
> /create_jtbd
```

This interactively creates a Jobs to Be Done document that captures the strategic "why" behind your product.

### 4. Decompose into specs

```
> /create_ralph_topics thoughts/shared/jtbd/YYYY-MM-DD-description.md
```

This decomposes the JTBD into Topics of Concern — each becomes a behavioral spec file in `thoughts/shared/specs/`.

### 5. Seed the implementation plan

After specs are created, populate `IMPLEMENTATION_PLAN.md`:

```markdown
# Implementation Plan

Source: thoughts/shared/specs/README.md
Last updated: YYYY-MM-DD

## Active

## Completed

## Unplanned Specs
- thoughts/shared/specs/01-first-topic.md
- thoughts/shared/specs/02-second-topic.md
- thoughts/shared/specs/03-third-topic.md
```

### 6. Run the loop

```bash
./loop.sh        # default 50 iterations
./loop.sh 20     # max 20 iterations
```

## How It Works

### The State Machine

The loop reads `IMPLEMENTATION_PLAN.md` every iteration to determine mode:

- **PLAN mode** — No active plan with remaining phases
  - Gap analysis → research → create plan
  - Managed by `/ralph_plan`
- **BUILD mode** — Active plan with unchecked phases
  - Implements one phase, verifies, commits
  - Managed by `/ralph_build`

### Signal Protocol

Claude communicates with the loop via signal strings in its final output:

| Signal | Exit Code | Meaning |
|---|---|---|
| `<done/>` | 0 | All specs satisfied — loop exits |
| Normal exit | 1 | Step complete — continue to next iteration |
| `<blocked reason="..."/>` | 2 | Human intervention needed — loop exits |
| Error | 3 | Claude error — loop continues |

### One-Operation-Per-Invocation

Both plan and build commands do exactly ONE heavy operation per Claude invocation:
- Plan: ONE research session OR ONE plan creation
- Build: ONE phase implementation

This keeps each context window focused and prevents drift.

### The `[DONE]` Protocol

Phase completion is tracked by appending `[DONE]` to phase headings:
- `## Phase 1: Title` → `## Phase 1: Title [DONE]`
- `loop.sh` counts phases without `[DONE]` to determine mode
- `implement_plan.md` writes the marker after verification passes

## Interactive Commands

These can be used standalone (outside the loop) in any Claude Code session:

| Command | Purpose |
|---|---|
| `/create_jtbd` | Create a Jobs to Be Done document |
| `/create_ralph_topics` | Decompose JTBD into behavioral specs |
| `/create_plan` | Create an implementation plan |
| `/iterate_plan` | Update an existing plan |
| `/implement_plan` | Implement a plan phase-by-phase |
| `/research_codebase` | Deep codebase research |
| `/research_codebase_lightweight` | Quick focused research |
| `/commit` | Create git commits |

## Logging

Runtime logs are written to `.ralph/` (gitignored):

- `.ralph/loop.log` — JSONL, one entry per iteration (cost, turns, duration, signals)
- `.ralph/raw/iter_NNN_MODE.jsonl` — Full stream-JSON per iteration

## Prerequisites

- [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code) installed
- Python 3.6+ (for `parse_stream.py`)
- Git repository

## License

MIT
