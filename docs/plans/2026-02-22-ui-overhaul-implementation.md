# FluxTerm UI Overhaul — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Transform FluxTerm's visual identity into a premium glass terminal with Catppuccin Mocha colors, smooth cursor animation, refined window chrome, and polished typography.

**Architecture:** Shader-first approach — all visual effects in the Metal pipeline. CPU manages animation state (cursor interpolation, blink phase) and passes to GPU via uniforms. No AppKit overlay layers.

**Tech Stack:** Swift 5.9+, Metal, AppKit, Core Text, SwiftTerm

---

### Task 1: Catppuccin Mocha Color Palette

**Files:**
- Modify: `Sources/FluxTerm/Terminal/TerminalConfig.swift:10-32`

**Step 1: Replace all color values in TerminalConfig**

Open `Sources/FluxTerm/Terminal/TerminalConfig.swift` and replace the color properties (lines 10-32):

```swift
var foregroundColor: SIMD4<Float> = SIMD4<Float>(0.804, 0.839, 0.957, 1.0)  // #CDD6F4
var backgroundColor: SIMD4<Float> = SIMD4<Float>(0.118, 0.118, 0.180, 1.0)  // #1E1E2E
var cursorColor: SIMD4<Float> = SIMD4<Float>(0.961, 0.878, 0.863, 0.90)     // #F5E0DC
var urlColor: SIMD4<Float> = SIMD4<Float>(0.537, 0.706, 0.980, 1.0)         // #89B4FA
var selectionColor: SIMD4<Float> = SIMD4<Float>(0.192, 0.196, 0.267, 0.70)  // #313244 @ 70%

var colors: [SIMD4<Float>] = [
    // Normal colors (0-7)
    SIMD4<Float>(0.271, 0.278, 0.353, 1.0),  // 0 black   #45475A
    SIMD4<Float>(0.953, 0.545, 0.659, 1.0),  // 1 red     #F38BA8
    SIMD4<Float>(0.651, 0.890, 0.631, 1.0),  // 2 green   #A6E3A1
    SIMD4<Float>(0.976, 0.886, 0.686, 1.0),  // 3 yellow  #F9E2AF
    SIMD4<Float>(0.537, 0.706, 0.980, 1.0),  // 4 blue    #89B4FA
    SIMD4<Float>(0.961, 0.761, 0.906, 1.0),  // 5 magenta #F5C2E7
    SIMD4<Float>(0.580, 0.886, 0.835, 1.0),  // 6 cyan    #94E2D5
    SIMD4<Float>(0.729, 0.761, 0.871, 1.0),  // 7 white   #BAC2DE
    // Bright colors (8-15)
    SIMD4<Float>(0.345, 0.357, 0.439, 1.0),  // 8  bright black   #585B70
    SIMD4<Float>(0.953, 0.545, 0.659, 1.0),  // 9  bright red     #F38BA8
    SIMD4<Float>(0.651, 0.890, 0.631, 1.0),  // 10 bright green   #A6E3A1
    SIMD4<Float>(0.976, 0.886, 0.686, 1.0),  // 11 bright yellow  #F9E2AF
    SIMD4<Float>(0.537, 0.706, 0.980, 1.0),  // 12 bright blue    #89B4FA
    SIMD4<Float>(0.796, 0.651, 0.969, 1.0),  // 13 bright magenta #CBA6F7 (Mauve)
    SIMD4<Float>(0.580, 0.886, 0.835, 1.0),  // 14 bright cyan    #94E2D5
    SIMD4<Float>(0.651, 0.678, 0.784, 1.0),  // 15 bright white   #A6ADC8
]
```

**Step 2: Build and run to verify colors render**

Run: `cd /Users/fayz/Code/Personal/personal-terminal && swift build 2>&1 | tail -5`
Expected: Build succeeds. Launch the app and verify the Catppuccin Mocha palette is visible.

**Step 3: Commit**

```bash
git add Sources/FluxTerm/Terminal/TerminalConfig.swift
git commit -m "style: switch to Catppuccin Mocha color palette"
```

---

### Task 2: Typography & Spacing Refinements

