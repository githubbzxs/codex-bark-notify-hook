#!/usr/bin/env bash

set -euo pipefail

# 统一发送 Bark 通知，失败时自动重试一次。
# 用法：
#   ./bin/codex-safe-final.sh "本次任务的一句话摘要"
#   ./bin/codex-safe-final.sh "本次任务的一句话摘要" "自定义标题"

SUMMARY="${1:-}"
TITLE="${2:-Codex 已完成}"
RETRY_DELAY_SEC="${BARK_RETRY_DELAY_SEC:-1}"

if [[ -n "${BARK_NOTIFY_BIN:-}" ]]; then
  NOTIFY_BIN="${BARK_NOTIFY_BIN}"
else
  NOTIFY_BIN="$(command -v bark-notify || true)"
fi

if [[ -z "${SUMMARY}" ]]; then
  echo "用法：./bin/codex-safe-final.sh \"本次任务的一句话摘要\" [自定义标题]" >&2
  exit 2
fi

if [[ -z "${NOTIFY_BIN}" ]] || [[ ! -x "${NOTIFY_BIN}" ]]; then
  echo "错误：未找到可执行的 bark-notify，请设置 BARK_NOTIFY_BIN 或把 bark-notify 放到 PATH 中。" >&2
  exit 3
fi

if [[ -z "${BARK_PUSH_URL:-}" ]]; then
  echo "错误：环境变量 BARK_PUSH_URL 未设置，无法发送 Bark 通知。" >&2
  exit 4
fi

send_notification() {
  "${NOTIFY_BIN}" "${TITLE}" "${SUMMARY}"
}

if send_notification; then
  echo "Bark 通知发送成功。"
  exit 0
fi

echo "第一次发送失败，准备重试一次..." >&2
sleep "${RETRY_DELAY_SEC}"

if send_notification; then
  echo "Bark 通知重试成功。"
  exit 0
fi

echo "Bark 通知发送失败（已重试 1 次）。" >&2
exit 1
