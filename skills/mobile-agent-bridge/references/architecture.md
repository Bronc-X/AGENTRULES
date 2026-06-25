# Mobile Agent Bridge Architecture

## Two Necessary Modules

A reusable phone-to-computer agent system normally needs two modules:

1. **Ingress / connection daemon**
   - Maintains a stable machine identity and auth token.
   - Publishes or exposes a reachable endpoint through LAN, relay, SSH, Tailscale, BLE handoff, or QR/JSON payload.
   - Accepts phone clients and routes requests to local runtimes.
   - Should be small, durable, autostarted, observable, and easy to rotate.

2. **Runtime app-server**
   - Owns the agent protocol and local capabilities.
   - Reads local credentials and config.
   - Talks to cloud model APIs, local tools, files, terminals, browsers, or custom APIs.
   - May run eagerly at login or be started on demand by the connection daemon.

Keep these separate unless the product is intentionally single-agent and single-transport. Separation gives a stable phone pairing surface while allowing runtimes to change independently.

## Standard Responsibilities

Connection daemon:

- Pairing payload generation and validation.
- Transport setup and reconnection.
- Runtime discovery and capability advertisement.
- Multiplexing many runtimes over one mobile connection.
- Logs that explain connection and dispatch failures.

Runtime app-server:

- Session/thread lifecycle.
- Tool and permission model.
- Agent-specific protocol, such as WebSocket or JSONL JSON-RPC.
- Local credential/API access.
- Long-running task state.

## Autostart Policy

Use three levels:

- **Required autostart**: connection daemon. The phone cannot discover or connect without it.
- **Recommended on-demand**: runtime app-servers. Start them only when the phone selects that runtime, unless startup latency is unacceptable.
- **Optional eager autostart**: runtime app-servers with high startup cost, remote SSH use cases, or servers that must be available before the connection daemon receives traffic.

For Codex, `codex app-server daemon bootstrap` installs durable management for SSH-driven use. `codex app-server daemon start` starts the runtime now but is not the same as creating an eager login LaunchAgent.

## Security Defaults

- Keep runtime app-server sockets loopback-only or Unix-domain by default.
- Prefer a connection daemon with explicit token auth over exposing raw runtime ports.
- Treat QR/JSON pair payloads as bearer secrets.
- Rotate pair tokens after accidental sharing.
- Avoid putting cloud API keys inside the connection daemon when the runtime app-server can own credentials.
- Log enough to diagnose failures, but do not log full tokens.

## Verification Ladder

1. Local process check: daemon PID and app-server PID/socket.
2. Autostart check: LaunchAgent/systemd-user entry for required daemon.
3. Daemon control check: `status`, `agents list`, or equivalent.
4. Pairing check: valid JSON object and QR payload.
5. Local network/relay check: daemon-native probe can connect to itself.
6. Runtime check: selected runtime initializes and returns a harmless method like `thread/list`.
7. Phone check: remove stale failed server entries and re-add with current payload.

## Failure Interpretation

If pairing JSON is rejected, stay at the pairing layer.

If the phone can list agents but cannot open a runtime, the connection daemon is working; inspect runtime startup and protocol logs.

If one runtime works and another fails, do not reinstall the daemon. Fix the failing runtime's binary, managed install, app-server socket, or protocol mode.

If relay warnings appear but local probe succeeds, treat them as transient network noise unless the phone cannot reach the endpoint.
