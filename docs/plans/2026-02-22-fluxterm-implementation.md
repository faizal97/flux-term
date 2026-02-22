# FluxTerm v1 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a macOS-native GPU-accelerated terminal emulator with glass/blur aesthetics, Metal rendering, and SwiftTerm for terminal emulation.

**Architecture:** Swift + Metal + AppKit layered architecture. SwiftTerm's `Terminal` class handles VT100 parsing and grid state. SwiftTerm's `LocalProcess` handles PTY management. A custom Metal renderer reads the terminal grid and renders via a glyph atlas. AppKit provides the window shell with `NSVisualEffectView` for glass effects.

**Tech Stack:** Swift, Metal, AppKit, SwiftTerm (SPM), Core Text, POSIX PTY

**Build:** Open `Package.swift` in Xcode. Metal shaders are compiled automatically by Xcode. Use `Cmd+R` to build and run.

---

## Task 1: Project Scaffolding + Hello Window with Glass

**Files:**
- Create: `Package.swift`
- Create: `Sources/FluxTerm/App/FluxTermApp.swift`
- Create: `Sources/FluxTerm/App/AppDelegate.swift`
- Create: `Sources/FluxTerm/UI/MainWindow.swift`

**Step 1: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FluxTerm",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/migueldeicaza/SwiftTerm.git", from: "1.0.0")
    ],
    targets: [
        .executableTarget(
            name: "FluxTerm",
            dependencies: ["SwiftTerm"]
        )
    ]
)
```

**Step 2: Create the app entry point**

`Sources/FluxTerm/App/FluxTermApp.swift`:
```swift
import AppKit

@main
struct FluxTermApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
```

**Step 3: Create AppDelegate**

`Sources/FluxTerm/App/AppDelegate.swift`:
```swift
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindow: MainWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        mainWindow = MainWindow()
        mainWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
```

**Step 4: Create MainWindow with glass effect**

`Sources/FluxTerm/UI/MainWindow.swift`:
```swift
import AppKit

class MainWindow: NSWindowController {
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "FluxTerm"
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear

        // Glass/blur effect
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        window.contentView = visualEffectView

        self.init(window: window)
    }
}
```

**Step 5: Resolve dependencies and build**

Run: `cd /Users/fayz/Code/Personal/personal-terminal && swift package resolve`

Then open in Xcode: `open Package.swift`

Build and run with `Cmd+R`. Expected: a translucent glass window appears with the macOS blur effect.

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: project scaffolding with glass window"
```

---

## Task 2: Terminal Session (SwiftTerm + PTY)

**Files:**
- Create: `Sources/FluxTerm/Terminal/TerminalSession.swift`
- Modify: `Sources/FluxTerm/UI/MainWindow.swift`

**Step 1: Create TerminalSession**

This class wires SwiftTerm's `Terminal` (VT parser + grid state) to `LocalProcess` (PTY + shell). It's the bridge between the shell process and our renderer.

`Sources/FluxTerm/Terminal/TerminalSession.swift`:
```swift
import Foundation
import SwiftTerm

protocol TerminalSessionDelegate: AnyObject {
    func terminalSession(_ session: TerminalSession, didReceiveData data: ArraySlice<UInt8>)
    func terminalSession(_ session: TerminalSession, titleDidChange title: String)
    func terminalSessionDidTerminate(_ session: TerminalSession, exitCode: Int32?)
}

class TerminalSession: TerminalDelegate, LocalProcessDelegate {
    let terminal: Terminal
    let process: LocalProcess
    weak var delegate: TerminalSessionDelegate?

    init(cols: Int = 80, rows: Int = 24) {
        let options = TerminalOptions(
            cols: cols,
            rows: rows,
            scrollback: 10000,
            termName: "xterm-256color"
        )
        terminal = Terminal(delegate: nil, options: options)
        process = LocalProcess(delegate: nil)
        terminal.delegate = self
        process.delegate = self
    }

    func start() {
        let shell = detectShell()
        let shellName = (shell as NSString).lastPathComponent
        process.startProcess(
            executable: shell,
            args: [],
            environment: nil,
            execName: "-\(shellName)"
        )
    }

    func resize(cols: Int, rows: Int) {
        terminal.resize(cols: cols, rows: rows)
        process.setWindowSize(rows: rows, cols: cols)
    }

    func sendInput(_ data: ArraySlice<UInt8>) {
        process.send(data: data)
    }

    func sendInput(_ text: String) {
        let bytes = Array(text.utf8)
        sendInput(bytes[...])
    }

    private func detectShell() -> String {
        if let shell = ProcessInfo.processInfo.environment["SHELL"], !shell.isEmpty {
            return shell
        }
        return "/bin/zsh"
    }

    // MARK: - TerminalDelegate

    func send(source: Terminal, data: ArraySlice<UInt8>) {
        process.send(data: data)
    }

    func setTerminalTitle(source: Terminal, title: String) {
        delegate?.terminalSession(self, titleDidChange: title)
    }

    func sizeChanged(source: Terminal) {}
    func scrolled(source: Terminal, yDisp: Int) {}
    func linefeed(source: Terminal) {}
    func bufferActivated(source: Terminal) {}
    func bell(source: Terminal) { NSSound.beep() }
    func showCursor(source: Terminal) {}
    func hideCursor(source: Terminal) {}
    func setTerminalIconTitle(source: Terminal, title: String) {}
    func selectionChanged(source: Terminal) {}
    func mouseModeChanged(source: Terminal) {}
    func cursorStyleChanged(source: Terminal, newStyle: CursorStyle) {}
    func isProcessTrusted(source: Terminal) -> Bool { true }
    func hostCurrentDirectoryUpdated(source: Terminal) {}
    func hostCurrentDocumentUpdated(source: Terminal) {}
    func clipboardCopy(source: Terminal, content: Data) {}
    func iTermContent(source: Terminal, content: ArraySlice<UInt8>) {}
    func colorChanged(source: Terminal, idx: Int?) {}
    func setForegroundColor(source: Terminal, color: SwiftTerm.Color) {}
    func setBackgroundColor(source: Terminal, color: SwiftTerm.Color) {}
    func setCursorColor(source: Terminal, color: SwiftTerm.Color) {}
    func notify(source: Terminal, title: String, body: String) {}
    func createImageFromBitmap(source: Terminal, bytes: inout [UInt8], width: Int, height: Int) {}
    func createImage(source: Terminal, data: Data, width: ImageSizeRequest, height: ImageSizeRequest, preserveAspectRatio: Bool) {}
    func windowCommand(source: Terminal, command: Terminal.WindowManipulationCommand) -> [UInt8]? { nil }

    // MARK: - LocalProcessDelegate

    func dataReceived(slice: ArraySlice<UInt8>) {
        terminal.feed(buffer: slice)
        delegate?.terminalSession(self, didReceiveData: slice)
    }

    func processTerminated(_ source: LocalProcess, exitCode: Int32?) {
        delegate?.terminalSessionDidTerminate(self, exitCode: exitCode)
    }

    func getWindowSize() -> winsize {
        return winsize(
            ws_row: UInt16(terminal.rows),
            ws_col: UInt16(terminal.cols),
            ws_xpixel: 0,
            ws_ypixel: 0
        )
    }
}
```

**Step 2: Verify TerminalSession compiles**

Build the project in Xcode. Expected: compiles without errors. Note: Some `TerminalDelegate` methods may have slightly different signatures depending on the SwiftTerm version. Fix any compilation errors by checking SwiftTerm's source.

**Step 3: Commit**

```bash
git add Sources/FluxTerm/Terminal/TerminalSession.swift
git commit -m "feat: add TerminalSession with SwiftTerm + LocalProcess"
```

---

## Task 3: Metal View Foundation

**Files:**
- Create: `Sources/FluxTerm/Renderer/TerminalMetalView.swift`
- Modify: `Sources/FluxTerm/UI/MainWindow.swift`

**Step 1: Create TerminalMetalView**

