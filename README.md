<div align="center">

# codex-bark-notify-hook

Turn Codex `notify` callbacks into reliable Bark push notifications.

A lightweight notification hook for long-running coding sessions: parse payloads, compress summaries, dedupe by turn, send through a single entrypoint, and retry once on failure.

[![中文](https://img.shields.io/badge/README-%E4%B8%AD%E6%96%87-0F172A?style=flat-square)](./README.zh-CN.md)
![Shell](https://img.shields.io/badge/Shell-Bash-121011?style=flat-square&logo=gnubash&logoColor=white)
![Python](https://img.shields.io/badge/Runtime-Python%203-3776AB?style=flat-square&logo=python&logoColor=white)
![Bark](https://img.shields.io/badge/Notify-Bark-2F7CF6?style=flat-square)
![Codex](https://img.shields.io/badge/Target-Codex%20Notify-0F172A?style=flat-square)
![Status](https://img.shields.io/badge/Status-Ready-1F883D?style=flat-square)

</div>

## Overview

`codex-bark-notify-hook` is a standalone notification adapter for Codex. It accepts Codex `notify` payloads, extracts a readable title and summary, deduplicates by `thread-id + turn-id`, then forwards the result to Bark through `bark-notify`.

The goal is not to build a heavyweight messaging platform. This repository focuses on a small, portable, easy-to-verify notification loop that can live independently from your main project repositories.

## Features

- Accept Codex `notify` payloads and derive a readable title, summary, and working-directory context.
- Compress notification summaries for mobile-friendly reading.
- Deduplicate repeated notifications using `thread-id + turn-id`.
- Send all Bark notifications through `bin/codex-safe-final.sh` with one retry on failure.
- Allow log path, state directory, and notification entrypoint to be overridden via environment variables.
- Keep runtime artifacts inside `log/` and `tmp/` by default so the repository stays clean.

## Tech Stack

- `bash` for hook orchestration and notification entrypoints
- `python3` for JSON parsing and summary formatting
- `bark-notify` for actual Bark delivery

## Project Structure

```text
.
├── bin/
│   ├── codex-notify-hook.sh
│   └── codex-safe-final.sh
├── log/
│   └── .gitkeep
├── tmp/
│   └── .gitkeep
├── .gitignore
├── README.md
└── README.zh-CN.md
```

## Quick Start

1. Clone the repository and enter the directory.

```bash
git clone https://github.com/githubbzxs/codex-bark-notify-hook.git
cd codex-bark-notify-hook
```

2. Make sure the scripts are executable.

```bash
chmod +x bin/codex-notify-hook.sh bin/codex-safe-final.sh
```

3. Prepare the runtime environment.

```bash
command -v python3
command -v bark-notify
export BARK_PUSH_URL="https://example.com/your-bark-endpoint"
```

4. Register the hook in your Codex configuration.

```toml
notify = ["/absolute/path/to/codex-bark-notify-hook/bin/codex-notify-hook.sh"]
```

5. Validate the flow manually before relying on it in real sessions.

```bash
./bin/codex-safe-final.sh "Test summary" "Test title"
./bin/codex-notify-hook.sh '{"thread-id":"t1","turn-id":"u1","cwd":"/root/demo","last-assistant-message":"Task completed","input-messages":["Please help me deploy notifications"]}'
```

## Environment Variables

### Required

- `BARK_PUSH_URL`: Bark push endpoint

### Supported by This Repository

- `BARK_NOTIFY_BIN`: custom path to the `bark-notify` executable
- `CODEX_BARK_HOOK_LOG`: custom hook log file path
- `CODEX_BARK_STATE_DIR`: custom dedupe state directory
- `CODEX_BARK_SAFE_FINAL`: custom path to the final notification entry script
- `BARK_RETRY_DELAY_SEC`: retry delay in seconds, default `1`

## Runtime Model

The notification flow works like this:

1. Codex triggers `notify` and passes the payload to `bin/codex-notify-hook.sh`.
2. The hook parses JSON and derives a title, summary, and dedupe key.
3. If the current turn was already delivered, it logs and exits.
4. Otherwise it calls `bin/codex-safe-final.sh` to send the Bark notification.
5. On success it writes the dedupe key to disk; on failure it logs the event without blocking the main Codex workflow.

## For Coding Agents

If you are a coding agent, your primary goal here is not feature expansion. It is to preserve a notification pipeline that is stable, verifiable, and easy to roll back.

Before changing anything, confirm these facts:

- There are only two core entrypoints: `bin/codex-notify-hook.sh` and `bin/codex-safe-final.sh`.
- The real dependencies are `bash`, `python3`, `bark-notify`, and `BARK_PUSH_URL`.
- A change is not done because the scripts look reasonable. It is done only when a real Bark notification is received and duplicate turns are suppressed.

Recommended workflow:

1. Check that both scripts exist and are executable.
2. Confirm that environment variables and external executables are present.
3. After changes, run both manual validations. Do not skip either the `safe-final` or the `notify-hook` path.
4. Unless absolutely necessary, do not introduce databases, queues, web services, or extra infrastructure.

Minimum validation commands:

```bash
./bin/codex-safe-final.sh "Test summary" "Test title"
./bin/codex-notify-hook.sh '{"thread-id":"t1","turn-id":"u1","cwd":"/root/demo","last-assistant-message":"Task completed","input-messages":["Please help me deploy notifications"]}'
```

A change should only be considered complete when all of the following are true:

- A Bark device actually receives the notification.
- Repeated triggers for the same `thread-id + turn-id` are deduplicated.
- Logs are written, but failures do not interrupt the main Codex flow.
- Notification content stays short and excludes secrets, tokens, passwords, or full conversation text.

## Use Cases

- You run Codex tasks in the terminal and want a phone notification when a turn completes.
- You want notification logic to live outside your main application repositories so it can be reused across machines.
- You want a small, direct solution instead of standing up a full bot platform or messaging backend.

## Security Note

- Do not commit `BARK_PUSH_URL`, device keys, tokens, passwords, or other secrets.
- Do not push full conversation content into notification bodies.
- Do not make notification retries block the main Codex workflow.
- Keep `log/` and `tmp/` out of versioned runtime artifacts.

## Repository

- GitHub: https://github.com/githubbzxs/codex-bark-notify-hook
- Default log file: `log/notify-hook.log`
- Default dedupe state file: `tmp/last-notify-key`

## Acknowledgements

Thanks to the LinuxDo community for discussion, shared experience, and inspiration.
