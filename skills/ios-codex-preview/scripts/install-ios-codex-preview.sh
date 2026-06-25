#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="${1:-$PWD}"
ROOT_DIR="$(cd "$ROOT_DIR" && pwd)"
cd "$ROOT_DIR"

mkdir -p scripts/ios-preview scripts/ios-dev .codex outputs/live-preview

if [[ ! -x scripts/ios-dev/boot-simulator ]]; then
  cat > scripts/ios-dev/boot-simulator <<'BOOT'
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

DEVICE_NAME="${IOS_SIMULATOR_NAME:-iPhone 14}"
RUNTIME="${IOS_SIMULATOR_RUNTIME:-iOS 16.2}"

udid="$(xcrun simctl list devices available | awk -v name="$DEVICE_NAME" -v runtime="$RUNTIME" '
  $0 ~ "-- " runtime " --" { in_runtime=1; next }
  /^-- / { in_runtime=0 }
  in_runtime && index($0, name " (") {
    if (match($0, /\(([A-F0-9-]{36})\)/, m)) { print m[1]; exit }
  }
')"

if [[ -z "$udid" ]]; then
  udid="$(xcrun simctl list devices available | awk -v name="$DEVICE_NAME" '
    index($0, name " (") {
      if (match($0, /\(([A-F0-9-]{36})\)/, m)) { print m[1]; exit }
    }
  ')"
fi

if [[ -z "$udid" ]]; then
  echo "ERROR: Could not find available simulator named $DEVICE_NAME" >&2
  exit 1
fi

echo "$udid" > .codex/ios-simulator-udid
xcrun simctl boot "$udid" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$udid" -b
echo "Simulator ready: $DEVICE_NAME ($udid)"
BOOT
  chmod +x scripts/ios-dev/boot-simulator
fi

if [[ ! -x scripts/ios-dev/build ]]; then
  cat > scripts/ios-dev/build <<'BUILD'
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

SCHEME="${IOS_SCHEME:-}"
PROJECT_ARG=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scheme) SCHEME="$2"; shift 2 ;;
    --project) PROJECT_ARG=(-project "$2"); shift 2 ;;
    --workspace) PROJECT_ARG=(-workspace "$2"); shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ ${#PROJECT_ARG[@]} -eq 0 ]]; then
  project="$(find . -maxdepth 1 -name '*.xcodeproj' -print | head -1)"
  workspace="$(find . -maxdepth 1 -name '*.xcworkspace' -print | head -1)"
  if [[ -n "$workspace" ]]; then
    PROJECT_ARG=(-workspace "$workspace")
  elif [[ -n "$project" ]]; then
    PROJECT_ARG=(-project "$project")
  else
    echo "ERROR: No .xcodeproj or .xcworkspace found" >&2
    exit 1
  fi
fi

if [[ -z "$SCHEME" ]]; then
  SCHEME="$(basename "${PROJECT_ARG[1]}" | sed 's/\.xcodeproj$//; s/\.xcworkspace$//')"
fi

DESTINATION="${IOS_DESTINATION:-platform=iOS Simulator,name=${IOS_SIMULATOR_NAME:-iPhone 14},OS=${IOS_SIMULATOR_OS:-16.2}}"
DERIVED_DATA_PATH="${IOS_DERIVED_DATA_PATH:-.codex/DerivedData}"

xcodebuild "${PROJECT_ARG[@]}" -scheme "$SCHEME" -configuration Debug -destination "$DESTINATION" -derivedDataPath "$DERIVED_DATA_PATH" build
BUILD
  chmod +x scripts/ios-dev/build
fi

if [[ ! -x scripts/ios-dev/run ]]; then
  cat > scripts/ios-dev/run <<'RUN'
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

SCHEME="${IOS_SCHEME:-$(find . -maxdepth 1 -name '*.xcodeproj' -print | head -1 | xargs basename | sed 's/\.xcodeproj$//')}"
BUNDLE_ID="${IOS_BUNDLE_ID:-}"
DERIVED_DATA_PATH="${IOS_DERIVED_DATA_PATH:-.codex/DerivedData}"

scripts/ios-dev/boot-simulator
scripts/ios-dev/build --scheme "$SCHEME"

APP_PATH="$(find "$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name "${SCHEME}.app" -print | head -1 || true)"
if [[ -z "$APP_PATH" ]]; then
  APP_PATH="$(find "$DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name "*.app" -print | head -1 || true)"
