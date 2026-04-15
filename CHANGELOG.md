# Changelog

All notable changes to this project will be documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Upgrade Guide

**Upgrading is safe and non-destructive:**
1. `git pull` (or re-clone) the latest Lotus
2. Re-run `./install.ps1 -Global` (Windows) or `./install.sh --global` (macOS/Linux)
3. Done — your existing projects are untouched

**What gets updated:** Global rules (`~/.codex/AGENTS.md`, `~/.claude/CLAUDE.md`, etc.) and global skills.
**What is NOT touched:** Project-level files (anything in your project's `.agents/`, `AGENTS.md`, `.cursor/rules/`). These were created by `--project` and are yours to manage.

---

## [1.0.0] - 2026-04-15

### 🎉 Initial Release

**Core Protocol:**
- GStack Engineering Protocol v1.0 (`core/AGENTS.md`)
- Intent Router: 4 scenarios (Feature / Bug / UI / Refactor)
- Quality Gates: Coding + Design checklists
- Universal review commands

**Task-level Skills (7):**
- `@gstack` — Full engineering workflow with 5 role personas
- `@feynman` — Feynman technique for zero-jargon explanation
- `@polanyi-tacit` — Tacit knowledge archaeology in codebases
- `@auto-build` — Automated `npm install` → `npm run build`
- `@powerup` — 10-level interactive tutorial system
- `@insights` — Usage habit analysis and optimization report
- `@subagent` — Multi-agent task orchestration

**In-context Skills (2):**
- `@btw` — Side-channel quick Q&A without interrupting main task
- `@loop` — In-session periodic task runner

**Platform Support:**
- Codex CLI/App (with auto-format conversion, BOM-free UTF-8)
- Claude Code
- Antigravity / Gemini CLI
- Cursor (`.mdc` global rules)
- Windsurf Cascade
- OpenCode CLI
- Aider

**Project Templates:**
- Next.js
- Vite
- HTML

**Installers:**
- `install.ps1` (Windows)
- `install.sh` (macOS/Linux)
- Auto-backup of existing configs (`.bak` files)