`Sources/FluxTerm/Renderer/TerminalMetalView.swift`:
```swift
import AppKit
import Metal
import QuartzCore

class TerminalMetalView: NSView {
    private(set) var device: MTLDevice!
    private(set) var commandQueue: MTLCommandQueue!
    private var metalLayer: CAMetalLayer { self.layer as! CAMetalLayer }

    private var needsRedraw = true

    // MARK: - Layer setup

    override var wantsUpdateLayer: Bool { true }

    override func makeBackingLayer() -> CALayer {
        let layer = CAMetalLayer()
        return layer
    }

    // MARK: - Init

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layerContentsRedrawPolicy = .duringViewResize

        device = metalLayer.preferredDevice ?? MTLCreateSystemDefaultDevice()!
        metalLayer.device = device
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.presentsWithTransaction = false
        // Allow transparency for glass effect
        metalLayer.isOpaque = false

        commandQueue = device.makeCommandQueue()!

        updateDrawableSize()
    }

    // MARK: - Drawable size

    private func updateDrawableSize() {
        guard let window = self.window else { return }
        let scale = window.backingScaleFactor
        metalLayer.drawableSize = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )
        metalLayer.contentsScale = scale
        needsRedraw = true
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateDrawableSize()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateDrawableSize()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateDrawableSize()
    }

    // MARK: - Rendering

    func setNeedsRedraw() {
        needsRedraw = true
    }

    /// Called by the renderer to get the next drawable and render.
    func renderFrame(with renderer: (CAMetalDrawable, MTLCommandQueue) -> Void) {
        guard needsRedraw else { return }
        guard let drawable = metalLayer.nextDrawable() else { return }
        renderer(drawable, commandQueue)
        needsRedraw = false
    }

    // MARK: - First responder (for keyboard input)

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        return true
    }
}
```

**Step 2: Add Metal view to the window**

Update `Sources/FluxTerm/UI/MainWindow.swift`:
```swift
import AppKit

class MainWindow: NSWindowController {
    var metalView: TerminalMetalView!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "FluxTerm"
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear

        // Glass/blur effect
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        window.contentView = visualEffectView

        self.init(window: window)

        // Add Metal view inside the glass effect view
        metalView = TerminalMetalView(frame: visualEffectView.bounds)
        metalView.autoresizingMask = [.width, .height]
        visualEffectView.addSubview(metalView)
    }
}
```

**Step 3: Verify Metal initialization**

Build and run. Expected: Glass window appears. No crash (Metal device created successfully). The Metal layer is transparent, so you see the glass blur effect through it.

**Step 4: Commit**

```bash
git add Sources/FluxTerm/Renderer/TerminalMetalView.swift Sources/FluxTerm/UI/MainWindow.swift
git commit -m "feat: add Metal-backed NSView with CAMetalLayer"
```

---

## Task 4: Terminal Configuration

**Files:**
- Create: `Sources/FluxTerm/Terminal/TerminalConfig.swift`

**Step 1: Create TerminalConfig**

`Sources/FluxTerm/Terminal/TerminalConfig.swift`:
```swift
import AppKit
import CoreText

struct TerminalConfig {
    var fontName: String = "MesloLGS NF"
    var fontSize: CGFloat = 14.0
    var backgroundOpacity: Float = 0.85
    var padding: CGFloat = 8.0

    // Default color scheme (One Dark inspired)
    var foregroundColor: SIMD4<Float> = SIMD4<Float>(0.847, 0.871, 0.914, 1.0) // #D8DEE9
    var backgroundColor: SIMD4<Float> = SIMD4<Float>(0.18, 0.204, 0.251, 1.0)  // #2E3440
    var cursorColor: SIMD4<Float> = SIMD4<Float>(0.847, 0.871, 0.914, 1.0)

    // ANSI 16 colors
    var colors: [SIMD4<Float>] = [
        SIMD4<Float>(0.231, 0.259, 0.322, 1.0), // 0: black    #3B4252
        SIMD4<Float>(0.749, 0.380, 0.416, 1.0), // 1: red      #BF616A
        SIMD4<Float>(0.631, 0.757, 0.549, 1.0), // 2: green    #A3BE8C
        SIMD4<Float>(0.922, 0.796, 0.545, 1.0), // 3: yellow   #EBCB8B
        SIMD4<Float>(0.506, 0.631, 0.757, 1.0), // 4: blue     #81A1C1
        SIMD4<Float>(0.706, 0.557, 0.678, 1.0), // 5: magenta  #B48EAD
        SIMD4<Float>(0.533, 0.753, 0.816, 1.0), // 6: cyan     #88C0D0
        SIMD4<Float>(0.898, 0.914, 0.941, 1.0), // 7: white    #E5E9F0
        SIMD4<Float>(0.298, 0.337, 0.416, 1.0), // 8: bright black   #4C566A
        SIMD4<Float>(0.749, 0.380, 0.416, 1.0), // 9: bright red     #BF616A
        SIMD4<Float>(0.631, 0.757, 0.549, 1.0), // 10: bright green  #A3BE8C
        SIMD4<Float>(0.922, 0.796, 0.545, 1.0), // 11: bright yellow #EBCB8B
        SIMD4<Float>(0.506, 0.631, 0.757, 1.0), // 12: bright blue   #81A1C1
        SIMD4<Float>(0.706, 0.557, 0.678, 1.0), // 13: bright magenta#B48EAD
        SIMD4<Float>(0.557, 0.773, 0.831, 1.0), // 14: bright cyan   #8FBCBB
        SIMD4<Float>(0.925, 0.937, 0.957, 1.0), // 15: bright white  #ECEFF4
    ]

    var font: CTFont {
        if let font = CTFontCreateWithName(fontName as CFString, fontSize, nil) as CTFont? {
            // Verify the font was actually found (not a fallback)
            let name = CTFontCopyPostScriptName(font) as String
            if name != ".AppleSystemUIFont" {
                return font
            }
        }
        // Fallback to Menlo
        return CTFontCreateWithName("Menlo" as CFString, fontSize, nil)
    }

    var cellSize: CGSize {
        let f = font
        let advance = glyphAdvance(for: "M", in: f)
        let lineHeight = CTFontGetAscent(f) + CTFontGetDescent(f) + CTFontGetLeading(f)
        return CGSize(width: ceil(advance), height: ceil(lineHeight))
    }

    private func glyphAdvance(for char: Character, in font: CTFont) -> CGFloat {
        var chars: [UniChar] = Array(char.utf16)
        var glyph: CGGlyph = 0
        CTFontGetGlyphsForCharacters(font, &chars, &glyph, 1)
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .default, &glyph, &advance, 1)
        return advance.width
    }
}
```

**Step 2: Verify it compiles**

Build. Expected: compiles. The `cellSize` computation should return reasonable values (e.g., ~8x17 for Menlo 14pt).

**Step 3: Commit**

```bash
git add Sources/FluxTerm/Terminal/TerminalConfig.swift
git commit -m "feat: add terminal configuration (font, colors, opacity)"
```

---

## Task 5: Glyph Atlas

**Files:**
- Create: `Sources/FluxTerm/Renderer/GlyphAtlas.swift`

**Step 1: Create GlyphAtlas**

