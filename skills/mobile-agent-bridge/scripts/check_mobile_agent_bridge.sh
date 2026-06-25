#!/usr/bin/env bash
set -u

probe=false
probe_codex=false

for arg in "$@"; do
  case "$arg" in
    --probe)
      probe=true
      ;;
    --probe-codex)
      probe=true
      probe_codex=true
      ;;
    -h|--help)
      cat <<'EOF'
Usage: check_mobile_agent_bridge.sh [--probe] [--probe-codex]

Read-only audit for a kittylitter/Codex-style mobile agent bridge.
EOF
      exit 0
      ;;
    *)
      echo "unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

section() {
  printf '\n== %s ==\n' "$1"
}

find_kittylitter() {
  if [ -n "${KITTYLITTER_BIN:-}" ] && [ -x "$KITTYLITTER_BIN" ]; then
    printf '%s\n' "$KITTYLITTER_BIN"
    return
  fi
  if command -v kittylitter >/dev/null 2>&1; then
    command -v kittylitter
    return
  fi
  local stable="$HOME/Library/Application Support/com.sigkitten.kittylitter/bin/kittylitter"
  if [ -x "$stable" ]; then
    printf '%s\n' "$stable"
  fi
}

find_codex() {
  if [ -n "${CODEX_BIN:-}" ] && [ -x "$CODEX_BIN" ]; then
    printf '%s\n' "$CODEX_BIN"
    return
  fi
  if [ -x "$HOME/.local/bin/codex" ]; then
    printf '%s\n' "$HOME/.local/bin/codex"
    return
  fi
  if command -v codex >/dev/null 2>&1; then
    command -v codex
    return
  fi
  local app="/Applications/Codex.app/Contents/Resources/codex"
  if [ -x "$app" ]; then
    printf '%s\n' "$app"
  fi
}

KITTY_BIN="$(find_kittylitter || true)"
CODEX_BIN_RESOLVED="$(find_codex || true)"

section "Binaries"
printf 'kittylitter: %s\n' "${KITTY_BIN:-not found}"
printf 'codex:       %s\n' "${CODEX_BIN_RESOLVED:-not found}"

section "Processes"
ps -ef | grep -E 'kittylitter serve|codex app-server|app-server-control' | grep -v grep || true

if [ "$(uname -s)" = "Darwin" ]; then
  section "LaunchAgents"
  find "$HOME/Library/LaunchAgents" -maxdepth 1 \( -iname '*kittylitter*' -o -iname '*codex*' -o -iname '*openai*' \) -print 2>/dev/null || true
  if launchctl print "gui/$(id -u)/com.sigkitten.kittylitter" >/tmp/mobile-agent-bridge-kittylitter.launchctl 2>&1; then
    sed -n '1,80p' /tmp/mobile-agent-bridge-kittylitter.launchctl
  else
    sed -n '1,40p' /tmp/mobile-agent-bridge-kittylitter.launchctl
  fi
  rm -f /tmp/mobile-agent-bridge-kittylitter.launchctl
fi

if [ -n "${KITTY_BIN:-}" ]; then
  section "KittyLitter Status"
  "$KITTY_BIN" status --json || true

  section "KittyLitter Agents"
  "$KITTY_BIN" agents list || true

  section "Pair Payload Shape"
  "$KITTY_BIN" pair 2>/dev/null | python3 -c 'import json,sys; data=json.load(sys.stdin); print({k:data.get(k) for k in ["v","node_id","host_name","relay"]}); print("token_present:", bool(data.get("token")))' 2>/dev/null || \
    "$KITTY_BIN" pair || true
fi

if [ -n "${CODEX_BIN_RESOLVED:-}" ]; then
  section "Codex App Server"
  "$CODEX_BIN_RESOLVED" app-server daemon version || true
  if [ -e "$HOME/.codex/packages/standalone/current/codex" ]; then
    printf 'standalone_current: present\n'
  else
    printf 'standalone_current: missing\n'
  fi
fi

if [ "$probe" = true ] && [ -n "${KITTY_BIN:-}" ]; then
  section "KittyLitter Probe"
  "$KITTY_BIN" probe --timeout-secs 30 --linger-secs 1 || true
fi

if [ "$probe_codex" = true ] && [ -n "${KITTY_BIN:-}" ]; then
  section "Codex Runtime Probe"
  "$KITTY_BIN" probe --agent codex --timeout-secs 30 --linger-secs 1 || true
fi