**Files:**
- Modify: `Sources/FluxTerm/Terminal/TerminalConfig.swift:5-8,34-48`

**Step 1: Update font configuration**

In `TerminalConfig.swift`, update the font and spacing properties:

```swift
var fontName: String = "JetBrainsMono-Regular"
var fontSize: CGFloat = 14.5
var backgroundOpacity: Float = 0.78
var padding: CGFloat = 14.0
var lineSpacingMultiplier: CGFloat = 1.15
```

**Step 2: Update the font fallback chain**

Replace the `font` computed property:

```swift
var font: CTFont {
    // Try JetBrains Mono first
    if let exact = NSFont(name: fontName, size: fontSize) {
        return exact as CTFont
    }
    // Fallback to MesloLGS NF (has Nerd Font icons)
    if let meslo = NSFont(name: "MesloLGS NF", size: fontSize) {
        return meslo as CTFont
    }
    // Fallback to Menlo (always available on macOS)
    if let menlo = NSFont(name: "Menlo", size: fontSize) {
        return menlo as CTFont
    }
    return CTFontCreateWithName("Menlo" as CFString, fontSize, nil)
}
```

**Step 3: Apply line spacing multiplier to cellSize**

Replace the `cellSize` computed property:

```swift
var cellSize: CGSize {
    let f = font
    let advance = glyphAdvance(for: "W", in: f)
    let lineHeight = CTFontGetAscent(f) + CTFontGetDescent(f) + CTFontGetLeading(f)
    return CGSize(
        width: max(1, advance),
        height: max(1, ceil(lineHeight * lineSpacingMultiplier))
    )
}
```

**Step 4: Build and verify**

Run: `cd /Users/fayz/Code/Personal/personal-terminal && swift build 2>&1 | tail -5`
Expected: Build succeeds. Font renders as JetBrains Mono (or falls back). Lines have more breathing room.

**Step 5: Commit**

```bash
git add Sources/FluxTerm/Terminal/TerminalConfig.swift
git commit -m "style: refine typography — JetBrains Mono, increased line spacing and padding"
```

---

### Task 3: Window Chrome Refinement

**Files:**
- Modify: `Sources/FluxTerm/UI/MainWindow.swift:6-35`

**Step 1: Update window configuration**

Replace the `MainWindow` convenience init to refine the glass material, window styling, and traffic light positioning:

```swift
convenience init() {
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 960, height: 640),
        styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
        backing: .buffered,
        defer: false
    )
    window.title = "FluxTerm"
    window.center()
    window.isReleasedWhenClosed = false
    window.titlebarAppearsTransparent = true
    window.titleVisibility = .hidden
    window.backgroundColor = .clear
    window.minSize = NSSize(width: 500, height: 320)
    window.isMovableByWindowBackground = true

    // Inset traffic light buttons
    if let closeButton = window.standardWindowButton(.closeButton) {
        closeButton.setFrameOrigin(NSPoint(x: 14, y: closeButton.frame.origin.y))
    }

    let visualEffectView = NSVisualEffectView(frame: window.contentLayoutRect)
    visualEffectView.autoresizingMask = [.width, .height]
    visualEffectView.material = .sidebar
    visualEffectView.blendingMode = .behindWindow
    visualEffectView.state = .active
    window.contentView = visualEffectView

    self.init(window: window)

    terminalVC = TerminalViewController()
    terminalVC.view.frame = visualEffectView.bounds
    terminalVC.view.autoresizingMask = [.width, .height]
    visualEffectView.addSubview(terminalVC.view)
    terminalVC.metalView.controller = terminalVC
}
```

Key changes:
- Added `.fullSizeContentView` to style mask (content extends behind titlebar)
- Switched material from `.hudWindow` to `.sidebar` (warmer, slightly more translucent)
- Added `isMovableByWindowBackground = true` (drag window from anywhere)
- Inset traffic light buttons to `x: 14`

**Step 2: Build and verify**

Run: `cd /Users/fayz/Code/Personal/personal-terminal && swift build 2>&1 | tail -5`
Expected: Build succeeds. Window has refined glass appearance with warmer blur.