fi
if [[ -z "$APP_PATH" ]]; then
  echo "ERROR: Built .app not found under $DERIVED_DATA_PATH/Build/Products/Debug-iphonesimulator" >&2
  exit 1
fi

if [[ -z "$BUNDLE_ID" ]]; then
  BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP_PATH/Info.plist")"
fi

xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted "$BUNDLE_ID"
echo "Launched $BUNDLE_ID"
RUN
  chmod +x scripts/ios-dev/run
fi

if [[ ! -x scripts/ios-dev/screenshot ]]; then
  cat > scripts/ios-dev/screenshot <<'SHOT'
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

mkdir -p outputs
out="outputs/ios-simulator-$(date '+%Y%m%d-%H%M%S').png"
udid="booted"
if [[ -f .codex/ios-simulator-udid ]]; then
  udid="$(cat .codex/ios-simulator-udid)"
fi
xcrun simctl io "$udid" screenshot "$out"
echo "$ROOT_DIR/$out"
SHOT
  chmod +x scripts/ios-dev/screenshot
fi

cat > scripts/ios-preview/server.mjs <<'SERVER'
#!/usr/bin/env node
import { createServer } from "node:http";
import { spawn, spawnSync } from "node:child_process";
import { existsSync, mkdirSync, readFileSync, statSync } from "node:fs";
import { join, resolve } from "node:path";

const root = resolve(new URL("../..", import.meta.url).pathname);
const outDir = join(root, "outputs", "live-preview");
const shotPath = join(outDir, "simulator.png");
const port = Number(process.env.IOS_PREVIEW_PORT || 3200);
const intervalMs = Number(process.env.IOS_PREVIEW_INTERVAL_MS || 1000);

mkdirSync(outDir, { recursive: true });

function readUdid() {
  const explicit = process.env.IOS_SIMULATOR_UDID;
  if (explicit) return explicit.trim();
  const file = join(root, ".codex", "ios-simulator-udid");
  if (existsSync(file)) return readFileSync(file, "utf8").trim();
  return "booted";
}

let captureRunning = false;
let lastCapture = { ok: false, at: 0, error: "Waiting for first capture" };

function capture() {
  if (captureRunning) return;
  captureRunning = true;
  const udid = readUdid();
  const child = spawn("xcrun", ["simctl", "io", udid, "screenshot", shotPath], {
    cwd: root,
    stdio: ["ignore", "ignore", "pipe"],
  });
  let stderr = "";
  child.stderr.on("data", (chunk) => { stderr += chunk.toString(); });
  child.on("close", (code) => {
    captureRunning = false;
    lastCapture = {
      ok: code === 0,
      at: Date.now(),
      error: code === 0 ? "" : stderr.trim() || `screenshot exited ${code}`,
    };
  });
}

function runStatus() {
  const result = spawnSync("xcrun", ["simctl", "list", "devices", "booted"], {
    cwd: root,
    encoding: "utf8",
  });
  return result.stdout || result.stderr || "";
}

function html() {
  return `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>iOS Simulator Preview</title>
  <style>
    :root { color-scheme: dark; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
    body { margin: 0; min-height: 100vh; background: #111318; color: #f4f5f7; display: grid; grid-template-rows: auto 1fr; }
    header { height: 44px; display: flex; align-items: center; justify-content: space-between; padding: 0 14px; background: #181b22; border-bottom: 1px solid #2a2e38; font-size: 13px; }
    .title { font-weight: 650; }
    .status { color: #9aa3b2; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 12px; }
    main { min-height: 0; display: grid; place-items: center; padding: 16px; }
    .phone { height: min(calc(100vh - 82px), 900px); aspect-ratio: 390 / 844; border-radius: 30px; background: #05060a; box-shadow: 0 18px 48px rgba(0,0,0,.45); overflow: hidden; display: grid; place-items: center; }
    img { display: block; width: 100%; height: 100%; object-fit: contain; background: white; }
    .empty { padding: 18px; color: #aeb6c4; text-align: center; line-height: 1.45; }
  </style>
</head>
<body>
  <header><div class="title">iOS Simulator Preview</div><div id="status" class="status">connecting</div></header>
  <main><div class="phone"><img id="screen" alt="Simulator screen" /><div id="empty" class="empty">Waiting for simulator screenshot...</div></div></main>
  <script>
    const img = document.getElementById("screen");
    const empty = document.getElementById("empty");
    const status = document.getElementById("status");
    async function tick() {
      try {
        const res = await fetch("/status", { cache: "no-store" });
        const data = await res.json();
        status.textContent = data.ok ? "live " + new Date(data.at).toLocaleTimeString() : data.error;
        if (data.hasImage) {
          img.style.display = "block";
          empty.style.display = "none";
          img.src = "/screen.png?t=" + data.mtimeMs;
        } else {
          img.style.display = "none";
          empty.style.display = "block";
        }
      } catch (error) {
        status.textContent = String(error);
      }
    }
    tick();
    setInterval(tick, ${Math.max(250, intervalMs)});
  </script>
</body>
</html>`;
}

