# FluxTerm — Design Document

**Date:** 2026-02-22
**Status:** Approved

## Summary

FluxTerm is a macOS-native GPU-accelerated terminal emulator built with Swift, Metal, and AppKit. It features a modern glass/blur aesthetic using macOS vibrancy effects, high-performance text rendering via a Metal glyph atlas pipeline, and SwiftTerm for terminal emulation.

## Goals

1. **Aesthetics** — Modern glass/blur macOS-native design with `NSVisualEffectView`
2. **Performance** — GPU-accelerated text rendering via Metal (glyph atlas, 2 draw calls per frame)
3. **Learning** — Deep understanding of terminal internals, GPU rendering, macOS APIs
4. **Usability** — A terminal good enough to use daily

## Tech Stack

- **Language:** Swift
- **Terminal Emulation:** SwiftTerm (Swift Package)
- **GPU Rendering:** Metal (CAMetalLayer, MTLTexture glyph atlas)
- **Font Shaping:** Core Text
- **Window/UI:** AppKit (NSWindow, NSView, NSVisualEffectView)
- **Future UI:** SwiftUI (settings, command palette — post-v1)
- **PTY:** POSIX forkpty() with dedicated IO thread per session
- **Platform:** macOS only

## Architecture

```
┌─────────────────────────────────────────────────────┐
│                  App Shell (AppKit)                  │
│  NSWindow + NSVisualEffectView (blur backdrop)      │
├─────────────────────────────────────────────────────┤
│           Terminal View (NSView + Metal)             │
│  CAMetalLayer — GPU-rendered text grid              │
│  Handles keyboard input, mouse events, selection    │
├─────────────────────────────────────────────────────┤
│           Terminal Engine (SwiftTerm)                │
│  VT100/Xterm emulation, escape code parsing,        │
│  terminal state (grid, cursor, scrollback)           │
├─────────────────────────────────────────────────────┤
│               PTY Layer (POSIX)                     │
│  forkpty() → shell process (zsh/bash/fish)          │
│  Dedicated IO thread: read/write PTY fd             │
└─────────────────────────────────────────────────────┘
```

## Rendering Pipeline

```
SwiftTerm Grid (terminal state)
        │
        ▼
  Font Shaping (Core Text)
  → Unicode to glyph IDs, ligatures, emoji
        │
        ▼
  Glyph Atlas (MTLTexture)
  → Rasterize each unique glyph once
  → Cache in GPU texture atlas
        │
        ▼
  Instance Buffer (per-frame)
  → Per-cell: position, atlas coords, fg/bg color
        │
        ▼
  Metal Render Pass (2 draw calls)
  → 1. Background rects (cell backgrounds)
  → 2. Glyph quads (textured from atlas)
```

**Key decisions:**
- Glyph atlas pattern: rasterize once, reuse across frames
- Two draw calls per frame (backgrounds + glyphs)
- Render on-demand (when terminal state changes), not fixed frame loop
- Core Text for font shaping (handles ligatures, emoji, CJK)

## v1 Scope

### Included
1. GPU-rendered text via Metal (glyph atlas pipeline)
2. Glass/blur window via NSVisualEffectView
3. SwiftTerm for terminal emulation
4. Dedicated IO thread for PTY read/write
5. Basic configuration: font, font size, opacity, color scheme
6. Keyboard input routed to PTY
7. Scrollback buffer with scroll-to-view
8. Selection and copy/paste
9. Clickable URLs (regex detection)

### Deferred (v2+)
- Tabs
- Split panes
- Command palette
- Inline rich content (images, markdown)
- AI integration
- Settings UI (SwiftUI)

## Project Structure

```
FluxTerm/
├── FluxTerm.xcodeproj
├── FluxTerm/
│   ├── App/
│   │   ├── FluxTermApp.swift          # @main entry point
│   │   └── AppDelegate.swift          # NSApplicationDelegate
│   ├── Terminal/
│   │   ├── TerminalView.swift         # NSView hosting Metal + SwiftTerm
│   │   ├── TerminalSession.swift      # PTY lifecycle, IO thread, SwiftTerm bridge
│   │   └── TerminalConfig.swift       # Font, colors, opacity settings
│   ├── Renderer/
│   │   ├── MetalRenderer.swift        # Metal setup, render loop, draw calls
│   │   ├── GlyphAtlas.swift           # Texture atlas for font glyphs
│   │   ├── Shaders.metal              # Vertex + fragment shaders
│   │   └── FontShaper.swift           # Core Text glyph shaping
│   ├── UI/
│   │   └── MainWindow.swift           # NSWindow + NSVisualEffectView setup
│   └── Resources/
│       └── Assets.xcassets
├── Package.swift                      # SwiftTerm dependency
└── docs/
    └── plans/
```

## Dependencies

| Dependency | Source | Purpose |
|---|---|---|
| SwiftTerm | Swift Package Manager | Terminal emulation (VT100/Xterm) |
| Metal | System framework | GPU rendering |
| AppKit | System framework | Window management, vibrancy |
| Core Text | System framework | Font shaping |

No other external dependencies.

## References

- [Ghostty](https://ghostty.org/) — Zig + Swift + Metal architecture inspiration
- [Alacritty](https://github.com/alacritty/alacritty) — Glyph atlas rendering approach
- [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) — Terminal emulation library
- [NSVisualEffectView](https://developer.apple.com/documentation/appkit/nsvisualeffectview) — macOS vibrancy API