`Sources/FluxTerm/Renderer/GlyphAtlas.swift`:
```swift
import Metal
import CoreText
import CoreGraphics

struct GlyphInfo {
    var atlasX: Int
    var atlasY: Int
    var width: Int
    var height: Int
    var bearingX: Float
    var bearingY: Float
    var advance: Float

    static let empty = GlyphInfo(atlasX: 0, atlasY: 0, width: 0, height: 0,
                                  bearingX: 0, bearingY: 0, advance: 0)
}

final class GlyphAtlas {
    let device: MTLDevice
    private(set) var texture: MTLTexture!

    private var atlasWidth: Int = 1024
    private var atlasHeight: Int = 1024
    private var cursorX: Int = 0
    private var cursorY: Int = 0
    private var rowHeight: Int = 0

    private var cache: [CacheKey: GlyphInfo] = [:]

    struct CacheKey: Hashable {
        let glyph: CGGlyph
        let bold: Bool
        let italic: Bool
    }

    init(device: MTLDevice) {
        self.device = device
        texture = createTexture(width: atlasWidth, height: atlasHeight)
    }

    private func createTexture(width: Int, height: Int) -> MTLTexture {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = [.shaderRead]
        desc.storageMode = .managed
        return device.makeTexture(descriptor: desc)!
    }

    func lookup(glyph: CGGlyph, font: CTFont, bold: Bool = false, italic: Bool = false) -> GlyphInfo {
        let key = CacheKey(glyph: glyph, bold: bold, italic: italic)
        if let cached = cache[key] {
            return cached
        }
        return rasterize(glyph: glyph, font: font, key: key)
    }

    private func rasterize(glyph: CGGlyph, font: CTFont, key: CacheKey) -> GlyphInfo {
        var g = glyph
        var bbox = CGRect.zero
        CTFontGetBoundingRectsForGlyphs(font, .default, &g, &bbox, 1)

        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .default, &g, &advance, 1)

        let pad = 1
        let bw = Int(ceil(bbox.width)) + 2 * pad
        let bh = Int(ceil(bbox.height)) + 2 * pad

        guard bw > 0, bh > 0 else {
            let info = GlyphInfo(
                atlasX: 0, atlasY: 0, width: 0, height: 0,
                bearingX: 0, bearingY: 0, advance: Float(advance.width)
            )
            cache[key] = info
            return info
        }

        // Rasterize to grayscale bitmap
        let bytesPerRow = bw
        let buf = UnsafeMutableRawPointer.allocate(byteCount: bw * bh, alignment: 1)
        defer { buf.deallocate() }
        buf.initializeMemory(as: UInt8.self, repeating: 0, count: bw * bh)

        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: buf, width: bw, height: bh,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return .empty
        }

        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        ctx.setFillColor(gray: 1.0, alpha: 1.0)

        let drawX = CGFloat(pad) - bbox.origin.x
        let drawY = CGFloat(pad) - bbox.origin.y
        var pos = CGPoint(x: drawX, y: drawY)
        CTFontDrawGlyphs(font, &g, &pos, 1, ctx)

        // Find space in atlas
        if cursorX + bw > atlasWidth {
            cursorX = 0
            cursorY += rowHeight
            rowHeight = 0
        }
        if cursorY + bh > atlasHeight {
            growAtlas()
        }

        // Upload to texture
        let region = MTLRegion(
            origin: MTLOrigin(x: cursorX, y: cursorY, z: 0),
            size: MTLSize(width: bw, height: bh, depth: 1)
        )
        texture.replace(region: region, mipmapLevel: 0,
                        withBytes: buf, bytesPerRow: bytesPerRow)

        let info = GlyphInfo(
            atlasX: cursorX, atlasY: cursorY,
            width: bw, height: bh,
            bearingX: Float(bbox.origin.x) - Float(pad),
            bearingY: Float(bbox.origin.y + bbox.height) + Float(pad),
            advance: Float(advance.width)
        )
        cache[key] = info

        cursorX += bw
        rowHeight = max(rowHeight, bh)

        return info
    }

    private func growAtlas() {
        let newHeight = atlasHeight * 2
        let newTexture = createTexture(width: atlasWidth, height: newHeight)

        guard let cmdQueue = device.makeCommandQueue(),
              let cmdBuf = cmdQueue.makeCommandBuffer(),
              let blit = cmdBuf.makeBlitCommandEncoder() else { return }

        blit.copy(from: texture, sourceSlice: 0, sourceLevel: 0,
                  sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                  sourceSize: MTLSize(width: atlasWidth, height: atlasHeight, depth: 1),
                  to: newTexture, destinationSlice: 0, destinationLevel: 0,
                  destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
        blit.endEncoding()
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()

        texture = newTexture
        atlasHeight = newHeight
    }

    func clearCache() {
        cache.removeAll()
        cursorX = 0
        cursorY = 0
        rowHeight = 0
        texture = createTexture(width: atlasWidth, height: atlasHeight)
    }
}
```

**Step 2: Verify it compiles**

Build. Expected: compiles without errors.

**Step 3: Commit**

```bash
git add Sources/FluxTerm/Renderer/GlyphAtlas.swift
git commit -m "feat: add glyph atlas with Core Text rasterization"
```

---

## Task 6: Metal Shaders

**Files:**
- Create: `Sources/FluxTerm/Renderer/Shaders.metal`
- Create: `Sources/FluxTerm/Renderer/ShaderTypes.swift`

**Step 1: Create shared type definitions**

`Sources/FluxTerm/Renderer/ShaderTypes.swift`:
```swift
import simd

struct CellInstance {
    var gridPos: SIMD2<Float> = .zero        // (col, row)
    var glyphUV: SIMD4<Float> = .zero        // (u0, v0, u1, v1) in pixels
    var glyphBearing: SIMD2<Float> = .zero   // offset from cell origin
    var glyphSize: SIMD2<Float> = .zero      // glyph bitmap size in pixels
    var fgColor: SIMD4<Float> = .init(1, 1, 1, 1)
    var bgColor: SIMD4<Float> = .init(0, 0, 0, 0)
}

struct Uniforms {
    var viewportSize: SIMD2<Float> = .zero
    var cellSize: SIMD2<Float> = .zero
    var atlasSize: SIMD2<Float> = .zero
    var gridOrigin: SIMD2<Float> = .zero
}
```

**Step 2: Create Metal shaders**

`Sources/FluxTerm/Renderer/Shaders.metal`:
```metal
#include <metal_stdlib>
using namespace metal;

// Must match Swift CellInstance layout
struct CellInstance {
    float2 gridPos;
    float4 glyphUV;
    float2 glyphBearing;
    float2 glyphSize;
    float4 fgColor;
    float4 bgColor;
};

struct Uniforms {
    float2 viewportSize;
    float2 cellSize;
    float2 atlasSize;
    float2 gridOrigin;
};

// ──────────────────────────────────────────
// Background pass: solid-color cell rectangles
// ──────────────────────────────────────────

struct BgOut {
    float4 position [[position]];
    float4 color;
};

vertex BgOut bg_vertex(
    uint vid [[vertex_id]],
    uint iid [[instance_id]],
    constant Uniforms &u [[buffer(0)]],
    constant CellInstance *cells [[buffer(1)]]
) {
    float2 unit;
    unit.x = (vid & 1) == 0 ? 0.0 : 1.0;
    unit.y = (vid & 2) == 0 ? 0.0 : 1.0;

    CellInstance cell = cells[iid];
    float2 pixel = u.gridOrigin + cell.gridPos * u.cellSize + unit * u.cellSize;

    float2 ndc;
    ndc.x = (pixel.x / u.viewportSize.x) * 2.0 - 1.0;
    ndc.y = 1.0 - (pixel.y / u.viewportSize.y) * 2.0;

    BgOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.color = cell.bgColor;
    return out;
}

fragment float4 bg_fragment(BgOut in [[stage_in]]) {
    return in.color;
}

// ──────────────────────────────────────────
// Glyph pass: textured quads from glyph atlas
// ──────────────────────────────────────────

struct GlyphOut {
    float4 position [[position]];
    float2 texCoord;
    float4 fgColor;
};

vertex GlyphOut glyph_vertex(
    uint vid [[vertex_id]],
    uint iid [[instance_id]],
    constant Uniforms &u [[buffer(0)]],
    constant CellInstance *cells [[buffer(1)]]
) {
    float2 unit;
    unit.x = (vid & 1) == 0 ? 0.0 : 1.0;
    unit.y = (vid & 2) == 0 ? 0.0 : 1.0;

    CellInstance cell = cells[iid];
    float2 cellOrigin = u.gridOrigin + cell.gridPos * u.cellSize;
    float2 glyphOrigin = cellOrigin + cell.glyphBearing;
    float2 pixel = glyphOrigin + unit * cell.glyphSize;

    float2 ndc;
    ndc.x = (pixel.x / u.viewportSize.x) * 2.0 - 1.0;
    ndc.y = 1.0 - (pixel.y / u.viewportSize.y) * 2.0;

    float2 uv;
    uv.x = mix(cell.glyphUV.x, cell.glyphUV.z, unit.x) / u.atlasSize.x;
    uv.y = mix(cell.glyphUV.y, cell.glyphUV.w, unit.y) / u.atlasSize.y;

    GlyphOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.texCoord = uv;
    out.fgColor = cell.fgColor;
    return out;
}

fragment float4 glyph_fragment(
    GlyphOut in [[stage_in]],
    texture2d<float> atlas [[texture(0)]],
    sampler s [[sampler(0)]]
) {
    float coverage = atlas.sample(s, in.texCoord).r;
    return float4(in.fgColor.rgb, in.fgColor.a * coverage);
}

// ──────────────────────────────────────────
// Cursor pass: blinking block cursor
// ──────────────────────────────────────────

struct CursorUniforms {
    float2 viewportSize;
    float2 cellSize;
    float2 gridOrigin;
    float2 cursorPos;    // (col, row)
    float4 cursorColor;
};

struct CursorOut {
    float4 position [[position]];
    float4 color;
};

vertex CursorOut cursor_vertex(
    uint vid [[vertex_id]],
    constant CursorUniforms &u [[buffer(0)]]
) {
    float2 unit;
    unit.x = (vid & 1) == 0 ? 0.0 : 1.0;
    unit.y = (vid & 2) == 0 ? 0.0 : 1.0;

    float2 pixel = u.gridOrigin + u.cursorPos * u.cellSize + unit * u.cellSize;

    float2 ndc;
    ndc.x = (pixel.x / u.viewportSize.x) * 2.0 - 1.0;
    ndc.y = 1.0 - (pixel.y / u.viewportSize.y) * 2.0;

    CursorOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.color = u.cursorColor;
    return out;
}

fragment float4 cursor_fragment(CursorOut in [[stage_in]]) {
    return in.color;
}
```

