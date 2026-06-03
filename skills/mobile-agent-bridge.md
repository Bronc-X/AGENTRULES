---
name: mobile-agent-bridge
description: |
  手机到本机 Agent 桥接底层 skill。用于搭建、验证和排查“手机客户端 -> 本机连接 Daemon -> 本机 App Server/Agent Runtime”的两层架构，覆盖 kittylitter/alleycat、Codex app-server、Claude bridge、Shell bridge、QR/JSON 配对、launchd 自启动、runtime stream 失败等场景。
allowed-tools:
  - Bash
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - AskUserQuestion
---

# Mobile Agent Bridge

这个 skill 用来把手机远程控制本机 Agent 的经验标准化。默认使用两层模型：

1. **Connection Daemon**：负责手机如何安全连到本机。
   - 配对二维码 / JSON
   - token 鉴权与轮换
   - LAN / relay / SSH / Tailscale 连接
   - agent 列表与 runtime 路由
   - 常驻、自启动、可观测日志

2. **Runtime App Server**：负责连上之后能控制什么。
   - Codex app-server、Claude bridge、Shell bridge 或自定义 API gateway
   - 会话 / thread / tool / permission / streaming 协议
   - 本机文件、终端、浏览器、系统能力、API key、云模型服务访问

一句话：Daemon 回答“手机怎么安全到达这台电脑”，App Server 回答“到达后能调用哪些 Agent 能力”。

## 使用场景

使用这个 skill 处理以下任务：

- 用户要从手机连接本机 Codex、Claude、Shell 或其他 Agent。
- 需要安装或验证 kittylitter / alleycat 风格的 daemon。
- 需要生成、验证或解释 QR / JSON pair payload。
- 需要判断 Daemon 和 App Server 是否自启动、是否应该自启动。
- 手机端报错：
  - `malformed JSON`
  - `expected PairPayloadWire`
  - `connection failed`
  - `no available runtime streams connected`
  - `Handshake not finished`
- 需要设计可复用的“手机控制本机 Agent/API/云模型服务”底层架构。

## 标准工作流

### 1. 先画清两层

先识别：

- 手机端客户端是什么，配对格式是什么。
- Connection Daemon 是什么，二进制、配置、日志、自启动位置在哪里。
- Runtime App Server 有哪些，哪些可用，哪些按需拉起。
- 安全边界是什么：token、loopback socket、SSH tunnel、relay、API key、权限模型。

不要把“手机已经连上 daemon”和“runtime 可控”混为一谈。很多错误发生在第二层。

### 2. 验证 Daemon

以 kittylitter 为例：

```bash
kittylitter status --json
kittylitter agents list
kittylitter pair
kittylitter pair --qr
```

macOS 上检查 launchd：

```bash
launchctl print "gui/$(id -u)/com.sigkitten.kittylitter"
plutil -p "$HOME/Library/LaunchAgents/com.sigkitten.kittylitter.plist"
```

成功标准：

- daemon 有真实 PID，不是只读到 file-only 状态。
- LaunchAgent 使用稳定路径，不指向临时工作区。
- `RunAtLoad` / `KeepAlive` 存在。
- pair payload 是 JSON object，并且包含 node、token、host/relay 信息。

### 3. 验证 Runtime App Server

每个 runtime 单独验证，先不要让手机参与。

Codex 示例：

```bash
codex app-server daemon start
codex app-server daemon version
```

如果 kittylitter 日志出现：

```text
managed standalone Codex install not found
```

说明只有 Codex App 内置 CLI，不够；需要安装 standalone Codex 到：

```text
~/.codex/packages/standalone/current/codex
```

然后重新运行：

```bash
codex app-server daemon start
kittylitter restart
```

### 4. 用本机 probe 代替手机盲试

先跑：

```bash
kittylitter probe
```

它应该能 `list_agents`。

再跑目标 runtime：

```bash
kittylitter probe --agent codex --timeout-secs 30 --linger-secs 1
kittylitter probe --agent claude --timeout-secs 30 --linger-secs 1
kittylitter probe --agent shell --timeout-secs 30 --linger-secs 1
```

只有本机 probe 能初始化 runtime，才让用户重新扫码或粘贴 JSON。

### 5. 分层解释错误

- `malformed JSON` / `expected PairPayloadWire`：
  手机收到的是字符串、路径或命令，不是 pair JSON object。重新给用户 `{...}` 原始 JSON。

- `connection failed` 且不能 list agents：
  优先检查 daemon 是否在线、token 是否匹配、relay/LAN/SSH 是否可达。

- `no available runtime streams connected`：
  手机已经连到 daemon，但所选 runtime 都初始化失败。看 daemon 日志并运行 `kittylitter probe --agent <name>`。

- `Handshake not finished`：
  通常是 runtime app-server 在 WebSocket/JSONL 握手前退出。查 daemon 日志里的真实命令错误。

- `status --json` 里 `pid: 0`：
  可能是 daemon 刚启动，还没完成 IPC；等待几秒再查。持续出现时看 launchd 和日志。

## 自启动策略

默认策略：

- Connection Daemon：应该自启动。没有它，手机发现不了本机。
- Runtime App Server：可以按需拉起。只有启动慢、SSH 场景、或用户明确要求开机即用时才做独立自启动。

Codex 示例：

- `codex app-server daemon start`：启动当前 runtime。
- `codex app-server daemon bootstrap`：安装更持久的 daemon 管理，适合 SSH/长期远程使用。

不要为了“看起来完整”默认把所有 runtime 暴露到公网或 `0.0.0.0`。

## 安全规则

- Pair JSON / QR 含 bearer token，视作密钥。
- 意外泄露后运行 `kittylitter rotate`。
- runtime app-server 默认使用 Unix socket 或 loopback。
- 让 runtime 持有 API key 和云模型凭证，daemon 只负责连接与路由。
- 日志里可以记录 token short，不要记录完整 token。

## 汇报格式

完成时报告：

```text
Connection daemon:
- binary:
- autostart:
- live pid:
- pair payload:

Runtime app-server:
- runtime:
- status:
- start mode:
- probe evidence:

Phone action:
- scan/re-add/reconnect steps:

Remaining risk:
- network / token / runtime / permissions:
```
