# Lotus

> The Ultimate "Out-of-the-Box" Universal Mindset Protocol for AI Coding Agents.

Lotus continuously leverages the **latest, safest, and most stable global agent management mechanisms**. By applying these rules directly to the highest global configurations on your local machine, Lotus governs the behavior of your AI agents across **all** your projects simultaneously. 

You instantly get professional workflows, zero-silence error handling, and high-standard design paradigms—without ever needing to write repetitive prompt instructions or perform tedious setups in advance. Write your engineering "Constitution" once, and deploy it everywhere.

## ✨ Why Choose Lotus?

- 🧠 **Mindset Over Scripts**: Lotus teaches your AI *how to think* like a Senior Architect, PM, and QA. It enforces the "GStack Workflow" (CEO Review -> Eng Review -> Code -> Global Review).
- 🌍 **Write Once, Run Everywhere**: A Single Source of Truth (`core/AGENTS.md`) automatically adapts and installs into Claude Code, Antigravity, Cursor, Windsurf, Copilot, and more.
- 🚧 **Zero Silent Failures**: Built-in quality gates guarantee your generated code includes proper user feedback, loading states, and aesthetic consistency.
- ⚡ **Seamless Wake-Up Calls (`@` and `/`)**: Summon specific expert personas and architectural overviews dynamically mid-chat using platform-native triggers.
- 🗑️ **Anti-Plugin Bloat**: 95% of plugins and skills on the market become stale junk within weeks. Lotus takes the opposite approach—every skill is **hand-curated, battle-tested, and minimally sufficient**. We only ship what survives real production workflows.
- 🔄 **Continuously Updated, Frontier-Tracked**: Lotus is a **living protocol**, not a static config dump. We actively track bleeding-edge releases from **Claude Code, Codex CLI, and top-tier open-source agent frameworks**, and fold the safest, most proven patterns back into `core/AGENTS.md` so your rules never go stale.

## 🚀 Zero-Foundation Quick Start (For Beginners)

Never used terminal commands? No problem.
If you are starting a new project or setting up a brand-new computer, simply **copy and paste the following prompt** directly into your AI assistant (e.g., Cursor, Claude, Antigravity) and it will handle the entire installation for you!

> "This is a brand new project. Please execute the following initialization steps locally:
> 1. Clone `https://github.com/Bronc-X/Lotus.git` into a temporary directory in the system.
> 2. Determine my OS. Run the installer inside the temporary repo to apply the `nextjs` template to my current directory (Windows: `install.ps1 -Project nextjs`, Mac/Linux: `install.sh --project nextjs`).
> 3. To make sure you retain our workflows globally on this new machine, also run the global install flag (Windows: `install.ps1 -Global`, Mac/Linux: `install.sh --global`).
> 4. Once finished, delete the temporary cloned repository.
> 5. Carefully read the newly generated `AGENTS.md` and `.agents/rules/` in my current directory to understand my coding standards and design language. Let me know when you are ready."

*(Note: Change `nextjs` to `vite` or `html` depending on your project type).*

## 🔌 Manual Installation

If you prefer to install it manually:

### 1. Global Installation (Configure all your IDEs)
**Windows (PowerShell):**
```powershell
.\install.ps1 -Global
```
**macOS / Linux:**
```bash
./install.sh --global
```

### 2. New Project Initialization
Inside your empty new project folder, inject your preferred technology stack:
**Windows (PowerShell):**
```powershell
C:\path\to\Lotus\install.ps1 -Project nextjs
```
**macOS / Linux:**
```bash
/path/to/Lotus/install.sh --project nextjs
```

## 🎯 Tool Wake-Up Mechanisms (Skills)

You do not need to memorize complicated prompts; just remember a few simple commands. You can dynamically **wake up** specific expert personas exactly when you need them.

> 💡 **Why so few?** We deliberately keep the skill count small. Every skill here has survived months of real-world iteration across dozens of production projects. If a skill doesn't consistently deliver value, it gets **removed**, not "deprecated". Quality over quantity, always.

**How to Wake Them Up:**
The trigger syntax depends on whether you are using a visual IDE or a command-line agent:
* **For GUI IDEs (Cursor / Windsurf)**: Use the slash command `/name` (e.g., `/gstack`).
* **For CLI Agents (Claude Code / Antigravity / Aider)**: Use the mention format `@name` (e.g., `@gstack`).

### Available Wakes:

1. **[`@gstack` / `/gstack`](https://github.com/Bronc-X/Lotus/blob/main/skills/gstack.md)**
   * **What it does**: Triggers the elite multi-role developer workflow. The AI will explicitly switch between Product Manager, Architect, Builder, and QA before writing code to ensure system integrity.
2. **[`@feynman` / `/feynman`](https://github.com/Bronc-X/Lotus/blob/main/skills/feynman.md)**
   * **What it does**: Forces the AI to use the Feynman Technique. It will break down and explain complex bugs or physical gear mechanisms using absolute layman terms before attempting to apply a fix.
3. **[`@polanyi-tacit` / `/polanyi-tacit`](https://github.com/Bronc-X/Lotus/blob/main/skills/polanyi-tacit.md)**
   * **What it does**: Wakes up a deeply analytical mode. The AI deliberately looks for architectural compromises, "defensive" code blocks, and unspoken organizational debt hidden behind the scenes.
4. **[`@auto-build` / `/auto-build`](https://github.com/Bronc-X/Lotus/blob/main/skills/auto-build.md)**
   * **What it does**: Silently performs an `npm install`, runs `npm run build`, and checks for compilation errors independently without ever asking for your permission.
5. **[`@vibe` / `/vibe`](https://github.com/Bronc-X/Lotus/blob/main/skills/vibe.md)**
   * **What it does**: Vibe Coding mode. Delegates technical aesthetics entirely to the AI, prioritizing visual elegance and silent, rapid iterations without asking boilerplate questions.

## 🏗️ Architecture (Hub-and-Spoke)

```text
Lotus/
├── core/                ← 🔶 Core Truth (Universal workflows, quality gates)
├── skills/              ← 🔶 Wake-up Skills (@gstack, @feynman, etc.)
├── templates/           ← 🔶 Tech stacks (Next.js, Vite) & Design languages
└── install scripts      ← 🤖 Auto-generates platform-specific IDE adapters
```

## 🔄 Update Philosophy

Lotus is **not a "set and forget" config**. It is a living, evolving protocol.

- **Primary tracking targets**: [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [Codex CLI](https://github.com/openai/codex), and battle-tested open-source agent frameworks from top contributors.
- **What we track**: New global rule injection mechanisms, safer permission models, improved context-window strategies, and proven workflow patterns.
- **What we discard**: Hype-driven features, unstable APIs, and anything that adds complexity without measurable value.
- **How to stay current**: Simply `git pull` and re-run the installer. Your global rules across all IDEs will be refreshed in seconds.

```bash
# Stay up to date in one command
cd /path/to/Lotus && git pull && ./install.sh --global
```
```powershell
# Windows equivalent
cd C:\path\to\Lotus; git pull; .\install.ps1 -Global
```
