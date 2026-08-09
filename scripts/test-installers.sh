#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CORE_GSTACK_SKILLS=(
  "gstack"
  "gstack-office-hours"
  "gstack-investigate"
  "gstack-ship"
)

CLAUDE_GSTACK_SKILLS=(
  "gstack"
  "office-hours"
  "investigate"
  "browse"
  "ship"
)

HIDDEN_TOP_LEVEL_SKILLS=(
  "brandkit"
  "full-output-enforcement"
  "gstack-plan-ceo-review"
  "gstack-plan-design-review"
  "gstack-plan-eng-review"
  "imagegen-frontend-mobile"
  "imagegen-frontend-web"
  "imagegen"
  "openai-docs"
  "plugin-creator"
  "skill-creator"
  "ios-ui-centering-fix"
  "skill-installer"
)

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_file_contains() {
  local file="$1"
  local pattern="$2"

  [ -f "$file" ] || fail "missing file: $file"
  grep -q "$pattern" "$file" || fail "expected '$pattern' in $file"
}

copy_repo_fixture() {
  local fixture="$1"

  mkdir -p "$fixture"
  cp "$ROOT/install.sh" "$fixture/install.sh"
  cp "$ROOT/install.ps1" "$fixture/install.ps1"
  cp -R "$ROOT/core" "$fixture/core"
  cp -R "$ROOT/skills" "$fixture/skills"
  mkdir -p "$fixture/scripts"
}

write_success_gstack_stub() {
  local script="$1"

  cat > "$script" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

core_skills=(
  "gstack"
  "gstack-office-hours"
  "gstack-investigate"
  "gstack-ship"
)
claude_skills=(
  "gstack"
  "office-hours"
  "investigate"
  "browse"
  "ship"
)

mkdir -p "$HOME/.gstack/repos/gstack/.git" "$HOME/.codex/skills" "$HOME/.claude/skills"

for skill in "${core_skills[@]}"; do
  mkdir -p "$HOME/.codex/skills/$skill"
  printf -- "---\nname: %s\n---\n# stub\n" "$skill" > "$HOME/.codex/skills/$skill/SKILL.md"
done

mkdir -p "$HOME/.codex/skills/gstack/browse"
printf -- "---\nname: browse\n---\n# stub\n" > "$HOME/.codex/skills/gstack/browse/SKILL.md"

for skill in "${claude_skills[@]}"; do
  mkdir -p "$HOME/.claude/skills/$skill"
  printf -- "---\nname: %s\n---\n# stub\n" "$skill" > "$HOME/.claude/skills/$skill/SKILL.md"
done
STUB
  chmod +x "$script"
}

write_failing_gstack_stub() {
  local script="$1"

  cat > "$script" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
echo "intentional gstack installer failure" >&2
exit 1
STUB
  chmod +x "$script"
}

write_incomplete_gstack_stub() {
  local script="$1"

  cat > "$script" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.gstack/repos/gstack/.git" "$HOME/.codex/skills/gstack"
printf -- "---\nname: gstack\n---\n# partial stub\n" > "$HOME/.codex/skills/gstack/SKILL.md"
STUB
  chmod +x "$script"
}

test_shell_syntax() {
  bash -n "$ROOT/install.sh" "$ROOT/scripts/install-managed-gstack.sh" "$ROOT/scripts/test-installers.sh"
  assert_file_contains "$ROOT/install.ps1" '$ErrorActionPreference = "Stop"'
  assert_file_contains "$ROOT/install.ps1" "function Ensure-DirectoryPath"
  assert_file_contains "$ROOT/install.ps1" '$gitBash'
  assert_file_contains "$ROOT/install.ps1" 'bash.exe'
  if grep -q '& bash \$BashManagedGstackInstaller' "$ROOT/install.ps1"; then
    fail "Windows installer must invoke managed gstack with Git for Windows bash.exe"
  fi
}

test_daloopa_plugin_has_single_discoverable_skill() {
  local plugin="$ROOT/plugins/lotus-daloopa"
  local skill_count
  local workflows=(
    "setup"
    "build-model"
    "bull-bear"
    "capital-allocation"
    "earnings-flash"
    "earnings-prep"
    "ib-deck"
    "precedent-transactions"
    "research-note"
  )

  skill_count="$(find "$plugin/skills" -type f -name SKILL.md | wc -l | tr -d '[:space:]')"
  [ "$skill_count" = "1" ] || fail "Daloopa should expose one discoverable SKILL.md, found $skill_count"

  for workflow in "${workflows[@]}"; do
    [ -f "$plugin/skills/daloopa/references/$workflow.md" ] ||
      fail "missing Daloopa workflow reference: $workflow"
    assert_file_contains "$plugin/skills/daloopa/SKILL.md" "references/$workflow.md"
  done

  [ -f "$plugin/skills/daloopa/references/ib-deck-slide-templates.md" ] ||
    fail "missing flattened IB deck slide templates"
  [ -f "$plugin/skills/daloopa/references/ib-deck-financial-components.md" ] ||
    fail "missing flattened IB deck financial components"
  [ -f "$plugin/skills/daloopa/references/ib-deck-advisory-patterns.md" ] ||
    fail "missing flattened IB deck advisory patterns"
}

