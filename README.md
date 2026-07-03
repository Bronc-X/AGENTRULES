# Lotus

Lotus 是一套给 AI 编码助手安装规矩、技能和一点良心的全局工程协议。它不会让模型突然变成圣人，但会让它在动手前先说清目标，在 debug 时先找根因，在交付时拿证据说话。若一个 agent 声称“我大概懂了”，Lotus 会递给它一张契约，让它把“大概”兑换成可验证结果。

它做三件事：

1. 把 Lotus 全局规则写入 Claude Code 与 Codex 的全局规则文件。
2. 安装 Lotus 自带 skills。
3. 从官方 [garrytan/gstack](https://github.com/garrytan/gstack) 安装并同步默认顶层 gstack skills。

Lotus 仓库不内置 gstack 快照。凡是 gstack 能力，官方上游 `garrytan/gstack` 是唯一真源。Lotus 的工作是把这些能力安顿好，让它们在你每个新项目里都像准时的账房先生一样出现。

## 为什么存在

AI 编码最常见的坏习惯并不神秘：

- 它会替你做沉默假设。
- 它会把 50 行能解决的问题修成一座小城。
- 它会顺手改旁边的代码，还说这是“改进”。
- 它会说“修好了”，但不给复现、证据和回归验证。

Lotus 的口号很朴素：少猜，少改，少装腔；多定位，多契约，多验证。

## Lotus 工作协议

Lotus 的全局规则真源在 [core/AGENTS.md](core/AGENTS.md)。全局安装会把它写入：

| 宿主 | 全局安装命令 | Lotus 写入位置 | 说明 |
|---|---|---|---|
| Claude Code | `install.ps1 -Global` / `install.sh --global` | `~/.claude/CLAUDE.md`、`~/.claude/skills` | 受托管 |
| Codex CLI / Codex App | `install.ps1 -Global` / `install.sh --global` | `~/.codex/AGENTS.md`、`~/.codex/skills` | 受托管 |

其他宿主不由 Lotus 安装器自动写入全局路径。如果该宿主支持手动全局规则，请直接导入 [core/AGENTS.md](core/AGENTS.md)。

### 四条护栏

1. 先想清楚，再写代码：先确认目标、边界、关键假设和成功标准。
2. 简单优先：只实现当前问题需要的最小方案，不提前抽象。
3. 手术式修改：只改与目标直接相关的文件、函数和行。
4. 目标驱动闭环：把任务变成可验证目标和明确契约，再实现并验证。

### Debug 规则

Debug 不许从“我猜这里坏了”开始。它从症状开始，一层层拆：

1. 沿入口、调用链、数据形状、状态变化和副作用收敛到最小位置。
2. 修复前先拆原因树，若还有“不知道为什么”，继续往下拆。
3. 每个主要判断都要有日志、测试、代码路径、状态快照、网络响应、构建错误或复现步骤支撑。
4. 补丁落在能解释问题的最小范围。
5. 用原始复现路径证明症状消失，再做回归验证。

### Agentic Coding 契约

非平凡任务开始前，agent 要形成轻量契约：

| 契约项 | 含义 |
|---|---|
| 目标 | 用户可观察到什么变化，什么算完成 |
| 边界 | 哪些文件、模块、行为在范围内，哪些不碰 |
| 做法 | 准备用哪类最小方案，不展开无关重构 |
| 验收 | 用什么测试、构建、复现步骤或静态检查证明完成 |
| 失败方式 | 若无法完成，给出卡点、证据和下一步 |

用户不该操心“具体每一刀怎么切”。用户负责目标和契约，AI 负责拆解、执行、验证和交代。

### 代码语言优先

能写进代码、类型、测试、schema、断言、路由表或配置契约的规则，不只写在自然语言里。自然语言会在转述中掉零件，代码里的契约比较不爱说谎。

## 快速安装

选择一个长期保存 Lotus 的目录。以后更新 Lotus 时就在这里执行 `git pull`。

Windows PowerShell：

```powershell
git clone https://github.com/Bronc-X/Lotus.git C:\Dev\Lotus
C:\Dev\Lotus\install.ps1 -Global
```

macOS / Linux：

```bash
git clone https://github.com/Bronc-X/Lotus.git ~/Dev/Lotus
~/Dev/Lotus/install.sh --global
```

如果下载方式丢失了可执行权限：

```bash
bash ~/Dev/Lotus/install.sh --global
```

无人值守安装：

```powershell
C:\Dev\Lotus\install.ps1 -Global -Force
```

```bash
~/Dev/Lotus/install.sh --global --yes
```

全局安装会：

1. 写入 Claude Code 全局规则：`~/.claude/CLAUDE.md`
2. 写入 Codex 全局规则：`~/.codex/AGENTS.md`
3. 安装 Lotus 自带 skills。
4. 安装或更新官方 gstack 到 `~/.gstack/repos/gstack`。
5. 同步默认顶层 gstack skills 到 `~/.claude/skills` 和 `~/.codex/skills`。

如果已存在全局规则文件，安装器会先创建 `.bak` 备份，再覆盖。旧会话通常不会自动加载新规则，请重启宿主或打开新会话。

## 让 AI 自己安装

如果你不想亲自碰命令行，把这段交给 AI 编码助手：

```text
请在本机安装 Lotus，并验证它已经对当前宿主生效。

1. 记录当前目录的绝对路径。
2. 将 https://github.com/Bronc-X/Lotus.git 克隆到一个长期保存目录。
3. 判断当前操作系统。
4. 运行全局安装：
   - Windows PowerShell: install.ps1 -Global -Force
   - macOS/Linux: bash install.sh --global --yes
5. 验证全局规则和 skills 已写入：
   - Codex: ~/.codex/AGENTS.md 和 ~/.codex/skills
   - Claude Code: ~/.claude/CLAUDE.md 和 ~/.claude/skills
6. 确认 Lotus 自带 skills 和默认 gstack 顶层 skills 存在。
7. 告诉我是否需要重启宿主或开启新会话。
8. 如果失败，给出失败命令、错误原文、已写入的 fallback/bootstrap 入口和下一步修复建议。
```

## 项目模板安装

全局安装不会在每个项目目录自动生成 `AGENTS.md`。Codex 会自动继承 `~/.codex/AGENTS.md`，Claude Code 会自动继承 `~/.claude/CLAUDE.md`。项目级模板是额外叠加层，只在你主动运行 `-Project` / `--project` 时写入当前项目。

Windows PowerShell：

```powershell
cd C:\Users\YourName\Projects\MyNewApp
C:\Dev\Lotus\install.ps1 -Project nextjs
```

macOS / Linux：

```bash
cd ~/Projects/MyNewApp
~/Dev/Lotus/install.sh --project nextjs
```

可用模板：

- `nextjs`
- `vite`
- `html`

## gstack profiles

默认 `core` profile 会暴露 11 个顶层 gstack skills：

- `gstack`
- `gstack-office-hours`
- `gstack-plan-ceo-review`
- `gstack-plan-design-review`
- `gstack-plan-eng-review`
- `gstack-design-review`
- `gstack-review`
- `gstack-investigate`
- `browse`
- `gstack-qa`
- `gstack-ship`

可选 profile：

| Profile | 暴露内容 |
|---|---|
| `core` | 默认 11 个顶层 skills |
| `design` | `core` 加设计相关 skills |
| `review` | `core` 加 QA / review / health 相关 skills |
| `deploy` | `core` 加发布部署相关 skills |
| `full` | 暴露当前官方 gstack 全量顶层 skills |

切换 profile：

```powershell
C:\Dev\Lotus\install.ps1 -Global -GstackProfile design
```

```bash
~/Dev/Lotus/install.sh --global --gstack-profile design
```

## Lotus 自带顶层 skills

这些是 Lotus 仓库托管和打包的跨平台顶层 skills。官方 gstack skills 由 `garrytan/gstack` 提供。全局安装或更新 Lotus 后，下面这些 skill 会写入受托管宿主的全局 skills 目录；重启宿主后即可用 `/skill-name` 调用。

| Skill | 用途 |
|---|---|
| `anysearch` | 实时搜索、垂直领域检索、批量搜索和 URL 内容提取 |
| `agent-reach` | 互联网能力路由器，覆盖网页、搜索、YouTube、RSS、V2EX、B站和需登录态的社交平台 |
| `codebase-memory-mcp` | 代码库记忆与图谱检索，支持索引、结构搜索、调用路径和架构追踪 |
| `test-driven-development` | 严格红绿重构，先写失败测试再写实现 |
| `frontend-design` | 前端审美与交互质量约束 |
| `taste-skill` | 前端审美与实现质量约束，强化布局、字体、动效、间距和组件完成度 |
| `gpt-taste` | 面向 GPT / Codex 的更严格 Taste Skill 变体 |
| `image-to-code` | 图像优先的网站设计到代码流程 |
| `redesign-existing-projects` | 既有项目 UI 改版流程 |
| `imagegen-frontend-web` | 生成网站视觉参考图 |
| `imagegen-frontend-mobile` | 生成移动端界面和流程参考图 |
| `brandkit` | 生成品牌板、Logo 方向、配色、字体和身份应用参考 |
| `high-end-visual-design` | 柔和、克制、高级感视觉设计方向 |
| `minimalist-ui` | 极简、编辑感产品 UI 方向 |
| `industrial-brutalist-ui` | 工业粗野主义、强对比、机械感界面方向 |
| `stitch-design-taste` | Google Stitch 兼容的 Taste Skill 规则 |
| `full-output-enforcement` | 防止模型半成品输出，要求完整可运行交付 |
| `mobile-agent-bridge` | 手机连接本机 Agent 的 daemon / runtime 两层架构调试与验证 |
| `ios-codex-preview` | 为 iOS / SwiftUI 项目安装并验证 Codex 侧边浏览器实时预览 |
| `ios-ui-centering-fix` | 修复 SwiftUI 中标题、加载块和 tab 参考轴的结构性居中偏移 |
| `shadcn-preset-refactor` | 用 shadcn/create preset 做无损视觉改造 |
| `image-2` | GPT Image 2 生图与改图入口 |
| `gsap` | GreenSock 官方 GSAP 动画 skill 聚合入口，路由到 React、ScrollTrigger、Timeline、Plugins 等官方子 skill |
| `ai-progress-workspace` | 搭建带真实 AI 工具进度和结构化 artifact 的 Agent 产品 |
| `web-to-design-md` | 从参考网页、品牌资料、需求文档生成结构化 `design.md` |
| `debugging-strategies` | 系统性排错，先定位根因再修复 |
| `mini-investigate` | 小型 Bug 的最小根因定位、修复与验证 |
| `security-auditor` | 安全审查，覆盖鉴权、注入、依赖风险等 |
| `feynman` | 用费曼学习法解释复杂机制 |
| `polanyi-tacit` | 分析代码背后的隐性业务和组织约束 |
| `auto-build` | 自动执行依赖安装与构建验证 |
| `agent-training-loop` | 持续执行复现、检测、执行、检查直到收敛 |
| `baseline-packager` | 将已通过行为封装为 baseline / golden master 回归保护 |
| `conversion-copywriter` | 官网、落地页、产品页和 CTA 的高转化营销文案 |
| `powerup` | AI 编程能力速成练习 |
| `insights` | 使用习惯回顾与优化建议 |
| `subagent` | 子 Agent 管理与并行任务编排 |
| `goal` | 长期任务目标管理，优先路由到宿主原生 Goal 能力 |

## 安装后验证

全局安装后，请打开一个新的宿主会话，把下面提示词复制给 AI 助手：

```text
请验证 Lotus 是否已经在当前宿主全局生效，而不是只存在于磁盘上的 Lotus 仓库中。

1. 判断你当前运行在哪个宿主中，例如 Codex、Claude Code 或其他宿主。
2. 读取当前宿主对应的全局规则文件：
   - Codex: ~/.codex/AGENTS.md
   - Claude Code: ~/.claude/CLAUDE.md
3. 确认文件顶部附近存在 Lotus 四条护栏：
   - 先想清楚，再写代码
   - 简单优先
   - 手术式修改
   - 目标驱动闭环
4. 确认文件包含 Agentic Coding 契约、Debug 规则和代码语言优先。
5. 检查当前宿主的全局 skills 目录，并确认默认 11 个 gstack 顶层 skills 存在。
6. 告诉我当前会话是否已经加载这些全局规则和 skills。
7. 如果没有加载，告诉我是否需要完全重启宿主或开启新会话。
8. 如果有缺失，请给出缺失路径、缺失项名称、复现依据和应重新运行的安装命令。
```

这段提示词只负责验证，不能让旧会话临时变成真正的全局会话。真正生效需要满足两个条件：

1. 安装器已经写入宿主全局规则文件和全局 skills。
2. 宿主开启了一个会读取这些文件的新会话。

## `/skill` 不显示时怎么排查

`AGENTS.md` 和 `CLAUDE.md` 只保存规则和路由说明，不保存 slash skill 本体。slash skills 还必须存在于宿主自己的全局 skills 目录：

- Codex: `~/.codex/skills`
- Claude Code: `~/.claude/skills`

如果 `/review`、`/qa` 或其他 gstack skills 没出现：

1. 重新运行 `install.ps1 -Global` 或 `install.sh --global`。
2. 确认 `~/.gstack/repos/gstack` 存在。
3. 确认宿主全局 skills 目录中存在对应目录。
4. 完全重启 IDE / App，让宿主重新扫描全局 skills。

如果 Windows 没有 Git Bash，安装器会写入 bootstrap skills。bootstrap skills 是真实菜单入口，但只负责提示如何补齐完整官方 gstack runtime。

## Windows 依赖说明

官方 gstack 完整运行时依赖：

- `git`
- `bash`
- `bun`
- Windows 下还需要 `node`

Windows 上的 `bash` 通常来自 [Git for Windows](https://git-scm.com/download/win)。

如果机器没有 Git Bash，或官方 gstack runtime 安装失败，`install.ps1 -Global` 仍会安装默认 11 个顶层 gstack bootstrap skills，保证 `/gstack-*` 菜单入口不缺失。安装 Git for Windows 并补齐依赖后，重新运行：

```powershell
C:\Dev\Lotus\install.ps1 -Global
```

## macOS / Codex App / Claude Code 说明

Codex App、Claude Code 和 IDE 启动的命令行有时不会加载你的 `.zprofile` / `.bashrc`，导致 `bun` 已安装但安装器找不到。Lotus 安装器会自动补充常见工具路径：

- `~/.bun/bin`
- `~/.local/bin`
- `/opt/homebrew/bin`
- `/usr/local/bin`

官方 gstack 在 macOS 上会尝试用 Homebrew 安装可选的 `coreutils`，只为了给少数命令增加 timeout 保护。Lotus 托管安装默认跳过这个可选步骤，避免全局安装卡在 Homebrew。确实需要该增强时，可以自己安装：

```bash
brew install coreutils
```

如果 GitHub 网络短暂抖动，安装器会重试官方 gstack 下载；本机已经有 `~/.gstack/repos/gstack` 时，会优先使用现有 checkout 完成 skills 同步。没有可用 checkout 时，安装器会写入 bootstrap slash skills，等网络恢复后重新运行全局安装即可替换成完整 runtime。

## Lotus 可选 Codex 插件

Lotus 也可以托管 Codex 插件市场文件。当前仓库内置一个可选 marketplace：

- `.agents/plugins/marketplace.json`

其中包含：

| Plugin | 用途 |
|---|---|
| `build-ios-apps` | iOS / SwiftUI / Xcode / Simulator 调试与预览工作流，位于 `plugins/build-ios-apps` |

`codex-security` 是 Codex 官方专有插件，不把插件运行时代码复制进 Lotus。安全审查的 Lotus 自带顶层入口仍是 `/security-auditor`；更完整的官方扫描工作流请在 Codex App 中安装或启用 Codex Security 插件。

## 仓库结构

```text
Lotus/
├── core/                 # 全局规则真源
├── skills/               # Lotus 自带 skills
├── plugins/              # 可选 Codex 插件
├── templates/            # 项目级模板
├── scripts/              # gstack 托管安装脚本
├── install.ps1           # Windows 安装器
└── install.sh            # macOS / Linux 安装器
```

## 安全与可回滚

- 覆盖前备份：安装器覆盖 `CLAUDE.md` 或 `AGENTS.md` 前会创建 `.bak`。
- 项目不被隐式修改：`-Global` / `--global` 只写全局路径，不写当前项目目录。
- 项目模板显式写入：只有运行 `-Project` / `--project` 才会写当前目录。
- 可卸载：删除对应全局规则文件和 skills 目录，或恢复 `.bak` 即可。

## 更新

进入 Lotus 长期目录后执行：

```powershell
cd C:\Dev\Lotus
git pull
.\install.ps1 -Global
```

```bash
cd ~/Dev/Lotus
git pull
./install.sh --global
```

这会刷新 Lotus 全局规则、Lotus 自带 skills、官方 gstack runtime 和默认顶层 gstack skills。项目级文件不会被自动覆盖。

## GitHub Actions 报 `Watch Upstream GStack` 失败

Lotus 使用 GitHub Actions 定时检查 `garrytan/gstack` 上游是否更新。如果 Actions 没有创建 PR 的权限，GitHub 会报：

```text
GitHub Actions is not permitted to create or approve pull requests.
```

修复方式：

1. 打开 GitHub 仓库设置。
2. 进入 `Settings -> Actions -> General -> Workflow permissions`。
3. 选择 `Read and write permissions`。
4. 勾选 `Allow GitHub Actions to create and approve pull requests`。

当前 workflow 已做容错：如果权限没开，会写入 workflow summary，不再因为无法创建 PR 而持续刷失败通知。

## 最后一张便条

Lotus 不保证 AI 永不犯错。那种保证一般写在漂亮广告里，旁边还站着一位收费很准时的人。Lotus 只做更可靠的一件事：让 agent 在犯错前先暴露假设，在动手前先写契约，在交付前先拿证据。许多工程事故到这里就不好意思继续发生了。