**Step 3: Verify shaders compile**

Build in Xcode (Xcode compiles .metal files automatically). Expected: no shader compilation errors.

**Step 4: Commit**

```bash
git add Sources/FluxTerm/Renderer/ShaderTypes.swift Sources/FluxTerm/Renderer/Shaders.metal
git commit -m "feat: add Metal shaders for background, glyph, and cursor rendering"
```

---

## Task 7: Terminal Renderer

**Files:**
- Create: `Sources/FluxTerm/Renderer/MetalRenderer.swift`

**Step 1: Create MetalRenderer**

This is the core rendering engine that reads SwiftTerm's grid and renders via Metal.

`Sources/FluxTerm/Renderer/MetalRenderer.swift`:
```swift
import Metal
import CoreText
import SwiftTerm

struct CursorUniforms {
    var viewportSize: SIMD2<Float> = .zero
    var cellSize: SIMD2<Float> = .zero
    var gridOrigin: SIMD2<Float> = .zero
    var cursorPos: SIMD2<Float> = .zero
    var cursorColor: SIMD4<Float> = .init(1, 1, 1, 1)
}

final class MetalRenderer {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let glyphAtlas: GlyphAtlas
    var config: TerminalConfig

    // Pipeline states
    private var bgPipeline: MTLRenderPipelineState!
    private var glyphPipeline: MTLRenderPipelineState!
    private var cursorPipeline: MTLRenderPipelineState!
    private var sampler: MTLSamplerState!

    // Triple-buffered instance data
    private let inflightCount = 3
    private var frameSemaphore: DispatchSemaphore
    private var frameIndex = 0
    private var instanceBuffers: [MTLBuffer] = []

    // Font metrics
    private(set) var cellWidth: Float = 0
    private(set) var cellHeight: Float = 0
    private(set) var fontAscent: Float = 0

    init(device: MTLDevice, commandQueue: MTLCommandQueue, config: TerminalConfig) {
        self.device = device
        self.commandQueue = commandQueue
        self.config = config
        self.glyphAtlas = GlyphAtlas(device: device)
        self.frameSemaphore = DispatchSemaphore(value: inflightCount)

        updateFontMetrics()
        buildPipelines()
        buildSampler()
        allocateBuffers()
    }

    func updateFontMetrics() {
        let cs = config.cellSize
        cellWidth = Float(cs.width)
        cellHeight = Float(cs.height)
        fontAscent = Float(CTFontGetAscent(config.font))
    }

    private func buildPipelines() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Failed to load Metal library. Build in Xcode to compile .metal files.")
        }

        // Background pipeline (opaque)
        let bgDesc = MTLRenderPipelineDescriptor()
        bgDesc.vertexFunction = library.makeFunction(name: "bg_vertex")
        bgDesc.fragmentFunction = library.makeFunction(name: "bg_fragment")
        let bgCA = bgDesc.colorAttachments[0]!
        bgCA.pixelFormat = .bgra8Unorm
        bgCA.isBlendingEnabled = true
        bgCA.sourceRGBBlendFactor = .sourceAlpha
        bgCA.destinationRGBBlendFactor = .oneMinusSourceAlpha
        bgCA.rgbBlendOperation = .add
        bgCA.sourceAlphaBlendFactor = .sourceAlpha
        bgCA.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        bgCA.alphaBlendOperation = .add
        bgPipeline = try! device.makeRenderPipelineState(descriptor: bgDesc)

        // Glyph pipeline (alpha blending)
        let glyphDesc = MTLRenderPipelineDescriptor()
        glyphDesc.vertexFunction = library.makeFunction(name: "glyph_vertex")
        glyphDesc.fragmentFunction = library.makeFunction(name: "glyph_fragment")
        let glyphCA = glyphDesc.colorAttachments[0]!
        glyphCA.pixelFormat = .bgra8Unorm
        glyphCA.isBlendingEnabled = true
        glyphCA.sourceRGBBlendFactor = .sourceAlpha
        glyphCA.destinationRGBBlendFactor = .oneMinusSourceAlpha
        glyphCA.rgbBlendOperation = .add
        glyphCA.sourceAlphaBlendFactor = .one
        glyphCA.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        glyphCA.alphaBlendOperation = .add
        glyphPipeline = try! device.makeRenderPipelineState(descriptor: glyphDesc)

        // Cursor pipeline
        let cursorDesc = MTLRenderPipelineDescriptor()
        cursorDesc.vertexFunction = library.makeFunction(name: "cursor_vertex")
        cursorDesc.fragmentFunction = library.makeFunction(name: "cursor_fragment")
        let cursorCA = cursorDesc.colorAttachments[0]!
        cursorCA.pixelFormat = .bgra8Unorm
        cursorCA.isBlendingEnabled = true
        cursorCA.sourceRGBBlendFactor = .sourceAlpha
        cursorCA.destinationRGBBlendFactor = .oneMinusSourceAlpha
        cursorCA.rgbBlendOperation = .add
        cursorCA.sourceAlphaBlendFactor = .one
        cursorCA.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        cursorCA.alphaBlendOperation = .add
        cursorPipeline = try! device.makeRenderPipelineState(descriptor: cursorDesc)
    }

    private func buildSampler() {
        let desc = MTLSamplerDescriptor()
        desc.minFilter = .linear
        desc.magFilter = .linear
        desc.sAddressMode = .clampToZero
        desc.tAddressMode = .clampToZero
        sampler = device.makeSamplerState(descriptor: desc)
    }

    private func allocateBuffers() {
        let maxCells = 300 * 100 // generous max
        let size = MemoryLayout<CellInstance>.stride * maxCells
        for _ in 0..<inflightCount {
            instanceBuffers.append(device.makeBuffer(length: size, options: .storageModeShared)!)
        }
    }

    // MARK: - Rendering

    func draw(terminal: Terminal, drawable: CAMetalDrawable) {
        frameSemaphore.wait()

        let buffer = instanceBuffers[frameIndex % inflightCount]
        let cellCount = buildInstances(terminal: terminal, into: buffer)
        frameIndex += 1

        var uniforms = Uniforms(
            viewportSize: SIMD2(Float(drawable.texture.width), Float(drawable.texture.height)),
            cellSize: SIMD2(cellWidth, cellHeight),
            atlasSize: SIMD2(Float(glyphAtlas.texture.width), Float(glyphAtlas.texture.height)),
            gridOrigin: SIMD2(Float(config.padding), Float(config.padding))
        )

        let passDesc = MTLRenderPassDescriptor()
        passDesc.colorAttachments[0].texture = drawable.texture
        passDesc.colorAttachments[0].loadAction = .clear
        passDesc.colorAttachments[0].storeAction = .store
        passDesc.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)

        guard let cmdBuf = commandQueue.makeCommandBuffer(),
              let enc = cmdBuf.makeRenderCommandEncoder(descriptor: passDesc) else {
            frameSemaphore.signal()
            return
        }

        // Pass 1: Backgrounds
        enc.setRenderPipelineState(bgPipeline)
        enc.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 0)
        enc.setVertexBuffer(buffer, offset: 0, index: 1)
        enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: cellCount)

        // Pass 2: Glyphs
        enc.setRenderPipelineState(glyphPipeline)
        enc.setFragmentTexture(glyphAtlas.texture, index: 0)
        enc.setFragmentSamplerState(sampler, index: 0)
        enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: cellCount)

        // Pass 3: Cursor
        let buf = terminal.buffer
        var cursorUniforms = CursorUniforms(
            viewportSize: uniforms.viewportSize,
            cellSize: uniforms.cellSize,
            gridOrigin: uniforms.gridOrigin,
            cursorPos: SIMD2(Float(buf.x), Float(buf.y)),
            cursorColor: config.cursorColor
        )
        enc.setRenderPipelineState(cursorPipeline)
        enc.setVertexBytes(&cursorUniforms, length: MemoryLayout<CursorUniforms>.size, index: 0)
        enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

        enc.endEncoding()
        cmdBuf.present(drawable)
        cmdBuf.addCompletedHandler { [weak self] _ in
            self?.frameSemaphore.signal()
        }
        cmdBuf.commit()
    }

    // MARK: - Instance data assembly

    private func buildInstances(terminal: Terminal, into buffer: MTLBuffer) -> Int {
        let ptr = buffer.contents().bindMemory(to: CellInstance.self,
                                                capacity: terminal.rows * terminal.cols)
        let termBuffer = terminal.buffer
        let font = config.font
        let defaultFg = config.foregroundColor
        let defaultBg = config.backgroundColor
        let opacity = config.backgroundOpacity

        var count = 0
        for row in 0..<terminal.rows {
            let line = termBuffer.lines[row + termBuffer.yDisp]
            for col in 0..<terminal.cols {
                let cell = line[col]

                // Skip continuation cells of wide characters
                if cell.width == 0 { continue }

                var inst = CellInstance()
                inst.gridPos = SIMD2(Float(col), Float(row))

                // Resolve colors
                inst.fgColor = resolveColor(cell.attribute.fg, defaultColor: defaultFg)
                var bg = resolveColor(cell.attribute.bg, defaultColor: defaultBg)
                bg.w = opacity // Apply background opacity
                inst.bgColor = bg

                // Handle inverse (swap fg/bg)
                if cell.attribute.style.contains(.inverse) {
                    let tmp = inst.fgColor
                    inst.fgColor = inst.bgColor
                    inst.fgColor.w = 1.0
                    inst.bgColor = tmp
                    inst.bgColor.w = opacity
                }

                // Look up glyph
                let char = cell.getCharacter()
                if char != " " && char != "\0" && !char.unicodeScalars.isEmpty {
                    let glyphID = getGlyph(for: char, font: font)
                    if glyphID != 0 {
                        let info = glyphAtlas.lookup(glyph: glyphID, font: font,
                                                     bold: cell.attribute.style.contains(.bold))
                        if info.width > 0 {
                            inst.glyphUV = SIMD4(
                                Float(info.atlasX), Float(info.atlasY),
                                Float(info.atlasX + info.width), Float(info.atlasY + info.height)
                            )
                            inst.glyphBearing = SIMD2(
                                info.bearingX,
                                fontAscent - info.bearingY
                            )
                            inst.glyphSize = SIMD2(Float(info.width), Float(info.height))
                        }
                    }
                }

                ptr[count] = inst
                count += 1
            }
        }
        return count
    }

    private func getGlyph(for char: Character, font: CTFont) -> CGGlyph {
        var chars: [UniChar] = Array(char.utf16)
        var glyph: CGGlyph = 0
        CTFontGetGlyphsForCharacters(font, &chars, &glyph, chars.count)
        return glyph
    }

    private func resolveColor(_ color: SwiftTerm.Color, defaultColor: SIMD4<Float>) -> SIMD4<Float> {
        // SwiftTerm Color stores RGB as UInt16 (0-65535)
        let r = Float(color.red) / 65535.0
        let g = Float(color.green) / 65535.0
        let b = Float(color.blue) / 65535.0

        // Check if this is the default color (approximately)
        if color == SwiftTerm.Color.defaultForeground || color == SwiftTerm.Color.defaultBackground {
            return defaultColor
        }

        return SIMD4(r, g, b, 1.0)
    }

    func gridSize(for viewSize: CGSize, scale: CGFloat) -> (cols: Int, rows: Int) {
        let padding = Float(config.padding) * 2
        let w = Float(viewSize.width) * Float(scale) - padding
        let h = Float(viewSize.height) * Float(scale) - padding
        let cols = max(1, Int(w / cellWidth))
        let rows = max(1, Int(h / cellHeight))
        return (cols, rows)
    }
}
```

