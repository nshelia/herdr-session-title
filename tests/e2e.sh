#!/bin/sh
# End-to-end test against a real, throwaway herdr server.
#
# Starts an isolated headless server (its own HOME and socket, so it never
# touches your running herdr), links this plugin, fakes an agent in a pane by
# setting the terminal title and reporting agent state, then checks the
# metadata the plugin published.
#
#   tests/e2e.sh                     uses `herdr` from PATH
#   HERDR=/path/to/herdr tests/e2e.sh

set -eu

ROOT=$(cd "$(dirname "$0")/.." && pwd)
HERDR=${HERDR:-$(command -v herdr)}
[ -x "$HERDR" ] || { echo "herdr not found; set HERDR=/path/to/herdr" >&2; exit 1; }

# Short path: unix socket paths are limited to ~100 characters.
SANDBOX=$(mktemp -d /tmp/hst.XXXXXX)
export HOME="$SANDBOX"
export HERDR_SOCKET_PATH="$SANDBOX/h.sock"
unset HERDR_ENV HERDR_PANE_ID HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_CLIENT_SOCKET_PATH HERDR_BIN_PATH 2>/dev/null || true
mkdir -p "$HOME/.config/herdr"
printf 'onboarding = false\n' >"$HOME/.config/herdr/config.toml"

cleanup() {
  "$HERDR" server stop >/dev/null 2>&1 || true
  rm -rf "$SANDBOX"
}
trap cleanup EXIT

failures=0
pass() { printf 'ok   %s\n' "$1"; }
fail() { printf 'FAIL %s\n     %s\n' "$1" "$2"; failures=$((failures + 1)); }

# expect <name> <jq filter on pane> <expected value>
expect() {
  actual=$("$HERDR" pane get "$PANE" | jq -r ".result.pane | $2")
  if [ "$actual" = "$3" ]; then pass "$1"; else fail "$1" "expected '$3', got '$actual'"; fi
}

# Wait until a jq condition on the pane is true (event hooks run async).
wait_for() {
  i=0
  while [ $i -lt 50 ]; do
    [ "$("$HERDR" pane get "$PANE" | jq -r ".result.pane | $1")" = "true" ] && return 0
    sleep 0.2
    i=$((i + 1))
  done
  return 0
}

set_title() {
  "$HERDR" pane send-text "$PANE" "printf '\\033]0;$1\\007'
"
  wait_for ".terminal_title_stripped == \"$1\""
}

# report_state <state>: simulate the agent integration reporting a transition.
seq=0
report_state() {
  seq=$((seq + 1))
  "$HERDR" pane report-agent "$PANE" --source e2e --agent claude --state "$1" --seq "$seq" >/dev/null
}

echo "herdr: $("$HERDR" --version)"
("$HERDR" server >"$SANDBOX/server.log" 2>&1 &)
i=0
until "$HERDR" workspace list >/dev/null 2>&1; do
  i=$((i + 1)); [ $i -lt 50 ] || { echo "server did not start" >&2; cat "$SANDBOX/server.log" >&2; exit 1; }
  sleep 0.2
done

warnings=$("$HERDR" plugin link "$ROOT" | jq -c '.result.plugin.warnings // []')
if [ "$warnings" = "[]" ]; then pass "manifest links without warnings"; else fail "manifest links without warnings" "$warnings"; fi

PANE=$("$HERDR" workspace create --cwd "$SANDBOX" --label e2e | jq -r '.result.root_pane.pane_id')

# 1. Placeholder titles are ignored.
set_title "Claude Code"
report_state working
sleep 1
expect "placeholder title is ignored" '.title // "none"' "none"

# 2. A real session title is published everywhere.
set_title "Fix login redirect"
report_state idle
wait_for '.title == "Fix login redirect"'
expect "title is set" '.title' "Fix login redirect"
expect "display agent is set" '.display_agent' "Fix login redirect"
expect "session_title token is set" '.tokens.session_title' "Fix login redirect"

# 3. Renamed sessions update on the next state change.
set_title "Fix login redirect on Safari"
report_state working
wait_for '.title == "Fix login redirect on Safari"'
expect "title follows renames" '.title' "Fix login redirect on Safari"

# 4. Long titles are truncated (max-length from the plugin config dir).
CONFIG_DIR=$("$HERDR" plugin config-dir herdr-session-title | tail -n 1)
mkdir -p "$CONFIG_DIR"
echo 10 >"$CONFIG_DIR/max-length"
set_title "A very long session title indeed"
report_state idle
wait_for '.title == "A very lo…"'
expect "long titles are truncated" '.title' "A very lo…"
rm "$CONFIG_DIR/max-length"

# 5. display-agent=0 keeps the agent name.
echo 0 >"$CONFIG_DIR/display-agent"
set_title "Keep agent name"
report_state working
wait_for '.title == "Keep agent name"'
expect "display-agent=0 still sets title" '.title' "Keep agent name"
expect "display-agent=0 shows the agent name" '.display_agent // "agent name"' "agent name"
rm "$CONFIG_DIR/display-agent"

# 6. The sync action refreshes every agent pane.
set_title "Synced by action"
"$HERDR" plugin action invoke herdr-session-title.sync >/dev/null
wait_for '.title == "Synced by action"'
expect "sync action refreshes titles" '.title' "Synced by action"

# 7. No plugin command failed.
errors=$("$HERDR" plugin log list --plugin herdr-session-title --limit 100 |
  jq '[.result.logs[]? | select((.exit_code // 0) != 0 or ((.stderr // "") != ""))] | length')
if [ "$errors" = "0" ]; then pass "no plugin command errors"; else
  fail "no plugin command errors" "$("$HERDR" plugin log list --plugin herdr-session-title --limit 100 | jq -c '.result.logs[]? | select((.exit_code // 0) != 0 or ((.stderr // "") != ""))')"
fi

echo
if [ $failures -eq 0 ]; then echo "all tests passed"; else echo "$failures test(s) failed"; exit 1; fi
