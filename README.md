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
