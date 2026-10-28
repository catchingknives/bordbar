# Bordbar

Train speed in the macOS menu bar, trip details on click, from the ICE onboard portal (only reachable on WIFIonICE).

Unofficial. Not affiliated with or endorsed by Deutsche Bahn; it reads an undocumented API that can change without notice.

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/screenshot-dark.png">
  <img src="docs/screenshot-light.png" width="320" alt="Bordbar panel: speed, next stop, your stop, route bar and stop list on an ICE from Hamburg to Stuttgart">
</picture>

<sub>Screenshot with made-up trip data.</sub>

## Install

Needs macOS 14 or later. The app runs on Apple silicon and Intel.

1. Download `Bordbar.zip` from the [latest release](https://github.com/catchingknives/bordbar/releases/latest) and unzip it.
2. Move `Bordbar.app` to `/Applications`.
3. Open it. macOS blocks the first launch because the app is not notarised by Apple. Go to **System Settings → Privacy & Security**, scroll down to the message about Bordbar and click **Open Anyway**. Or, in Terminal: `xattr -dr com.apple.quarantine /Applications/Bordbar.app`
4. Optional: add it under **System Settings → General → Login Items** so it starts with your Mac.

If you run a firewall such as Little Snitch, allow Bordbar to reach `iceportal.de`. Until you do, it shows "Not on ICE WiFi".

### Build it yourself

Needs the Xcode Command Line Tools (`xcode-select --install`); full Xcode is not required.

```
git clone https://github.com/catchingknives/bordbar.git
cd bordbar/macos
./build-app.sh
open dist/Bordbar.app
```

## Use

- **Menu bar:** the train's speed while you are on WIFIonICE, a train symbol otherwise.
- **Click it:** train and destination, next stop with platform and delay, the whole route as a bar, and every stop.
- **Your stops:** click a stop behind you to mark where you got on, one ahead for where you get off; click a marked stop again to clear it. The km, km-to-go and percent figures then cover only your part of the route. Marks are saved per train (date and train number) and do not carry over to the next one.

## Development

Portal field notes: `API.md`.

- `./build-app.sh` builds for this Mac; `./build-app.sh --universal` builds for Apple silicon and Intel, as the releases are.
- Test paths, run from `macos/` with the built binary `dist/Bordbar.app/Contents/MacOS/Bordbar`:
  - `--once` prints the menu contents instead of starting the menu bar app
  - `--render <dir>` writes the panel as light and dark PNGs
  - `--fixtures ../fixtures` uses saved responses instead of the train
  - `--once --click <evaNr>` runs the same mark toggle as a click in the menu

### Notes

- Every rebuild gets a new ad-hoc signature, so a firewall like Little Snitch asks again.
- Swift 6.4's default build system fails on Command Line Tools without Xcode ("Unknown error parsing property list"), so the build script uses `--build-system native`. That one takes a single architecture, so a universal build is two builds joined with `lipo`.
- SwiftUI's `MenuBarExtra` dropped the menu bar symbol and menu item images on macOS 27; the app uses an AppKit status item with a SwiftUI panel hosted in a menu item.
- SwiftUI's `@State` (and other SwiftUI macros) need Xcode's compiler plugin and fail to build with Command Line Tools; keep view state in the `@Observable` store.
- `ImageRenderer` hangs without a running `NSApplication`; the render path starts one invisibly.

## License

MIT, see `LICENSE`.