test_codex_conversion_with_stubbed_gstack() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  copy_repo_fixture "$tmp/lotus"
  write_success_gstack_stub "$tmp/lotus/scripts/install-managed-gstack.sh"

  mkdir -p \
    "$tmp/home/.codex/skills/brandkit" \
    "$tmp/home/.codex/skills/.system/openai-docs" \
    "$tmp/home/.claude/skills/plan-ceo-review"
  printf 'stale\n' > "$tmp/home/.codex/skills/brandkit/SKILL.md"
  printf 'system\n' > "$tmp/home/.codex/skills/.system/openai-docs/SKILL.md"
  printf 'stale\n' > "$tmp/home/.claude/skills/plan-ceo-review/SKILL.md"

  HOME="$tmp/home" bash "$tmp/lotus/install.sh" --global --yes >/dev/null

  assert_file_contains "$tmp/home/.codex/skills/image-2/SKILL.md" "# Image 2"
  if grep -q "^allowed-tools:" "$tmp/home/.codex/skills/image-2/SKILL.md"; then
    fail "image-2 should not restrict Codex native image tools with allowed-tools"
  fi
  assert_file_contains "$tmp/home/.codex/skills/image-2/SKILL.md" "image_gen"
  [ -f "$tmp/home/.codex/skills/image-2/scripts/image2_newapi.py" ] || fail "missing image-2 newapi fallback"
  [ -f "$tmp/home/.codex/skills/image-2/runtime.example.json" ] || fail "missing image-2 runtime example"
  [ ! -e "$tmp/home/.codex/skills/image-2/runtime.local.json" ] || fail "image-2 local runtime should not be installed from repo"
  assert_file_contains "$tmp/home/.codex/skills/ai-progress-workspace/SKILL.md" "# AI Progress Workspace"
  assert_file_contains "$tmp/home/.codex/skills/ai-progress-workspace/SKILL.md" "  - WebSearch"
  assert_file_contains "$tmp/home/.codex/skills/taste-skill/SKILL.md" "# Taste Skill: Codex Visual Frontend Entry Point"
  assert_file_contains "$tmp/home/.codex/skills/taste-skill/SKILL.md" "references/full-rules.md"
  [ -f "$tmp/home/.codex/skills/taste-skill/references/full-rules.md" ] ||
    fail "taste-skill full rules reference missing"
  [ -f "$tmp/home/.codex/skills/taste-skill/references/image-first-workflow.md" ] ||
    fail "taste-skill image-first reference missing"
  [ ! -e "$tmp/home/.codex/skills/taste-skill.md" ] ||
    fail "taste-skill should be installed as a package, not a flat legacy file"
  assert_file_contains "$tmp/home/.codex/skills/agent-training-loop/SKILL.md" "# Agent Training Loop"
  assert_file_contains "$tmp/home/.codex/skills/agent-training-loop/SKILL.md" "Use only when the user explicitly invokes"
  assert_file_contains "$tmp/home/.codex/skills/agent-training-loop/SKILL.md" "  - Bash"
  assert_file_contains "$tmp/home/.codex/skills/baseline-packager/SKILL.md" "# Baseline Packager"
  assert_file_contains "$tmp/home/.codex/skills/baseline-packager/SKILL.md" "Do not default to Playwright"
  assert_file_contains "$tmp/home/.codex/skills/mini-investigate/SKILL.md" "# Minimal Bug Fix"
  assert_file_contains "$tmp/home/.codex/skills/test-driven-development/SKILL.md" "# Test-Driven Development"
  assert_file_contains "$tmp/home/.codex/skills/anysearch/SKILL.md" "## Overview"
  assert_file_contains "$tmp/home/.codex/skills/anysearch/runtime.conf" "scripts/anysearch_cli"
  [ -f "$tmp/home/.codex/skills/anysearch/scripts/anysearch_cli.py" ] || fail "missing Codex anysearch CLI"
  [ ! -e "$tmp/home/.codex/skills/anysearch/.env" ] || fail "Codex anysearch .env should not be installed"
  assert_file_contains "$tmp/home/.codex/skills/agent-reach/SKILL.md" "purpose-built skill, MCP, connector, or app tool"
  assert_file_contains "$tmp/home/.claude/skills/anysearch/SKILL.md" "## Overview"
  assert_file_contains "$tmp/home/.claude/skills/anysearch/runtime.conf" "scripts/anysearch_cli"
  [ -f "$tmp/home/.claude/skills/anysearch/scripts/anysearch_cli.py" ] || fail "missing Claude anysearch CLI"
  [ ! -e "$tmp/home/.claude/skills/anysearch/.env" ] || fail "Claude anysearch .env should not be installed"
  assert_file_contains "$tmp/home/.codex/AGENTS.md" "版本：v1.4"
  assert_file_contains "$tmp/home/.codex/AGENTS.md" "先想清楚，再写代码"
  assert_file_contains "$tmp/home/.codex/AGENTS.md" "简单优先"
  assert_file_contains "$tmp/home/.codex/AGENTS.md" "手术式修改"
  assert_file_contains "$tmp/home/.codex/AGENTS.md" "目标驱动闭环"
  assert_file_contains "$tmp/home/.claude/skills/gsap/SKILL.md" "# GSAP"
  [ ! -e "$tmp/home/.claude/skills/gsap.md" ] || fail "Claude should not keep legacy flat gsap.md"

  [ ! -e "$tmp/home/.codex/skills/btw" ] || fail "Codex in-context skill should not be installed as slash skill: btw"
  [ ! -e "$tmp/home/.codex/skills/loop" ] || fail "Codex in-context skill should not be installed as slash skill: loop"

  for skill in "${HIDDEN_TOP_LEVEL_SKILLS[@]}"; do
    [ ! -e "$tmp/home/.codex/skills/$skill" ] || fail "hidden Codex skill should not be top-level: $skill"
    [ ! -e "$tmp/home/.claude/skills/$skill" ] || fail "hidden Claude skill should not be top-level: $skill"
  done
  [ -f "$tmp/home/.codex/hidden-skills/lotus/codex/brandkit/SKILL.md" ] || fail "Codex hidden skill backup missing"
  [ -f "$tmp/home/.codex/hidden-skills/lotus/codex-system/openai-docs/SKILL.md" ] || fail "Codex system hidden skill backup missing"
  [ -f "$tmp/home/.codex/hidden-skills/lotus/claude/plan-ceo-review/SKILL.md" ] || fail "Claude hidden skill backup missing"

  for skill in "${CORE_GSTACK_SKILLS[@]}"; do
    [ -f "$tmp/home/.codex/skills/$skill/SKILL.md" ] || fail "missing Codex gstack skill: $skill"
  done
  [ -f "$tmp/home/.codex/skills/gstack/browse/SKILL.md" ] || fail "missing Codex nested browse skill"
  [ ! -e "$tmp/home/.codex/skills/gstack-browse" ] || fail "Codex should rely on gstack/browse instead of duplicate gstack-browse"

  for skill in "${CLAUDE_GSTACK_SKILLS[@]}"; do
    [ -f "$tmp/home/.claude/skills/$skill/SKILL.md" ] || fail "missing Claude gstack skill: $skill"
  done
}

