# ReviveBAR

ReviveBAR is a native macOS app that brings the Touch Bar back to life with focused, modern micro-apps.

The project is **open source** and intentionally **vibecoded**: fast iteration, product taste first, and pragmatic engineering choices that keep the app useful in real workflows.

## Design language

ReviveBAR uses a native Apple visual system (materials, spacing, typography, and subtle depth) with a Nothing-inspired “essential apps” concept:

- each module is a focused micro-tool
- one tap to action
- minimal, high-contrast card layout
- fast context switching through profiles

## Current modules

- **Quick Note**: save short notes in one tap.
- **Clipboard Stack**: capture and keep recent clipboard text entries.
- **Focus Session**: start a 25-minute focus timer from the Touch Bar.

## Requirements

- macOS 12 or later
- Xcode command line tools (`swift` available)
- A Mac with a physical Touch Bar for the full experience

## Run locally

```bash
swift build
swift run ReviveBAR
```

## Universal build (Intel + Apple Silicon)

```bash
swift build --arch arm64 --arch x86_64
file .build/out/Products/Debug/ReviveBAR
```

Expected output includes both `arm64` and `x86_64`.

## Project structure

- `Package.swift` — Swift Package config
- `Sources/EssentialTouchBar/` — app source code
  - `MainViewController.swift` — Touch Bar UI and module actions
  - `ProfileStore.swift` — profile and layout persistence
  - `QuickNoteStore.swift` — quick notes storage
  - `ClipboardStackStore.swift` — clipboard history storage
  - `FocusSessionStore.swift` — focus timer state storage

## Open source license

This project is released under the MIT License. See `LICENSE`.
