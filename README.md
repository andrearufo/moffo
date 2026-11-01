# Moffo

A tiny, squishy jelly that lives in your Mac menu bar. Think tamagotchi: feed it, play with it, give it a bath, put it to bed and let it study. Ignore it and it gets sick… and eventually dies.

Free and open source. Native SwiftUI, no dependencies.

## Features (v0.1)

- Hatches from an egg about a minute after the first launch
- Stats: **Fullness, Hygiene, Energy, Fun, Smarts, Health** and an overall **Happiness** index
- Actions: Feed, Play, Bath, Sleep/Wake, Study, Medicine
- **Study**: Moffo studies for 3 minutes, then tells you a useful or curious fact
- Poops every ~4 hours. Too many poops or an empty stat make it sick, and a sick Moffo loses health until it dies
- Time keeps running while the Mac is off: an ignored Moffo lives about 2 days
- macOS notifications when it needs you
- Menu bar icon changes with its mood

## Requirements

- macOS 14 (Sonoma) or later
- Xcode or the Xcode Command Line Tools (Swift 5.9+) to build it

## Install

```bash
git clone https://github.com/andrearufo/moffo.git
cd moffo
./scripts/build-app.sh
cp -R build/Moffo.app /Applications/
open /Applications/Moffo.app
```

The app is ad-hoc signed. If macOS blocks it, right-click it in Finder, choose Open, then confirm.

To start Moffo at login: System Settings → General → Login Items → add Moffo.

## Development

```bash
swift test                                   # simulation tests
./scripts/build-app.sh && open build/Moffo.app
```

Time warp for testing: `MOFFO_SPEED=60` makes one real minute last one Moffo hour.

```bash
pkill Moffo; MOFFO_SPEED=60 build/Moffo.app/Contents/MacOS/Moffo
```

Reset Moffo (new egg): `pkill Moffo; defaults delete dev.rufo.moffo`

All game rules live in [`Sources/MoffoCore/Pet.swift`](Sources/MoffoCore/Pet.swift), and the facts Moffo learns live in [`Facts.swift`](Sources/MoffoCore/Facts.swift).

## License

MIT
