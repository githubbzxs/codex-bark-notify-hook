<div align="center">

# codex-bark-notify-hook

把 Codex 的 `notify` 回调稳定地转成 Bark 推送。

一套足够轻、足够直接、适合长期挂在开发环境里的通知 hook：解析 payload、压缩摘要、按 turn 去重、统一发送、失败重试。

[![English](https://img.shields.io/badge/README-English-0F172A?style=flat-square)](./README.md)
![Shell](https://img.shields.io/badge/Shell-Bash-121011?style=flat-square&logo=gnubash&logoColor=white)
![Python](https://img.shields.io/badge/Runtime-Python%203-3776AB?style=flat-square&logo=python&logoColor=white)
![Bark](https://img.shields.io/badge/Notify-Bark-2F7CF6?style=flat-square)
![Codex](https://img.shields.io/badge/Target-Codex%20Notify-0F172A?style=flat-square)
![Status](https://img.shields.io/badge/Status-Ready-1F883D?style=flat-square)

</div>

## 项目概览

`codex-bark-notify-hook` 是一个独立的 Codex 通知适配层。它接收 Codex 的 `notify` payload，提取可读标题与摘要，按 `thread-id + turn-id` 去重，再通过 `bark-notify` 把结果发送到 Bark。

这个仓库的目标不是做一套重型消息平台，而是提供一个足够小、可迁移、容易验证的通知闭环。你可以把它单独放在任意机器上，然后在 Codex 配置中把它接成统一通知入口。

## 功能特性

- 接收 Codex `notify` payload，自动提取标题、摘要与上下文目录名。
- 默认把摘要压缩成更适合移动端通知阅读的短文本。
- 使用 `thread-id + turn-id` 作为去重键，避免同一轮重复推送。
- 统一通过 `bin/codex-safe-final.sh` 发送 Bark，并在失败时自动重试 1 次。
- 日志文件、状态目录、通知入口都支持环境变量覆盖，不依赖固定路径。
- 默认把运行产物限制在 `log/` 和 `tmp/`，避免污染仓库提交。

## 技术栈

- `bash`：负责 hook 入口、流程编排与发送脚本。
- `python3`：负责解析 JSON payload 和整理通知文案。
- `bark-notify`：负责真正发送 Bark 推送。

## 项目结构

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

1. 克隆仓库并进入目录。

```bash
git clone https://github.com/githubbzxs/codex-bark-notify-hook.git
cd codex-bark-notify-hook
```

2. 确保脚本可执行。

```bash
chmod +x bin/codex-notify-hook.sh bin/codex-safe-final.sh
```

3. 准备运行环境。

```bash
command -v python3
command -v bark-notify
export BARK_PUSH_URL="https://example.com/your-bark-endpoint"
```

4. 在 Codex 全局配置中接入 `notify` hook。

```toml
notify = ["/absolute/path/to/codex-bark-notify-hook/bin/codex-notify-hook.sh"]
```

5. 先手动验证，再交给 Codex 正式使用。

```bash
./bin/codex-safe-final.sh "测试摘要" "测试标题"
./bin/codex-notify-hook.sh '{"thread-id":"t1","turn-id":"u1","cwd":"/root/demo","last-assistant-message":"任务完成","input-messages":["请帮我做点什么"]}'
```

## 环境变量

### 必填

- `BARK_PUSH_URL`：Bark 推送地址。

### 仓库脚本支持

- `BARK_NOTIFY_BIN`：自定义 `bark-notify` 可执行文件路径。
- `CODEX_BARK_HOOK_LOG`：自定义 hook 日志文件路径。
- `CODEX_BARK_STATE_DIR`：自定义去重状态目录。
- `CODEX_BARK_SAFE_FINAL`：自定义通知发送入口脚本路径。
- `BARK_RETRY_DELAY_SEC`：失败后重试前等待秒数，默认 `1`。

## 运行模型

通知链路按下面的顺序工作：

1. Codex 触发 `notify`，并把 payload 传给 `bin/codex-notify-hook.sh`。
2. hook 脚本解析 JSON，生成标题、摘要和去重键。
3. 如果当前 turn 已推送过，则直接记录日志并跳过。
4. 若未命中去重，则调用 `bin/codex-safe-final.sh` 统一发送 Bark。
5. 发送成功后写入状态文件；发送失败则记录日志，但不阻塞 Codex 主流程。

## 给 Coding Agent 的说明

如果你是一个 coding agent，这个仓库最重要的不是“继续加功能”，而是维持通知链路的稳定性、可验证性和可回滚性。

开始工作前，请先确认以下事实：

- 核心入口只有两个：`bin/codex-notify-hook.sh` 与 `bin/codex-safe-final.sh`。
- 真实依赖只有 `bash`、`python3`、`bark-notify` 和环境变量 `BARK_PUSH_URL`。
- 这个项目的验收标准不是脚本看起来合理，而是能收到一条真实 Bark 通知，并且重复 turn 不会重复推送。

推荐工作顺序：

1. 先检查脚本是否存在、是否可执行。
2. 再检查环境变量与可执行依赖是否齐全。
3. 修改后必须执行手动验证，不要跳过 `safe-final` 与 `notify-hook` 两类测试。
4. 除非确有必要，不要引入额外服务、数据库、消息队列或 Web 后端。

推荐最小验证命令：

```bash
./bin/codex-safe-final.sh "测试摘要" "测试标题"
./bin/codex-notify-hook.sh '{"thread-id":"t1","turn-id":"u1","cwd":"/root/demo","last-assistant-message":"任务完成","input-messages":["请帮我做点什么"]}'
```

只有满足下面几点，才算改动完成：

- Bark 终端实际收到通知。
- 同一组 `thread-id + turn-id` 被重复触发时会命中去重。
- 日志有记录，但失败不会中断主流程。
- 通知内容保持简短，不包含密钥、Token、密码或完整对话正文。

## 使用场景

- 你经常把 Codex 任务挂在终端里跑，希望任务结束后第一时间收到手机提醒。
- 你希望通知逻辑能独立于业务仓库存在，方便多台机器复用。
- 你需要一个足够轻的方案，而不是搭一整套机器人、数据库和消息中间件。

## 安全说明

- 不要把 `BARK_PUSH_URL`、设备 Key、Token、密码或其他敏感信息写入仓库。
- 不要把完整对话内容直接塞进通知正文。
- 不要把失败重试设计成阻塞 Codex 主流程。
- `log/` 与 `tmp/` 默认不会进入提交历史，请保持这一约束。

## 仓库说明

- GitHub: https://github.com/githubbzxs/codex-bark-notify-hook
- 默认日志文件：`log/notify-hook.log`
- 默认去重状态文件：`tmp/last-notify-key`

## 致谢

感谢 LinuxDo 社区的讨论、经验分享与灵感支持。