**Step 2: Verify it compiles**

Build in Xcode. Expected: compiles. May need to adjust SwiftTerm `Color` API calls if the version differs — check the actual SwiftTerm API for `Color.red`, `Color.green`, `Color.blue` properties.

**Step 3: Commit**

```bash
git add Sources/FluxTerm/Renderer/MetalRenderer.swift
git commit -m "feat: add Metal renderer with glyph atlas integration"
```

---

## Task 8: Wire Everything Together

**Files:**
- Create: `Sources/FluxTerm/Terminal/TerminalViewController.swift`
- Modify: `Sources/FluxTerm/UI/MainWindow.swift`
- Modify: `Sources/FluxTerm/App/AppDelegate.swift`

**Step 1: Create TerminalViewController**

This is the coordinator that connects the terminal session, Metal view, and renderer.

`Sources/FluxTerm/Terminal/TerminalViewController.swift`:
```swift
import AppKit
import SwiftTerm

class TerminalViewController: NSViewController, TerminalSessionDelegate {
    var metalView: TerminalMetalView!
    var renderer: MetalRenderer!
    var session: TerminalSession!
    var config = TerminalConfig()

    private var displayLink: CVDisplayLink?
    private var isRendering = false

    override func loadView() {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        self.view = view

        metalView = TerminalMetalView(frame: view.bounds)
        metalView.autoresizingMask = [.width, .height]
        view.addSubview(metalView)

        renderer = MetalRenderer(
            device: metalView.device,
            commandQueue: metalView.commandQueue,
            config: config
        )

        // Calculate initial grid size
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let gridSize = renderer.gridSize(for: view.bounds.size, scale: scale)

        session = TerminalSession(cols: gridSize.cols, rows: gridSize.rows)
        session.delegate = self
        session.start()

        setupDisplayLink()
        metalView.window?.makeFirstResponder(metalView)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(metalView)
    }

    // MARK: - Display Link

    private func setupDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let displayLink = displayLink else { return }

        let opaquePtr = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(displayLink, { (_, _, _, _, _, ctx) -> CVReturn in
            let vc = Unmanaged<TerminalViewController>.fromOpaque(ctx!).takeUnretainedValue()
            vc.render()
            return kCVReturnSuccess
        }, opaquePtr)

        CVDisplayLinkStart(displayLink)
    }

    private func render() {
        guard !isRendering else { return }
        isRendering = true
        defer { isRendering = false }

        guard let drawable = metalView.metalLayer.nextDrawable() else { return }
        renderer.draw(terminal: session.terminal, drawable: drawable)
    }

    // MARK: - Resize

    override func viewDidLayout() {
        super.viewDidLayout()

        let scale = view.window?.backingScaleFactor ?? 2.0
        let gridSize = renderer.gridSize(for: view.bounds.size, scale: scale)
        session.resize(cols: gridSize.cols, rows: gridSize.rows)
    }

    // MARK: - Keyboard Input

    func handleKeyDown(_ event: NSEvent) {
        // Let SwiftTerm handle the key encoding
        let bytes = encodeKey(event)
        if !bytes.isEmpty {
            session.sendInput(bytes[...])
        }
    }

    func handleKeyEvent(text: String) {
        session.sendInput(text)
    }

    private func encodeKey(_ event: NSEvent) -> [UInt8] {
        // Handle special keys
        guard let chars = event.charactersIgnoringModifiers else { return [] }
        let modifiers = event.modifierFlags

        // Check for Cmd shortcuts first
        if modifiers.contains(.command) {
            return [] // Let the system handle Cmd+key
        }

        // Control key combinations
        if modifiers.contains(.control) {
            if let scalar = chars.unicodeScalars.first {
                let code = scalar.value
                if code >= 0x61 && code <= 0x7a { // a-z
                    return [UInt8(code - 0x60)]
                }
            }
        }

        // Special keys
        switch event.keyCode {
        case 36: return [0x0D] // Return
        case 48: return [0x09] // Tab
        case 51: return [0x7F] // Backspace (Delete key sends DEL)
        case 53: return [0x1B] // Escape
        case 123: return [0x1B, 0x5B, 0x44] // Left arrow: ESC [ D
        case 124: return [0x1B, 0x5B, 0x43] // Right arrow: ESC [ C
        case 125: return [0x1B, 0x5B, 0x42] // Down arrow: ESC [ B
        case 126: return [0x1B, 0x5B, 0x41] // Up arrow: ESC [ A
        case 115: return [0x1B, 0x5B, 0x48] // Home: ESC [ H
        case 119: return [0x1B, 0x5B, 0x46] // End: ESC [ F
        case 116: return [0x1B, 0x5B, 0x35, 0x7E] // Page Up: ESC [ 5 ~
        case 121: return [0x1B, 0x5B, 0x36, 0x7E] // Page Down: ESC [ 6 ~
        case 117: return [0x1B, 0x5B, 0x33, 0x7E] // Forward Delete: ESC [ 3 ~
        default: break
        }

        // Regular text input
        if let text = event.characters {
            return Array(text.utf8)
        }

        return []
    }

    // MARK: - TerminalSessionDelegate

    func terminalSession(_ session: TerminalSession, didReceiveData data: ArraySlice<UInt8>) {
        metalView.setNeedsRedraw()
    }

    func terminalSession(_ session: TerminalSession, titleDidChange title: String) {
        DispatchQueue.main.async { [weak self] in
            self?.view.window?.title = title
        }
    }

    func terminalSessionDidTerminate(_ session: TerminalSession, exitCode: Int32?) {
        DispatchQueue.main.async {
            NSApp.terminate(nil)
        }
    }

    deinit {
        if let displayLink = displayLink {
            CVDisplayLinkStop(displayLink)
        }
    }
}
```

