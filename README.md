# Lotus

> The Ultimate "Out-of-the-Box" Universal Mindset Protocol for AI Coding Agents.

Forget writing repetitive prompt instructions. Lotus is a unified Hub-and-Spoke rule repository that instantly injects professional developer workflows, zero-silence error handling, and high-standard design paradigms into all your AI agents globally. Write your engineering "Constitution" once, and deploy it everywhere.

## ✨ Why Choose Lotus?

- 🧠 **Mindset Over Scripts**: Lotus teaches your AI *how to think* like a Senior Architect, PM, and QA. It enforces the "GStack Workflow" (CEO Review -> Eng Review -> Code -> Global Review).
- 🌍 **Write Once, Run Everywhere**: A Single Source of Truth (`core/AGENTS.md`) automatically adapts and installs into Claude Code, Antigravity, Cursor, Windsurf, Copilot, and more.
- 🚧 **Zero Silent Failures**: Built-in quality gates guarantee your generated code includes proper user feedback, loading states, and aesthetic consistency.
- ⚡ **Seamless Wake-Up Calls (`@` and `/`)**: Summon specific expert personas and architectural overviews dynamically mid-chat using platform-native triggers.

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

Once Lotus is installed globally, it registers "Skills" in your agents. You can dynamically **wake up** these skills by typing `@` or `/` in your chat window, depending on your AI editor:

* **In Claude Code / Antigravity / Aider**: Type `@name` (e.g., `@gstack`).
* **In Cursor / Windsurf**: Type `/name` (e.g., `/gstack`).

### Available Wakes:

1. **`@gstack` / `/gstack`**
   * **What it does**: Triggers the elite multi-role developer workflow. The AI will explicitly switch between Product Manager, Architect, Builder, and QA before writing code.
2. **`@feynman` / `/feynman`**
   * **What it does**: Forces the AI to use the Feynman Technique to explain a complex bug or physical gear mechanism using absolute layman terms before fixing it.
3. **`@polanyi-tacit` / `/polanyi-tacit`**
   * **What it does**: Wakes up deeply analytical mode. The AI looks for architectural compromises, "defensive" code blocks, and unspoken organizational debt.
4. **`@auto-build` / `/auto-build`**
   * **What it does**: Silently performs an `npm install`, runs `npm run build`, and checks for compilation errors without asking you for permission.
5. **`@vibe` / `/vibe`**
   * **What it does**: Vibe Coding mode. Delegate technical aesthetics entirely to the AI, prioritizing visual elegance and silent iteration without asking boilerplate questions.

## 🏗️ Architecture (Hub-and-Spoke)

```text
Lotus/
├── core/                ← 🔶 Core Truth (Universal workflows, quality gates)
├── skills/              ← 🔶 Wake-up Skills (@gstack, @feynman, etc.)
├── templates/           ← 🔶 Tech stacks (Next.js, Vite) & Design languages
└── install scripts      ← 🤖 Auto-generates platform-specific IDE adapters
```
