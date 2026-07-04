---
name: codebase-memory-mcp
description: 用代码图谱索引仓库并查询架构、调用链、依赖和影响面。
metadata:
  homepage: https://github.com/DeusData/codebase-memory-mcp
---

# codebase-memory-mcp

`codebase-memory-mcp` is a stdio MCP server for code intelligence. It is not a
standalone web service. The durable setup is:

1. install the package/binary,
2. register it in the host MCP config,
3. enable auto indexing,
4. let the host start the MCP server for each agent session.

Do not start it as a detached background process just to keep it alive; without
an MCP client on stdin/stdout, that process is not useful.

## When To Use

Use this skill when the user asks for:

- code graph, repository memory, indexed codebase search, or architecture map,
- "where is this called", "what depends on this", "trace this path",
- cross-file impact analysis before edits,
- large-repo exploration where repeated grep/read cycles would be noisy,
- preserving codebase understanding across future agent sessions.

For exact filenames, literal strings, or quick local search, use `rg` first.
For structural questions, use the MCP tools below after indexing.

## Setup / Repair

```powershell
python -m venv "$env:USERPROFILE\.codebase-memory-mcp-venv"
& "$env:USERPROFILE\.codebase-memory-mcp-venv\Scripts\python.exe" -m pip install --upgrade pip codebase-memory-mcp
& "$env:USERPROFILE\.codebase-memory-mcp-venv\Scripts\codebase-memory-mcp.exe" install
& "$env:USERPROFILE\.codebase-memory-mcp-venv\Scripts\codebase-memory-mcp.exe" config set auto_index true
& "$env:USERPROFILE\.codebase-memory-mcp-venv\Scripts\codebase-memory-mcp.exe" config set auto_index_limit 50000
```

Verify:

```powershell
& "$env:USERPROFILE\.codebase-memory-mcp-venv\Scripts\codebase-memory-mcp.exe" config list
```

Expected config:

```text
auto_index = true
auto_index_limit = 50000
```

If `install` says indexes must be rebuilt, confirm only when the listed paths
are under the tool's own cache directory, such as
`~/.cache/codebase-memory-mcp/`.

## MCP Workflow

Use MCP tools when available:

1. `list_projects` to see indexed project names.
2. `index_repository` with `repo_path` and a mode:
   - `fast` for first validation or quick local work,
   - `moderate` for normal cross-file work,
   - `full` for deeper architecture/semantic analysis,
   - `cross-repo-intelligence` when linking already indexed projects.
3. `index_status` with the project name returned by `list_projects`.
4. `search_graph`, `trace_path`, `query_graph`, `get_code_snippet`,
   `get_architecture`, or `detect_changes` depending on the question.

Do not guess the normalized project name. It may be derived from the path, for
example `D-Toni-code-lotus`; read it from `index_repository`, `list_projects`,
or an `index_status` hint.

## Operating Rules

- Use `fast` indexing first if the goal is simply to prove the server works.
- Use `detect_changes` before relying on an older index for active repos.
- Use `get_code_snippet` or normal file reads before editing any returned path.
- Keep generated persistent artifacts only when the user wants team sharing or
  reusable code memory in the repo; otherwise use the local cache.
- If the MCP server is unavailable, repair the install once, then fall back to
  `rg`, file reads, and the repo's normal tests.
