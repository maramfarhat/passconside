#!/usr/bin/env bash
set -euo pipefail
PASS_AI_HOME=/workspace/pass-ai
PID_FILE="$PASS_AI_HOME/logs/admin.pid"
LOG="$PASS_AI_HOME/logs/admin.log"
mkdir -p "$PASS_AI_HOME/logs"
if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
  echo "Admin already running PID $(cat "$PID_FILE")"
  exit 0
fi
nohup python3 "$PASS_AI_HOME/scripts/admin_server.py" >> "$LOG" 2>&1 &
echo $! > "$PID_FILE"
echo "Admin API on :30001 PID $(cat "$PID_FILE")"
