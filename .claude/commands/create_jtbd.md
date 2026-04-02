---
description: Create Jobs to Be Done documents through exhaustive codebase research and spec analysis
model: opus
---

# Create Jobs to Be Done

You are tasked with creating high-level Jobs to Be Done (JTBD) documents by deeply understanding the codebase and specification, then articulating the jobs that the product is hired to do. JTBD documents are strategic artifacts — they describe WHY users hire this product, not HOW it's implemented.

## Initial Response

When this command is invoked:

1. **Check if parameters were provided**:
   - If a specific area of focus was provided (e.g., "discovery", "policy", "mcp"), scope the JTBD analysis to that area
   - If a file path was provided, read it fully before proceeding

2. **If no parameters provided**, respond with:
```
I'll help you create a Jobs to Be Done document.

JTBD captures the "jobs" users hire this product to do — the progress they're trying to make, not the features they're requesting.

Please provide:
1. An area of focus (optional — e.g., "discovery", "policy", "agent execution")
2. Any specific user context or scenarios you want explored
3. Whether to scope to the full product or a specific component

Or just say "go" and I'll analyze the full product.

Tip: You can invoke with a focus area directly: `/create_jtbd discovery engine`
```

Then wait for the user's input.

## Process Steps

### Step 1: Read the Specification

1. **Read SPEC.md completely** — this is the source of truth for what the product does and why
2. **Read any files mentioned by the user** fully before proceeding
3. **Do NOT spawn sub-tasks yet** — understand the spec yourself first

### Step 2: Exhaustive Codebase Research

Before writing any JTBD document, you must deeply understand what actually exists.

1. **List the directories** in the project root and in `packages/` (or equivalent)

2. **For each package directory**, spawn parallel agents using the Agent tool:

   For each directory, launch a **general-purpose** agent with instructions to:
   - Use the **codebase-locator** agent to find the key parts of that package — entry points, exported APIs, core modules, config files
   - Wait for the locator to finish
   - For each key part found, use the **codebase-analyzer** agent to understand the functions, patterns, data flow, and domain concepts
   - Use the **codebase-pattern-finder** agent to identify recurring patterns, conventions, and integration points
   - Return a structured summary of:
     - What this package does (capabilities)
     - Who it serves (what kind of user/caller)
     - What problems it solves
     - How it connects to other packages
     - Key domain concepts and entities

   **Run all package agents IN PARALLEL** — do not wait for one to finish before starting another.

3. **Additionally, spawn these research agents in parallel**:

   - A **codebase-analyzer** agent focused on the CLI entry point and user-facing commands — what workflows does the CLI expose?
   - A **codebase-analyzer** agent focused on the domain model (types, entities, data structures) — what concepts does the system model?
   - If a `thoughts/` directory exists, a **thoughts-locator** agent to find any existing JTBD, research, or strategic documents

4. **Wait for ALL agents to complete** before proceeding

5. **Synthesize findings** — you now have a deep understanding of:
   - What the codebase does today
   - What the spec says it should do
   - The domain model and key entities
   - The user-facing surface area
   - How components connect

### Step 3: Identify the Jobs

Using your research, identify the jobs through these lenses:

1. **The Main Job** — What core progress is the user trying to make?
   - Think about the state transition: what's the user's world like BEFORE vs AFTER using this product?

2. **Job Executors** — Who performs each job, and in what situation/context?
   - NOT personas ("as a developer") — situations ("when I'm setting up a new AI-assisted environment")

3. **Job Stories** — For each distinct job, use the format:
   ```
   When [situation that triggers the need],
   I want to [the motivation / action],
   so I can [the outcome / progress made].
   ```

4. **Forces Analysis** — For each major job:
   - **Push forces** (struggling moments with current approaches)
   - **Pull forces** (attraction of the new solution)
   - **Inertia** (habits keeping users on current approach)
   - **Anxiety** (concerns about switching)

5. **Desired Outcomes** — Measurable success criteria in ODI format:
   ```
   [Minimize/Increase] + [metric] + [object] + [context]
   ```

6. **Current Workarounds** — What do people do today when this product doesn't exist?

7. **Related Jobs** — Adjacent jobs the product doesn't own but is connected to

### Step 4: Interactive Refinement

Present your initial JTBD analysis to the user BEFORE writing the document:

```
Based on my analysis of the spec and codebase, here are the jobs I've identified:

**Main Job**: [one sentence]

**Core Job Stories**:
1. [Job Story 1 — short label]
2. [Job Story 2 — short label]
3. [Job Story 3 — short label]

**Key Insight**: [something non-obvious you discovered]

**Open Question**: [anything you're uncertain about]

Does this capture the right jobs? Should I dig deeper into any area?
```

Iterate with the user. JTBD is about getting the framing right — the user may correct your understanding of the situation, the motivation, or the desired outcome. Each correction is valuable.

### Step 5: Write the JTBD Document

After alignment with the user, write the document.

1. **Gather metadata**:
   - Get the current git commit hash: `git rev-parse HEAD`
   - Get the current branch: `git branch --show-current`
   - Get today's date

2. **Write to**: `thoughts/shared/jtbd/YYYY-MM-DD-description.md`
   - Create `thoughts/shared/jtbd/` if it doesn't exist
   - Format: `YYYY-MM-DD-description.md` where description is kebab-case

3. **Use this template**:

