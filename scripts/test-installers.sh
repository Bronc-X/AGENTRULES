#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CORE_GSTACK_SKILLS=(
  "gstack"
  "gstack-office-hours"
  "gstack-plan-ceo-review"
  "gstack-plan-design-review"
  "gstack-plan-eng-review"
  "gstack-design-review"
  "gstack-review"
  "gstack-investigate"
  "gstack-browse"
  "gstack-qa"
  "gstack-ship"
)

CLAUDE_GSTACK_SKILLS=(
  "gstack"
  "office-hours"
  "plan-ceo-review"
  "plan-design-review"
  "plan-eng-review"
  "design-review"
  "review"
  "investigate"
  "browse"
  "qa"
  "ship"
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
  "gstack-plan-ceo-review"
  "gstack-plan-design-review"
  "gstack-plan-eng-review"
  "gstack-design-review"
  "gstack-review"
  "gstack-investigate"
  "gstack-browse"
  "gstack-qa"
  "gstack-ship"
)
claude_skills=(
  "gstack"
  "office-hours"
  "plan-ceo-review"
  "plan-design-review"
  "plan-eng-review"
  "design-review"
  "review"
  "investigate"
  "browse"
  "qa"
  "ship"
)

mkdir -p "$HOME/.gstack/repos/gstack/.git" "$HOME/.codex/skills" "$HOME/.claude/skills"

for skill in "${core_skills[@]}"; do
  mkdir -p "$HOME/.codex/skills/$skill"
  printf -- "---\nname: %s\n---\n# stub\n" "$skill" > "$HOME/.codex/skills/$skill/SKILL.md"
done

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

test_shell_syntax() {
  bash -n "$ROOT/install.sh" "$ROOT/scripts/install-managed-gstack.sh" "$ROOT/scripts/test-installers.sh"
}

test_codex_conversion_with_stubbed_gstack() {
  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  copy_repo_fixture "$tmp/lotus"
  write_success_gstack_stub "$tmp/lotus/scripts/install-managed-gstack.sh"

  HOME="$tmp/home" bash "$tmp/lotus/install.sh" --global --yes >/dev/null

  assert_file_contains "$tmp/home/.codex/skills/image-2/SKILL.md" "# Image 2"
  assert_file_contains "$tmp/home/.codex/skills/ai-progress-workspace/SKILL.md" "# AI Progress Workspace"
  assert_file_contains "$tmp/home/.codex/skills/ai-progress-workspace/SKILL.md" "  - WebSearch"
  assert_file_contains "$tmp/home/.codex/skills/taste-skill/SKILL.md" "# Taste Skill"
  assert_file_contains "$tmp/home/.codex/skills/agent-training-loop/SKILL.md" "# Agent Training Loop"
  assert_file_contains "$tmp/home/.codex/skills/agent-training-loop/SKILL.md" "Use only when the user explicitly invokes"
  assert_file_contains "$tmp/home/.codex/skills/agent-training-loop/SKILL.md" "  - Bash"
  assert_file_contains "$tmp/home/.codex/skills/baseline-packager/SKILL.md" "# Baseline Packager"
  assert_file_contains "$tmp/home/.codex/skills/baseline-packager/SKILL.md" "Do not default to Playwright"
  assert_file_contains "$tmp/home/.codex/skills/conversion-copywriter/SKILL.md" "# Conversion Copywriter"
  assert_file_contains "$tmp/home/.codex/skills/test-driven-development/SKILL.md" "# Test-Driven Development"

  [ ! -e "$tmp/home/.codex/skills/btw" ] || fail "Codex in-context skill should not be installed as slash skill: btw"
  [ ! -e "$tmp/home/.codex/skills/loop" ] || fail "Codex in-context skill should not be installed as slash skill: loop"

  for skill in "${CORE_GSTACK_SKILLS[@]}"; do
    [ -f "$tmp/home/.codex/skills/$skill/SKILL.md" ] || fail "missing Codex gstack skill: $skill"
  done

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
  assert_file_contains "$tmp/home/.codex/skills/gstack-qa/SKILL.md" "Official gstack bootstrap"
  assert_file_contains "$tmp/home/.claude/skills/qa/SKILL.md" "Official gstack bootstrap"
}

test_shell_syntax
test_codex_conversion_with_stubbed_gstack
test_failed_gstack_install_preserves_existing_codex_runtime_and_succeeds

echo "installer tests passed"
