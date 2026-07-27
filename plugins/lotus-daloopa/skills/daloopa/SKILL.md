---
name: daloopa
description: |
  Daloopa 金融分析总入口。根据任务按需路由到九个内部工作流，不在顶层菜单重复展开。
---

# Daloopa Router

Use this skill as the only top-level entry for the Lotus-packaged Daloopa workflows.

## Route

Choose exactly one primary workflow from the user's request:

| Intent | Internal workflow |
|---|---|
| Verify the Daloopa connection or inspect available capabilities | `references/setup.md` |
| Build a multi-tab Excel financial model | `references/build-model.md` |
| Build bull, base, and bear scenarios | `references/bull-bear.md` |
| Analyze buybacks, dividends, reinvestment, and shareholder yield | `references/capital-allocation.md` |
| Produce a rapid first-read earnings flash | `references/earnings-flash.md` |
| Prepare for an upcoming earnings report | `references/earnings-prep.md` |
| Generate an investment-banking-style pitch deck | `references/ib-deck.md` |
| Analyze precedent M&A transactions and deal multiples | `references/precedent-transactions.md` |
| Produce a full professional research note | `references/research-note.md` |

If the request genuinely spans multiple deliverables, select the smallest set of workflows that covers it and execute them in dependency order.

## Execution Contract

1. Read the selected workflow reference completely before taking task actions.
2. Follow every direct reference named by that workflow, resolving paths relative to the `references/` directory.
3. Use the Daloopa app/MCP tools when available. If they are unavailable, run the setup workflow or explain the exact missing connection.
4. Preserve Daloopa citation requirements and the shared `data-access.md` and `design-system.md` conventions.
5. Keep the internal workflow names out of the top-level skill menu; they are implementation details behind this router.

The nine workflow references are vendored from the Daloopa plugin and retain their original licenses and attribution.
