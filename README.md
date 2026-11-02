# StillBar

A small macOS menu bar app that puts your Touch Bar to sleep to reduce flickering. Double-tap **Command** to turn it off or on. It remembers your choice and reapplies it after wake.

## Setup

Requires a MacBook with a Touch Bar, macOS 13+, and Xcode Command Line Tools with Swift 5.9+ (`xcode-select --install`).

```sh
git clone https://github.com/MathiasWP/StillBar.git
cd StillBar
bash scripts/build.sh
mkdir -p "$HOME/Applications"
ditto build/StillBar.app "$HOME/Applications/StillBar.app"
open "$HOME/Applications/StillBar.app"
```

1. Quit other Touch Bar utilities, such as Hide My Bar.
2. Click **Enable…** beside Double Command. Enable StillBar in **System Settings → Privacy & Security → Input Monitoring**. If it is missing, click **+** and choose the installed `StillBar.app`. Quit and reopen StillBar if requested.
3. Tap and release Command twice to toggle the Touch Bar, or use the button in StillBar.
4. Enable **Start at login** if you want it to run automatically.

Closing the window leaves StillBar in the menu bar. **Quit & Restore** turns the Touch Bar back on. No typed text is recorded or sent anywhere.

Uses private macOS APIs, so future macOS updates may need a fix. Software sleep cannot guarantee zero flicker from faulty hardware or during startup. Touch Bar keys, including Escape on older models, may be unavailable while off.

## Development

Run `swift test` to test the shortcut and sleep policy. Build with `bash scripts/build.sh`.

Builds are ad-hoc signed by default. To preserve permissions across rebuilds, set `STILLBAR_SIGNING_IDENTITY` to an existing Apple Development or Developer ID signing identity when building; the script remembers it locally. Otherwise, macOS may require removing and re-adding StillBar in Input Monitoring after an update. Quit the installed app before replacing it.

MIT licensed. Private API integration informed by [TouchBarOff](https://github.com/gbili/touchbar-off) and [Touch Bar Controller](https://github.com/skimmilk/TouchBarController); see [third-party notices](THIRD_PARTY_NOTICES.txt).