capture();
setInterval(capture, intervalMs);

const server = createServer((req, res) => {
  const url = new URL(req.url || "/", `http://127.0.0.1:${port}`);
  if (url.pathname === "/") {
    res.writeHead(200, { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" });
    res.end(html());
    return;
  }
  if (url.pathname === "/screen.png") {
    if (!existsSync(shotPath)) {
      res.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
      res.end("No screenshot yet");
      return;
    }
    res.writeHead(200, { "content-type": "image/png", "cache-control": "no-store" });
    res.end(readFileSync(shotPath));
    return;
  }
  if (url.pathname === "/status") {
    const hasImage = existsSync(shotPath);
    const mtimeMs = hasImage ? statSync(shotPath).mtimeMs : 0;
    res.writeHead(200, { "content-type": "application/json", "cache-control": "no-store" });
    res.end(JSON.stringify({ ...lastCapture, hasImage, mtimeMs, udid: readUdid() }));
    return;
  }
  if (url.pathname === "/devices") {
    res.writeHead(200, { "content-type": "text/plain; charset=utf-8", "cache-control": "no-store" });
    res.end(runStatus());
    return;
  }
  res.writeHead(404, { "content-type": "text/plain; charset=utf-8" });
  res.end("Not found");
});

server.listen(port, "127.0.0.1", () => {
  console.log(`iOS Simulator preview: http://127.0.0.1:${port}`);
  console.log(`Screenshot: ${shotPath}`);
});
SERVER
chmod +x scripts/ios-preview/server.mjs

cat > scripts/ios-preview/watch-run.sh <<'WATCH'
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

last=""
echo "Watching Swift project files. Press Ctrl-C to stop."
while true; do
  current="$(find . -maxdepth 3 \( -name '*.swift' -o -name 'project.pbxproj' -o -name '*.json' \) -print0 | xargs -0 stat -f '%m %N' | sort | cksum)"
  if [[ -z "$last" ]]; then
    last="$current"
  fi
  if [[ "$current" != "$last" ]]; then
    last="$current"
    echo
    echo "[$(date '+%H:%M:%S')] Change detected. Building and launching app..."
    scripts/ios-dev/run || true
  fi
  sleep 2
done
WATCH
chmod +x scripts/ios-preview/watch-run.sh

cat > scripts/ios-preview/stop.sh <<'STOP'
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

kill_pid() {
  local pid="$1"
  if [[ "$pid" =~ ^[0-9]+$ ]] && [[ "$pid" != "$$" ]]; then
    kill "$pid" >/dev/null 2>&1 || true
  fi
}

for file in .codex/ios-preview-watch.pid .codex/ios-preview-server.pid .codex/ios-preview-start-all.pid; do
  if [[ -f "$file" ]]; then
    pid="$(cat "$file")"
    kill_pid "$pid"
    rm -f "$file"
  fi
done

for pattern in \
  "scripts/ios-preview/server.mjs" \
  "scripts/ios-preview/watch-run.sh" \
  "bash scripts/ios-preview/start-all.sh --foreground" \
  "/scripts/ios-preview/start-all.sh --foreground"; do
  while IFS= read -r pid; do
    kill_pid "$pid"
  done < <(pgrep -f "$pattern" || true)
done

echo "Stopped iOS preview helpers."
STOP
chmod +x scripts/ios-preview/stop.sh

cat > scripts/ios-preview/start-all.sh <<'START'
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ "${1:-}" == "--daemon" ]]; then
  mkdir -p outputs/live-preview
  scripts/ios-preview/stop.sh >/dev/null 2>&1 || true
  if [[ "$(uname -s)" == "Darwin" ]] && command -v open >/dev/null 2>&1; then
    open "$ROOT_DIR/preview-dev.command"
    echo "iOS preview started in Terminal."
  else
    nohup /bin/bash --noprofile --norc -c "cd '$ROOT_DIR' && exec scripts/ios-preview/start-all.sh --foreground" \
      > outputs/live-preview/start-all.log 2>&1 < /dev/null &
    echo "$!" > .codex/ios-preview-start-all.pid
    echo "iOS preview daemon pid: $!"
    echo "Log: $ROOT_DIR/outputs/live-preview/start-all.log"
  fi
  echo "Open http://127.0.0.1:${IOS_PREVIEW_PORT:-3200} in Codex Browser."
  exit 0
