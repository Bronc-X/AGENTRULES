---
name: ai-progress-workspace
description: 用事件流展示AI真实进度
risk: unknown
source: community
date_added: "2026-05-18"
---

# AI Progress Workspace (@ai-progress-workspace)

Use this skill to build products where the user sees AI genuinely working in a central workspace and a progress panel.

Core pattern:

```text
Model reasoning -> tool calls -> event stream -> progress panel
Tool outputs -> structured artifacts -> workspace renderer/editor
```

Do not treat progress as a decorative animation. Progress must correspond to real observable work: a tool started, a tool completed, an artifact was created, an artifact was patched, a job failed, a retry happened, or user approval is needed.

## First decision

Identify the workspace type before choosing libraries:

- **Document workspace**: script editor, report editor, course lesson, slide outline, legal draft. Prefer `Tiptap`, `ProseMirror`, or `Lexical`.
- **Node or board workspace**: storyboard, flowchart, research map, kanban, planning canvas. Prefer `React Flow` for graph-like nodes, or DOM cards with stable IDs for simple boards.
- **Whiteboard workspace**: freeform shapes, sketches, annotation. Prefer `tldraw`, `Excalidraw`, `Konva`, or `Fabric.js`.
- **Mixed workspace**: combine a document editor with side artifacts, scenes, assets, cards, or nodes. Keep one canonical artifact model and let UI views project from it.

If the product looks like a page with blocks, headings, script formatting, tables, or paragraphs, treat it as a structured editor rather than a literal canvas.

## Architecture

Build four layers:

1. **Chat surface**: accepts user intent, displays assistant messages, approvals, retries, and final summaries.
2. **Tool runtime**: exposes typed business tools such as `read_script`, `view_outline`, `create_character`, `generate_scene_nodes`, `insert_nodes`.
3. **Event stream**: pushes `tool.started`, `tool.completed`, `artifact.created`, `artifact.patch`, `step.failed`, and `job.completed` to the UI.
4. **Workspace renderer**: renders structured artifacts in the center and updates them from events or persisted state.

Recommended defaults:

- Frontend: `Next.js` or the existing app stack.
- State: local reducer or `Zustand`.
- Realtime: `SSE` for one-way AI progress; `WebSocket` only for collaborative cursors, multiplayer, or bidirectional live control.
- Long jobs: queue with `BullMQ`/Redis, `Temporal`, `Celery`, or the existing backend job system.
- Persistence: store `jobs`, `job_events`, `artifacts`, and domain entities in the database.
- AI integration: use model tool/function calling when available; otherwise implement a deterministic orchestrator that calls typed tools around LLM calls.

## Implementation workflow

1. Restate the product goal as: "What artifact is being generated, where does it render, and what real work should the user see?"
2. Define the domain artifact schema before building the UI.
3. Define the tool list as real functions with typed inputs and outputs.
4. Define the event schema and which component consumes each event.
5. Build the static workspace/editor first with sample artifacts.
6. Add the event stream and progress panel using mocked events.
7. Wire real tools to emit events.
8. Insert or patch artifacts only from structured outputs, not raw prose blobs.
9. Persist events and artifacts so refresh/replay works.
10. Verify with a real generation run and confirm the progress panel matches actual tool execution.

## Event contract

Use a small, stable event vocabulary:

```ts
type JobEvent =
  | { type: "job.started"; jobId: string; title: string; at: string }
  | { type: "step.started"; jobId: string; stepId: string; title: string; at: string }
  | { type: "tool.started"; jobId: string; callId: string; name: string; inputSummary?: string; at: string }
  | { type: "tool.completed"; jobId: string; callId: string; name: string; outputSummary?: string; at: string }
  | { type: "artifact.created"; jobId: string; artifactId: string; kind: string; title?: string; data: unknown; at: string }
  | { type: "artifact.patch"; jobId: string; artifactId: string; patch: unknown; at: string }
  | { type: "step.failed"; jobId: string; stepId: string; error: string; recoverable: boolean; at: string }
  | { type: "job.completed"; jobId: string; at: string };
```

Progress should be derived from real completed steps, real artifact counts, or real external API statuses. For opaque LLM calls, show streaming text or a running state, not an exact fake percentage.

## UI pattern

Use a three-pane product shell when appropriate:

```text
Left: project navigation, artifact index, scenes/assets/entities
Center: generated workspace/editor/canvas
Right: AI chat, task timeline, tool-call log, approvals
```

The right panel should distinguish:

- Assistant messages: natural-language explanation.
- Tool calls: compact status chips with running/done/error state.
- Artifact changes: "Inserted 8 script nodes", "Created 3 characters", "Updated outline".
- User controls: stop, retry, approve, continue, inspect details.

## Domain example: scriptwriting

Model the editor as script nodes rather than plain Markdown:

```ts
type ScriptNode =
  | { type: "scene"; text: string }
  | { type: "action"; text: string }
  | { type: "character"; text: string }
  | { type: "parenthetical"; text: string }
  | { type: "dialogue"; text: string }
  | { type: "transition"; text: string };
```

Typical tools:

```text
read_script
view_outline
view_characters
view_locations
create_character
create_location
plan_scenes
generate_script_nodes
insert_nodes
review_script
```

The center editor updates after `insert_nodes`; the right progress panel updates after every tool event.

