#!/bin/bash

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_AGENTS="$REPO_ROOT/core/AGENTS.md"
SKILLS_DIR="$REPO_ROOT/skills"
MANAGED_GSTACK_INSTALLER="$REPO_ROOT/scripts/install-managed-gstack.sh"

# Skills that rely on "staying in current conversation" and are incompatible
# with Codex App's architecture (each skill invocation = new task context).
# These skills work via AGENTS.md rule-level recognition instead.
CODEX_EXCLUDED_SKILLS=("btw" "loop")
MANAGED_OFFICIAL_SKILLS=("gstack")

GLOBAL=0
PROJECT=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --global) GLOBAL=1 ;;
        --project) PROJECT="$2"; shift ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

backup_if_exists() {
    if [ -f "$1" ]; then
        cp "$1" "$1.bak"
        echo "    Backed up existing: $1 -> $1.bak"
    fi
}

path_exists_any() {
    for candidate in "$@"; do
        if [ -e "$candidate" ]; then
            return 0
        fi
    done
    return 1
}

verify_managed_gstack_install() {
    local missing=()

    if [ ! -d "$HOME/.gstack/repos/gstack/.git" ]; then
        missing+=("official gstack repo (~/.gstack/repos/gstack)")
    fi
    if ! path_exists_any "$HOME/.claude/skills/gstack"; then
        missing+=("Claude runtime (~/.claude/skills/gstack)")
    fi
    if ! path_exists_any "$HOME/.codex/skills/gstack-review/SKILL.md" "$HOME/.codex/skills/review/SKILL.md"; then
        missing+=("Codex skill (~/.codex/skills/gstack-review or review)")
    fi
    if ! path_exists_any "$HOME/.config/opencode/skills/gstack-review/SKILL.md" "$HOME/.config/opencode/skills/review/SKILL.md"; then
        missing+=("OpenCode skill (~/.config/opencode/skills/gstack-review or review)")
    fi
    if ! path_exists_any "$HOME/.cursor/skills/gstack-review/SKILL.md" "$HOME/.cursor/skills/review/SKILL.md"; then
        missing+=("Cursor skill (~/.cursor/skills/gstack-review or review)")
    fi

    if [ "${#missing[@]}" -gt 0 ]; then
        echo "Official gstack install is incomplete. Missing:" >&2
        for item in "${missing[@]}"; do
            echo "  - $item" >&2
        done
        echo "Lotus global rules live in AGENTS/CLAUDE files, but slash skills must exist in each host's global skills directory." >&2
        return 1
    fi
}

copy_lotus_skills() {
    local target_dir="$1"
    shift
    mkdir -p "$target_dir"
    for skill_file in "$SKILLS_DIR"/*.md; do
        local skill_name
        skill_name="$(basename "$skill_file" .md)"
        local should_skip=false
        for excluded in "$@"; do
            if [ "$skill_name" = "$excluded" ]; then
                should_skip=true
                break
            fi
        done
        if [ "$should_skip" = false ]; then
            cp "$skill_file" "$target_dir/"
        fi
    done
}

# Convert a Lotus skill .md file into a Codex-compatible SKILL.md directory.
# Codex expects: ~/.codex/skills/<name>/SKILL.md with YAML frontmatter containing
# name, description, and allowed-tools fields.
convert_to_codex_skill() {
    local source_file="$1"
    local target_dir="$2"

    local content
    content=$(cat "$source_file")

    local skill_name=""
    local description=""

    if echo "$content" | head -1 | grep -q "^---"; then
        local frontmatter
        frontmatter=$(echo "$content" | sed -n '/^---$/,/^---$/p' | sed '1d;$d')
        skill_name=$(echo "$frontmatter" | grep '^name:' | sed 's/^name:[[:space:]]*//' || true)
        description=$(echo "$frontmatter" | grep '^description:' | sed 's/^description:[[:space:]]*//' || true)
    fi

    if [ -z "$skill_name" ]; then
        skill_name=$(basename "$source_file" .md)
    fi
    if [ -z "$description" ]; then
        description="Lotus skill: $skill_name"
    fi

    local allowed_tools
    case "$skill_name" in
        auto-build)     allowed_tools="Bash\n  - Read" ;;
        btw)            allowed_tools="Read\n  - AskUserQuestion" ;;
        feynman)        allowed_tools="Read\n  - AskUserQuestion" ;;
        polanyi-tacit)  allowed_tools="Read\n  - AskUserQuestion" ;;
        powerup)        allowed_tools="Read\n  - AskUserQuestion" ;;
        insights)       allowed_tools="Read\n  - Bash\n  - Grep\n  - Glob" ;;
        loop)           allowed_tools="Bash\n  - Read\n  - AskUserQuestion" ;;
        subagent)       allowed_tools="Bash\n  - Read\n  - Write\n  - Edit\n  - Grep\n  - Glob\n  - AskUserQuestion" ;;
        gstack)         allowed_tools="Bash\n  - Read\n  - Write\n  - Edit\n  - Grep\n  - Glob\n  - AskUserQuestion" ;;
        *)              allowed_tools="Read\n  - AskUserQuestion" ;;
    esac

    local body
    body=$(echo "$content" | sed '1{/^---$/!q}; 1,/^---$/d')

    local skill_dir="$target_dir/$skill_name"
    mkdir -p "$skill_dir"

    cat > "$skill_dir/SKILL.md" <<CODEX_EOF
---
name: $skill_name
description: |
  $description
allowed-tools:
  - $(echo -e "$allowed_tools")
---
$body
CODEX_EOF

    echo "    Converted skill: $skill_name"
}

