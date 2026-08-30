# 工作流包契约

## 标准结构

```text
<workflow-pack>/
|-- WORKFLOW.md
|-- WORKFLOW_SPEC.json
|-- DETOURS_AND_GUARDRAILS.md
|-- QA.md
|-- CHANGE_POLICY.md
|-- evidence/
|   |-- FORWARD_TEST.json
|   `-- commands/<command-id>.json
|-- golden/
|   `-- REFERENCE.json
`-- tests/
    `-- CASES.json
```

## 文件职责

- `WORKFLOW.md`：用户可见短路径、成功契约、适用范围、完整路径、门禁和停止条件；状态与优化声明的机器标记必须和 `WORKFLOW_SPEC.json` 一致。
- `WORKFLOW_SPEC.json`：机器可检查的范围、步骤、分支、门禁、优化声明和验证命令。
- `DETOURS_AND_GUARDRAILS.md`：可复现弯路、根因、删除动作和防回归门禁。
- `QA.md`：事实、行为、权限、技术和人工验证结果；不得只写“已检查”。
- `CHANGE_POLICY.md`：版本规则、重跑范围和状态降级规则。
- `evidence/`：包内相对路径的不可空证据；引用必须带 SHA-256，命令与前向测试还要绑定当前工作流定义哈希。
- `golden/REFERENCE.json`：真实成功样本的稳定摘要、预期结果和受保护不变量；不复制不必要的敏感原始数据。
- `tests/CASES.json`：黄金、负向、边界和按需消融案例，以及它们覆盖的 step、gate 和 branch。

## WORKFLOW_SPEC 核心字段

- `status`：`DRAFT`、`LOCALLY_VALIDATED`、`VERIFIED` 或 `DEPRECATED`；只表示工作流可复现程度。
- `validated_scope`：输入类型、环境、规模边界、风险等级和未验证条件。
- `optimization.hard_constraints`：结果正确、授权与安全、可追溯与可复现，不能为了变快而牺牲。
- `optimization.secondary_objectives`：由项目声明的指标、方向、优先级和理由。
- `optimization.claim`：`UNASSESSED`、`IRREDUCIBLE_WITHIN_VALIDATED_SCOPE` 或 `SHORTEST_AMONG_TESTED_CANDIDATES`；与可复现状态分开验证，`VERIFIED` 不自动获得最短性结论，较低状态不能展示当前优化声明。
- `optimization.candidate_paths[]`：候选的步骤、分支、门禁和关键配置形成规范化路径，`path_fingerprint` 是该结构的 canonical JSON SHA-256；两个不同 ID 但相同 fingerprint 仍是一条路径。
- `steps[].kind`：`INVARIANT`、`DEFAULT` 或 `CONDITIONAL`。
- `steps[].side_effect`：`NONE`、`REVERSIBLE_LOCAL`、`IRREVERSIBLE_LOCAL` 或 `EXTERNAL_WRITE`。
- `gates[].step_ids/case_ids`：门禁必须绑定动作和通过的负向或边界案例。
- `conditional_branches[].case_ids`：每个分支至少绑定一个通过的边界案例。
- `validation.commands[]`：记录 `id`、无 shell 的可移植 `argv`、包内 `cwd`、超时和 `evidence_path`；不接受自报 `exit_code`，也不写本机绝对路径。runner 只执行人工确认过的可信命令。

普通证据引用统一使用：

```json
{"path":"evidence/example.json","sha256":"<64 hex>"}
```

严格 QA 拒绝绝对路径、`..`、越界 symlink、缺失/空文件和哈希不一致。项目只存稳定 `source_project_id`；本机路径留在本地运行时映射，不进入可分享包。

## Skill 封装

只有工作流包通过验证且确实会跨项目复用时，才封装为 Skill：

1. 建立规则导出 allowlist；每条规则记录分类、来源项目、泛化依据和脱敏结果。
2. 经验性 `INVARIANT` 至少有两个独立项目来源；单项目结论只能是项目 `DEFAULT` 或 `LOCAL_DETAIL`。
3. 宿主政策和安全规则可引用一个权威来源，不需要人为凑项目数。
4. `SKILL.md` 只保留跨项目不变量、路由和完成门槛；项目姓名、品牌、账号和路径不进入 Skill。
5. 详细领域规则放 `references/`，确定的机械动作放已测试的 `scripts/`，输出模板放 `assets/`。
6. 用 `quick_validate.py` 检查结构，再做隔离的独立行为评测。

不要把一次项目的品牌文案、人物映射、本机路径、缓存故障或偶发工具噪音升级成全局规则。

每个 `skill_export.source_workflows[]` 必须包含稳定的 `project_id`、`workflow_id`、语义版本、工作流定义 SHA-256、`verification_status: VERIFIED` 和一个包内证据引用。该证据文件至少使用以下收据结构，并与来源声明逐字段一致：

```json
{
  "schema_version": "1.0",
  "project_id": "stable-project-id",
  "workflow_id": "verified-workflow-id",
  "workflow_version": "1.0.0",
  "status": "VERIFIED",
  "workflow_definition_sha256": "<64 hex>",
  "strict_qa_result": "PASS",
  "verified_at": "<ISO-8601>",
  "result_summary": "<non-empty>"
}
```

导出物放在包内 `exported-skill/<skill-name>/`。`artifact_manifest` 指向的证据文件必须声明 `schema_version: 1.0`、相同的 `artifact_root`、ISO 时间和每个导出文件的相对路径与 SHA-256；严格 QA 会把 manifest 与实际目录逐文件比对，并拒绝缓存文件、本机绝对路径、来源项目/工作流 ID 和电子邮箱。该扫描不能证明所有品牌事实或隐性身份信息都已移除，仍需人工脱敏检查；需要防伪来源时使用包外可信回执。
