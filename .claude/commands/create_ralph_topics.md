---
description: Decompose JTBD into Topics of Concern and write behavioral spec files
model: opus
---

# Create Ralph Topics

You are tasked with taking a Jobs to Be Done document and decomposing it into **Topics of Concern** — the distinct, scoped aspects of each job that each become a standalone behavioral specification file. This is the bridge between strategic JTBD thinking and actionable specs that a planning/building loop can consume.

## Core Concept

A **Topic of Concern** is a single, cohesive capability area within a JTBD. The scoping test:

> "Can you describe this topic in one sentence without conjoining unrelated capabilities?"

- **Pass**: "The discovery engine analyzes CLI help output to extract a structured command tree"
- **Fail**: "The provider system handles discovery, policy enforcement, and config persistence" → that's 3 topics

Each topic produces exactly one spec file. The relationship:
- 1 JTBD → N topics of concern
- 1 topic → 1 spec file (`thoughts/shared/specs/NN-topic-name.md`)
- 1 spec → N tasks (consumed by planning/building loops later)

## Initial Response

When this command is invoked:

1. **Check if a JTBD document path was provided**:
   - If yes, read it fully before proceeding
   - If a JTBD path and a focus area were provided, scope to that area

2. **If no parameters provided**, respond with:
```
I'll decompose your JTBD into Topics of Concern and write spec files.

I need:
1. The path to a JTBD document (e.g., `thoughts/shared/jtbd/YYYY-MM-DD-description.md`)
2. Optionally, a specific job story to focus on (e.g., "JS-001" or "registration")

If no JTBD document exists yet, run `/create_jtbd` first.

Tip: `/create_ralph_topics thoughts/shared/jtbd/YYYY-MM-DD-description.md`
```

Then wait for the user's input.

## Process Steps

### Step 1: Load Context

1. **Read the JTBD document completely** — this is your primary input
2. **Read SPEC.md completely** — this grounds topics in what the product actually specifies
3. **Read any other files the user mentions** fully
4. **Do NOT spawn sub-tasks yet** — understand the JTBD and spec yourself first

### Step 2: Codebase Research

You need to understand what exists so topics align with real code boundaries.

1. **Spawn parallel research agents**:

   - A **codebase-locator** agent: "Find all source directories, entry points, exported modules, and config files across the entire project. Return a map of what capability lives where."
   - A **codebase-analyzer** agent: "Analyze the domain model — types, entities, interfaces, data structures. What concepts does the system model? How are they related?"
   - A **codebase-pattern-finder** agent: "Find the natural boundaries in the codebase — which files/modules are tightly coupled? Which are independent? Where are the seams between concerns?"
   - If `thoughts/shared/specs/` directory exists, a **codebase-analyzer** agent: "Read all existing spec files and summarize what topics are already covered"
   - If `thoughts/` directory exists, a **thoughts-locator** agent: "Find any existing topic decompositions, research, or architectural decisions"

2. **Wait for ALL agents to complete**

3. **Synthesize**: You now understand:
   - The jobs (from JTBD document)
   - The spec (from SPEC.md)
   - The code boundaries (from research)
   - Any existing specs (from `thoughts/shared/specs/` if present)

### Step 3: Identify Topics of Concern

For each Job Story in the JTBD document:

1. **List the distinct capabilities** the job requires
2. **Group tightly-coupled capabilities** — things that must change together are one topic
3. **Split loosely-coupled capabilities** — things that can be built/tested independently are separate topics
4. **Apply the one-sentence test** to each candidate topic
5. **Frame as activities** (verbs, not nouns) when possible:
   - Prefer: "Discover CLI command trees" over "Discovery Engine"
   - Prefer: "Enforce per-command access policy" over "Policy System"
   - This makes the user journey through topics more natural

6. **Align with code boundaries** where they exist — topics that cross major module boundaries are likely too broad

7. **Check for completeness** — every job story should be fully served by the union of topics. No gaps.

### Step 4: Build the Story Map

Arrange topics into a user journey:

```
[Activity 1]  →  [Activity 2]  →  [Activity 3]  →  [Activity 4]
   basic            basic            basic            basic
   enhanced         enhanced         enhanced         enhanced
   advanced         advanced         advanced         advanced
```

