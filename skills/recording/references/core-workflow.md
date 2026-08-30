# 核心工作流

## 1. 项目契约

开始时先确认或记录：

- 项目名称、录音来源、时区和目标语言。
- 用户要的资产与明确不要的资产。
- 正式内容是否从整场开始；若不是，记录正式零点。
- 排除区间、受限区间、补录和可能重叠的文件。
- 参与者候选名单；候选名单不是身份确认。
- 内部使用、草稿上传和公开发布的边界。

非关键缺失信息可写成 `PENDING` 后继续证据工作。会改变内容范围、身份归属、授权或公开结果的信息必须在进入对应阶段前确认。

## 2. 原音冻结

为每个输入记录：

```text
source_id
relative_path
track_or_channel
bytes
sha256
container / codec / sample_rate / bit_depth / channels
source_start_absolute（若已知）
duration
is_partial
ingest_status
```

规则：

- 不分析正在增长、无法完整解码或标记为 partial 的文件。
- 复制进项目时保留原文件名，并用清单建立稳定 `source_id`。
- 后续转码文件放到 `work/`，不得替换 `inputs/audio/` 中的母本。
- 停录后检查缺口、静音、异常短文件、重叠和补录，不能用推测填平真实缺口。

## 3. 逐轮证据

转写和说话人识别的最小记录：

```json
{
  "turn_id": "TURN-000001",
  "source_id": "SRC-001",
  "source_sha256": "<64 hex>",
  "track": "TX1",
  "source_time": {"start": "00:00:01.000", "end": "00:00:04.200"},
  "session_time": {"start": "00:20:01.000", "end": "00:20:04.200"},
  "formal_time": null,
  "machine_speaker_id": "CLUSTER-03",
  "stable_speaker_id": null,
  "raw_text": "……",
  "confidence": 0.81,
  "overlap_group_id": null,
  "scope": "PRE_ROLL",
  "editorial_policy": "EVIDENCE_ONLY"
}
```

保留原始机器输出；规范化文字另设字段，不覆盖 `raw_text`。若工具没有可靠的置信度，填 `null`，不要伪造分数。

## 4. 时间与重叠

同一内容尽量保留四种时间：

- `source_time`：在单个文件内的位置。
- `session_time`：从整次录音开始计算的位置。
- `formal_time`：从用户确认的正式零点开始的位置。
- `absolute_time`：含时区的 ISO-8601 时间。

第二段从零计时、设备时钟漂移或文件有重叠时，用声学/文本指纹找候选，再人工抽查边界。重复内容保留两份来源证据，用同一 `overlap_group_id` 标记；内容母库只计一次，并记录首选来源与备用来源。

正式零点确认后满足：

```text
formal 00:00:00.000
= confirmed source + source_time
= confirmed session_time
= confirmed absolute_time（若可得）
```

## 5. 人物与权利

为每个稳定人物分别记录：

- 机器聚类 ID。
- 稳定匿名 ID。
- 用户确认的显示名。
- 公开身份是否允许。
- 内容是否可编辑引用。
- 会议原声是否可用。
- 是否允许采集声音样本。
- 是否允许试音、批量合成或数字人形象。

显示名确认不等于公开身份确认；允许文字引用不等于允许使用原声；主持人允许试音不等于允许批量合成或发布。

无法确认的人物保留稳定匿名 ID，`editorial_policy=EVIDENCE_ONLY`。对外资产中不要出现 `UNKNOWN`、`UNRESOLVED`、`CLUSTER-*` 或猜测姓名。

同一授权域允许按人物、片段、资产、平台和账号存在多条 grant；不要用一条全局布尔值覆盖所有人。每条授权至少包含：

```text
grant_id / domain / subject_id / status / scope
confirmation_text / approved_at / approval_event_id
bound_artifacts[{relative_path, sha256}] / does_not_grant[]
```

`APPROVED` grant 必须引用 `audit/events.jsonl` 中匹配的 `AUTHORIZATION_APPROVED` 事件。人物表写 `APPROVED` 时，还必须有覆盖该 `stable_speaker_id` 的对应 grant；聊天中的一句“可以”不能只更新其中一边。

## 6. 受限区间与隐私

受限区间支持两种策略：

- `EVIDENCE_ONLY`：可在受限证据仓保存文字，但任何成品不得使用。
- `EXISTENCE_ONLY`：只记录来源、时间范围、原因和授权人，不做转写、摘要、嵌入、标签或文件名泄漏。

个人手机号、邮箱、住址、证件和未公开客户身份默认从衍生资产匿名化。匿名化映射放在受限决策文件，不散落在稿件中。

## 7. 内容母库

母库至少包含：

- `formal-transcript`：正式范围全文。
- `themes`：母题、冲突、转折、结论。
- `claims`：事实主张、状态、证据、冲突关系。
- `quotes`：原话、轻度规范化版本、人物与时间。
- `people`：只含获准进入编辑层的人物。
- `glossary`：专名、英文缩写、标准写法与读音。
- `decisions`：被提出、改变、推翻和最终确认的决定。
- `actions`：事项、负责人、截止时间、状态；缺失就标 `PENDING`。
- `unresolved`：听不清、身份、数字、时间、授权和事实缺口。

主张状态建议：`SUPPORTED`、`CONFLICTED`、`SUPERSEDED`、`UNRESOLVED`、`EXCLUDED`。文章、播客和商业材料不得把后四种包装成已确认事实。

引语状态建议：

- `EXACT`：逐字可在证据中找到。
- `NORMALIZED_EXACT`：只修口头重复、标点或显然的转写错字，含义未变。
- `PARAPHRASE`：只能作为叙述，不加引号。
- `AMBIGUOUS` / `UNRESOLVED`：不进入公开引语。

## 8. 状态事件

每次门禁通过都向 `audit/events.jsonl` 追加一条事件：

```json
{"event_id":"EVT-...","at":"<ISO-8601>","from":"S20_EVIDENCE_READY","to":"S30_SCOPE_CONFIRMED","decision":"APPROVED","confirmation_text":"<用户原话>","scope":{},"bound_sha256":{}}
```

旧事件不可原地改写。并行任务必须先读取最新状态；同一资产只允许一个活动 worker，输出按输入哈希幂等复用。

## 9. 资源预检

在下载多 GB 模型、启用付费转写/声线服务或启动长时间批量任务前，先检查本地已有工具、CPU/GPU、磁盘、网络、预计成本和隐私边界。把选择写入审计；模型下载使用 staging、大小/SHA 校验和原子替换，避免多个 worker 重复下载。
