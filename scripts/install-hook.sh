#!/usr/bin/env bash
#
# install-hook.sh
#
# Installs the Claude Code statusLine hook. This is the actual install logic
# — UsageLine.app just runs this script once on launch and quits; this file
# also works completely standalone, no app required. Copies
# statusline-indicator.sh to a stable location (~/.claude/usageline/) and
# points $CLAUDE_CONFIG_DIR/settings.json's `statusLine` key at it (falling
# back to ~/.claude if CLAUDE_CONFIG_DIR isn't set). If a compatible hook
# (this one, or Margherita's) is already installed, does nothing — both
# scripts write the same indicator.json shape, so there's no need to fight
# over which one is active.
#
# To install into an isolated Claude Code profile (one that's normally
# launched with its own CLAUDE_CONFIG_DIR, e.g. a per-client setup like
# `alias cc-work='CLAUDE_CONFIG_DIR="$HOME/.claude-work" claude'`), set the
# same variable before running this script:
#   CLAUDE_CONFIG_DIR="$HOME/.claude-work" ./scripts/install-hook.sh
# The installed script itself is shared (one copy, always under
# ~/.claude/usageline/ regardless of profile) — only settings.json and the
# resulting indicator.json are per-profile.
#
# Usage: ./scripts/install-hook.sh
#
# Dependencies: bash + jq only. No network access, no Xcode/Swift required.

set -euo pipefail

command -v jq >/dev/null 2>&1 || {
  echo "error: jq is required (brew install jq)" >&2
  exit 1
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source_script="$script_dir/statusline-indicator.sh"
if [[ ! -f "$source_script" ]]; then
  echo "error: couldn't find statusline-indicator.sh next to this script" >&2
  exit 1
fi

settings_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
hook_dir="$HOME/.claude/usageline"
dest_script="$hook_dir/statusline-indicator.sh"
settings="$settings_dir/settings.json"

mkdir -p "$settings_dir"

if [[ -f "$settings" ]] && jq -e '.statusLine.command // "" | contains("statusline-indicator.sh")' "$settings" >/dev/null 2>&1; then
  echo "A statusLine hook is already installed ($(jq -r '.statusLine.command' "$settings")); leaving it as-is."
  echo "Its output is compatible with UsageLine, so nothing else to do."
  exit 0
fi

mkdir -p "$hook_dir"
cp "$source_script" "$dest_script"
chmod +x "$dest_script"

tmp="$(mktemp "$settings_dir/.settings.json.XXXXXX.tmp")"
trap 'rm -f "$tmp"' EXIT

if [[ -f "$settings" ]]; then
  # Fails fast (set -e) on invalid JSON rather than clobbering the user's
  # other Claude Code settings (model, env, other hooks...).
  jq --arg cmd "$dest_script" '.statusLine = {type: "command", command: $cmd}' "$settings" > "$tmp"
else
  jq -n --arg cmd "$dest_script" '{statusLine: {type: "command", command: $cmd}}' > "$tmp"
fi
mv "$tmp" "$settings"

echo "Hook installed: $dest_script"
echo "Ask Claude Code a question in your terminal to see the usage line appear."