fi

if [[ "${1:-}" == "--foreground" ]]; then
  shift
fi

cleanup() {
  if [[ -n "${watch_pid:-}" ]]; then
    kill "$watch_pid" >/dev/null 2>&1 || true
  fi
  if [[ -n "${server_pid:-}" ]]; then
    kill "$server_pid" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT INT TERM HUP

scripts/ios-dev/run

node scripts/ios-preview/server.mjs &
server_pid="$!"
echo "$server_pid" > .codex/ios-preview-server.pid

scripts/ios-preview/watch-run.sh &
watch_pid="$!"
echo "$watch_pid" > .codex/ios-preview-watch.pid

echo "iOS preview server pid: $server_pid"
echo "iOS watch-run pid: $watch_pid"
echo "Open http://127.0.0.1:${IOS_PREVIEW_PORT:-3200} in Codex Browser."

wait "$server_pid"
START
chmod +x scripts/ios-preview/start-all.sh

cat > scripts/ios-preview/health.sh <<'HEALTH'
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

PORT="${IOS_PREVIEW_PORT:-3200}"
STATUS_URL="http://127.0.0.1:${PORT}/status"
failures=0

check() {
  local label="$1"
  shift
  if "$@" >/tmp/ios-preview-health.out 2>/tmp/ios-preview-health.err; then
    echo "ok - $label"
  else
    failures=$((failures + 1))
    echo "fail - $label"
    if [[ -s /tmp/ios-preview-health.err ]]; then
      sed 's/^/  /' /tmp/ios-preview-health.err
    elif [[ -s /tmp/ios-preview-health.out ]]; then
      sed 's/^/  /' /tmp/ios-preview-health.out
    fi
  fi
}

check "simulator booted" xcrun simctl list devices booted
check "preview status endpoint" curl -fsS "$STATUS_URL"
check "preview port ${PORT}" lsof -nP -iTCP:"$PORT"
check "live screenshot exists" test -s outputs/live-preview/simulator.png

if pgrep -f "scripts/ios-preview/server.mjs" >/dev/null; then
  echo "ok - preview server process"
else
  failures=$((failures + 1))
  echo "fail - preview server process"
fi

if pgrep -f "scripts/ios-preview/watch-run.sh" >/dev/null; then
  echo "ok - watch-run process"
else
  failures=$((failures + 1))
  echo "fail - watch-run process"
fi

echo
echo "Preview URL: http://127.0.0.1:${PORT}"

if [[ "$failures" -gt 0 ]]; then
  echo "Health check failed with ${failures} issue(s)."
  exit 1
fi

echo "Health check passed."
HEALTH
chmod +x scripts/ios-preview/health.sh

cat > preview-dev.command <<'COMMAND'
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

echo "Starting iOS preview..."
echo "Project: $ROOT_DIR"
echo "Preview: http://127.0.0.1:${IOS_PREVIEW_PORT:-3200}"
echo

scripts/ios-preview/start-all.sh --foreground
COMMAND
chmod +x preview-dev.command

echo "Installed iOS Codex preview helpers in $ROOT_DIR"
echo "Start: scripts/ios-preview/start-all.sh --daemon"
echo "Health: scripts/ios-preview/health.sh"
