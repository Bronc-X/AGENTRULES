# 播客原声剪辑计划

## 分集依据

先总结完整正式范围的主题图、主要冲突、转折、案例和未决问题，再说明为什么自然形成这些集数。不要先定集数再塞材料。

- 计划集数：
- 分集依据：
- 优选时长：30–60 分钟/集（非硬上限）
- 原声占比目标：`≥95%`；正式长访谈机器最低：`90%`

## 每集计划

| episode_id | 核心主题 | 自然起点/终点 | 预计总时长 | 原声时长 | 旁白时长 | 原声占比 | 状态 |
|---|---|---|---:|---:|---:|---:|---|

分支完成时，`PODCAST_EDIT_PLAN.json` 中每集至少写入：

```json
{
  "episode_id": "E01",
  "asset_kind": "FORMAL_LONGFORM_PODCAST",
  "theme": "来自完整会议的主题",
  "actual_total_seconds": 0,
  "actual_original_audio_seconds": 0,
  "actual_narration_seconds": 0,
  "original_audio_share": 0,
  "source_clip_count": 0,
  "original_audio_speaker_ids": [],
  "narration_segments": [
    {
      "segment_id": "E01-INTRO",
      "type": "INTRO",
      "duration_seconds": 0,
      "necessity_reason": "固定节目开场"
    }
  ],
  "full_listen_qa": "PENDING",
  "original_audio_rights_qa": "PENDING"
}
```

完成态必须使用实际音频时长，不能填预计值；原声占比按 `原声秒数 ÷（原声秒数 + AI 旁白秒数）` 重算。

短摘要必须使用 `SHORT_AUDIO_SUMMARY` 或其他独立资产类型，并放到单独计划；正式 `episodes` 只接受 `FORMAL_LONGFORM_PODCAST`。

## 原声剪辑表

| clip_id | episode_id | 人物 | source/track | in | out | 时长 | theme/claim/turn | 编辑功能 | 原声权 | 完整回听 |
|---|---|---|---|---|---|---:|---|---|---|---|

## 极简旁白清单

| segment_id | episode_id | 类型 | 文字 | 时长 | 不可替代的功能 | 证据 | 状态 |
|---|---|---|---|---:|---|---|---|

类型只允许 `INTRO / NECESSARY_TRANSITION`。每段必须写出具体、不可替代的 `necessity_reason`；能靠原声顺序、章节、show notes 或元数据解决的内容不做 AI 口播。

## 待授权/待回听

原声权未完成时，片段保持 `BLOCKED`；不得改写成 Toni 全旁白来替代。
