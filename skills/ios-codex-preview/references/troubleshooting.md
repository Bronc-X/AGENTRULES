# Troubleshooting

## Stale LaunchAgents

If port `3200` is occupied but `watch-run.sh` is missing, check for stale LaunchAgents:

```bash
launchctl list | rg 'codex.*preview|ios-preview|preview-server|watch-run'
ls -la ~/Library/LaunchAgents | rg 'codex|preview|watch'
```

Unload and disable project-specific preview LaunchAgents:

```bash
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/<name>.plist
mkdir -p ~/Library/LaunchAgents.disabled
mv ~/Library/LaunchAgents/<name>.plist ~/Library/LaunchAgents.disabled/<name>.plist.disabled
```

Do this when the project lives under `~/Documents` and logs show:

- `Operation not permitted`
- `getcwd: cannot access parent directories`
- `bash: .../scripts/ios-preview/watch-run.sh: Operation not permitted`

## Intel Mac

If `serve-sim` fails with architecture errors such as system error `-86`, use the compatibility preview. It is screenshot based and works on Intel.

## Health Is Not Complete

Do not treat `/status` as enough. Completion requires:

- `ok: true`
- `hasImage: true`
- `server.mjs` process alive
- `watch-run.sh` process alive
- a visible Swift change appears in a simulator screenshot after the watcher runs