- **Columns** = activities in chronological order (the journey backbone)
- **Rows** = capability depth (basic → enhanced → advanced)
- This reveals natural SLC (Simple/Lovable/Complete) release slices as horizontal cuts

### Step 5: Present Topics for Refinement

Present your decomposition to the user BEFORE writing any spec files:

```
Based on the JTBD document and codebase research, here are the topics I've identified:

## Topics of Concern

| # | Topic (Activity) | One-Sentence Description | Job Stories Served | Code Area |
|---|---|---|---|---|
| 01 | [Activity name] | [One sentence — passes the test] | JS-001, JS-003 | `src/...` |
| 02 | [Activity name] | [One sentence] | JS-002 | `src/...` |
| ... | ... | ... | ... | ... |

## Story Map

[The journey map from Step 4]

## Proposed SLC Slices

- **Slice 1** (MVP): Topics 01, 03, 05 — [what this delivers]
- **Slice 2**: + Topics 02, 04 — [what this adds]
- **Slice 3**: + Topics 06, 07 — [full vision]

## Validation

- Every job story is covered: [yes/no — list any gaps]
- Each topic passes one-sentence test: [yes/no]
- Topics align with code boundaries: [yes/notes]

Questions:
- [Any topics you're uncertain about]
- [Any boundaries that could go either way]

Should I adjust any topics before I write the spec files?
```

**Iterate** until the user approves the topic decomposition. This is the most important checkpoint — wrong topics produce wrong specs.

### Step 6: Write Spec Files

After the user approves the topics:

1. **Create the `thoughts/shared/specs/` directory** if it doesn't exist

2. **For each topic**, write a spec file following the naming convention:
   - Format: `thoughts/shared/specs/NN-kebab-case-topic-name.md`
   - NN is a zero-padded sequence number matching the topic order
   - Examples:
     - `thoughts/shared/specs/01-discover-cli-command-trees.md`
     - `thoughts/shared/specs/02-persist-provider-manifest.md`
     - `thoughts/shared/specs/03-enforce-command-policy.md`

3. **Use this template for each spec file**:

````markdown
---
topic: "[Topic name — activity form]"
description: "[One-sentence description that passes the scoping test]"
job_stories: [JS-001, JS-003]
jtbd_source: "[path to JTBD document]"
spec_reference: "SPEC.md"
status: draft
created: [YYYY-MM-DD]
---

# [Topic Name]

## What This Topic Covers

[One paragraph. What capability this topic represents and what progress it enables for the user. No implementation details.]

## What This Topic Does NOT Cover

[Explicit boundaries. Adjacent topics that are handled elsewhere. This prevents scope creep during planning/building.]

- [Adjacent concern] → see `thoughts/shared/specs/NN-other-topic.md`
- [Out of scope entirely] → not planned

## Acceptance Criteria

[Behavioral outcomes — observable results that verify this topic is complete. These become the basis for tests during the building phase.]

### Required Outcomes

- [ ] [Observable behavior or result — WHAT, not HOW]
- [ ] [Another observable outcome]
- [ ] [Edge case that must be handled]

### Quality Criteria

- [ ] [Performance expectation if applicable]
- [ ] [Error behavior expectation]
- [ ] [User-facing output expectation]

## User Workflow

[How the user experiences this topic — the sequence of actions and results from THEIR perspective. No internal system details.]

1. User does [action]
2. System responds with [observable result]
3. User can then [next action]

## Dependencies

[What must exist or be true for this topic to work]

- **Requires**: [Other topic or external dependency]
- **Required by**: [Topics that depend on this one]
- **External**: [System dependencies — e.g., "CLI binary installed on PATH"]

## Existing Implementation

[What already exists in the codebase for this topic. Descriptive, not prescriptive — document reality.]

- `path/to/file.ts` — [what it currently does]
- [Or: "No existing implementation" if greenfield]

## Open Questions

[Behavioral questions only — things that affect WHAT the system should do, not HOW.]

- [Question about desired behavior in edge case]
````

4. **Important rules for spec content**:
   - **WHAT, not HOW** — describe outcomes, not implementation
   - **No code blocks** showing implementation (pseudocode for workflows is OK)
   - **No function/class names** as requirements (those are implementation decisions)
   - **No framework references** — "the system persists data", not "ConfigManager writes JSON"
   - **Acceptance criteria are behavioral** — "extracts 5-10 dominant colors" not "uses K-means clustering"
   - A different team on a different stack should be able to implement from the spec alone

