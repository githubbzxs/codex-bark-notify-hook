#!/usr/bin/env bash

set -euo pipefail

# 统一发送通知，当前支持 Bark 与通用 Webhook 转发。
# 用法：
#   ./bin/codex-safe-final.sh "本次任务的一句话摘要"
#   ./bin/codex-safe-final.sh "本次任务的一句话摘要" "自定义标题"

SUMMARY="${1:-}"
TITLE="${2:-Codex 已完成}"
RETRY_DELAY_SEC="${NOTIFY_RETRY_DELAY_SEC:-${BARK_RETRY_DELAY_SEC:-1}}"
WEBHOOK_URL="${WEBHOOK_URL:-}"

if [[ -n "${BARK_NOTIFY_BIN:-}" ]]; then
  NOTIFY_BIN="${BARK_NOTIFY_BIN}"
else
  NOTIFY_BIN="$(command -v bark-notify || true)"
fi

if [[ -z "${SUMMARY}" ]]; then
  echo "用法：./bin/codex-safe-final.sh \"本次任务的一句话摘要\" [自定义标题]" >&2
  exit 2
fi

send_notification() {
  "${NOTIFY_BIN}" "${TITLE}" "${SUMMARY}"
}

send_bark() {
  if [[ -z "${BARK_PUSH_URL:-}" ]]; then
    return 10
  fi

  if [[ -z "${NOTIFY_BIN}" ]] || [[ ! -x "${NOTIFY_BIN}" ]]; then
    echo "错误：已设置 BARK_PUSH_URL，但未找到可执行的 bark-notify，请设置 BARK_NOTIFY_BIN 或把 bark-notify 放到 PATH 中。" >&2
    return 1
  fi

  if send_notification; then
    echo "Bark 通知发送成功。"
    return 0
  fi

  echo "Bark 第一次发送失败，准备重试一次..." >&2
  sleep "${RETRY_DELAY_SEC}"

  if send_notification; then
    echo "Bark 通知重试成功。"
    return 0
  fi

  echo "Bark 通知发送失败（已重试 1 次）。" >&2
  return 1
}

send_webhook() {
  if [[ -z "${WEBHOOK_URL}" ]]; then
    return 10
  fi

  python3 - "${WEBHOOK_URL}" "${TITLE}" "${SUMMARY}" <<'PY'
import json
from datetime import datetime, timezone
import sys
import urllib.error
import urllib.request

webhook_url = sys.argv[1]
title = sys.argv[2]
summary = sys.argv[3]

text = title if not summary else f"{title}\n{summary}"
payload = {
    "source": "codex-bark-notify-hook",
    "title": title,
    "summary": summary,
    "text": text,
    "sent_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
}
data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
request = urllib.request.Request(
    webhook_url,
    data=data,
    headers={"Content-Type": "application/json; charset=utf-8"},
    method="POST",
)

try:
    with urllib.request.urlopen(request, timeout=10) as response:
        body = response.read().decode("utf-8", errors="replace")
except urllib.error.HTTPError as exc:
    detail = exc.read().decode("utf-8", errors="replace")
    print(f"Webhook 请求失败：HTTP {exc.code} {detail}", file=sys.stderr)
    raise SystemExit(1)
except Exception as exc:
    print(f"Webhook 请求失败：{exc}", file=sys.stderr)
    raise SystemExit(1)

if body:
    try:
        parsed = json.loads(body)
    except Exception:
        parsed = None
    if isinstance(parsed, dict):
        status = parsed.get("status")
        ok = parsed.get("ok")
        success = parsed.get("success")
        if status not in (None, "ok", "success", 0, 200):
            print(f"Webhook 返回异常：status={status} body={body}", file=sys.stderr)
            raise SystemExit(1)
        if ok is False or success is False:
            print(f"Webhook 返回异常：body={body}", file=sys.stderr)
            raise SystemExit(1)

print("Webhook 通知发送成功。")
PY
}

configured_channels=0
successful_channels=0
failed_channels=0

if [[ -n "${BARK_PUSH_URL:-}" ]]; then
  configured_channels=$((configured_channels + 1))
  if send_bark; then
    successful_channels=$((successful_channels + 1))
  else
    failed_channels=$((failed_channels + 1))
  fi
fi

if [[ -n "${WEBHOOK_URL}" ]]; then
  configured_channels=$((configured_channels + 1))
  if send_webhook; then
    successful_channels=$((successful_channels + 1))
  else
    failed_channels=$((failed_channels + 1))
  fi
fi

if [[ "${configured_channels}" -eq 0 ]]; then
  echo "错误：未设置任何通知通道，请至少配置 BARK_PUSH_URL 或 WEBHOOK_URL。" >&2
  exit 4
fi

if [[ "${successful_channels}" -gt 0 ]]; then
  if [[ "${failed_channels}" -gt 0 ]]; then
    echo "警告：部分通知通道发送失败，但至少有一个通道发送成功。" >&2
  fi
  exit 0
fi

exit 1
