---
name: agent-training-loop
description: 修Bug时循环复现定位修复验证
risk: medium
source: lotus
date_added: "2026-05-11"
---

# Agent Training Loop

Use only when the user explicitly invokes `/agent-training-loop`.

This skill treats AI coding as an optimization process: the user defines the objective, tests and acceptance criteria define constraints and validation, and the coding agent iterates inside the allowed search space until the goal converges or a stop condition fires.

## Mental Model

- Requirement = optimization objective / loss function
- Tests and acceptance criteria = validation set
- Editable files and allowed approaches = search space
- Each agent iteration = training step
- Final codebase = trained artifact

Passing tests is not the same as reliable generalization. Watch for overfitting, data leakage, reward hacking, flaky signals, and hidden failures.

## Before Starting

Define these before the first loop:

1. **Objective**
   - What feature, fix, or behavior should be achieved?
   - What user-observable change proves progress?

2. **Validation**
   - Which tests, commands, pages, APIs, logs, or manual checks define success?
   - Which failures must stop the loop?

3. **Search Space**
   - Which files or modules may be changed?
   - Which behavior must not change?
   - Which shortcuts are forbidden?
   - Tests are read-only by default unless there is evidence that the test is wrong.

4. **Stop Conditions**
   - Default maximum: 5 iterations.
   - Stop if two consecutive iterations produce no new signal or progress.
   - Stop immediately on unclear requirements, environment blockers, or validation integrity risk.
   - When all validation passes, run a generalization check before declaring completion.

## Per-Iteration Loop

Run each iteration in this order:

1. **Reproduce**
   - Run the current validation entrypoint.
   - Record command, input, environment, and current result.
   - If the issue cannot be reproduced, stop and explain the blocker.

2. **Detect**
   - Analyze the failure or mismatch.
   - Classify it as product bug, test bug, environment issue, flaky signal, or unclear requirement.
   - State which loss this iteration will reduce.

3. **Execute**
   - Make the smallest necessary change.
   - Touch only files connected to this iteration's loss.
   - Do not weaken tests, hide failures, or broaden scope.

4. **Check**
   - Re-run the same validation entrypoint.
   - If it passes, run related regression checks.
   - If it fails, record the new signal and continue only if it adds information.

5. **Generalization Check**
   - After target validation passes, check for overfitting:
     - hardcoded test data
     - weakened assertions
     - bypassed business logic
     - polluted fixtures
     - swallowed errors
   - Add 1-3 boundary, counterexample, or holdout checks when risk is meaningful.

## Output

Report:

- Objective
- Validation set
- Stop condition
- Iteration summaries: signal -> change -> result
- Final commands and results
- Remaining risks
- Overfitting/data-leakage/hidden-failure assessment

## Hard Rules

- No infinite loops
- No weakening validation to pass
- No hidden failures
- No completion claims without evidence
- No repeated same-class edits when failure signals do not change
- Keep a readable summary for every iteration