### Step 7: Write the Topic Index

After all spec files are written, create a topic index:

1. **Write to**: `thoughts/shared/specs/README.md`

````markdown
# Topics of Concern

Generated from: `[path to JTBD document]`
Date: [YYYY-MM-DD]

## Story Map

```
[Activity 1]  →  [Activity 2]  →  [Activity 3]  →  [Activity 4]
   basic            basic            basic            basic
   enhanced         enhanced         enhanced         enhanced
```

## Topics

| # | Spec File | Topic | Status | Job Stories |
|---|---|---|---|---|
| 01 | [`01-topic.md`](01-topic.md) | [Description] | draft | JS-001 |
| 02 | [`02-topic.md`](02-topic.md) | [Description] | draft | JS-002 |

## SLC Release Slices

### Slice 1 — [Name] (MVP)
Topics: 01, 03, 05
Delivers: [What the user can do after this slice]

### Slice 2 — [Name]
Topics: + 02, 04
Delivers: [What this adds]

## Dependencies

```
01 ──→ 02 ──→ 04
        ↓
       03 ──→ 05
```

[Or describe in prose if the graph is simple]
````

### Step 8: Present Results

```
I've created [N] spec files from the JTBD decomposition:

[List each spec file with its one-line description]

Index: `thoughts/shared/specs/README.md`
Source JTBD: `[path]`

Next steps:
- Review each spec for completeness and correct scoping
- Run `/create_ralph_topics` again with corrections if topics need adjustment
- When specs are approved, use PLANNING mode to generate an implementation plan from these specs

Want me to adjust any topics or dig deeper into a specific spec?
```

### Step 9: Handle Follow-ups

- If the user wants to **split a topic**: create two new spec files, update the index, delete the old one
- If the user wants to **merge topics**: combine into one spec file, update the index, delete the extras
- If the user wants to **add a topic**: create a new spec file, update the index
- If the user wants to **refine acceptance criteria**: update the specific spec file
- Always update `thoughts/shared/specs/README.md` after any changes

## Important Guidelines

1. **The one-sentence test is sacred**:
   - Every topic MUST pass: "Can you describe it in one sentence without 'and' joining unrelated capabilities?"
   - If a topic fails, split it. No exceptions.
   - Run the test explicitly for each topic and show the result to the user

2. **Specs are behavioral, not technical**:
   - A spec describes WHAT the system does from the user's perspective
   - Implementation decisions belong to the planning/building phases
   - If you catch yourself writing about internal architecture, zoom out to user-observable behavior

3. **Topics should be buildable and testable independently**:
   - Each topic should be implementable without completing all other topics
   - Dependencies should be explicit and minimal
   - This enables incremental delivery and parallel work

4. **Activity framing over capability framing**:
   - "Discover CLI command trees" (activity — what the user triggers)
   - NOT "Discovery Engine" (component — internal system name)
   - Activities map naturally to user workflows and test scenarios

5. **Align with but don't be constrained by code boundaries**:
   - Topics should roughly align with how code is organized
   - But if the code has poor boundaries, topics define the DESIRED boundaries
   - Specs inform how code SHOULD be organized, not the other way around

6. **Story Map reveals release strategy**:
   - The horizontal journey (activities in order) shows the user's workflow
   - Vertical depth shows capability progression
   - Horizontal slices are SLC release candidates
   - Present this clearly — it's a key strategic output

7. **No open questions in final specs**:
   - If a spec has open behavioral questions, STOP
   - Ask the user for clarification
   - Resolve before finalizing the spec
   - Implementation questions are fine to leave open (the build loop decides those)

## Sub-task Spawning Best Practices

1. **Research phase**: spawn all agents in parallel — locator, analyzer, pattern-finder
2. **Spec writing phase**: write spec files sequentially (they may reference each other)
3. **Each agent gets a focused question** — "find boundaries" not "analyze everything"
4. **Verify agent findings** — if a code boundary seems wrong, read the file yourself
5. **Wait for ALL agents** before identifying topics — you need the complete picture
