# UsageLine

UsageLine installs the one thing that makes Claude Code show your rate-limit
usage in the terminal — a compact line like `"5h 22% · 7d 2%"`, printed by
Claude Code's own built-in `statusLine` feature — and then gets out of the
way completely.

**It is not a background app.** Double-click it once, it installs a small
hook, and it quits. Nothing of ours keeps running afterward — no menu bar
icon, no Dock icon, no process. The usage line keeps appearing in your
terminal forever because Claude Code itself calls the installed hook script
directly on every turn; that has nothing to do with UsageLine still running.

---

## Install (one click)

1. Download `UsageLine.dmg` and open it.
2. Double-click **`Install UsageLine.command`** (right-click → Open the
   first time — macOS always asks that once for anything downloaded that
   isn't from a paid Apple Developer ID, no way around that part for free).
3. That's it. A small terminal window shows its progress and closes; ask
   Claude Code something in your terminal — the usage line appears from then on.

That one script does the whole job in one step: copies `UsageLine.app` to
`/Applications`, re-signs it locally (a pre-built `.app` carries an ad-hoc
signature from the builder's machine, which macOS otherwise rejects with
`EXC_BAD_SIGNATURE`/`SIGKILL` on any other machine), clears the quarantine
flag, and launches it. If something then goes wrong (most commonly: `jq`
isn't installed), a dialog tells you what to fix.

<details>
<summary>Prefer to drag-and-drop + fix it yourself?</summary>

The DMG also has the traditional `UsageLine.app` + `Applications` shortcut
if you'd rather drag it in manually. In that case you'll need to run this
once yourself, since the copy Finder makes still carries the ad-hoc
signature from the builder's machine:

```bash
codesign --force --deep --sign - /Applications/UsageLine.app && xattr -d com.apple.quarantine /Applications/UsageLine.app 2>/dev/null || true
```

`Install UsageLine.command` exists specifically so nobody has to do this by
hand.
</details>

### Homebrew Tap Installation

```bash
brew tap f3r21/tap
brew install --cask usageline
```

---

## Don't even want to double-click an app?

`UsageLine.app` is just a thin wrapper around a shell script. Skip the app
entirely:

```bash
git clone https://github.com/f3r21/UsageLine.git
cd UsageLine
make install-hook       # or: ./scripts/install-hook.sh
```

Needs only `bash` + `jq` (`brew install jq`). To remove it later:
`make uninstall-hook`.

---

## Using an isolated Claude Code profile (e.g. per client)?

If you run Claude Code with its own config directory — a common pattern for
keeping separate accounts/clients isolated —

```bash
alias cc-work='CLAUDE_CONFIG_DIR="$HOME/.claude-work" claude'
```

double-clicking `UsageLine.app` only ever installs into the **default**
profile (`~/.claude`), since a GUI app launched from Finder doesn't inherit
env vars from a shell alias. Install into the other profile with the same
variable set:

```bash
CLAUDE_CONFIG_DIR="$HOME/.claude-work" ./scripts/install-hook.sh
```

Do this once per profile. The hook script itself is shared (one copy either
way); only each profile's `settings.json` and resulting `indicator.json` are
separate, so usage data never crosses between profiles.

---

## How it works

```
Claude Code  --[stdin JSON]--->  statusline-indicator.sh
                                         |
                                         v atomic mv
                                ~/.claude/indicator.json
                                         |
                                  (nothing reads this
                                   unless you also use
                                   Margherita's menu bar icon)

Claude Code's own terminal <----  the same script's stdout,
                                  printed on every turn
```

Double-clicking `UsageLine.app` runs `scripts/install-hook.sh` once: it
copies `statusline-indicator.sh` to `~/.claude/usageline/` and points
`~/.claude/settings.json`'s `statusLine` key at it — unless a compatible hook
(this one, or [Margherita's](../native)) is already installed, in which case
it does nothing. From that point on, **Claude Code calls the script
directly, on its own, forever** — installing or running UsageLine.app again
is never required for the terminal line to keep working.

`~/.claude/indicator.json` is written for compatibility with Margherita's
menu bar icon, in case you have that installed too; UsageLine itself never
reads it back.

---

## Local Development

```bash
make run             # Compile in release mode, bundle as .app, and open it (installs, then quits)
make build            # Compile the application bundle
make clean            # Clean build cache and temporary DMG stages
make dmg              # Package the application into a distribution-ready UsageLine.dmg
make install-hook     # Install just the statusLine hook (bash + jq, no app needed)
make uninstall-hook   # Remove the statusLine hook
```

### Project Layout
```
.
├── Package.swift                       SwiftPM manifest
├── Info.plist                          App manifest (LSUIElement = YES: no Dock icon)
├── Makefile                            Automation for compilation and packaging
├── scripts/
│   ├── statusline-indicator.sh         Claude Code stdin processing hook
│   ├── install-hook.sh                 The actual install logic (also runs standalone)
│   ├── uninstall-hook.sh               Standalone hook remover
│   └── install.command                 Packaged into the DMG as "Install UsageLine.command"
├── resources/
│   └── usageline.rb                    Homebrew Cask recipe file
└── Sources/UsageLine/
    └── main.swift                      The entire app: run install-hook.sh once, quit
```

---

## License

MIT — see [LICENSE](LICENSE).