test_failed_gstack_install_preserves_existing_codex_runtime_and_succeeds() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  copy_repo_fixture "$tmp/lotus"
  write_failing_gstack_stub "$tmp/lotus/scripts/install-managed-gstack.sh"

  mkdir -p "$tmp/home/.codex/skills/gstack"
  printf 'sentinel\n' > "$tmp/home/.codex/skills/gstack/SKILL.md"

  HOME="$tmp/home" bash "$tmp/lotus/install.sh" --global --yes >/dev/null 2>"$tmp/stderr"

  assert_file_contains "$tmp/home/.codex/skills/gstack/SKILL.md" "sentinel"
  assert_file_contains "$tmp/home/.codex/skills/gstack-investigate/SKILL.md" "gstack bootstrap"
  assert_file_contains "$tmp/home/.claude/skills/investigate/SKILL.md" "gstack bootstrap"
}

test_incomplete_gstack_install_falls_back_to_bootstrap() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  copy_repo_fixture "$tmp/lotus"
  write_incomplete_gstack_stub "$tmp/lotus/scripts/install-managed-gstack.sh"

  HOME="$tmp/home" bash "$tmp/lotus/install.sh" --global --yes >/dev/null 2>"$tmp/stderr"

  assert_file_contains "$tmp/stderr" "Official gstack installation or verification failed"
  assert_file_contains "$tmp/home/.codex/skills/gstack/SKILL.md" "partial stub"
  assert_file_contains "$tmp/home/.codex/skills/gstack-investigate/SKILL.md" "gstack bootstrap"
  assert_file_contains "$tmp/home/.claude/skills/investigate/SKILL.md" "gstack bootstrap"
}

test_shell_syntax
test_daloopa_plugin_has_single_discoverable_skill
test_codex_conversion_with_stubbed_gstack
test_failed_gstack_install_preserves_existing_codex_runtime_and_succeeds
test_incomplete_gstack_install_falls_back_to_bootstrap

echo "installer tests passed"