**Step 2: Update TerminalMetalView for keyboard input routing**

Add to `Sources/FluxTerm/Renderer/TerminalMetalView.swift` — add a property and key handling:

Add a `weak var controller: TerminalViewController?` property and override `keyDown`:

```swift
// Add inside TerminalMetalView class:

weak var controller: TerminalViewController?

// Add the metalLayer accessor
var metalLayer: CAMetalLayer { self.layer as! CAMetalLayer }

override func keyDown(with event: NSEvent) {
    controller?.handleKeyDown(event)
}

// Also handle text input for IME / composed characters
override func insertText(_ insertString: Any, replacementRange: NSRange) {
    if let str = insertString as? String {
        controller?.handleKeyEvent(text: str)
    }
}
```

**Step 3: Update MainWindow to use TerminalViewController**

`Sources/FluxTerm/UI/MainWindow.swift`:
```swift
import AppKit

class MainWindow: NSWindowController {
    var terminalVC: TerminalViewController!

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "FluxTerm"
        window.center()
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = .clear
        window.minSize = NSSize(width: 400, height: 300)

        // Glass/blur effect
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        window.contentView = visualEffectView

        self.init(window: window)

        // Add terminal view controller
        terminalVC = TerminalViewController()
        terminalVC.view.frame = visualEffectView.bounds
        terminalVC.view.autoresizingMask = [.width, .height]
        visualEffectView.addSubview(terminalVC.view)

        // Wire up keyboard routing
        terminalVC.metalView.controller = terminalVC
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeFirstResponder(terminalVC.metalView)
    }
}
```

**Step 4: Build and run**

Build in Xcode with `Cmd+R`.

Expected: A glass window appears. The terminal shell starts (zsh). You should see text rendered via Metal. You can type commands and see output. Arrow keys, backspace, enter all work.

**Troubleshooting:**
- If the window is blank: Check that `device.makeDefaultLibrary()` is not nil. Metal shaders must be compiled by Xcode.
- If text appears but colors are wrong: Check the `resolveColor` method — SwiftTerm's Color API may vary.
- If keyboard input doesn't work: Ensure `makeFirstResponder` is called on the Metal view.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: wire terminal session, Metal renderer, and keyboard input together"
```

---

## Task 9: Scrollback Support

**Files:**
- Modify: `Sources/FluxTerm/Renderer/TerminalMetalView.swift`
- Modify: `Sources/FluxTerm/Terminal/TerminalViewController.swift`

**Step 1: Add scroll handling to TerminalMetalView**

Add scroll event handling to `TerminalMetalView`:

```swift
// Add to TerminalMetalView:

override func scrollWheel(with event: NSEvent) {
    controller?.handleScroll(event)
}
```

**Step 2: Add scroll handling to TerminalViewController**

```swift
// Add to TerminalViewController:

private var scrollOffset: Int = 0  // lines scrolled back from bottom

func handleScroll(_ event: NSEvent) {
    let delta = Int(event.scrollingDeltaY)
    let terminal = session.terminal
    let buffer = terminal.buffer

    // Calculate max scrollback
    let maxScroll = buffer.lines.count - terminal.rows
    guard maxScroll > 0 else { return }

    // Update scroll position
    scrollOffset = max(0, min(maxScroll, scrollOffset + delta))

    // Update SwiftTerm's viewport offset
    // yDisp controls which line is at the top of the visible area
    let newYDisp = buffer.yBase - scrollOffset
    if newYDisp >= 0 {
        terminal.scroll(toPosition: Double(scrollOffset) / Double(maxScroll))
    }

    metalView.setNeedsRedraw()
}
```

Note: The scroll implementation depends on SwiftTerm's `scroll(toPosition:)` API or direct `yDisp` manipulation. Adjust based on what SwiftTerm exposes. The `yDisp` property on `Buffer` controls the viewport position — `yBase` is the bottom (most recent output), and scrolling back means setting `yDisp` to a value less than `yBase`.

**Step 3: Auto-scroll to bottom on new output**

Update the `terminalSession(_:didReceiveData:)` delegate method:

```swift
func terminalSession(_ session: TerminalSession, didReceiveData data: ArraySlice<UInt8>) {
    scrollOffset = 0  // Reset scroll on new output
    metalView.setNeedsRedraw()
}
```

**Step 4: Verify**

Build and run. Run a command with lots of output (e.g., `ls -la /usr/lib`). Scroll up with trackpad/mouse wheel. Expected: can see scrollback history. Typing a new command scrolls back to bottom.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add scrollback support with scroll wheel"
```

---

## Task 10: Selection and Copy/Paste

**Files:**
- Modify: `Sources/FluxTerm/Renderer/TerminalMetalView.swift`
- Modify: `Sources/FluxTerm/Terminal/TerminalViewController.swift`
- Modify: `Sources/FluxTerm/Renderer/MetalRenderer.swift`

