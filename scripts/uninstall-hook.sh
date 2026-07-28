#!/usr/bin/env bash
#
# uninstall-hook.sh
#
# Removes the `statusLine` key installed by install-hook.sh (or by the
# UsageLine/Margherita app) from $CLAUDE_CONFIG_DIR/settings.json (falling
# back to ~/.claude if CLAUDE_CONFIG_DIR isn't set), leaving every other key
# untouched. Does NOT delete ~/.claude/usageline/statusline-indicator.sh or
# indicator.json — only the hook wiring is removed.
#
# To remove the hook from an isolated profile, set the same
# CLAUDE_CONFIG_DIR that profile normally uses:
#   CLAUDE_CONFIG_DIR="$HOME/.claude-work" ./scripts/uninstall-hook.sh
#
# Usage: ./scripts/uninstall-hook.sh
#
# Dependencies: bash + jq only.

set -euo pipefail

command -v jq >/dev/null 2>&1 || {
  echo "error: jq is required (brew install jq)" >&2
  exit 1
}

settings_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings="$settings_dir/settings.json"

if [[ ! -f "$settings" ]]; then
  echo "Nothing to uninstall: $settings doesn't exist."
  exit 0
fi

tmp="$(mktemp "$settings_dir/.settings.json.XXXXXX.tmp")"
trap 'rm -f "$tmp"' EXIT

# Fails fast (set -e) on invalid JSON rather than clobbering the user's
# other Claude Code settings.
jq 'del(.statusLine)' "$settings" > "$tmp"
mv "$tmp" "$settings"

echo "Hook removed from $settings"
