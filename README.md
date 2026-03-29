# codex-bark-notify-hook

把 Codex 的 `notify` 回调转成 Bark 推送的独立仓库。

## 目录结构

```text
.
├── bin/
│   ├── codex-notify-hook.sh
│   └── codex-safe-final.sh
├── log/
├── tmp/
└── README.md
```

## 功能说明

- 接收 Codex `notify` payload，提取标题、摘要与去重键。
- 自动跳过重复 turn，避免同一轮多次推送。
- 通过 `bark-notify` 发送 Bark 通知，失败时自动重试 1 次。
- 日志、状态文件、通知入口都支持环境变量覆盖，不依赖固定项目路径。

## 依赖

- `bash`
- `python3`
- `bark-notify`
- 环境变量 `BARK_PUSH_URL`

## 安装

1. 克隆仓库。
2. 确保 `bin/codex-notify-hook.sh` 与 `bin/codex-safe-final.sh` 可执行。
3. 在 Codex 全局配置中加入：

```toml
notify = ["/绝对路径/codex-bark-notify-hook/bin/codex-notify-hook.sh"]
```

## 给 Coding Agent 的部署说明

> 如果你是一个 coding agent，请先读完本节，再决定是否修改脚本或执行部署。

你的目标不是扩展出一套通用通知平台，而是保证这条 Bark 通知链路稳定、可验证、可回滚。

### 推荐工作顺序

1. 先检查 `bin/codex-notify-hook.sh` 和 `bin/codex-safe-final.sh` 是否存在且可执行。
2. 再确认运行依赖是否齐全：`bash`、`python3`、`bark-notify`、`BARK_PUSH_URL`。
3. 修改后优先做手动验证，不要只看脚本能跑通就结束。

### 最小部署流程

```bash
chmod +x bin/codex-notify-hook.sh bin/codex-safe-final.sh
command -v bark-notify
test -n "${BARK_PUSH_URL:-}"
```

Codex 侧配置目标：

```toml
notify = ["/绝对路径/codex-bark-notify-hook/bin/codex-notify-hook.sh"]
```

### 必做验证

先验证最终发送入口：

```bash
./bin/codex-safe-final.sh "测试摘要" "测试标题"
```

再验证 hook 入口：

```bash
./bin/codex-notify-hook.sh '{"thread-id":"t1","turn-id":"u1","cwd":"/root/demo","last-assistant-message":"任务完成","input-messages":["请帮我做点什么"]}'
```

### 验收标准

- Bark 终端能实际收到通知。
- 同一组 `thread-id + turn-id` 重复触发时会被去重。
- 失败信息进入日志，但不会阻塞主流程。
- 通知内容保持简短，且不包含敏感信息。

### 禁止事项

- 不要把 `BARK_PUSH_URL`、设备 Key、Token 或密码写入仓库。
- 不要把完整对话原文直接推送到 Bark。
- 不要为了这个项目额外引入数据库、队列或 Web 服务。

## 环境变量

- `BARK_PUSH_URL`：必填，Bark 推送地址。
- `BARK_NOTIFY_BIN`：可选，`bark-notify` 可执行文件路径。
- `CODEX_BARK_HOOK_LOG`：可选，自定义 hook 日志文件路径。
- `CODEX_BARK_STATE_DIR`：可选，自定义去重状态目录。
- `CODEX_BARK_SAFE_FINAL`：可选，自定义通知发送入口脚本路径。
- `BARK_RETRY_DELAY_SEC`：可选，重试前等待秒数，默认 `1`。

## 手动测试

直接发送一条 Bark：

```bash
./bin/codex-safe-final.sh "测试摘要" "测试标题"
```

模拟 Codex notify hook：

```bash
./bin/codex-notify-hook.sh '{"thread-id":"t1","turn-id":"u1","cwd":"/root/demo","last-assistant-message":"任务完成","input-messages":["请帮我做点什么"]}'
```

## 日志与状态

- 日志默认写入 `log/notify-hook.log`
- 去重状态默认写入 `tmp/last-notify-key`

这两个目录默认已加入 `.gitignore`，不会污染仓库提交。

## 致谢

感谢 LinuxDo 社区的讨论、经验分享与灵感支持。
