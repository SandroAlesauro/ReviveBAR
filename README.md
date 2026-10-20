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

## Create mode (custom buttons)

ReviveBAR includes a real **Create mode**:

- switch from `Use` to `Create`
- choose a button title
- define the payload text
- save it, and it appears on the Touch Bar

Custom buttons are persisted per profile and can be deleted from the same panel.

## Touch Bar behavior notes

ReviveBAR uses AppKit touch bar providers and button items (see Apple/AppKit references) and refreshes the window touch bar whenever profile or custom actions change.

If you don't see app items:

- keep ReviveBAR as the active foreground app
- open **System Settings → Keyboard**
- set Touch Bar behavior to app controls (not only expanded control strip)

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
