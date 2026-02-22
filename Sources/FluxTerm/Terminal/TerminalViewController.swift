import AppKit
import CoreVideo
import QuartzCore
import SwiftTerm

final class TerminalViewController: NSViewController, TerminalSessionDelegate {
    struct CellPosition {
        var col: Int
        var row: Int
    }

    var metalView: TerminalMetalView!
    var renderer: MetalRenderer!
    var session: TerminalSession!
    var config = TerminalConfig()
    // Visible for testing: lets KeyInputPipelineTests intercept handleKeyDown bytes.
    var inputInterceptor: (([UInt8]) -> Void)?

    private var displayLink: CVDisplayLink?
    private var isRendering = false
    private var cursorBlinkPhase: Float = 0.0
    private var cursorBlinkTimer: Timer?
    private var lastCursorActivity: Date = Date()
    private let cursorBlinkPeriod: TimeInterval = 1.0
    private let cursorIdleDelay: TimeInterval = 0.5

    private var displayCursorPos: SIMD2<Float> = .zero
    private var targetCursorPos: SIMD2<Float> = .zero
    private var cursorAnimationStartPos: SIMD2<Float> = .zero
    private var cursorAnimationStartTime: TimeInterval = 0
    private let cursorAnimationDuration: TimeInterval = 0.10

    private var lastGrid: (cols: Int, rows: Int)?
    private var scrollBottomYDisp: Int = 0

    // Visible for testing: selection assertions in KeyInputPipelineTests.
    var selectionStart: CellPosition?
    var selectionEnd: CellPosition?

