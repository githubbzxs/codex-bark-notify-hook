#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
PAYLOAD="${@: -1}"
HOOK_LOG="${CODEX_BARK_HOOK_LOG:-${REPO_ROOT}/log/notify-hook.log}"
STATE_DIR="${CODEX_BARK_STATE_DIR:-${REPO_ROOT}/tmp}"
STATE_FILE="${STATE_DIR}/last-notify-key"
SAFE_FINAL="${CODEX_BARK_SAFE_FINAL:-${REPO_ROOT}/bin/codex-safe-final.sh}"

mkdir -p "${STATE_DIR}" "$(dirname "${HOOK_LOG}")"

log() {
  printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" >>"${HOOK_LOG}"
}

if [[ -z "${PAYLOAD}" ]]; then
  log "收到空 payload，跳过通知。"
  exit 0
fi

parsed="$(
  python3 - "${PAYLOAD}" <<'PY'
import json
import os
import re
import sys

payload = sys.argv[1]

try:
    data = json.loads(payload)
except Exception:
    print(json.dumps({
        "ok": False,
        "error": "invalid-json",
    }, ensure_ascii=False))
    raise SystemExit(0)

def compact(text: str) -> str:
    text = re.sub(r"\s+", " ", text or "").strip()
    if len(text) > 120:
        text = text[:117].rstrip() + "..."
    return text

turn_type = data.get("type") or ""
thread_id = data.get("thread-id") or ""
turn_id = data.get("turn-id") or ""
cwd = data.get("cwd") or ""
client = data.get("client") or ""
inputs = data.get("input-messages") or []
last_message = data.get("last-assistant-message") or ""

summary = compact(last_message)
if not summary and inputs:
    summary = "已完成：" + compact(str(inputs[-1]))
if not summary:
    summary = "本次任务已完成"

base = os.path.basename(cwd.rstrip("/")) if cwd else ""
title = "Codex 已完成"
if base:
    title = f"Codex 已完成 · {base}"

print(json.dumps({
    "ok": True,
    "type": turn_type,
    "thread_id": thread_id,
    "turn_id": turn_id,
    "client": client,
    "cwd": cwd,
    "title": title,
    "summary": summary,
    "dedupe_key": f"{thread_id}:{turn_id}",
}, ensure_ascii=False))
PY
)"

ok="$(python3 - "${parsed}" <<'PY'
import json, sys
try:
    print("1" if json.loads(sys.argv[1]).get("ok") else "0")
except Exception:
    print("0")
PY
)"

if [[ "${ok}" != "1" ]]; then
  log "payload 解析失败，跳过通知。"
  exit 0
fi

dedupe_key="$(python3 - "${parsed}" <<'PY'
import json, sys
print(json.loads(sys.argv[1]).get("dedupe_key", ""))
PY
)"

if [[ -n "${dedupe_key}" ]] && [[ -f "${STATE_FILE}" ]] && [[ "$(cat "${STATE_FILE}")" == "${dedupe_key}" ]]; then
  log "检测到重复 turn：${dedupe_key}，跳过通知。"
  exit 0
fi

summary="$(python3 - "${parsed}" <<'PY'
import json, sys
print(json.loads(sys.argv[1])["summary"])
PY
)"

title="$(python3 - "${parsed}" <<'PY'
import json, sys
print(json.loads(sys.argv[1])["title"])
PY
)"

if [[ ! -x "${SAFE_FINAL}" ]]; then
  log "未找到通知入口脚本：${SAFE_FINAL}"
  exit 0
fi

if "${SAFE_FINAL}" "${summary}" "${title}" >>"${HOOK_LOG}" 2>&1; then
  if [[ -n "${dedupe_key}" ]]; then
    printf '%s' "${dedupe_key}" >"${STATE_FILE}"
  fi
  log "通知发送完成：${title} | ${summary}"
else
  log "通知发送失败：${title} | ${summary}"
fi

exit 0
