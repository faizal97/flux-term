import AppKit
import Metal
import QuartzCore

final class TerminalMetalView: NSView {
    weak var controller: TerminalViewController?

    private(set) var device: MTLDevice!
    private(set) var commandQueue: MTLCommandQueue!

    var metalLayer: CAMetalLayer {
        layer as! CAMetalLayer
    }

    private var needsRedraw = true

    override var wantsUpdateLayer: Bool { true }

    override func makeBackingLayer() -> CALayer {
        CAMetalLayer()
    }

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

        let createdDevice = MTLCreateSystemDefaultDevice()
        guard let createdDevice else {
            fatalError("Metal unavailable on this system")
        }
        device = createdDevice
        metalLayer.device = createdDevice
        metalLayer.pixelFormat = .bgra8Unorm
        metalLayer.framebufferOnly = true
        metalLayer.presentsWithTransaction = false
        metalLayer.isOpaque = true

        guard let queue = createdDevice.makeCommandQueue() else {
            fatalError("Failed to create Metal command queue")
        }
        commandQueue = queue

        updateDrawableSize()
    }

    private func updateDrawableSize() {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0
        metalLayer.contentsScale = scale
        metalLayer.drawableSize = CGSize(width: bounds.width * scale, height: bounds.height * scale)
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

    func setNeedsRedraw() {
        dispatchPrecondition(condition: .onQueue(.main))
        needsRedraw = true
    }

    func consumeNeedsRedraw() -> Bool {
        dispatchPrecondition(condition: .onQueue(.main))
        if needsRedraw {
            needsRedraw = false
            return true
        }
        return false
    }

    override var acceptsFirstResponder: Bool { true }
    override var mouseDownCanMoveWindow: Bool { false }

    override func becomeFirstResponder() -> Bool {
        true
    }

    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            let key = event.charactersIgnoringModifiers?.lowercased()
            if key == "c" {
                controller?.copy(self)
                return
            }
            if key == "v" {
                controller?.paste(self)
                return
            }
        }
        controller?.handleKeyDown(event)
    }

    override func insertText(_ insertString: Any) {
        insertText(insertString, replacementRange: NSRange(location: NSNotFound, length: 0))
    }

    func insertText(_ insertString: Any, replacementRange: NSRange) {
        if let text = insertString as? String {
            controller?.handleTextInput(text)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        controller?.handleScroll(event)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        controller?.handleMouseDown(event)
    }

    override func mouseDragged(with event: NSEvent) {
        controller?.handleMouseDragged(event)
    }

    override func mouseUp(with event: NSEvent) {
        controller?.handleMouseUp(event)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
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
}