````markdown
---
date: [ISO timestamp with timezone]
author: claude
git_commit: [current commit hash]
branch: [current branch]
topic: "[JTBD focus area]"
tags: [jtbd, strategy, relevant-component-names]
status: complete
last_updated: [YYYY-MM-DD]
---

# Jobs to Be Done: [Product/Feature Name]

**Date**: [Current date and time with timezone]
**Git Commit**: [Current commit hash]
**Branch**: [Current branch name]
**Spec Reference**: `SPEC.md`

## Main Job

[One sentence. The core functional job the product is hired to do.]

> "[The progress statement — from state A to state B]"

## Job Executors

[Who performs this job, in what context — situation-based, not persona-based]

- **[Role in context]** — [situation that creates the need]
- **[Role in context]** — [situation that creates the need]

## Job Map

The chronological stages the executor goes through:

| Phase | Stage | Description |
|---|---|---|
| Define | 1. Identify | [What happens at this stage] |
| Prepare | 2. Set up | [What happens at this stage] |
| Confirm | 3. Verify | [What happens at this stage] |
| Execute | 4. Control | [What happens at this stage] |
| Monitor | 5. Observe | [What happens at this stage] |
| Modify | 6. Update | [What happens at this stage] |

## Job Stories

### Core Jobs

#### [Job Story ID] — [Short Label]

**When** [situation that triggers the need],
**I want to** [the motivation / action],
**so I can** [the outcome / progress made].

**Forces:**
- Push: [struggling moment with current approach]
- Pull: [attraction of this solution]
- Inertia: [habit keeping user on current approach]
- Anxiety: [concern about switching]

**Codebase Evidence**: [which components/code serves this job, with file references]

---

[Repeat for each job story]

### Peripheral Jobs

[Secondary jobs — less frequent but still important]

### Emotional / Social Jobs

[How the user wants to feel or be perceived]

## Desired Outcomes

[Measurable success criteria in ODI format]

- Minimize the [time/effort/risk] it takes to [achieve X] [when/while Y]
- Increase the [confidence/reliability/speed] of [X] [in context Y]

## Current Workarounds

[What people do today without this product]

| Workaround | Pain Point |
|---|---|
| [Current approach] | [Why it falls short] |

## Out of Scope (Related Jobs We Don't Own)

- [Adjacent job] — owned by [what]
- [Adjacent job] — owned by [what]

## Constraints and Anxieties

[Forces that make executors hesitant to adopt]

- "[Anxiety statement — what could go wrong?]"
- "[Constraint — environmental or organizational limit]"

## Spec-to-JTBD Mapping

[How the specification components map to jobs]

| Spec Component | Job(s) Served | Section |
|---|---|---|
| [Component from SPEC.md] | [Which job story] | [Spec section ref] |

## Code References

- `path/to/file.ts:line` — [What it does and which job it serves]

## Open Questions

[Any unresolved strategic questions — NOT implementation questions]
````

### Step 6: Present and Iterate

1. **Present the document location**:
   ```
   I've created the JTBD document at:
   `thoughts/shared/jtbd/YYYY-MM-DD-description.md`

   Key jobs identified:
   - [Job 1 summary]
   - [Job 2 summary]
   - [Job 3 summary]

   Please review. I can:
   - Dig deeper into any specific job
   - Reframe jobs based on your corrections
   - Add jobs I may have missed
   - Create separate focused JTBD docs for specific components
   ```

2. **Handle follow-ups**:
   - If the user wants to explore a specific job deeper, spawn focused research agents
   - Update the document in place, updating `last_updated` in frontmatter
   - Add `last_updated_note: "Added [description of update]"` to frontmatter

## Important Guidelines

1. **JTBD is strategic, not tactical**:
   - Focus on WHY users hire the product, not HOW it works
   - Job stories describe situations and desired progress, not features
   - If you find yourself writing implementation details, zoom back out

2. **Situations over personas**:
   - "When I'm onboarding a new team member to our AI-assisted workflow" NOT "As a team lead"
   - The same person in different situations has different jobs

3. **Be exhaustive in research, concise in output**:
   - The research phase should leave no stone unturned
   - The JTBD document should be crisp and readable
   - Every job story should be backed by evidence from the spec or codebase

4. **Forces analysis reveals insight**:
   - The push/pull/inertia/anxiety framework is where the real value lives
   - Don't skip it or make it generic — be specific about what competes with this product

5. **Connect back to the spec**:
   - The Spec-to-JTBD mapping section is critical
   - It shows which parts of the spec serve which jobs
   - It can also reveal spec components that don't clearly serve a job (potential bloat) or jobs not served by the spec (potential gaps)

6. **Iterate with the user**:
   - JTBD framing is subjective — the user knows their users best
   - Present early, get corrections, refine
   - A corrected JTBD is more valuable than a polished but wrong one

7. **No implementation details in the final document**:
   - Code references are for traceability only — "this code serves this job"
   - Don't describe algorithms, data structures, or control flow
   - That belongs in implementation plans, not JTBD

## Sub-task Spawning Best Practices

1. **Maximize parallelism** — every independent research task should run concurrently
2. **Each agent gets a focused mission** — don't ask one agent to analyze everything
3. **Wait for ALL agents** before synthesizing — partial information leads to wrong jobs
4. **Verify agent findings against the spec** — agents describe what IS, you determine what JOB it serves
5. **Use codebase-locator first, then codebase-analyzer** — find then understand
6. **Request structured output** from agents — capabilities, users served, problems solved
