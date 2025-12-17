# then (macOS menu bar app) — MVP

Local (offline) helper to detect and fix “wrong TH↔EN keyboard layout” text by converting the clipboard.

## What it does (MVP)
- Menu bar app (no Dock icon).
- **Convert Clipboard Now**: reads clipboard text, detects wrong layout, converts, writes back.
- **Auto Convert Clipboard** (optional): watches clipboard changes and auto-converts when confidence is high.
- **Fix Last Word (⌘⇧L)** (optional): while typing in any app, fix the last word and switch input source.
- **Auto-fix While Typing** (optional): fixes wrong-layout word on space/return.
- **Selected text (right click)**: select text → right click → **Services** → `then` → Toggle/Convert.
- **Selected text (hotkey)**: enable in Settings; triggers copy→convert→paste for current selection.
- **Settings…**: choose mode (Auto / Force EN→TH / Force TH→EN) and threshold.

## Permissions
For typing fix (hotkey/auto-fix), macOS requires **Accessibility** permission:
- System Settings → Privacy & Security → Accessibility → enable RightLang

For selection hotkey (copy/paste automation), Accessibility is also required.

## Build
From repo root:

```bash
zsh apps/RightLang/build.zsh
```

Output:
- `apps/RightLang/dist/then.app`

## Install
Install to `/Applications/then.app` (may require permissions):

```bash
zsh apps/RightLang/install_to_applications.zsh
```
