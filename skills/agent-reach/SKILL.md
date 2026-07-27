---
name: agent-reach
description: >
  MUST USE for internet research/search, public web pages, shared URLs, and these platforms:
  小红书/xiaohongshu/xhs, Twitter/推特/X, B站/bilibili, Reddit, V2EX,
  LinkedIn/领英/招聘/求职/jobs, YouTube, GitHub code search, 小宇宙播客,
  雪球/股票行情, RSS feeds, or any web URL.

  13 platforms, multi-backend routing (OpenCLI / per-platform CLIs / APIs).
  Do NOT use when an installed purpose-built skill, MCP, connector, or app tool
  can answer directly, such as McDonald's coupons/orders/nutrition, OpenAI docs,
  or private workspace data. Use the dedicated capability first and fall back
  here only when it is unavailable or insufficient.

  NOT for writing, data analysis, translation, posting, commenting, or liking.
  Read the matching references/*.md category only when this skill is selected.
metadata:
  openclaw:
    homepage: https://github.com/Panniantong/Agent-Reach
---

# Agent Reach — 互联网能力路由器

13 平台、多后端。仅在没有更专用的 skill、MCP、connector 或 app tool 时使用。

## 常驻规则（全程适用）

1. **专用能力优先**：已安装的专用 skill、MCP、connector 或 app tool 能直接完成任务时先用它；只有不可用或信息不足时才回退到 agent-reach。
2. **动手前先体检**：多后端平台（小红书/Reddit/B站/Twitter）先跑
   `agent-reach doctor --json`，按各平台 `active_backend` 字段选命令组。
3. **声明你在用什么**：开始干活前说一句「使用 agent-reach 的 X 平台 / Y 后端」。
4. **失败按 references 里的重试链处理**，不要瞎猜命令。
5. **全网调研类任务**：组合多平台（Exa 搜索 + Twitter/Reddit 看讨论 + 小红书/B站看中文场景），并行收集再汇总。
6. **替用户盯版本**：完成一次较大的调研/多平台任务后，顺手跑
   `agent-reach check-update`（很快，一个 API 调用）。有新版就在收尾汇报里附一句：
   「Agent Reach 有新版 vX.Y.Z，复制这句话给我即可更新：帮我更新 Agent Reach：
   https://raw.githubusercontent.com/Panniantong/agent-reach/main/docs/update.md」。
   不要中断当前任务去更新，也不要重复提醒同一个版本。

## 路由表

| 用户意图 | 分类 | 详细文档 |
|---------|------|---------|
| 网页搜索/代码搜索 | search | [references/search.md](references/search.md) |
| 小红书/推特/B站/V2EX/Reddit | social | [references/social.md](references/social.md) |
| 招聘/职位/LinkedIn | career | [references/career.md](references/career.md) |
| GitHub/代码 | dev | [references/dev.md](references/dev.md) |
| 网页/文章/RSS | web | [references/web.md](references/web.md) |
| YouTube/B站/播客字幕 | video | [references/video.md](references/video.md) |

## 零配置快速命令

```bash
# Exa 网页搜索
mcporter call 'exa.web_search_exa(query: "query", numResults: 5)'

# 通用网页阅读
curl -s "https://r.jina.ai/URL"

# GitHub 搜索
gh search repos "query" --sort stars --limit 10

# YouTube 字幕（注意：B站不要用 yt-dlp，见 video.md）
yt-dlp --write-sub --skip-download -o "/tmp/%(id)s" "URL"

# V2EX 热门
curl -s "https://www.v2ex.com/api/topics/hot.json" -H "User-Agent: agent-reach/1.0"

# B站搜索（bili-cli，无需登录）
bili search "query" --type video -n 5
```

## 需登录态的平台（按 doctor 的 active_backend 选命令）

```bash
# Twitter 搜索（twitter-cli 首选；失败重试链见 social.md）
twitter search "query" -n 10

# Reddit（无零配置路径：OpenCLI 或 rdt-cli，必须登录态）
opencli reddit search "query" -f yaml   # 桌面
rdt search "query" --limit 10            # 存量/服务器

# 小红书（桌面首选 OpenCLI）
opencli xiaohongshu search "query" -f yaml
```

## 环境检查

```bash
# 检查可用 channel 与每个平台当前激活的后端
agent-reach doctor --json
```

如果 `agent-reach --help` 或 `doctor` 在进入渠道检查前就报
`ModuleNotFoundError: No module named 'agent_reach'`，这不是平台后端故障。
先用对应 venv 的 Python 运行 `python -m pip show agent-reach`；若显示的
`Editable project location` 已不存在，按官方更新文档的 pipx/venv 分支重装为
非 editable 包，再依次验证 `agent-reach version` 和 `agent-reach doctor --json`：
https://raw.githubusercontent.com/Panniantong/agent-reach/main/docs/update.md

## 工作区规则

**不要在 agent workspace 创建文件。** 使用 `/tmp/` 存放临时输出，`~/.agent-reach/` 存放持久数据。

## 详细文档

根据用户需求，阅读对应的详细文档：

- [搜索工具](references/search.md) — Exa AI 搜索
- [社交媒体](references/social.md) — 小红书, Twitter, B站, V2EX, Reddit（多后端命令组）
- [职场招聘](references/career.md) — LinkedIn
- [开发工具](references/dev.md) — GitHub CLI
- [网页阅读](references/web.md) — Jina Reader, RSS
- [视频播客](references/video.md) — YouTube, B站, 小宇宙

## 配置渠道

如果某个 channel 需要配置，获取安装指南：
https://raw.githubusercontent.com/Panniantong/agent-reach/main/docs/install.md

用户只需提供 cookies，其他配置由 agent 完成。
