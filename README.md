# Folder Icon Studio

<p align="center">
  <img src="Assets/FolderIconStudio.svg" width="160" alt="Folder Icon Studio app icon">
</p>

A native macOS app for designing and applying custom Finder folder icons. It uses SwiftUI and AppKit and supports folder colors, SF Symbols, emoji, text, images, and PNG/ICNS export.

## Features

- Choose a writable Finder folder and apply a custom icon or restore its default icon.
- Use standard, open, or group system-folder artwork with presets or a custom color.
- Add SF Symbols with search, category browsing, monochrome or palette rendering.
- Add emoji, text, and image layers; configure text font family, weight, italic style, color, size, opacity, rotation, and position.
- Import existing `.icns` files and export designs as PNG or ICNS.
- Save and reuse icon templates.

## Architecture

The codebase follows MVVM and is organized by responsibility:

| Directory | Responsibility |
|---|---|
| `App` | SwiftUI application entry point |
| `Models` | Codable icon document, layer, color, and typography models |
| `Services` | Icon rendering, Finder integration, export, validation, and template storage |
| `ViewModels` | Editor state, user actions, and coordination of services |
| `Views` | Main editor, sidebar, canvas, inspector, and reusable UI components |
| `Features/SFSymbols` | SF Symbol catalog loading, filtering, and UI |

Views bind to `EditorViewModel`; they do not contain Finder, export, or rendering logic.

## Requirements

- macOS 14 or later
- Xcode 16 or later
- Swift 6
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) when regenerating the Xcode project

## Build and run

### Swift Package Manager

```bash
swift run FolderIconStudio
```

### Xcode

Regenerate the project after adding or moving source files:

```bash
xcodegen generate
open FolderIconStudio.xcodeproj
```

Select the `FolderIconStudio` scheme and run it.

## Test

```bash
swift test
```

## Privacy

Screen access is requested only when using the screen color sampler. Folder updates occur only after you explicitly choose **Apply to Finder**.
