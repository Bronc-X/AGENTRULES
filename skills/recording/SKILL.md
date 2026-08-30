---
name: recording
description: 将一批录音整理成可追溯的内容母库，并按需生产播客、文章、视频、社交、知识库或商业内容资产。用于用户明确调用 $recording，或要求录入、处理、解析录音并继续形成内容或发布草稿时。不要用于只有降噪、裁切、转码的单纯音频编辑，也不要用于没有录音证据的普通文案修改或实时语音聊天。
---

# Recording

把录音处理成一个可验证、可继续生产的内容系统，而不是一次性“洗稿”。核心产物是内容母库；所有对外内容都从母库派生。

## 先读取什么

每次使用都先读取：

- `references/core-workflow.md`：证据、时间、人物、权限和状态机。
- `references/asset-planning.md`：选择资产分支，不默认全做。

只在用户选择相应资产时读取对应文件：

- 播客：`references/podcast.md`
- 文章：`references/article.md`
- 视频或数字人：`references/video.md`
- 社交内容：`references/social.md`
- 企业知识资产：`references/knowledge.md`
- 客户案例、销售或商业传播：`references/commercial.md`
- 上传、发布或分发：`references/publishing.md`

## 不可突破的边界

1. 原始录音只读。先记录文件清单、大小和 SHA-256，再做任何处理；不得覆盖、重命名或重编码唯一母本。
2. 活跃的 `.partial`、仍在增长或尚未封口的录音不得进入转写和分析。
3. 先解析证据，再重编内容。逐轮证据必须能回到 `source_id + track + source_time + source_sha256`。
4. 重叠录音去重但不删证据；听不清、身份不明、数字冲突和前后改口必须显式保留，不猜、不平均、不补全。
5. `UNKNOWN`、`UNRESOLVED` 和机器聚类名只能留在证据层。未经确认的人物不得进入对外署名、引语、原声或数字声线。
6. 显示名、公开身份、会议原声使用、声音采集、数字声线、批量合成、数字人形象、草稿上传和公开发布分别授权，任何一项都不自动授予另一项。
7. 用户说“继续”只表示继续当前已选分支和已授权步骤，不增加资产、不上传、不发布。
8. 即使用户一开始说“做好直接发布”，也先生成不可变发布候选和预览；公开写入前必须再次确认具体内容、平台、账号和候选哈希。候选有变化则重新确认。
9. 用户未选资产时，只完成内容母库和 `ASSET_PLAN` 建议，不自动生成全部分支。
10. 受限或 off-the-record 区间按用户要求处理；若要求“只留存在性标记”，不得转写、摘要、向量化、写入文件名或衍生元数据。

## 入口范围检查

若实际任务仅为降噪、裁切、转码、设备设置、实时语音，或没有录音证据的普通文案编辑，即使用户显式调用 `$recording`，也说明该任务不适用本工作流；不得创建 Recording 项目、转写、生成母库或派生资产。

## 执行入口

若还没有项目目录，使用：

```powershell
pwsh -NoProfile -File scripts/new_recording_project.ps1 `
  -ProjectId <project-id> `
  -Title <title> `
  -Destination <absolute-project-path> `
  -BrandProfile <Blank|DeepEvolutions>
```

若环境只有 Windows PowerShell 5.1，可将 `pwsh` 换成 `powershell`。脚本拒绝覆盖已有目录。`BrandProfile` 默认是 `Blank`；只有当前项目确属 DeepEvolutions 播客时才显式选择 `DeepEvolutions`。

随后按顺序推进：

1. **录入**：登记来源、轨道、录制时间、时区、文件状态和哈希；原音冻结。
2. **解析**：转写、说话人聚类、重叠识别、时间归一化；只写证据层。
3. **确认**：冻结正式零点、排除/受限区间、人物显示名与各类权利。
4. **母库**：形成正式全文、主题、主张、引语、人物、术语、决策、行动项和疑点。
5. **规划**：更新 `plans/ASSET_PLAN.json` 和 `plans/ASSET_PLAN.md`，只把用户选择的分支设为 `SELECTED`。
6. **生产**：读取并执行所选分支规范，所有实质性陈述保留母库证据引用。
7. **质检**：做事实、权限、隐私、风格和媒介技术 QA；失败则保持 `BLOCKED`。
8. **按范围停止**：如果用户没有选择上传或发布，在所选分支 QA 完成后停在 `S80_QA_PASSED`；不生成公开版或发布候选。
9. **发布候选**：仅在用户选择上传/发布时，冻结内容、平台、账号、文件与哈希，生成预览。
10. **单独授权与验证**：取得与该候选完全绑定的最终确认后才执行外部写入；之后区分“已上传、平台已发布、链接可达、搜索已索引、地区可见”。

不要为了赶进度跳过人工决策。可以继续完成不依赖该决策的证据和内部草稿，并把缺口列入 `unresolved`。

## 项目状态

只允许按以下方向推进；缺门禁时保持当前状态或进入 `BLOCKED`：

```text
S00_INIT
→ S10_SOURCE_FROZEN
→ S20_EVIDENCE_READY
→ S30_SCOPE_CONFIRMED
→ S40_PEOPLE_RIGHTS_CONFIRMED
→ S50_LIBRARY_READY
→ S60_ASSETS_PLANNED
→ S70_BRANCHES_READY
→ S80_QA_PASSED
├─ 未选择上传/发布：STOP
└─ 已选择上传/发布
   → S90_RELEASE_CANDIDATE
   → S100_RELEASE_AUTHORIZED
   → S110_RELEASED
   → S120_DISTRIBUTION_VERIFIED
```

把人工决定写入 `audit/events.jsonl`，带时间、原始确认文本、作用域和绑定的文件哈希；不要只把决定留在聊天里。

## DeepEvolutions 播客默认品牌配置

脚手架会写入 `decisions/brand-profile.json`。只对 DeepEvolutions 播客分支应用：

- 主持人显示名：`Toni`
- 每期第一段、恰好一次固定开场
- 保留用户原文和 TTS 规范稿两个版本，不互相覆盖
- 固定开场只授予内容使用，不代表已经授予声音采集、合成或公开发布

其他客户或节目不得继承该开场；先建立自己的品牌配置。

## 完成前验证

运行：

```powershell
pwsh -NoProfile -File scripts/qa_recording_project.ps1 -ProjectRoot <absolute-project-path>
```

报告必须说明：当前状态、已完成资产、仍阻断事项、未授权范围、验证命令与结果。只有用户选中的资产完成且未授权范围仍保持阻断，项目才算本阶段完成。
