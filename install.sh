#!/bin/bash

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_AGENTS="$REPO_ROOT/core/AGENTS.md"
SKILLS_DIR="$REPO_ROOT/skills"

# Skills that rely on "staying in current conversation" and are incompatible
# with Codex App's architecture (each skill invocation = new task context).
# These skills work via AGENTS.md rule-level recognition instead.
CODEX_EXCLUDED_SKILLS=("btw" "loop")

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

# Backup helper: creates a .bak copy if the target file already exists
backup_if_exists() {
    if [ -f "$1" ]; then
        cp "$1" "$1.bak"
        echo "    ⚠️  Backed up existing: $1 → $1.bak"
    fi
}

# Convert a Lotus skill .md file into a Codex-compatible SKILL.md directory.
# Codex expects: ~/.codex/skills/<name>/SKILL.md with YAML frontmatter containing
# name, description, and allowed-tools fields.
convert_to_codex_skill() {
    local source_file="$1"
    local target_dir="$2"

    local content
    content=$(cat "$source_file")

    # Parse frontmatter to extract name and description
    local skill_name=""
    local description=""

    if echo "$content" | head -1 | grep -q "^---"; then
        local frontmatter
        frontmatter=$(echo "$content" | sed -n '/^---$/,/^---$/p' | sed '1d;$d')
        skill_name=$(echo "$frontmatter" | grep '^name:' | sed 's/^name:[[:space:]]*//')
        description=$(echo "$frontmatter" | grep '^description:' | sed 's/^description:[[:space:]]*//')
    fi

    # Fallback: derive name from filename if not in frontmatter
    if [ -z "$skill_name" ]; then
        skill_name=$(basename "$source_file" .md)
    fi
    if [ -z "$description" ]; then
        description="Lotus skill: $skill_name"
    fi

    # Determine allowed-tools based on skill type
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

    # Extract body (everything after frontmatter)
    local body
    body=$(echo "$content" | sed '1{/^---$/!q}; 1,/^---$/d')

    # Build Codex-compatible SKILL.md content
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

    echo "    📦 Converted skill: $skill_name"
}

if [ "$GLOBAL" -eq 1 ]; then
    echo -e "\033[0;36mInstalling Global Rules & Skills...\033[0m"

    # 1. Antigravity / Gemini CLI
    mkdir -p ~/.gemini/antigravity/skills
    backup_if_exists ~/.gemini/GEMINI.md
    cp "$CORE_AGENTS" ~/.gemini/GEMINI.md
    cp "$SKILLS_DIR"/* ~/.gemini/antigravity/skills/
    echo "  ✅ Antigravity & Gemini CLI configured"

    # 2. Claude Code
    mkdir -p ~/.claude/skills
    backup_if_exists ~/.claude/CLAUDE.md
    cp "$CORE_AGENTS" ~/.claude/CLAUDE.md
    cp "$SKILLS_DIR"/* ~/.claude/skills/
    echo "  ✅ Claude Code configured"

    # 3. OpenCode
    mkdir -p ~/.config/opencode
    backup_if_exists ~/.config/opencode/AGENTS.md
    cp "$CORE_AGENTS" ~/.config/opencode/AGENTS.md
    echo "  ✅ OpenCode CLI configured"

    # 4. Windsurf
    mkdir -p ~/.windsurf/rules
    backup_if_exists ~/.windsurf/rules/global.md
    cp "$CORE_AGENTS" ~/.windsurf/rules/global.md
    echo "  ✅ Windsurf Cascade configured"

    # 5. Codex CLI — Rules + Skills (auto-convert to Codex SKILL.md format)
    #    Skills that require "in-context" behavior (btw, loop, subagent, insights)
    #    are excluded — they work via AGENTS.md rules instead of /commands.
    mkdir -p ~/.codex/skills
    backup_if_exists ~/.codex/AGENTS.md
    cp "$CORE_AGENTS" ~/.codex/AGENTS.md

    # Clean up previously deployed incompatible skills
    for excluded in "${CODEX_EXCLUDED_SKILLS[@]}"; do
        if [ -d "$HOME/.codex/skills/$excluded" ]; then
            rm -rf "$HOME/.codex/skills/$excluded"
            echo "    🗑️  Removed incompatible skill: $excluded"
        fi
    done

    # Convert compatible Lotus skills to Codex directory format
    for skill_file in "$SKILLS_DIR"/*.md; do
        skill_name=$(basename "$skill_file" .md)
        # Check if skill is in excluded list
        is_excluded=false
        for excluded in "${CODEX_EXCLUDED_SKILLS[@]}"; do
            if [ "$skill_name" = "$excluded" ]; then
                is_excluded=true
                break
            fi
        done
        if [ "$is_excluded" = true ]; then
            echo "    ⏭️  Skipped (in-context only): $skill_name"
        else
            convert_to_codex_skill "$skill_file" ~/.codex/skills
        fi
    done
    echo "  ✅ Codex CLI configured (rules + compatible skills)"

    # 6. Cursor (Global Rules)
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
    echo "  ✅ Cursor configured"

    # 7. Aider
    backup_if_exists ~/.aider.conf.yml
    cat <<EOF > ~/.aider.conf.yml
read:
  - CONVENTIONS.md
  - AGENTS.md
EOF
    echo "  ✅ Aider AI configured"

    echo ""
    echo -e "\033[0;32mGlobal installation completed successfully!\033[0m"
    echo -e "\033[0;33mIf any existing configs were overwritten, .bak backups have been created.\033[0m"
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