    private var detectedURLs: [DetectedURL] = []
    private var hoveredURL: DetectedURL?
    private var urlRefreshWorkItem: DispatchWorkItem?

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 960, height: 640))
        view = root

        metalView = TerminalMetalView(frame: root.bounds)
        metalView.autoresizingMask = [.width, .height]
        root.addSubview(metalView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        renderer = MetalRenderer(device: metalView.device, commandQueue: metalView.commandQueue, config: config)

        let grid = renderer.gridSize(for: view.bounds.size)
        lastGrid = grid

        session = TerminalSession(cols: grid.cols, rows: grid.rows)
        session.delegate = self
        session.start()
        let (cursorX, cursorY) = session.terminal.getCursorLocation()
        let initialCursorPos = SIMD2<Float>(Float(cursorX), Float(cursorY))
        displayCursorPos = initialCursorPos
        targetCursorPos = initialCursorPos
        cursorAnimationStartPos = initialCursorPos
        cursorAnimationStartTime = CACurrentMediaTime() - cursorAnimationDuration

        scrollBottomYDisp = session.terminal.getTopVisibleRow()
        refreshURLs()

        setupDisplayLink()
        setupCursorTimer()
        metalView?.setNeedsRedraw()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(metalView)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        resizeTerminalIfNeeded()
    }

    private func resizeTerminalIfNeeded() {
        guard renderer != nil, session != nil else { return }
        let grid = renderer.gridSize(for: view.bounds.size)
        if lastGrid?.cols == grid.cols && lastGrid?.rows == grid.rows {
            return
        }
        lastGrid = grid
        session.resize(cols: grid.cols, rows: grid.rows)
        scrollBottomYDisp = session.terminal.getTopVisibleRow()
        refreshURLs()
        metalView?.setNeedsRedraw()
    }

    private func setupDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let displayLink else { return }

        let context = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(displayLink, { _, _, _, _, _, userInfo in
            guard let userInfo else { return kCVReturnSuccess }
            let controller = Unmanaged<TerminalViewController>.fromOpaque(userInfo).takeUnretainedValue()
            DispatchQueue.main.async {
                controller.render()
            }
            return kCVReturnSuccess
        }, context)

        CVDisplayLinkStart(displayLink)
    }

    private func setupCursorTimer() {
        cursorBlinkTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let elapsed = Date().timeIntervalSince(self.lastCursorActivity)
            if elapsed < self.cursorIdleDelay {
                if self.cursorBlinkPhase != 0.0 {
                    self.cursorBlinkPhase = 0.0
                    self.metalView?.setNeedsRedraw()
                }
            } else {
                let blinkElapsed = elapsed - self.cursorIdleDelay
                let cyclePosition = blinkElapsed.truncatingRemainder(dividingBy: self.cursorBlinkPeriod) / self.cursorBlinkPeriod
                let newPhase = Float(cyclePosition) * 2.0 * .pi
                if newPhase != self.cursorBlinkPhase {
                    self.cursorBlinkPhase = newPhase
                    self.metalView?.setNeedsRedraw()
                }
            }
        }
    }

    private func render() {
        guard !isRendering else { return }
        guard metalView.consumeNeedsRedraw() else { return }
        guard let drawable = metalView.metalLayer.nextDrawable() else { return }

        isRendering = true
        defer { isRendering = false }

        // Update cursor animation target.
        let (cx, cy) = session.terminal.getCursorLocation()
        let newTarget = SIMD2<Float>(Float(cx), Float(cy))
        if newTarget != targetCursorPos {
            cursorAnimationStartPos = displayCursorPos
            cursorAnimationStartTime = CACurrentMediaTime()
            targetCursorPos = newTarget
        }
        displayCursorPos = interpolatedCursorPos()

        // Keep redrawing while cursor is animating.
        let animating = CACurrentMediaTime() - cursorAnimationStartTime < cursorAnimationDuration
        if animating {
            metalView?.setNeedsRedraw()
        }

        let cursorOpacity = 0.5 + 0.5 * cos(cursorBlinkPhase)

        renderer.draw(
            terminal: session.terminal,
            drawable: drawable,
            scale: Float(view.window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2.0),
            isSelected: { [weak self] col, row in
                guard let self else { return false }
                let bufferRow = self.bufferRow(for: row)
                return self.isSelected(col: col, row: bufferRow)
            },
            isURLCell: { [weak self] col, row in
                guard let self else { return false }
                let bufferRow = self.bufferRow(for: row)
                return URLDetector.urlAt(col: col, row: bufferRow, in: self.detectedURLs) != nil
            },
            isHoveredURLCell: { [weak self] col, row in
                guard let self, let hovered = self.hoveredURL else { return false }
                let bufferRow = self.bufferRow(for: row)
                return hovered.row == bufferRow && col >= hovered.startCol && col <= hovered.endCol
            },
            cursorVisible: true,
            cursorOpacity: cursorOpacity,
            cursorDisplayPos: displayCursorPos
        )
    }

    private func interpolatedCursorPos() -> SIMD2<Float> {
        let now = CACurrentMediaTime()
        let elapsed = now - cursorAnimationStartTime
        let t = min(1.0, elapsed / cursorAnimationDuration)
        // Ease-out curve for a quick settle.
        let eased = Float(1.0 - pow(1.0 - t, 3))
        return cursorAnimationStartPos + (targetCursorPos - cursorAnimationStartPos) * eased
    }

    func handleKeyDown(_ event: NSEvent) {
        if selectionStart != nil || selectionEnd != nil {
            selectionStart = nil
            selectionEnd = nil
            metalView?.setNeedsRedraw()
        }
        let bytes = encodeKey(event)
        if !bytes.isEmpty {
            resetCursorBlinkCycle()
            if let interceptor = inputInterceptor {
                interceptor(bytes)
            } else {
                session.sendInput(bytes[...])
            }
        }
    }

    func handleTextInput(_ text: String) {
        guard !text.isEmpty else { return }
        if selectionStart != nil || selectionEnd != nil {
            selectionStart = nil
            selectionEnd = nil
            metalView?.setNeedsRedraw()
        }
        resetCursorBlinkCycle()
        session.sendInput(text)
    }

    private func encodeKey(_ event: NSEvent) -> [UInt8] {
        KeyEncoder.encode(
            keyCode: event.keyCode,
            modifiers: event.modifierFlags,
            characters: event.characters,
            charactersIgnoringModifiers: event.charactersIgnoringModifiers
        )
    }

    func handleScroll(_ event: NSEvent) {
        let magnitude = max(1, Int(abs(event.scrollingDeltaY)))
        let current = min(session.terminal.buffer.yDisp, scrollBottomYDisp)
        if session.terminal.buffer.yDisp != current {
            session.terminal.buffer.yDisp = current
        }
        let proposed: Int

        if event.scrollingDeltaY > 0 {
            proposed = max(0, current - magnitude)
        } else {
            proposed = min(scrollBottomYDisp, current + magnitude)
        }

        if proposed != current {
            session.terminal.buffer.yDisp = proposed
            refreshURLs()
            metalView?.setNeedsRedraw()
        }
    }

    func handleMouseDown(_ event: NSEvent) {
        if event.modifierFlags.contains(.command) {
            let pos = cellPosition(from: event)
            if let hit = URLDetector.urlAt(col: pos.col, row: pos.row, in: detectedURLs) {
                NSWorkspace.shared.open(hit.url)
                return
            }
        }

        let pos = cellPosition(from: event)
        selectionStart = pos
        selectionEnd = pos
        metalView?.setNeedsRedraw()
    }

    func handleMouseDragged(_ event: NSEvent) {
        selectionEnd = cellPosition(from: event)
        metalView?.setNeedsRedraw()
    }

    func handleMouseUp(_ event: NSEvent) {
        selectionEnd = cellPosition(from: event)
        metalView?.setNeedsRedraw()
    }

    func handleMouseMoved(_ event: NSEvent) {
        let pos = cellPosition(from: event)
        let hit = URLDetector.urlAt(col: pos.col, row: pos.row, in: detectedURLs)
        hoveredURL = hit
        if hit != nil {
            NSCursor.pointingHand.set()
        } else {
            NSCursor.iBeam.set()
        }
        metalView?.setNeedsRedraw()
    }

    private func cellPosition(from event: NSEvent) -> CellPosition {
        let point = metalView.convert(event.locationInWindow, from: nil)
        let padding = Float(config.padding)

        let col = Int((Float(point.x) - padding) / max(1, renderer.cellWidth))

        let viewHeightPoints = Float(metalView.bounds.height)
        let yFromTop = viewHeightPoints - Float(point.y) - padding
        let viewportRow = Int(yFromTop / max(1, renderer.cellHeight))
        let clampedViewportRow = max(0, min(viewportRow, session.terminal.rows - 1))

        return CellPosition(
            col: max(0, min(col, session.terminal.cols - 1)),
            row: bufferRow(for: clampedViewportRow)
        )
    }

    func bufferRow(for viewportRow: Int) -> Int {
        session.terminal.buffer.yDisp + viewportRow
    }

    private func normalizeSelection(start: CellPosition, end: CellPosition) -> (Int, Int, Int, Int) {
        if start.row < end.row || (start.row == end.row && start.col <= end.col) {
            return (start.row, start.col, end.row, end.col)
        }
        return (end.row, end.col, start.row, start.col)
    }

    func isSelected(col: Int, row: Int) -> Bool {
        guard let start = selectionStart, let end = selectionEnd else { return false }
        let (startRow, startCol, endRow, endCol) = normalizeSelection(start: start, end: end)

        if row < startRow || row > endRow {
            return false
        }
        if row == startRow && row == endRow {
            return col >= startCol && col <= endCol
        }
        if row == startRow {
            return col >= startCol
        }
        if row == endRow {
            return col <= endCol
        }
        return true
    }

    func getSelectedText() -> String? {
        guard let start = selectionStart, let end = selectionEnd else { return nil }
        let (startRow, startCol, endRow, endCol) = normalizeSelection(start: start, end: end)

        var output = ""
        for row in startRow...endRow {
            guard let line = session.terminal.getScrollInvariantLine(row: row) else { continue }
            let c0 = row == startRow ? startCol : 0
            let c1 = row == endRow ? endCol : session.terminal.cols - 1

            if c0 <= c1 {
                for col in c0...c1 {
                    let charData = line[col]
                    let char = session.terminal.getCharacter(for: charData)
                    if char != "\0" {
                        output.append(char)
                    }
                }
            }

            if row < endRow {
                output.append("\n")
            }
        }

        return output.isEmpty ? nil : output
    }

    private func refreshURLs() {
        detectedURLs = URLDetector.detectURLs(in: session.terminal)
        if let hovered = hoveredURL {
            hoveredURL = URLDetector.urlAt(col: hovered.startCol, row: hovered.row, in: detectedURLs)
        }
    }

    private func scheduleURLRefresh(delay: TimeInterval = 0.05) {
        urlRefreshWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.refreshURLs()
            self?.metalView?.setNeedsRedraw()
        }
        urlRefreshWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    func terminalSession(_ session: TerminalSession, didReceiveData data: ArraySlice<UInt8>) {
        scrollBottomYDisp = session.terminal.getTopVisibleRow()
        session.terminal.buffer.yDisp = scrollBottomYDisp
        scheduleURLRefresh()
        metalView?.setNeedsRedraw()
    }

    func terminalSession(_ session: TerminalSession, didScrollTo yDisp: Int) {
        scrollBottomYDisp = yDisp
    }

    func terminalSessionBufferActivated(_ session: TerminalSession) {
        scrollBottomYDisp = session.terminal.getTopVisibleRow()
        session.terminal.buffer.yDisp = scrollBottomYDisp
        refreshURLs()
        metalView?.setNeedsRedraw()
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

    @objc func copy(_ sender: Any?) {
        guard let text = getSelectedText() else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        selectionStart = nil
        selectionEnd = nil
        metalView?.setNeedsRedraw()
    }

    @objc func paste(_ sender: Any?) {
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        resetCursorBlinkCycle()
        let payload = encodedPastePayload(for: text)
        session.sendInput(payload[...])
    }

    func encodedPastePayload(for text: String) -> [UInt8] {
        guard !session.terminal.bracketedPasteMode else {
            var payload: [UInt8] = []
            payload.reserveCapacity(
                EscapeSequences.bracketedPasteStart.count +
                text.utf8.count +
                EscapeSequences.bracketedPasteEnd.count
            )
            payload.append(contentsOf: EscapeSequences.bracketedPasteStart)
            payload.append(contentsOf: text.utf8)
            payload.append(contentsOf: EscapeSequences.bracketedPasteEnd)
            return payload
        }

        return Array(text.utf8)
    }

    @objc override func selectAll(_ sender: Any?) {
        let topVisibleRow = session.terminal.getTopVisibleRow()
        selectionStart = CellPosition(col: 0, row: topVisibleRow)
        selectionEnd = CellPosition(col: session.terminal.cols - 1, row: topVisibleRow + session.terminal.rows - 1)
        metalView?.setNeedsRedraw()
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
        scrollBottomYDisp = session.terminal.getTopVisibleRow()
        resizeTerminalIfNeeded()
        metalView?.setNeedsRedraw()
    }

    private func resetCursorBlinkCycle() {
        lastCursorActivity = Date()
        cursorBlinkPhase = 0.0
        metalView?.setNeedsRedraw()
    }

    deinit {
        urlRefreshWorkItem?.cancel()
        cursorBlinkTimer?.invalidate()
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }
    }
}
