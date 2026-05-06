# Codex Overlay

Small macOS overlay for sending one-shot prompts to `codex exec` from a global shortcut.

## Requirements

- macOS 14 or newer.
- Xcode Command Line Tools or Xcode, so `swift build` is available.
- Codex CLI installed and authenticated.
- `codex` available from a login shell, or installed in one of these paths:
  - `/opt/homebrew/bin/codex`
  - `/usr/local/bin/codex`
  - `~/.local/bin/codex`

## Run

From the repo root:

```bash
./script/build_and_run.sh
```

The script builds with SwiftPM, stages `dist/CodexOverlay.app`, stops any previous
running instance, and opens the app.

Useful commands:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
pkill -x CodexOverlay
```

Optional shell alias:

```bash
alias overlay='/path/to/codex-overlay/script/build_and_run.sh'
```

With that alias loaded, run:

```bash
overlay
```

The script changes into the repo root before building, so the alias can be run
from any directory.

## Usage

- `Option Space`: show or hide the overlay.
- `Command Return`: run the prompt.
- `Escape`: close the overlay.
- `Copy`: copy the final raw response to the clipboard.
- Gear button: temporarily change model, reasoning effort, or service tier for this app session.

`codex exec` is run with ephemeral sessions, full permissions, and `service_tier="fast"` by default.
The UI shows only the final Codex message.

## Distribution

This is currently a development build flow. The generated app in `dist/` is not
signed, notarized, or packaged as a DMG.

For another technical user, share the repo and have them run:

```bash
./script/build_and_run.sh
```

For normal distribution, the next step is signing, notarization, icon/app metadata,
and packaging.

## Login Startup

For day-to-day development, the simplest approach is a shell alias and launching
the app manually from Terminal.

If automatic startup is needed later, create:

```text
~/Library/LaunchAgents/com.brauliomendez.codex-overlay.dev.plist
```

with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.brauliomendez.codex-overlay.dev</string>
    <key>ProgramArguments</key>
    <array>
      <string>/path/to/codex-overlay/script/build_and_run.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>WorkingDirectory</key>
    <string>/path/to/codex-overlay</string>
    <key>StandardOutPath</key>
    <string>/tmp/codex-overlay-dev.out.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/codex-overlay-dev.err.log</string>
  </dict>
</plist>
```

Load it with:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.brauliomendez.codex-overlay.dev.plist
launchctl enable gui/$(id -u)/com.brauliomendez.codex-overlay.dev
launchctl kickstart -k gui/$(id -u)/com.brauliomendez.codex-overlay.dev
```
