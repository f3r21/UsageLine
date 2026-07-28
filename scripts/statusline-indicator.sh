#!/usr/bin/env bash
#
# statusline-indicator.sh
#
# Claude Code invokes this as its `statusLine` command, piping the session
# JSON payload on stdin. Writes the rate-limit meters to
# $CLAUDE_CONFIG_DIR/indicator.json (falling back to ~/.claude if
# CLAUDE_CONFIG_DIR isn't set — same shape Margherita's own hook script uses,
# so either one can be the active hook without breaking the other) and
# prints a compact usage line — e.g. "5h 22% · 7d 2%" — which is what Claude
# Code shows in your terminal.
#
# Respecting CLAUDE_CONFIG_DIR matters for isolated Claude Code profiles
# (e.g. `CLAUDE_CONFIG_DIR="$HOME/.claude-work" claude`): Claude Code invokes
# this script with that profile's own CLAUDE_CONFIG_DIR already set in its
# environment, so each profile's indicator.json stays separate automatically
# — no per-profile install step needed for this part.
#
# Dependencies: bash + jq only. No network access.

set -euo pipefail

input="$(cat)"

# `rate_limits` is only present for Claude.ai (Pro/Max) sessions, and only
# after the first API response. When absent, leave the output file untouched
# and emit nothing.
if ! printf '%s' "$input" | jq -e '(.rate_limits // {}) | length > 0' >/dev/null 2>&1; then
  exit 0
fi

claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
out="$claude_dir/indicator.json"
tmp="$claude_dir/.indicator.json.tmp"
trap 'rm -f "$tmp"' EXIT

# Build indicator.json. Meter names are not hardcoded: every key under
# `rate_limits` is carried through so future meters surface automatically.
printf '%s' "$input" | jq '{
  updated_at: (now | todateiso8601),
  primary_meter: (
    if (.rate_limits | has("seven_day")) then "seven_day"
    else (.rate_limits | keys | sort | .[0])
    end
  ),
  rate_limits: (
    .rate_limits
    | to_entries
    | map({
        key: .key,
        value: {
          used_percentage: (.value.used_percentage // 0),
          resets_at_unix: (.value.resets_at // 0)
        }
      })
    | from_entries
  )
}' > "$tmp"

# Atomic replace: any app watching ~/.claude for this file watches the
# parent directory, since this rename changes the inode on every update.
mv "$tmp" "$out"

# Visible status line: compact per-meter usage, e.g. "7d 2% · 5h 22%".
printf '%s' "$input" | jq -r '
  def meterName(k):
    if k == "seven_day" then "7d"
    elif k == "five_hour" then "5h"
    else k end;
  .rate_limits
  | to_entries
  | map("\(meterName(.key)) \(.value.used_percentage // 0 | floor)%")
  | join(" · ")
'