if [ "$GLOBAL" -eq 1 ]; then
    echo -e "\033[0;36mInstalling Global Rules & Skills...\033[0m"

    mkdir -p ~/.gemini/antigravity/skills
    backup_if_exists ~/.gemini/GEMINI.md
    cp "$CORE_AGENTS" ~/.gemini/GEMINI.md
    copy_lotus_skills ~/.gemini/antigravity/skills "${MANAGED_OFFICIAL_SKILLS[@]}"
    echo "  Antigravity & Gemini CLI configured"

    mkdir -p ~/.claude/skills
    backup_if_exists ~/.claude/CLAUDE.md
    cp "$CORE_AGENTS" ~/.claude/CLAUDE.md
    copy_lotus_skills ~/.claude/skills "${MANAGED_OFFICIAL_SKILLS[@]}"
    echo "  Claude Code configured"

    mkdir -p ~/.config/opencode
    backup_if_exists ~/.config/opencode/AGENTS.md
    cp "$CORE_AGENTS" ~/.config/opencode/AGENTS.md
    echo "  OpenCode CLI configured"

    mkdir -p ~/.windsurf/rules
    backup_if_exists ~/.windsurf/rules/global.md
    cp "$CORE_AGENTS" ~/.windsurf/rules/global.md
    echo "  Windsurf Cascade configured"

    mkdir -p ~/.codex/skills
    backup_if_exists ~/.codex/AGENTS.md
    cp "$CORE_AGENTS" ~/.codex/AGENTS.md

    for excluded in "${CODEX_EXCLUDED_SKILLS[@]}" "${MANAGED_OFFICIAL_SKILLS[@]}"; do
        if [ -d "$HOME/.codex/skills/$excluded" ]; then
            rm -rf "$HOME/.codex/skills/$excluded"
            echo "    Removed incompatible skill: $excluded"
        fi
    done

    for skill_file in "$SKILLS_DIR"/*.md; do
        skill_name=$(basename "$skill_file" .md)
        is_excluded=false
        for excluded in "${CODEX_EXCLUDED_SKILLS[@]}" "${MANAGED_OFFICIAL_SKILLS[@]}"; do
            if [ "$skill_name" = "$excluded" ]; then
                is_excluded=true
                break
            fi
        done
        if [ "$is_excluded" = true ]; then
            echo "    Skipped (managed elsewhere or in-context only): $skill_name"
        else
            convert_to_codex_skill "$skill_file" ~/.codex/skills
        fi
    done
    echo "  Codex CLI configured (rules + Lotus-only compatible skills)"

    mkdir -p ~/.cursor/rules
    CURSOR_FILE=~/.cursor/rules/lotus.mdc
    backup_if_exists "$CURSOR_FILE"
    cat > "$CURSOR_FILE" <<CURSOR_EOF
---
description: Lotus GStack Engineering Protocol - Global rules and workflow standards
globs:
alwaysApply: true
---

$(cat "$CORE_AGENTS")
CURSOR_EOF
    echo "  Cursor configured"

    backup_if_exists ~/.aider.conf.yml
    cat <<EOF > ~/.aider.conf.yml
read:
  - CONVENTIONS.md
  - AGENTS.md
EOF
    echo "  Aider AI configured"

    echo "  Installing official gstack upstream..."
    if ! bash "$MANAGED_GSTACK_INSTALLER"; then
        echo "Official gstack installation failed. Lotus rules were written, but slash skills were not fully installed." >&2
        exit 1
    fi
    verify_managed_gstack_install
    echo "  Official gstack configured for Claude/Codex/OpenCode/Cursor"

    echo ""
    echo -e "\033[0;32mGlobal installation completed successfully!\033[0m"
    echo -e "\033[0;33mIf any existing configs were overwritten, .bak backups have been created.\033[0m"
    echo ""
    echo -e "\033[0;36mCodex note:\033[0m"
    echo "  - Global rules were installed to ~/.codex/AGENTS.md and are auto-loaded in local repos."
    echo "  - --global does not create AGENTS.md inside each project folder."
    echo "  - Run ./install.sh --project nextjs|vite|html inside a project when you want local AGENTS.md and .agents/rules/ files."
    echo "  - Official gstack is managed at ~/.gstack/repos/gstack and kept auto-updatable."
    echo "  - Slash skills live in host-specific global skills folders such as ~/.codex/skills, ~/.claude/skills, ~/.cursor/skills, and ~/.config/opencode/skills."
fi

if [ -n "$PROJECT" ]; then
    echo -e "\033[0;36mInstalling Project Template: $PROJECT...\033[0m"
    TEMPLATE_DIR="$REPO_ROOT/templates/$PROJECT"

    if [ ! -d "$TEMPLATE_DIR" ]; then
        echo -e "\033[0;31mTemplate '$PROJECT' not found.\033[0m"
        exit 1
    fi

    cp -R "$TEMPLATE_DIR"/* .
    cp -R "$TEMPLATE_DIR"/.[!.]* . 2>/dev/null || true

    CONVENTIONS_FILE="$REPO_ROOT/core/CONVENTIONS.md"
    if [ -f "$CONVENTIONS_FILE" ]; then
        cp "$CONVENTIONS_FILE" .
    fi

    echo -e "\033[0;32mProject template '$PROJECT' applied to current directory.\033[0m"
    echo -e "\033[0;33mRemember to adjust the design system and tech stack files in .agents/rules/.\033[0m"
fi

if [ "$GLOBAL" -eq 0 ] && [ -z "$PROJECT" ]; then
    echo -e "\033[0;36mLotus Installer\033[0m"
    echo "--------------------"
    echo "Usage:"
    echo "  ./install.sh --global              (Install global rules to all IDE/CLI folders)"
    echo "  ./install.sh --project <name>      (Apply template to current directory)"
    echo ""
    echo "Available templates: nextjs, vite, html"
fi
