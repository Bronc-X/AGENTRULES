---
name: workflow
description: 将已有可核验成功执行记录、且用户要求为同类重复任务固化的项目，复盘成可验证、可版本化的工作流或 Codex Skill。用于项目跑通后的路径蒸馏、减少返工和工作流固化。不要用于尚未执行的新流程设计、性能或市场 benchmark、纯复盘文章，也不要把未验收方案标成最短或最优。
---

# Workflow

把一次真实成功交付蒸馏成下一次可以直接复用的路径。产物不是复盘文章，而是带证据、门禁、测试和变更规则的执行系统；“验证通过”和“证明最短”是两件独立的事。

## 先读取什么

- 每次使用先读取 [references/distillation-method.md](references/distillation-method.md)。
- 需要落盘为工作流包或 Codex Skill 时，再读取 [references/package-contract.md](references/package-contract.md)。
- 准备声称“已验证”“最短”或“最优”前，再读取 [references/validation.md](references/validation.md)。

## 入口条件

先找到真实成功运行的证据：原始目标、最终产物、验收结果、执行记录、用户纠正、失败与返工。只有计划、提示词或未验收草稿时，可以建立 `DRAFT`，但不得称为最短或最优工作流。

若项目尚未跑通：记录当前证据、缺失门禁和下一次验证实验，然后停止蒸馏；不要用想象补完成功路径。

自动触发只适用于“项目已跑通，并要为同类重复任务固化”的请求。用户显式调用 `$workflow` 但项目尚未跑通，可以输出 `DRAFT` 缺口包；全新流程设计、性能或市场 benchmark、只写复盘文章以及要求证明抽象全局最优的任务不应自动触发。

## 优化约束

以下三项是不可牺牲的硬约束：

1. 用户可观察结果正确。
2. 权限、安全、隐私和发布边界正确。
3. 可追溯、可复现、失败可诊断。
用户确认次数、串行等待、工具调用、重复计算、耗时和成本属于项目级次要目标。按用户的成功契约声明优先级，不在全局 Skill 中硬编码。

逐步删除实验只能证明 `IRREDUCIBLE_WITHIN_VALIDATED_SCOPE`；只有比较至少两条都满足硬约束、且绑定证据的候选路径，才能声称 `SHORTEST_AMONG_TESTED_CANDIDATES`。不得声称数学上的全局最优。

## 核心流程

1. **冻结成功契约**：写清用户最终认可的结果、范围、明确不做的事和通过证据。
2. **重建实际路径**：先确定权威版本图和扫描预算，再从线程、日志、提交、命令和产物时间线还原真实执行；不把归档、缓存或旧候选当最终版本。
3. **逐步分类**：把动作标为 `INVARIANT`、`DEFAULT`、`CONDITIONAL`、`LOCAL_DETAIL` 或 `DETOUR`；记录输入、输出、依赖、负责人和失败方式。
4. **解释弯路**：可复现且影响受保护行为的返工，必须落到根因、浪费动作、最早信号、前置门禁和回归测试；偶发噪音只记录，不升级为全局门禁。
5. **压缩路径**：删除 `DETOUR`；只把稳定、纯读取的便宜检查前移；可变授权在副作用发生前重新验证；合并同一决策点的用户确认；只并行真正独立的步骤。仅当步骤确定、可重放且缓存键覆盖语义输入、环境、工具版本和权限域时，才按哈希复用。
6. **保留必要分支**：把低频条件移出主路径，但不得合并本来独立的授权域，也不得用默认值扩大用户权限。
7. **双层表达**：用户层只显示有意义的决策或可观察状态，通常不超过 7 个节点，不设最少节点数；在最短性尚未验证时称“用户可见短路径”，不能称“最短用户路径”。执行层保留完整状态、门禁、输入输出、停止条件和恢复方式。
8. **固化与验证**：建立黄金样本、至少一个负向案例、独立前向测试和单一 QA 命令；通过后才标为 `VERIFIED`。

## 产物选择

- 只服务一个项目或团队：优先生成项目内工作流包。
- 会跨项目重复触发并改变 Codex 行为：在工作流包验证后，宿主提供 `skill-creator` 时用它创建或更新 Skill；宿主未提供时按 [references/package-contract.md](references/package-contract.md) 手工封装，并明确报告缺少独立 Skill 结构校验。经验性 `INVARIANT` 至少需要两个独立项目来源；单项目结论保持 `LOCAL_DETAIL` 或 `DEFAULT`。宿主政策和安全规则可引用其权威来源，不要求凑两个项目。
- 两者都需要时，项目内工作流包是证据源；Skill 只保留跨项目不变量和路由，不复制项目私有事实。

可用脚手架创建工作流包：

```powershell
python scripts/new_workflow_pack.py `
  --workflow-id <lowercase-id> `
  --title <title> `
  --destination <absolute-path> `
  --source-project-id <stable-project-id>
```

脚手架要求 Python 3.10+，拒绝覆盖已有目录，也不把本机绝对路径写进可分享包。填充完成后先用无 shell runner 生成与工作流哈希绑定的验证记录，再做严格检查。运行 runner 前必须人工确认 `validation.commands[].argv` 来自当前可信项目；不要执行不可信工作流包内的命令。runner 不是沙箱，严格 QA 只能核对记录与当前 runner、命令和工作流定义一致，不能提供防伪执行证明；高风险场景需由宿主沙箱或可信 CI 留存外部回执。

```powershell
python scripts/run_validation_commands.py <workflow-pack-path>            # 只预览计划
python scripts/run_validation_commands.py <workflow-pack-path> --execute  # 审阅后执行
python scripts/qa_workflow_pack.py <workflow-pack-path> --strict
```

只有需要声称路径不可再删或在已测试候选中最短时，再运行：

```powershell
python scripts/qa_workflow_pack.py <workflow-pack-path> --require-optimization
```

## 完成门槛

只有同时满足以下条件，才能把工作流标为 `VERIFIED`：

- 至少一个真实成功样本从原始输入走到最终结果。
- 可复现且影响受保护行为的弯路都有防回归门禁，负向案例能被拦截。
- 新执行者只看工作流即可完成一次独立前向测试。
- QA 命令经人工审阅后用 `--execute` 执行，记录存在、哈希匹配，并绑定当前工作流定义哈希；需要防伪证明时另附可信宿主回执。
- 所有仍依赖人工判断、外部权限或未验证环境的内容明确标注。
- 版本号和变更规则已冻结；后续失败用于窄修，不无限堆规则。

技术命令成功、用户接受、外部系统可达分别记录，不能互相替代。未达到门槛时报告 `DRAFT` 或 `LOCALLY_VALIDATED`，说明缺口。

`VERIFIED` 不自动授予最短性声明。只有 `--require-optimization` 通过，才能说“在已验证范围内不可再删”或“在已测试候选中最短”，并必须同时说出比较指标、候选范围和未验证条件。不要泛称“最优”。

## 权限边界

复盘、生成草稿或固化流程不授予部署、上传、发布、通知、删除或修改生产系统的权限。工作流必须保留原任务中的授权边界和停止条件。

## 交付说明

最终向用户说明：用户可见短路径、不可删除的门禁、删掉的弯路、文件位置、验证命令与结果、适用范围、证据等级、优化声明级别和仍未验证的条件。