**Step 1: Add mouse tracking to TerminalMetalView**

```swift
// Add to TerminalMetalView:

override func mouseDown(with event: NSEvent) {
    controller?.handleMouseDown(event)
}

override func mouseDragged(with event: NSEvent) {
    controller?.handleMouseDragged(event)
}

override func mouseUp(with event: NSEvent) {
    controller?.handleMouseUp(event)
}
```

**Step 2: Add selection tracking to TerminalViewController**

```swift
// Add to TerminalViewController:

struct CellPosition {
    var col: Int
    var row: Int
}

private var selectionStart: CellPosition?
private var selectionEnd: CellPosition?
var hasSelection: Bool { selectionStart != nil && selectionEnd != nil }

private func cellPosition(from event: NSEvent) -> CellPosition {
    let point = metalView.convert(event.locationInWindow, from: nil)
    let scale = view.window?.backingScaleFactor ?? 2.0
    let padding = Float(config.padding)
    let col = Int((Float(point.x) * Float(scale) - padding) / renderer.cellWidth)
    // NSView Y is bottom-up, terminal is top-down
    let viewHeight = Float(metalView.bounds.height) * Float(scale)
    let row = Int((viewHeight - Float(point.y) * Float(scale) - padding) / renderer.cellHeight)
    return CellPosition(
        col: max(0, min(col, session.terminal.cols - 1)),
        row: max(0, min(row, session.terminal.rows - 1))
    )
}

func handleMouseDown(_ event: NSEvent) {
    let pos = cellPosition(from: event)
    selectionStart = pos
    selectionEnd = pos
    metalView.setNeedsRedraw()
}

func handleMouseDragged(_ event: NSEvent) {
    selectionEnd = cellPosition(from: event)
    metalView.setNeedsRedraw()
}

func handleMouseUp(_ event: NSEvent) {
    selectionEnd = cellPosition(from: event)
    metalView.setNeedsRedraw()
}

func getSelectedText() -> String? {
    guard let start = selectionStart, let end = selectionEnd else { return nil }

    let terminal = session.terminal
    let buffer = terminal.buffer
    var text = ""

    let (startRow, startCol, endRow, endCol) = normalizeSelection(start: start, end: end)

    for row in startRow...endRow {
        let lineIdx = row + buffer.yDisp
        guard lineIdx >= 0 && lineIdx < buffer.lines.count else { continue }
        let line = buffer.lines[lineIdx]

        let colStart = (row == startRow) ? startCol : 0
        let colEnd = (row == endRow) ? endCol : terminal.cols - 1

        for col in colStart...colEnd {
            let char = line[col].getCharacter()
            if char != "\0" {
                text.append(char)
            }
        }
        if row < endRow && !line.isWrapped {
            text.append("\n")
        }
    }
    return text.isEmpty ? nil : text
}

private func normalizeSelection(start: CellPosition, end: CellPosition)
    -> (startRow: Int, startCol: Int, endRow: Int, endCol: Int)
{
    if start.row < end.row || (start.row == end.row && start.col <= end.col) {
        return (start.row, start.col, end.row, end.col)
    } else {
        return (end.row, end.col, start.row, start.col)
    }
}

func isSelected(col: Int, row: Int) -> Bool {
    guard let start = selectionStart, let end = selectionEnd else { return false }
    let (sr, sc, er, ec) = normalizeSelection(start: start, end: end)
    if row < sr || row > er { return false }
    if row == sr && row == er { return col >= sc && col <= ec }
    if row == sr { return col >= sc }
    if row == er { return col <= ec }
    return true
}
```

**Step 3: Add Cmd+C (copy) and Cmd+V (paste) handling**

Update `handleKeyDown` in `TerminalViewController` and `keyDown` in `TerminalMetalView`:

```swift
// In TerminalMetalView, update keyDown:
override func keyDown(with event: NSEvent) {
    let modifiers = event.modifierFlags
    if modifiers.contains(.command) {
        if event.charactersIgnoringModifiers == "c" {
            controller?.copy(self)
            return
        }
        if event.charactersIgnoringModifiers == "v" {
            controller?.paste(self)
            return
        }
    }
    controller?.handleKeyDown(event)
}

// In TerminalViewController, add:
@objc func copy(_ sender: Any?) {
    guard let text = getSelectedText() else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(text, forType: .string)
    // Clear selection after copy
    selectionStart = nil
    selectionEnd = nil
    metalView.setNeedsRedraw()
}

@objc func paste(_ sender: Any?) {
    guard let text = NSPasteboard.general.string(forType: .string) else { return }
    session.sendInput(text)
}
```

**Step 4: Highlight selected cells in the renderer**

Pass selection info to `MetalRenderer.buildInstances`. Add a closure or pass the selection state:

```swift
// In MetalRenderer, modify buildInstances to accept a selection check:
private func buildInstances(terminal: Terminal, into buffer: MTLBuffer,
                            isSelected: ((Int, Int) -> Bool)? = nil) -> Int {
    // ... existing code ...
    // Inside the inner loop, after resolving colors:
    if isSelected?(col, row) == true {
        // Swap fg/bg for selection highlight
        let tmpFg = inst.fgColor
        inst.fgColor = inst.bgColor
        inst.fgColor.w = 1.0
        inst.bgColor = tmpFg
        inst.bgColor.w = 1.0
    }
    // ... rest of code ...
}

// Update draw() to pass the selection check:
func draw(terminal: Terminal, drawable: CAMetalDrawable,
          isSelected: ((Int, Int) -> Bool)? = nil) {
    // ... existing code ...
    let cellCount = buildInstances(terminal: terminal, into: buffer, isSelected: isSelected)
    // ... rest ...
}
```

Update the `render()` method in `TerminalViewController`:
```swift
private func render() {
    guard !isRendering else { return }
    isRendering = true
    defer { isRendering = false }

    guard let drawable = metalView.metalLayer.nextDrawable() else { return }
    renderer.draw(terminal: session.terminal, drawable: drawable) { [weak self] col, row in
        self?.isSelected(col: col, row: row) ?? false
    }
}
```

**Step 5: Verify**

Build and run. Click and drag in the terminal to select text. Selected text should appear highlighted (inverted colors). Press Cmd+C to copy. Press Cmd+V to paste into the terminal.

**Step 6: Commit**

```bash
git add -A
git commit -m "feat: add text selection and copy/paste support"
```

---

## Task 11: Clickable URLs

**Files:**
- Create: `Sources/FluxTerm/Terminal/URLDetector.swift`
- Modify: `Sources/FluxTerm/Renderer/TerminalMetalView.swift`
- Modify: `Sources/FluxTerm/Terminal/TerminalViewController.swift`

**Step 1: Create URL detector**

`Sources/FluxTerm/Terminal/URLDetector.swift`:
```swift
import Foundation
import SwiftTerm

struct DetectedURL {
    let url: URL
    let startCol: Int
    let endCol: Int
    let row: Int
}

class URLDetector {
    private static let urlPattern: NSRegularExpression = {
        let pattern = #"https?://[^\s<>\"'\])]+"#
        return try! NSRegularExpression(pattern: pattern, options: [])
    }()

    static func detectURLs(in terminal: Terminal) -> [DetectedURL] {
        var results: [DetectedURL] = []
        let buffer = terminal.buffer

        for row in 0..<terminal.rows {
            let lineIdx = row + buffer.yDisp
            guard lineIdx >= 0, lineIdx < buffer.lines.count else { continue }
            let line = buffer.lines[lineIdx]
            let text = line.translateToString()
            let range = NSRange(text.startIndex..., in: text)

            let matches = urlPattern.matches(in: text, options: [], range: range)
            for match in matches {
                guard let swiftRange = Range(match.range, in: text) else { continue }
                let urlString = String(text[swiftRange])
                guard let url = URL(string: urlString) else { continue }

                let startCol = text.distance(from: text.startIndex, to: swiftRange.lowerBound)
                let endCol = text.distance(from: text.startIndex, to: swiftRange.upperBound) - 1

                results.append(DetectedURL(url: url, startCol: startCol, endCol: endCol, row: row))
            }
        }
        return results
    }

    static func urlAt(col: Int, row: Int, in urls: [DetectedURL]) -> DetectedURL? {
        return urls.first { url in
            url.row == row && col >= url.startCol && col <= url.endCol
        }
    }
}
```

