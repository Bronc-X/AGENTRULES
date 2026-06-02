---
name: mini-investigate
description: 查小Bug时做最小修复
risk: medium
source: lotus
date_added: "2026-06-02"
---

# Minimal Bug Fix

## Core Rule

Find the real cause, prove it with evidence, make the smallest fix, and verify the original symptom is gone.

Do not refactor, rename, reorganize files, rewrite flows, upgrade dependencies, redesign UI, extract abstractions, or clean unrelated code while using this skill.

## Context Contract

Before editing, write a short context card:

```text
Goal:
Known scope:
Verified facts:
Ruled out:
Next validation:
Success check:
```

Use the user's previous conclusions as locked context. Do not re-open ruled-out causes unless new evidence directly contradicts them.

If any required context is missing, infer it from code, logs, tests, browser behavior, or git diff. Ask one concise question only when the missing fact blocks safe progress.

## Workflow

### 1. Reproduce

Run the smallest reproduction available:

- For UI bugs, open the affected page and perform the exact interaction.
- For routing bugs, trigger the route change and capture the current and expected URL.
- For repeated requests, inspect network calls and count the unexpected repeats.
- For backend request anomalies, capture method, endpoint, status, and relevant request parameters.
- For page jitter, observe the state transition, layout shift, render loop, or request loop that causes it.

If reproduction is impossible in the environment, state the blocker and use the closest observable signal, such as test output, logs, static code path, or browser/network trace.

### 2. Build the Evidence Chain

List plausible causes before editing. Use this format:

```text
Hypothesis:
Evidence for:
Evidence against / ruled out:
Validation action:
Verdict: confirmed | rejected | still possible
```

Do not fix while more than one cause is still equally plausible. Gather one more signal first.

### 3. Lock the Patch Scope

Before editing, name the intended patch surface:

```text
Files to touch:
Lines / functions:
Why this is enough:
What stays unchanged:
```

Default target: one file. Two files is acceptable when one is a test or a direct caller. More than three files means stop and explain why this no longer looks like a small bug.

### 4. Apply the Minimal Fix

Allowed changes include:

- CSS value, layout constraint, class, selector, or responsive rule adjustments.
- Correct route target, navigation guard, redirect condition, or link parameter.
- Request dedupe, dependency array correction, missing cancellation, debounce, or loading guard.
- Simple request parameter, header, status handling, or error handling correction.
- Narrow state update fix that removes flicker, jitter, duplicate fetch, or stuck loading.

Forbidden changes include:

- Component rewrites, broad extraction, or design system changes.
- Moving files, renaming modules, or reorganizing routing structure.
- Dependency upgrades or config rewrites.
- Formatting whole files or applying unrelated lint cleanup.
- Weakening tests, swallowing errors, or hiding symptoms without fixing the cause.

If the smallest honest fix requires a refactor, stop and escalate to a broader debugging or engineering-review workflow.

### 5. Regression Check

Re-run the original reproduction first. Then run the closest cheap regression check:

- Existing focused test for the touched code.
- Build or typecheck when the touched code can break compilation.
- Browser check and screenshot for visual/layout fixes.
- Network check for duplicate request or backend request fixes.
- Route check for navigation fixes.

Do not claim completion with "should be fixed." Use observed evidence.

## Completion Report

End with this report:

```text
STATUS: DONE | DONE_WITH_CONCERNS | BLOCKED | ESCALATED
Fixed: yes | no | partially
Root cause:
Changed:
Evidence:
Regression checks:
Not changed:
Remaining risk:
```

`Changed` must name the concrete files and behavior changed. `Not changed` must call out nearby code or broader refactors intentionally left alone.

Use `DONE_WITH_CONCERNS` when the likely fix is applied but full verification is blocked by environment, credentials, unavailable services, or intermittent behavior.

## Escalation Rules

Escalate instead of continuing if any of these happen:

- Three hypotheses fail.
- The fix needs more than three files.
- The bug involves security, permissions, data loss, migrations, or production incident response.
- The cause spans multiple services or unclear architecture boundaries.
- A minimal fix would only hide the symptom.
- Reproduction remains impossible and no trustworthy proxy signal exists.