**Step 3: Commit**

```bash
git add Sources/FluxTerm/UI/MainWindow.swift
git commit -m "style: refine window chrome — sidebar material, fullSizeContentView, inset traffic lights"
```

---

### Task 4: Smooth Cursor Blink (Sinusoidal Fade)

**Files:**
- Modify: `Sources/FluxTerm/Terminal/TerminalViewController.swift:17-19,100-106,108-133,415-419`

**Step 1: Add animation state properties**

In `TerminalViewController`, replace the cursor-related properties:

```swift
// Replace these:
//   private var cursorVisible = true
//   private var cursorTimer: Timer?
// With:
private var cursorBlinkPhase: Float = 0.0
private var cursorBlinkTimer: Timer?
private var lastCursorActivity: Date = Date()
private let cursorBlinkPeriod: TimeInterval = 1.0  // Full cycle duration
private let cursorIdleDelay: TimeInterval = 0.5     // Delay before blinking starts
```

**Step 2: Replace setupCursorTimer**

```swift
private func setupCursorTimer() {
    cursorBlinkTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
        guard let self else { return }
        let elapsed = Date().timeIntervalSince(self.lastCursorActivity)
        if elapsed < self.cursorIdleDelay {
            // Cursor recently active — fully visible
            self.cursorBlinkPhase = 0.0
        } else {
            // Advance blink phase
            let blinkElapsed = elapsed - self.cursorIdleDelay
            self.cursorBlinkPhase = Float(blinkElapsed.truncatingRemainder(dividingBy: self.cursorBlinkPeriod) / self.cursorBlinkPeriod) * 2.0 * .pi
        }
        self.metalView.setNeedsRedraw()
    }
}
```

**Step 3: Compute cursor opacity and pass to renderer**

In the `render()` method, compute cursor opacity from the blink phase and pass it. Replace the `renderer.draw(...)` call:

```swift
// Compute cursor opacity: smooth sinusoidal fade
// cos(0) = 1.0 (fully visible), cos(pi) = -1.0 (invisible)
let cursorOpacity = 0.5 + 0.5 * cos(cursorBlinkPhase)

renderer.draw(
    terminal: session.terminal,
    drawable: drawable,
    scale: Float(view.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0),
    isSelected: { [weak self] col, row in
        self?.isSelected(col: col, row: row) ?? false
    },
    isURLCell: { [weak self] col, row in
        guard let self else { return false }
        return URLDetector.urlAt(col: col, row: row, in: self.detectedURLs) != nil
    },
    isHoveredURLCell: { [weak self] col, row in
        guard let hovered = self?.hoveredURL else { return false }
        return hovered.row == row && col >= hovered.startCol && col <= hovered.endCol
    },
    cursorVisible: true,
    cursorOpacity: cursorOpacity
)
```

**Step 4: Replace resetCursorBlinkCycle**

```swift
private func resetCursorBlinkCycle() {
    lastCursorActivity = Date()
    cursorBlinkPhase = 0.0
    metalView.setNeedsRedraw()
}
```

**Step 5: Update deinit**

Replace `cursorTimer?.invalidate()` with `cursorBlinkTimer?.invalidate()` in `deinit`.

**Step 6: Update MetalRenderer.draw() signature to accept cursorOpacity**

In `MetalRenderer.swift`, update the `draw` method signature:

```swift
func draw(
    terminal: Terminal,
    drawable: CAMetalDrawable,
    scale: Float,
    isSelected: ((Int, Int) -> Bool)? = nil,
    isURLCell: ((Int, Int) -> Bool)? = nil,
    isHoveredURLCell: ((Int, Int) -> Bool)? = nil,
    cursorVisible: Bool = true,
    cursorOpacity: Float = 1.0
) {
```

And in the cursor rendering section (around line 222-232), apply opacity to cursor color:

```swift
if cursorVisible {
    let (x, y) = terminal.getCursorLocation()
    var cursorColor = config.cursorColor
    cursorColor.w *= cursorOpacity  // Apply smooth blink opacity
    var cursorUniforms = CursorUniforms(
        viewportSize: uniforms.viewportSize,
        cellSize: uniforms.cellSize,
        gridOrigin: uniforms.gridOrigin,
        cursorPos: SIMD2(Float(x), Float(y)),
        cursorColor: cursorColor
    )
    enc.setRenderPipelineState(cursorPipeline)
    enc.setVertexBytes(&cursorUniforms, length: MemoryLayout<CursorUniforms>.size, index: 0)
    enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
}
```

**Step 7: Build and verify**

Run: `cd /Users/fayz/Code/Personal/personal-terminal && swift build 2>&1 | tail -5`
Expected: Build succeeds. Cursor smoothly fades in and out instead of blinking hard.

**Step 8: Commit**

```bash
git add Sources/FluxTerm/Terminal/TerminalViewController.swift Sources/FluxTerm/Renderer/MetalRenderer.swift
git commit -m "feat: smooth sinusoidal cursor blink animation"
```

---

### Task 5: Smooth Cursor Position Animation

**Files:**
- Modify: `Sources/FluxTerm/Terminal/TerminalViewController.swift`
- Modify: `Sources/FluxTerm/Renderer/MetalRenderer.swift`

**Step 1: Add cursor interpolation state to TerminalViewController**

Add these properties alongside the existing cursor properties:

```swift
private var displayCursorPos: SIMD2<Float> = .zero
private var targetCursorPos: SIMD2<Float> = .zero
private var cursorAnimationStartPos: SIMD2<Float> = .zero
private var cursorAnimationStartTime: TimeInterval = 0
private let cursorAnimationDuration: TimeInterval = 0.10  // 100ms ease-out
```

**Step 2: Add cursor position interpolation method**

```swift
private func interpolatedCursorPos() -> SIMD2<Float> {
    let now = CACurrentMediaTime()
    let elapsed = now - cursorAnimationStartTime
    let t = min(1.0, elapsed / cursorAnimationDuration)
    // Ease-out: 1 - (1 - t)^3
    let eased = Float(1.0 - pow(1.0 - t, 3))
    return cursorAnimationStartPos + (targetCursorPos - cursorAnimationStartPos) * eased
}
```

**Step 3: Update render() to use interpolated cursor position**

In the `render()` method, before calling `renderer.draw()`, get the current cursor position from the terminal, update animation state if target changed, and compute the interpolated position:

```swift
private func render() {
    guard !isRendering else { return }
    guard metalView.consumeNeedsRedraw() else { return }
    guard let drawable = metalView.metalLayer.nextDrawable() else { return }

    isRendering = true
    defer { isRendering = false }

    // Update cursor animation target
    let (cx, cy) = session.terminal.getCursorLocation()
    let newTarget = SIMD2<Float>(Float(cx), Float(cy))
    if newTarget != targetCursorPos {
        cursorAnimationStartPos = displayCursorPos
        cursorAnimationStartTime = CACurrentMediaTime()
        targetCursorPos = newTarget
    }
    displayCursorPos = interpolatedCursorPos()

    // Keep redrawing while cursor is animating
    let animating = CACurrentMediaTime() - cursorAnimationStartTime < cursorAnimationDuration
    if animating {
        metalView.setNeedsRedraw()
    }

    let cursorOpacity = 0.5 + 0.5 * cos(cursorBlinkPhase)

    renderer.draw(
        terminal: session.terminal,
        drawable: drawable,
        scale: Float(view.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0),
        isSelected: { [weak self] col, row in
            self?.isSelected(col: col, row: row) ?? false
        },
        isURLCell: { [weak self] col, row in
            guard let self else { return false }
            return URLDetector.urlAt(col: col, row: row, in: self.detectedURLs) != nil
        },
        isHoveredURLCell: { [weak self] col, row in
            guard let hovered = self?.hoveredURL else { return false }
            return hovered.row == row && col >= hovered.startCol && col <= hovered.endCol
        },
        cursorVisible: true,
        cursorOpacity: cursorOpacity,
        cursorDisplayPos: displayCursorPos
    )
}
```