**Step 2: Add hover and click handling**

Add to `TerminalMetalView`:
```swift
// Add tracking area for mouse hover
override func updateTrackingAreas() {
    super.updateTrackingAreas()
    for area in trackingAreas {
        removeTrackingArea(area)
    }
    let area = NSTrackingArea(
        rect: bounds,
        options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
        owner: self,
        userInfo: nil
    )
    addTrackingArea(area)
}

override func mouseMoved(with event: NSEvent) {
    controller?.handleMouseMoved(event)
}
```

Add to `TerminalViewController`:
```swift
// Add to TerminalViewController:
private var detectedURLs: [DetectedURL] = []
private var hoveredURL: DetectedURL?

func handleMouseMoved(_ event: NSEvent) {
    let pos = cellPosition(from: event)
    let url = URLDetector.urlAt(col: pos.col, row: pos.row, in: detectedURLs)

    if url != nil {
        NSCursor.pointingHand.set()
    } else {
        NSCursor.iBeam.set()
    }
    hoveredURL = url
}

// Update terminalSession didReceiveData to refresh URLs:
func terminalSession(_ session: TerminalSession, didReceiveData data: ArraySlice<UInt8>) {
    scrollOffset = 0
    detectedURLs = URLDetector.detectURLs(in: session.terminal)
    metalView.setNeedsRedraw()
}

// Update handleMouseDown for URL clicking:
func handleMouseDown(_ event: NSEvent) {
    // Check for Cmd+click on URL
    if event.modifierFlags.contains(.command), let url = hoveredURL {
        NSWorkspace.shared.open(url.url)
        return
    }

    let pos = cellPosition(from: event)
    selectionStart = pos
    selectionEnd = pos
    metalView.setNeedsRedraw()
}
```

**Step 3: Underline hovered URLs in renderer**

Pass URL hover state to the renderer and render underlines for URL ranges. This can be done by modifying the foreground color for URL cells or adding a separate underline pass. For simplicity, change the foreground color of URL cells:

```swift
// In MetalRenderer.buildInstances, add URL highlighting:
// Accept an additional parameter: urlRanges: [(row: Int, startCol: Int, endCol: Int)]
// For cells matching a URL range, set a distinct fg color (e.g., blue underline).
```

**Step 4: Verify**

Build and run. Run `echo "Visit https://github.com"`. Hover over the URL — cursor should change to pointing hand. Cmd+Click should open the URL in the browser.

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add clickable URL detection with Cmd+click"
```

---

## Task 12: Polish and Final Integration

**Files:**
- Modify: `Sources/FluxTerm/App/AppDelegate.swift`
- Modify: `Sources/FluxTerm/UI/MainWindow.swift`
- Modify various files for polish

**Step 1: Add basic menu bar**

Update `AppDelegate`:
```swift
// In AppDelegate.applicationDidFinishLaunching, add:
setupMenuBar()

// Add method:
private func setupMenuBar() {
    let mainMenu = NSMenu()

    // App menu
    let appMenuItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(withTitle: "About FluxTerm", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(withTitle: "Quit FluxTerm", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    appMenuItem.submenu = appMenu
    mainMenu.addItem(appMenuItem)

    // Edit menu (for copy/paste)
    let editMenuItem = NSMenuItem()
    let editMenu = NSMenu(title: "Edit")
    editMenu.addItem(withTitle: "Copy", action: #selector(TerminalViewController.copy(_:)), keyEquivalent: "c")
    editMenu.addItem(withTitle: "Paste", action: #selector(TerminalViewController.paste(_:)), keyEquivalent: "v")
    editMenu.addItem(withTitle: "Select All", action: #selector(TerminalViewController.selectAll(_:)), keyEquivalent: "a")
    editMenuItem.submenu = editMenu
    mainMenu.addItem(editMenuItem)

    // View menu
    let viewMenuItem = NSMenuItem()
    let viewMenu = NSMenu(title: "View")
    viewMenu.addItem(withTitle: "Increase Font Size", action: #selector(TerminalViewController.increaseFontSize(_:)), keyEquivalent: "+")
    viewMenu.addItem(withTitle: "Decrease Font Size", action: #selector(TerminalViewController.decreaseFontSize(_:)), keyEquivalent: "-")
    viewMenuItem.submenu = viewMenu
    mainMenu.addItem(viewMenuItem)

    NSApp.mainMenu = mainMenu
}
```

**Step 2: Add font size controls**

Add to `TerminalViewController`:
```swift
@objc func selectAll(_ sender: Any?) {
    selectionStart = CellPosition(col: 0, row: 0)
    selectionEnd = CellPosition(col: session.terminal.cols - 1, row: session.terminal.rows - 1)
    metalView.setNeedsRedraw()
}

@objc func increaseFontSize(_ sender: Any?) {
    config.fontSize = min(72, config.fontSize + 1)
    applyFontChange()
}

@objc func decreaseFontSize(_ sender: Any?) {
    config.fontSize = max(8, config.fontSize - 1)
    applyFontChange()
}

private func applyFontChange() {
    renderer.config = config
    renderer.updateFontMetrics()
    renderer.glyphAtlas.clearCache()

    let scale = view.window?.backingScaleFactor ?? 2.0
    let gridSize = renderer.gridSize(for: view.bounds.size, scale: scale)
    session.resize(cols: gridSize.cols, rows: gridSize.rows)
    metalView.setNeedsRedraw()
}
```

**Step 3: Handle cursor blinking**

Add a timer for cursor blink:
```swift
// In TerminalViewController:
private var cursorVisible = true
private var cursorTimer: Timer?

// In loadView, add:
cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
    self?.cursorVisible.toggle()
    self?.metalView.setNeedsRedraw()
}

// Pass cursorVisible to the renderer:
// In render(), pass it to renderer.draw()
```

**Step 4: Final verification**

Build and run. Verify:
- [ ] Glass window with blur effect appears
- [ ] Shell prompt is visible with correct colors
- [ ] Can type commands and see output
- [ ] Arrow keys, backspace, tab work
- [ ] Can scroll through output history
- [ ] Can select text with mouse drag
- [ ] Cmd+C copies selected text
- [ ] Cmd+V pastes from clipboard
- [ ] Cmd+Click opens URLs
- [ ] Cmd+Plus/Minus changes font size
- [ ] Window resize reflows terminal content
- [ ] Cursor blinks
- [ ] Menu bar has App, Edit, View menus
- [ ] Quit (Cmd+Q) works
- [ ] Programs like `vim`, `htop`, `less` render correctly

**Step 5: Commit**

```bash
git add -A
git commit -m "feat: add menu bar, font size controls, cursor blink, and polish"
```

---

## Post-Implementation Notes

### Known Limitations of v1
- No tabs or split panes
- No settings UI (all config is in code)
- No true ligature support (each cell is one character)
- No emoji rendering (would need RGBA atlas)
- No sixel/image protocol support
- Bold text uses the same font (not a bold variant)

### Next Steps (v2)
1. **Tabs** — Add NSTabView or custom tab bar
2. **Split panes** — NSSplitView with multiple TerminalViewControllers
3. **Command palette** — SwiftUI overlay with fuzzy search
4. **Settings UI** — SwiftUI preferences window
5. **Bold/italic fonts** — Load font variants, cache separately in atlas
6. **Emoji** — Separate RGBA texture atlas for color emoji
7. **Ligatures** — Use CTTypesetter for multi-character glyph shaping

### Debugging Tips
- **Metal GPU debugger**: In Xcode, use GPU Frame Capture to inspect draw calls and textures
- **Atlas visualization**: Temporarily render the atlas texture full-screen to debug glyph packing
- **Terminal debug**: Print `terminal.buffer` contents to Console to verify VT parsing
- **Performance**: Use Instruments > Metal System Trace to profile frame times
