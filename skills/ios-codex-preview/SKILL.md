---
name: ios-codex-preview
description: 搭建 iOS 模拟器预览，让 Codex 构建、运行、检查 SwiftUI 应用。
---

# iOS Codex Preview Intel

Use this skill to make an iOS project ready for Codex-driven development with a live right-side preview.

## What To Deliver

- A booted iOS Simulator.
- A built, installed, launched app.
- A Browser-visible preview at `http://127.0.0.1:3200`.
- A watcher that rebuilds and relaunches after Swift/Xcode project changes.
- A health check that proves simulator, server, watcher, screenshot, and port are working.
- Clear project-local commands for start, stop, screenshot, and health.

## Preferred Flow

1. Inspect the project root for `.xcodeproj` or `.xcworkspace`, schemes, bundle ID, and existing helper scripts.
2. Run `scripts/install-ios-codex-preview.sh` from this skill if the project does not already have `scripts/ios-preview/*` or if they are stale.
3. Start the preview with `scripts/ios-preview/start-all.sh --daemon`.
4. Open or keep `http://127.0.0.1:3200` in the Codex in-app Browser and make it visible.
5. Run `scripts/ios-preview/health.sh`.
6. Prove hot reload by making a small visible SwiftUI text change, waiting for the watcher, and taking a simulator screenshot.

## Machine-Specific Rule

On Apple Silicon, an official `serve-sim` / iOS Simulator Browser flow may be available. Prefer it only when it actually runs.

On Intel Macs (`uname -m == x86_64`), do not spend time retrying `serve-sim` if it fails with an architecture error. Install the compatibility preview. It polls `xcrun simctl io <udid> screenshot` and shows the latest image in Codex Browser.

## Important Pitfalls

- Do not rely on LaunchAgents for projects under `~/Documents`; macOS TCC can block background agents from reading the project.
- If a stale LaunchAgent exists, unload and disable it before declaring success:
  - `launchctl list | rg 'codex.*preview|lotusapp|ios-preview|watch-run'`
  - `launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/<plist>`
  - move the plist to `~/Library/LaunchAgents.disabled/`.
- Health checks must match both relative and absolute process paths, e.g. `scripts/ios-preview/server.mjs`, not just `node scripts/...`.
- A reachable `/status` endpoint alone is not sufficient. The watcher process must be alive and a fresh screenshot must be updating.

## Commands

Install/update preview helpers in a project:

```bash
/Users/broncin/.codex/skills/ios-codex-preview/scripts/install-ios-codex-preview.sh
```

Start:

```bash
scripts/ios-preview/start-all.sh --daemon
```

Stop:

```bash
scripts/ios-preview/stop.sh
```

Health:

```bash
scripts/ios-preview/health.sh
```

## Completion Criteria

Only report completion when all are true:

- `scripts/ios-preview/health.sh` exits 0.
- `curl -sS http://127.0.0.1:3200/status` returns `ok: true` and `hasImage: true`.
- `ps` shows both `server.mjs` and `watch-run.sh`.
- Codex Browser tab at `http://127.0.0.1:3200/` shows `live` and an image.
- A visible Swift change has appeared in a new simulator screenshot after watcher rebuild/relaunch.
