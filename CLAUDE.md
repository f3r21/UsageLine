# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

**UsageLine** is a one-shot installer, not a background app. Double-clicking
`UsageLine.app` runs the hook install logic once and quits immediately —
there is no menu bar icon, no Dock icon, no persistent process, no
`ObservableObject`, no file watcher. After that single launch, Claude Code's
own terminal shows a compact usage line (`"5h 22% · 7d 2%"`) forever, on its
own, because Claude Code calls the installed hook script directly on every
turn — this has nothing to do with whether UsageLine.app is running.

**If you're tempted to add any kind of ongoing UI, state, or timer to this
app, stop and reconsider** — that was tried (an earlier version of this repo
was a full `MenuBarExtra` app with a live-updating text label, jq/hook status
checks, and Launch-at-Login) and was deliberately torn out in favor of this
install-once-and-quit design. The simplification was explicit and intentional,
not a partial migration.

Targets **macOS 13+**. `Package.swift` declares `swift-tools-version:5.9`, a
single executable target, **no test target** (see
[No tests, on purpose](#no-tests-on-purpose)).

This is a **sibling project to `../native` (Margherita)**, not a fork or a
dependent of it — its own git repo, its own `Package.swift`.

## Repository layout

**This directory is the git repository root and the SwiftPM package root.**
Run every command below from here.

## Commands

```bash
make build          # swift build -c release, then assemble + ad-hoc-codesign UsageLine.app bundle
make run            # build, open the .app (it installs the hook and quits — nothing to killall first)
make install        # build, copy bundle to /Applications
make dmg            # build, stage into dmg_staging/, hdiutil → UsageLine.dmg
make clean          # swift package clean + remove .app/.build/.dmg/dmg_staging
make install-hook   # bash+jq only: runs the exact same install logic without the app
make uninstall-hook # bash+jq only: removes the statusLine key

swift build -c release   # compile only (bare executable, no bundle)
```

- **`make build` is required for the app to actually work.** `Sources/UsageLine/main.swift`
  shells out to a *bundled copy* of `install-hook.sh` (resolved via
  `Bundle.main.path(forResource:)`), and only the Makefile's bundle step
  copies `scripts/install-hook.sh` **and** `scripts/statusline-indicator.sh`
  into `UsageLine.app/Contents/Resources/` — both are required there, since
  `install-hook.sh` looks for `statusline-indicator.sh` as a sibling in its
  own directory (`$(dirname "${BASH_SOURCE[0]}")`).
- **Incremental-build footgun:** editing either script alone does **not**
  retrigger `make build` (they aren't Make prerequisites of the bundle
  target) — touch a source file or `make clean` first.
- Signing is ad-hoc: `codesign --force --deep --sign - UsageLine.app`.

## Architecture

`Sources/UsageLine/main.swift` is the **entire app** — no `@main` struct, no
SwiftUI. A bare `main.swift` file is SwiftPM's script-style entry point
(top-level code runs directly), which fits a program that has exactly one
job and no ongoing state:

```swift
NSApplication.shared.setActivationPolicy(.accessory)  // never shows a Dock icon
// run bundled install-hook.sh via Process, capture stderr
// success -> exit(0) silently
// failure -> NSAlert().runModal() showing the script's stderr, then exit(0)
```

- **Success is silent by design.** No alert, no notification, nothing — the
  proof it worked is that Claude Code's terminal starts showing the usage
  line. This was a deliberate choice to keep the install to *exactly* one
  click with no dismissal step; don't add a success dialog or a
  `UNUserNotification` "installed!" banner back in — a notification would
  also require a permission prompt the first time, which is itself an extra
  interaction this design avoids.
- **`NSAlert().runModal()` works here without ever calling `NSApplication.run()`.**
  Touching `NSApplication.shared` is enough to get Cocoa's window-server
  connection initialized; `runModal()` pumps its own nested run loop for the
  single alert. Don't "fix" this by adding a full app run loop — it isn't
  needed and would change the app from "runs once and exits" to "keeps a
  process alive."
- **All the actual install logic lives in `scripts/install-hook.sh`**, not in
  Swift. It's bash+jq, already works completely standalone (`make
  install-hook` doesn't touch the Swift binary at all), and is invoked via
  `/bin/bash <path>` rather than executing it directly — so its executable
  bit doesn't need to survive codesigning/bundling.
- **`scripts/statusline-indicator.sh` is intentionally the plain,
  Margherita-compatible reshape** — no additive fields. An earlier version of
  this app added a precomputed `line` field to guarantee its own live menu
  bar text matched the console exactly; once the live-text UI was removed,
  that field had no reader left, so it was removed too. If you're about to
  add a field here again, first check whether anything in *this* repo
  actually reads it back — if not, it doesn't belong here.
- **`indicator.json` is still written**, purely for compatibility with
  Margherita's menu bar icon if the user also has that installed. Nothing in
  this repo reads it back.
- **All three scripts respect `CLAUDE_CONFIG_DIR`**, falling back to
  `$HOME/.claude` when it's unset — matching how Claude Code itself resolves
  its config directory for isolated profiles (`CLAUDE_CONFIG_DIR="$HOME/.claude-work" claude`,
  a real pattern in use — this surfaced from a colleague's own per-client
  setup). `statusline-indicator.sh` needs no install-time awareness of this:
  Claude Code invokes it with that profile's `CLAUDE_CONFIG_DIR` already in
  its environment, so `indicator.json` lands in the right place automatically.
  `install-hook.sh`/`uninstall-hook.sh` only pick this up if the *caller's*
  shell has it set — a GUI-launched `UsageLine.app` never does, so it only
  ever installs into the default profile; installing into another profile is
  a deliberate one-line command (see README's "isolated Claude Code profile"
  section), not automatic. **The installed script file itself is not
  per-profile** — always `~/.claude/usageline/statusline-indicator.sh`
  regardless of which profile's `settings.json` points at it; only
  `settings.json` and the resulting `indicator.json` vary per profile.
- **Never reclaims an already-installed hook.** `install-hook.sh` checks
  `.statusLine.command` for the substring `"statusline-indicator.sh"` before
  doing anything; if a compatible hook (this one's, or Margherita's) is
  already active, it prints a message and exits 0 without touching
  `settings.json` or copying anything. This is what lets UsageLine and
  Margherita coexist without either one stealing the hook back from the
  other on every launch.

### `scripts/install.command` — the actual "one click" for a downloaded DMG

`make dmg` copies this into the DMG as **`Install UsageLine.command`**,
alongside `UsageLine.app` and the traditional `Applications` symlink. It
exists because the ad-hoc-signature fix
(`codesign --force --deep --sign -` + `xattr -d com.apple.quarantine`) was
the single biggest piece of friction in "one click to install" — asking
someone to open Terminal and paste a command defeats that entirely. This
script does the **whole** install in one double-click: copies the app from
the mounted DMG to `/Applications` itself (no manual drag needed), re-signs
it, clears quarantine, launches it.

- It resolves its own location via `$(dirname "${BASH_SOURCE[0]}")`, so it
  must ship *next to* `UsageLine.app` inside the DMG — don't move one
  without the other in the Makefile's `dmg` target.
- A `.command` file run this way still requires one right-click → Open the
  first time (Gatekeeper's standard "downloaded executable" gate) — that
  part is unavoidable without paying for a Developer ID + notarization, and
  is *not* a bug to try to engineer around.
- The traditional drag-to-Applications + manual `codesign`/`xattr` path
  (documented in the README's collapsed "prefer to drag-and-drop" section)
  still works and is kept for people who want it; `install.command` is the
  recommended path, not a replacement that removed the other one.

### No tests, on purpose

There is no `Tests/` directory and no test target in `Package.swift`. This
isn't an oversight: once the live-display logic (the part that used to have
meaningful pure functions worth unit-testing — meter formatting, display-text
priority) was removed, what's left is a few lines of `Process`/`NSAlert` glue
around a bash script. The bash scripts themselves are covered by `bash -n` in CI, and were
hand-verified against a fake `$HOME` (settings.json merge safety, the "don't
reclaim an existing hook" check, empty-`rate_limits` no-op) — including
`install.command`, run end-to-end from an actually-mounted DMG on a real
`/Applications` install. If you add real Swift logic back to this app, add
tests for it — but don't
add a test target just to have one testing glue code that has nothing to
assert about.

## Distribution

Ad-hoc signed, same re-sign-after-install caveat as Margherita:

```bash
codesign --force --deep --sign - /Applications/UsageLine.app && xattr -d com.apple.quarantine /Applications/UsageLine.app 2>/dev/null || true
```

`resources/usageline.rb` is a **source copy only** (mirrors Margherita's own
`resources/margherita.rb` convention) — the cask Homebrew actually reads
would live at `Casks/usageline.rb` in the `f3r21/homebrew-tap` repo, synced
manually after each tagged release. Neither the tap entry nor the
`f3r21/UsageLine` GitHub repo exist yet as of this writing — `release.yml`
and the cask both reference them as placeholders.