**Step 4: Update MetalRenderer.draw() to accept cursorDisplayPos**

Add `cursorDisplayPos: SIMD2<Float> = .zero` parameter and use it instead of `terminal.getCursorLocation()`:

```swift
func draw(
    terminal: Terminal,
    drawable: CAMetalDrawable,
    scale: Float,
    isSelected: ((Int, Int) -> Bool)? = nil,
    isURLCell: ((Int, Int) -> Bool)? = nil,
    isHoveredURLCell: ((Int, Int) -> Bool)? = nil,
    cursorVisible: Bool = true,
    cursorOpacity: Float = 1.0,
    cursorDisplayPos: SIMD2<Float> = .zero
) {
```

In the cursor rendering section, use `cursorDisplayPos` instead of getting from terminal:

```swift
if cursorVisible {
    var cursorColor = config.cursorColor
    cursorColor.w *= cursorOpacity
    var cursorUniforms = CursorUniforms(
        viewportSize: uniforms.viewportSize,
        cellSize: uniforms.cellSize,
        gridOrigin: uniforms.gridOrigin,
        cursorPos: cursorDisplayPos,
        cursorColor: cursorColor
    )
    enc.setRenderPipelineState(cursorPipeline)
    enc.setVertexBytes(&cursorUniforms, length: MemoryLayout<CursorUniforms>.size, index: 0)
    enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
}
```

**Step 5: Build and verify**

Run: `cd /Users/fayz/Code/Personal/personal-terminal && swift build 2>&1 | tail -5`
Expected: Build succeeds. Cursor glides smoothly between positions with ease-out timing.

**Step 6: Commit**

```bash
git add Sources/FluxTerm/Terminal/TerminalViewController.swift Sources/FluxTerm/Renderer/MetalRenderer.swift
git commit -m "feat: smooth cursor position animation with ease-out interpolation"
```

---

### Task 6: Cursor Glow/Bloom Effect

**Files:**
- Modify: `Sources/FluxTerm/Renderer/Shaders.metal`
- Modify: `Sources/FluxTerm/Renderer/ShaderTypes.swift`
- Modify: `Sources/FluxTerm/Renderer/MetalRenderer.swift`

**Step 1: Add bloom shader functions to Shaders.metal**

Add these shader functions after the existing cursor shaders:

```metal
// Cursor bloom/glow effect
struct BloomOut {
    float4 position [[position]];
    float2 uv;  // -1 to 1 within bloom quad
    float4 color;
};

vertex BloomOut cursor_bloom_vertex(
    uint vid [[vertex_id]],
    constant CursorUniforms &u [[buffer(0)]]
) {
    float2 unit;
    unit.x = (vid & 1) == 0 ? 0.0 : 1.0;
    unit.y = (vid & 2) == 0 ? 0.0 : 1.0;

    // Bloom extends 4px beyond cursor in each direction
    float bloomPad = 4.0;
    float2 bloomOrigin = u.gridOrigin + u.cursorPos * u.cellSize - bloomPad;
    float2 bloomSize = u.cellSize + bloomPad * 2.0;
    float2 pixel = bloomOrigin + unit * bloomSize;

    float2 ndc;
    ndc.x = (pixel.x / u.viewportSize.x) * 2.0 - 1.0;
    ndc.y = 1.0 - (pixel.y / u.viewportSize.y) * 2.0;

    BloomOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.uv = unit * 2.0 - 1.0;  // Map to -1..1
    out.color = u.cursorColor;
    return out;
}

fragment float4 cursor_bloom_fragment(BloomOut in [[stage_in]]) {
    // Gaussian-ish falloff from center
    float dist = length(in.uv);
    float glow = exp(-dist * dist * 2.5);
    return float4(in.color.rgb, in.color.a * glow * 0.15);
}
```

**Step 2: Add bloom pipeline in MetalRenderer**

Add a new pipeline property:

```swift
private var cursorBloomPipeline: MTLRenderPipelineState!
```

In `buildPipelines()`, after the cursor pipeline setup, add:

