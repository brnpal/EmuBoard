#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PLIST_NAME="com.brnpal.emuboard.plist"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME"
SERVICE_NAME="com.brnpal.emuboard"
HOST="${EMUBOARD_HOST:-127.0.0.1}"
PORT="${EMUBOARD_PORT:-8080}"
HEALTH_URL="http://$HOST:$PORT/api/health"
DEFAULT_URL="http://$HOST:$PORT/"
SERVER_STDOUT="$REPO_ROOT/logs/emuboard.stdout.log"
SERVER_STDERR="$REPO_ROOT/logs/emuboard.stderr.log"
SKIP_BROWSER="${EMUBOARD_SKIP_OPEN:-0}"
LAUNCH_ARG="${1:-}"

if [[ "$LAUNCH_ARG" == "--no-browser" ]]; then
  SKIP_BROWSER=1
  LAUNCH_ARG="${2:-}"
fi

mkdir -p "$REPO_ROOT/logs"

normalize_target_url() {
  local candidate="${1:-}"

  if [[ -z "$candidate" ]]; then
    echo "$DEFAULT_URL"
    return 0
  fi

  if [[ "$candidate" == http://* || "$candidate" == https://* ]]; then
    echo "$candidate"
    return 0
  fi

  echo "$DEFAULT_URL"
}

is_server_healthy() {
  curl -fsS "$HEALTH_URL" >/dev/null 2>&1
}

wait_for_server() {
  local attempt

  for attempt in {1..40}; do
    if is_server_healthy; then
      return 0
    fi

    sleep 0.25
  done

  return 1
}

bootstrap_launch_agent() {
  local gui_domain="gui/$(id -u)"
  local service_target="$gui_domain/$SERVICE_NAME"

  if launchctl print "$service_target" >/dev/null 2>&1; then
    launchctl kickstart -k "$service_target" >/dev/null 2>&1 || true
    return 0
  fi

  launchctl bootstrap "$gui_domain" "$PLIST_PATH" >/dev/null 2>&1 || true
  launchctl kickstart -k "$service_target" >/dev/null 2>&1 || true
}

start_server_directly() {
  local node_path
  node_path="$(command -v node)"

  if [[ -z "$node_path" ]]; then
    echo "Could not find node on PATH."
    exit 1
  fi

  "$node_path" "$REPO_ROOT/server.js" >>"$SERVER_STDOUT" 2>>"$SERVER_STDERR" &
}

ensure_server_running() {
  if is_server_healthy; then
    return 0
  fi

  if [[ -f "$PLIST_PATH" ]]; then
    bootstrap_launch_agent
    if wait_for_server; then
      return 0
    fi
  fi

  start_server_directly

  if wait_for_server; then
    return 0
  else
    echo "EmuBoard did not become healthy at $HEALTH_URL"
    exit 1
  fi
}

TARGET_URL="$(normalize_target_url "$LAUNCH_ARG")"

ensure_server_running

if [[ "$SKIP_BROWSER" != "1" ]]; then
  open "$TARGET_URL"
fi
