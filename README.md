# Lotus

Lotus 是一套全局 Agent 工程规则与安装器。它的目标很简单：把你希望 AI 编码助手长期遵守的工作方式，安装到受托管宿主的全局配置中，让新项目自动继承这些规则。

Lotus 当前托管两类内容：

1. Lotus 全局规则：写入 Claude Code 与 Codex 的全局规则文件。
2. 官方 gstack 运行时：从 [garrytan/gstack](https://github.com/garrytan/gstack) 安装并同步默认顶层 skills。

Lotus 仓库不再内置 gstack 快照。凡是 gstack 能力，官方上游 `garrytan/gstack` 是唯一真源。

## 管理范围

| 宿主 | 全局安装命令 | Lotus 写入位置 | 说明 |
|---|---|---|---|
| Claude Code | `install.ps1 -Global` / `install.sh --global` | `~/.claude/CLAUDE.md`、`~/.claude/skills` | 受托管 |
| Codex CLI / Codex App | `install.ps1 -Global` / `install.sh --global` | `~/.codex/AGENTS.md`、`~/.codex/skills` | 受托管 |

其他宿主不由 Lotus 安装器自动写入全局路径。如果该宿主支持手动全局规则，请直接导入 [core/AGENTS.md](core/AGENTS.md)。

## Lotus 四条执行护栏

全局规则文件顶部会注入四条最高优先级护栏：

1. Think Before Coding：先确认目标、边界、假设、成功标准，再写代码。
2. Simplicity First：只写解决当前问题所需的最小代码，不提前抽象。
3. Surgical Changes：只改和当前目标直接相关的文件、函数和行。
4. Goal-Driven Execution：把任务改写成可验证目标，再实现并验证。

这些不是提示词装饰，而是每次会话开始时宿主自动读取的全局规则。安装完成后，需要重启宿主或开启新会话，旧会话不会自动获得新的全局规则。

## 零基础快速安装提示词

如果你不熟悉命令行，可以把下面整段提示词复制给你的 AI 编码助手。它应该在你的本地机器执行这些步骤。

```text
这是一个全新项目目录。请在本地执行以下初始化步骤：

1. 先记录当前项目目录的绝对路径，不要在克隆 Lotus 时丢失这个路径。
2. 将 https://github.com/Bronc-X/Lotus.git 克隆到系统临时目录中的一个新目录。
3. 判断当前操作系统。
4. 在临时 Lotus 仓库中运行项目模板安装，把 nextjs 模板应用到我当前项目目录：
   - Windows PowerShell: 使用完整路径执行 `install.ps1 -Project nextjs`
   - macOS/Linux: 使用 `bash install.sh --project nextjs`，不要依赖 `install.sh` 是否有可执行权限
5. 为了让这台机器以后所有受托管宿主都继承 Lotus 规则，再运行全局安装，并使用非交互确认参数避免卡住：
   - Windows PowerShell: `install.ps1 -Global -Force`
   - macOS/Linux: `bash install.sh --global --yes`
6. 完成后删除刚才克隆的临时 Lotus 仓库。
7. 仔细阅读当前项目目录中新生成的 AGENTS.md 和 .agents/rules/，确认你理解本项目的编码标准、技术栈约束和设计语言。
8. 验证全局规则与 skills 已写入宿主目录：
   - Codex: `~/.codex/AGENTS.md` 和 `~/.codex/skills`
   - Claude Code: `~/.claude/CLAUDE.md` 和 `~/.claude/skills`
9. 确认至少存在 Lotus 自带 skills（例如 `image-2`、`taste-skill`）和默认 gstack 顶层入口（例如 `gstack`、`gstack-qa` 或 Windows/网络失败时的 bootstrap 入口）。
10. 告诉我当前宿主是否需要完全重启或开启新会话，才能加载刚写入的全局规则和全局 skills。
11. 最后告诉我安装是否成功；如果失败，给出失败命令、错误原文、已写入了哪些 fallback/bootstrap 入口，以及下一步修复建议。
```

如果项目不是 Next.js，把 `nextjs` 改成 `vite` 或 `html`。

## 手动安装

### 第 0 步：克隆 Lotus

选择一个长期保存 Lotus 的目录。以后更新 Lotus 时就在这里执行 `git pull`。

Windows PowerShell：

```powershell
git clone https://github.com/Bronc-X/Lotus.git C:\Dev\Lotus
```

macOS / Linux：

```bash
git clone https://github.com/Bronc-X/Lotus.git ~/Dev/Lotus
```

### 第 1 步：全局安装

Windows PowerShell：

```powershell
C:\Dev\Lotus\install.ps1 -Global
```

macOS / Linux：

```bash
~/Dev/Lotus/install.sh --global
# 如果下载方式丢失了可执行权限，也可以用：
bash ~/Dev/Lotus/install.sh --global
```

这一步会：

1. 写入 Claude Code 全局规则：`~/.claude/CLAUDE.md`
2. 写入 Codex 全局规则：`~/.codex/AGENTS.md`
3. 安装 Lotus 自带 skills。
4. 安装或更新官方 gstack 到 `~/.gstack/repos/gstack`。
5. 同步默认顶层 gstack skills 到 `~/.claude/skills` 和 `~/.codex/skills`。

如果已存在全局规则文件，安装器会先创建 `.bak` 备份，再覆盖。无人值守安装可以使用：

Windows：

```powershell
C:\Dev\Lotus\install.ps1 -Global -Force
```

macOS / Linux：

```bash
~/Dev/Lotus/install.sh --global --yes
```

### 第 2 步：项目模板安装，可选

如果你希望当前项目目录里也出现项目级规则文件，例如 `AGENTS.md` 和 `.agents/rules/`，在项目目录执行：

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

全局安装不会在每个项目目录自动生成 `AGENTS.md`。Codex 会自动继承 `~/.codex/AGENTS.md`，Claude Code 会自动继承 `~/.claude/CLAUDE.md`。项目级模板是额外叠加层，只在你主动运行 `-Project` / `--project` 时写入当前项目。

## Windows 依赖说明

官方 gstack 完整运行时依赖：

- `git`
- `bash`
- `bun`
- Windows 下还需要 `node`

Windows 上的 `bash` 通常来自 [Git for Windows](https://git-scm.com/download/win)。

如果机器没有 Git Bash，或官方 gstack runtime 安装失败，`install.ps1 -Global` 仍会安装默认 11 个顶层 gstack bootstrap skills，保证 `/gstack-*` 菜单入口不缺失。macOS / Linux 的 `install.sh --global` 也会在官方 runtime 下载失败时写入同样的 bootstrap 入口。安装 Git for Windows 并补齐依赖后，重新运行：

```powershell
C:\Dev\Lotus\install.ps1 -Global
```

重新运行后，bootstrap 入口会被完整官方 gstack 运行时替换，并恢复官方自动更新能力。

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

## 默认暴露的 gstack 顶层 skills

默认 `core` profile 会暴露 11 个顶层 gstack skills：

- `gstack`
- `gstack-office-hours`
- `gstack-plan-ceo-review`
- `gstack-plan-design-review`
- `gstack-plan-eng-review`
- `gstack-design-review`
- `gstack-review`
- `gstack-investigate`
- `gstack-browse`
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

Windows：

```powershell
C:\Dev\Lotus\install.ps1 -Global -GstackProfile design
```

macOS / Linux：

```bash
~/Dev/Lotus/install.sh --global --gstack-profile design
```

## 安装后验证提示词

全局安装后，请打开一个新的宿主会话，把下面提示词复制给 AI 助手：

```text
请验证 Lotus 是否已经在当前宿主全局生效，而不是只存在于磁盘上的 Lotus 仓库中。

请按以下步骤检查：

1. 判断你当前运行在哪个宿主中，例如 Codex、Claude Code 或其他宿主。
2. 读取当前宿主对应的全局规则文件：
   - Codex: ~/.codex/AGENTS.md
   - Claude Code: ~/.claude/CLAUDE.md
3. 确认文件顶部附近存在 Lotus 四条执行护栏：
   - Think Before Coding
   - Simplicity First
   - Surgical Changes
   - Goal-Driven Execution
4. 检查当前宿主的全局 skills 目录，并确认默认 11 个 gstack 顶层 skills 存在：
   - gstack
   - gstack-office-hours
   - gstack-plan-ceo-review
   - gstack-plan-design-review
   - gstack-plan-eng-review
   - gstack-design-review
   - gstack-review
   - gstack-investigate
   - gstack-browse
   - gstack-qa
   - gstack-ship
5. 告诉我当前会话是否已经加载这些全局规则和 skills。
6. 如果没有加载，告诉我是否需要完全重启宿主或开启新会话。
7. 如果有缺失，请给出缺失路径、缺失项名称、复现依据和应重新运行的安装命令。
```

这段提示词只负责验证，不能让旧会话“临时变成”真正的全局会话。真正生效需要满足两个条件：

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

## 常用 Lotus 自带 skills

这些是 Lotus 仓库自身提供的跨平台 skills。官方 gstack skills 由 `garrytan/gstack` 提供。全局安装或更新 Lotus 后，下面这些 skill 会写入受托管宿主的全局 skills 目录；重启宿主后即可用 `/skill-name` 调用，例如 `/taste-skill`、`/image-2`。

| Skill | 用途 |
|---|---|
| `test-driven-development` | 严格红绿重构，先写失败测试再写实现 |
| `frontend-design` | 前端审美与交互质量约束 |
| `taste-skill` | Taste Skill 前端审美与实现质量约束，强化布局、字体、动效、间距和组件完成度，来源于 `Leonxlnx/taste-skill` |
| `image-2` | GPT Image 2 生图与改图入口，用于图片生成、图片编辑、风格迁移、换背景、透明素材和批量视觉资产 |
| `ai-progress-workspace` | 搭建带真实 AI 工具进度、中间生成工作区和结构化 artifact 的 Agent 产品 |
| `web-to-design-md` | 从参考网页、品牌资料、需求文档生成结构化 `design.md` |
| `debugging-strategies` | 系统性排错，先定位根因再修复 |
| `security-auditor` | 安全审查，覆盖鉴权、注入、依赖风险等 |
| `feynman` | 用费曼学习法解释复杂机制 |
| `polanyi-tacit` | 分析代码背后的隐性业务和组织约束 |
| `auto-build` | 自动执行依赖安装与构建验证 |
| `agent-training-loop` | 机器学习式 Agent 编程循环，持续执行复现、检测、执行、检查直到收敛 |
| `baseline-packager` | 将当前已通过行为封装为 baseline / golden master 回归保护 |
| `conversion-copywriter` | 官网、落地页、产品页和 CTA 的高转化营销文案 |
| `powerup` | AI 编程能力速成练习 |
| `insights` | 使用习惯回顾与优化建议 |
| `subagent` | 子 Agent 管理与并行任务编排 |

## 仓库结构

```text
Lotus/
├── core/                 # 全局规则真源
├── skills/               # Lotus 自带 skills
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

Windows：

```powershell
cd C:\Dev\Lotus
git pull
.\install.ps1 -Global
```

macOS / Linux：

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