```swift
let bloomDesc = MTLRenderPipelineDescriptor()
bloomDesc.vertexFunction = library.makeFunction(name: "cursor_bloom_vertex")
bloomDesc.fragmentFunction = library.makeFunction(name: "cursor_bloom_fragment")
let bloomColorAttachment = bloomDesc.colorAttachments[0]!
bloomColorAttachment.pixelFormat = .bgra8Unorm
bloomColorAttachment.isBlendingEnabled = true
bloomColorAttachment.sourceRGBBlendFactor = .sourceAlpha
bloomColorAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
bloomColorAttachment.rgbBlendOperation = .add
bloomColorAttachment.sourceAlphaBlendFactor = .one
bloomColorAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
bloomColorAttachment.alphaBlendOperation = .add
cursorBloomPipeline = try! device.makeRenderPipelineState(descriptor: bloomDesc)
```

**Step 3: Draw bloom before cursor in the draw() method**

In `MetalRenderer.draw()`, just before the cursor draw call, add the bloom draw:

```swift
if cursorVisible {
    var cursorColor = config.cursorColor
    cursorColor.w *= cursorOpacity

    // Draw bloom first (behind cursor)
    var bloomUniforms = CursorUniforms(
        viewportSize: uniforms.viewportSize,
        cellSize: uniforms.cellSize,
        gridOrigin: uniforms.gridOrigin,
        cursorPos: cursorDisplayPos,
        cursorColor: cursorColor
    )
    enc.setRenderPipelineState(cursorBloomPipeline)
    enc.setVertexBytes(&bloomUniforms, length: MemoryLayout<CursorUniforms>.size, index: 0)
    enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

    // Draw cursor on top
    var cursorUniforms = CursorUniforms(
        viewportSize: uniforms.viewportSize,
        cellSize: uniforms.cellSize,
        gridOrigin: uniforms.gridOrigin,
        cursorPos: cursorDisplayPos,
        cursorColor: cursorColor
    )
    enc.setRenderPipelineState(cursorPipeline)
    enc.setVertexBytes(&cursorUniforms, length: MemoryLayout<CursorUniforms>.size, index: 0)
    enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
}
```

**Step 4: Build and verify**

Run: `cd /Users/fayz/Code/Personal/personal-terminal && swift build 2>&1 | tail -5`
Expected: Build succeeds. Cursor has a subtle warm glow around it that fades with the blink.

**Step 5: Commit**

```bash
git add Sources/FluxTerm/Renderer/Shaders.metal Sources/FluxTerm/Renderer/MetalRenderer.swift
git commit -m "feat: subtle cursor bloom/glow effect via Metal shader"
```

---

### Task 7: Selection Highlight Refinement

**Files:**
- Modify: `Sources/FluxTerm/Renderer/MetalRenderer.swift:298-304`
- Modify: `Sources/FluxTerm/Terminal/TerminalConfig.swift` (already has selectionColor from Task 1)

**Step 1: Change selection rendering from color-inversion to overlay**

In `MetalRenderer.buildInstances()`, replace the selection block (around lines 298-304):

```swift
// Old: color inversion for selection
// if isSelected?(col, row) == true {
//     let tmp = instance.fgColor
//     instance.fgColor = instance.bgColor
//     instance.fgColor.w = 1.0
//     instance.bgColor = tmp
//     instance.bgColor.w = 1.0
// }

// New: distinct selection background, preserve foreground
if isSelected?(col, row) == true {
    instance.bgColor = config.selectionColor
}
```

This gives selections a distinct muted background instead of harsh color inversion.

**Step 2: Build and verify**

Run: `cd /Users/fayz/Code/Personal/personal-terminal && swift build 2>&1 | tail -5`
Expected: Build succeeds. Text selection shows a subtle surface-colored background instead of inverting colors.

**Step 3: Commit**

```bash
git add Sources/FluxTerm/Renderer/MetalRenderer.swift
git commit -m "style: refined selection highlight with distinct background instead of inversion"
```

---

### Task 8: URL Hover Underline

**Files:**
- Modify: `Sources/FluxTerm/Renderer/Shaders.metal`
- Modify: `Sources/FluxTerm/Renderer/ShaderTypes.swift`
- Modify: `Sources/FluxTerm/Renderer/MetalRenderer.swift`