## Implementation patterns

Minimal data model:

```sql
jobs(id, project_id, status, title, created_at, started_at, completed_at, error)
job_events(id, job_id, sequence, type, payload_json, created_at)
artifacts(id, project_id, kind, title, data_json, version, created_at, updated_at)
artifact_events(id, artifact_id, job_id, type, patch_json, created_at)
```

For document editors, `artifacts.data_json` can hold editor JSON. For large documents, store blocks/nodes separately:

```sql
document_nodes(id, document_id, parent_id, position, type, data_json, created_at, updated_at)
```

SSE endpoint shape:

```ts
// GET /api/jobs/:jobId/events
return new Response(stream, {
  headers: {
    "Content-Type": "text/event-stream",
    "Cache-Control": "no-cache, no-transform",
    Connection: "keep-alive",
  },
});
```

Send SSE messages like:

```text
event: tool.completed
data: {"jobId":"job_1","callId":"call_1","name":"insert_nodes"}
```

On reconnect, support replay from `Last-Event-ID` or a `?after=<sequence>` query by reading persisted `job_events`.

Frontend reducer:

```ts
function applyJobEvent(state: WorkspaceState, event: JobEvent): WorkspaceState {
  switch (event.type) {
    case "tool.started":
      return addTimelineItem(state, { id: event.callId, name: event.name, status: "running" });
    case "tool.completed":
      return markTimelineItemDone(state, event.callId);
    case "artifact.created":
      return upsertArtifact(state, event.artifactId, event.kind, event.data);
    case "artifact.patch":
      return patchArtifact(state, event.artifactId, event.patch);
    case "step.failed":
      return addError(state, event);
    default:
      return state;
  }
}
```

Tool wrapper:

```ts
async function runTool<TInput, TOutput>(
  ctx: JobContext,
  name: string,
  input: TInput,
  fn: (input: TInput) => Promise<TOutput>
): Promise<TOutput> {
  const callId = createId("call");
  await ctx.emit({ type: "tool.started", jobId: ctx.jobId, callId, name, inputSummary: summarize(input), at: now() });
  try {
    const output = await fn(input);
    await ctx.emit({ type: "tool.completed", jobId: ctx.jobId, callId, name, outputSummary: summarize(output), at: now() });
    return output;
  } catch (error) {
    await ctx.emit({ type: "step.failed", jobId: ctx.jobId, stepId: callId, error: formatError(error), recoverable: true, at: now() });
    throw error;
  }
}
```

MVP orchestrator:

```ts
async function generateFirstScenes(ctx: JobContext, request: UserRequest) {
  const script = await runTool(ctx, "read_script", {}, readScript);
  const outline = await runTool(ctx, "view_outline", {}, viewOutline);
  const characters = await runTool(ctx, "view_characters", {}, viewCharacters);
  const locations = await runTool(ctx, "view_locations", {}, viewLocations);

  const missingEntities = await callModelForJson("plan missing entities", {
    request,
    script,
    outline,
    characters,
    locations,
  });

  for (const character of missingEntities.characters) {
    await runTool(ctx, "create_character", character, createCharacter);
  }

  for (const location of missingEntities.locations) {
    await runTool(ctx, "create_location", location, createLocation);
  }

  const nodes = await callModelForJson("generate script nodes", { request, outline });
  validateScriptNodes(nodes);
  await runTool(ctx, "insert_nodes", { nodes }, insertScriptNodes);
}
```

Upgrade to model-selected tool calls only when the product benefits from open-ended planning.

## Editor and canvas notes

For Tiptap/ProseMirror:

- Create one node extension per domain block type.
- Store editor JSON, not HTML, as canonical data.
- Insert AI output through commands such as `insertContent`.
- Validate node types and required fields before insertion.
- Use transaction metadata to tag AI-generated insertions for undo/review.

For Lexical:

- Define custom nodes for domain blocks.
- Use editor updates to insert validated generated nodes.
- Serialize to Lexical JSON for persistence.

For React Flow:

- Store `nodes` and `edges` as artifacts.
- Let AI produce node data and layout hints, then run deterministic layout if needed.
- Treat each generated node/card as an artifact with an ID so it can be patched later.

For DOM card boards:

- Use stable IDs, ordered lists, and persisted positions.
- Avoid canvas APIs unless freeform drawing is required.

## Guardrails

- Keep AI progress truthful: never imply the model's private reasoning is directly observable.
- Make every displayed progress item correspond to a function, API call, database write, or artifact mutation.
- Prefer structured JSON/tool outputs over parsing prose.
- Validate generated artifact data before inserting it into the workspace.
- Support cancellation and recoverable errors for long-running jobs.
- Log enough event metadata to debug failed runs.
- Avoid overbuilding agent frameworks for MVPs; a deterministic orchestrator plus typed tools is often enough.

## Verification checklist

- Start a real job and confirm every right-panel status maps to a persisted event.
- Refresh mid-job and confirm the timeline and workspace restore.
- Cancel a job and confirm the worker stops or reaches a safe checkpoint.
- Force a tool failure and confirm the user sees an error plus retry/continue behavior.
- Confirm generated artifacts validate before insertion.
- Confirm final workspace content can be edited manually after AI insertion.
- Confirm the app does not display fake exact percentages for opaque LLM calls.