**Step 1: Add underline flag to CellInstance**

In `ShaderTypes.swift`, add a flags field:

```swift
struct CellInstance {
    var gridPos: SIMD2<Float> = .zero
    var glyphUV: SIMD4<Float> = .zero
    var glyphBearing: SIMD2<Float> = .zero
    var glyphSize: SIMD2<Float> = .zero
    var fgColor: SIMD4<Float> = .init(1, 1, 1, 1)
    var bgColor: SIMD4<Float> = .init(0, 0, 0, 0)
    var flags: SIMD4<Float> = .zero  // x: underline (0 or 1), y-w: reserved
}
```

Update the matching struct in `Shaders.metal`:

```metal
struct CellInstance {
    float2 gridPos;
    float4 glyphUV;
    float2 glyphBearing;
    float2 glyphSize;
    float4 fgColor;
    float4 bgColor;
    float4 flags;  // x: underline (0 or 1)
};
```

**Step 2: Add underline rendering in the background shader**

Update `bg_vertex` and `bg_fragment` to pass through the underline flag and the foreground color for the underline:

```metal
struct BgOut {
    float4 position [[position]];
    float4 color;
    float4 fgColor;
    float2 cellUV;  // 0-1 within cell
    float underline;
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
    out.fgColor = cell.fgColor;
    out.cellUV = unit;
    out.underline = cell.flags.x;
    return out;
}

fragment float4 bg_fragment(BgOut in [[stage_in]]) {
    float4 color = in.color;
    // Draw underline at bottom 1px of cell
    if (in.underline > 0.5 && in.cellUV.y > 0.92) {
        color = float4(in.fgColor.rgb, 1.0);
    }
    return color;
}
```

**Step 3: Set underline flag for hovered URL cells in MetalRenderer**

In `buildInstances()`, in the hovered URL section, set the flag:

```swift
if isHoveredURLCell?(col, row) == true {
    instance.fgColor = config.urlColor
    instance.flags.x = 1.0  // Enable underline
}
```

Also simplify the URL cell handling — non-hovered URLs just get the color, no brightness bump:

```swift
if isURLCell?(col, row) == true {
    instance.fgColor = config.urlColor
}
if isHoveredURLCell?(col, row) == true {
    instance.fgColor = config.urlColor
    instance.flags.x = 1.0  // Enable underline
}
```

**Step 4: Build and verify**

Run: `cd /Users/fayz/Code/Personal/personal-terminal && swift build 2>&1 | tail -5`
Expected: Build succeeds. Hovering over URLs shows an underline decoration.

**Step 5: Commit**

```bash
git add Sources/FluxTerm/Renderer/Shaders.metal Sources/FluxTerm/Renderer/ShaderTypes.swift Sources/FluxTerm/Renderer/MetalRenderer.swift
git commit -m "feat: URL hover underline decoration via shader flags"
```

---

### Task 9: Final Polish & Integration Testing

**Files:**
- All modified files from previous tasks

**Step 1: Full clean build**

Run: `cd /Users/fayz/Code/Personal/personal-terminal && swift build -c release 2>&1 | tail -10`
Expected: Release build succeeds with no warnings.

**Step 2: Verify all visual elements work together**

Launch the app and verify:
- [ ] Catppuccin Mocha colors render correctly
- [ ] JetBrains Mono font renders (or clean fallback to Menlo)
- [ ] Increased padding and line spacing look right
- [ ] Glass window effect with sidebar material
- [ ] Cursor glides smoothly between positions
- [ ] Cursor blink is smooth sinusoidal fade
- [ ] Cursor has subtle bloom/glow
- [ ] Text selection shows Surface0 background (not inversion)
- [ ] URL hover shows underline
- [ ] Copy/paste still works
- [ ] Scroll still works
- [ ] Window resize reflows correctly
- [ ] Font size Cmd+/- still works

**Step 3: Commit any final adjustments**

```bash
git add -A
git commit -m "style: final polish for UI overhaul"
```
