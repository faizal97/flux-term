import AppKit

protocol TabBarViewDelegate: AnyObject {
    func tabBarDidSelectTab(at index: Int)
    func tabBarDidCloseTab(at index: Int)
    func tabBarDidRequestNewTab()
}

final class TabBarView: NSView {
    static let height: CGFloat = 28

    struct Tab {
        let title: String
    }

    weak var delegate: TabBarViewDelegate?

    var tabs: [Tab] = [] {
        didSet { needsDisplay = true }
    }

    var selectedIndex: Int = 0 {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }
    override var mouseDownCanMoveWindow: Bool { true }

    private let mantleColor = NSColor(red: 0.094, green: 0.094, blue: 0.145, alpha: 1.0)
    private let baseColor = NSColor(red: 0.118, green: 0.118, blue: 0.180, alpha: 1.0)
    private let surface0Color = NSColor(red: 0.192, green: 0.196, blue: 0.267, alpha: 1.0)
    private let textColor = NSColor(red: 0.804, green: 0.839, blue: 0.957, alpha: 1.0)
    private let subtext0Color = NSColor(red: 0.651, green: 0.678, blue: 0.784, alpha: 1.0)
    private let overlay0Color = NSColor(red: 0.424, green: 0.439, blue: 0.525, alpha: 1.0)
    private let redColor = NSColor(red: 0.953, green: 0.545, blue: 0.659, alpha: 1.0)

    private let tabMinWidth: CGFloat = 120
    private let tabMaxWidth: CGFloat = 200
    private let tabPadding: CGFloat = 12
    private let closeButtonSize: CGFloat = 12
    private let newTabButtonWidth: CGFloat = 28
    private let trafficLightInset: CGFloat = 76

    private var hoveredCloseButton: Int?
    private var trackingAreaRef: NSTrackingArea?

    private static let truncatingStyle: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        return style
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        mantleColor.setFill()
        bounds.fill()

        surface0Color.setFill()
        NSRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1).fill()

        guard !tabs.isEmpty else {
            drawNewTabButton(atX: trafficLightInset + 4)
            return
        }

        let width = calculateTabWidth()
        var x = trafficLightInset
        for (index, tab) in tabs.enumerated() {
            let isActive = index == selectedIndex
            let rect = NSRect(x: x, y: 0, width: width, height: bounds.height - 1)
            drawTab(tab, at: index, in: rect, isActive: isActive)
            x += width
        }

        drawNewTabButton(atX: x + 4)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if newTabButtonRect().contains(point) {
            delegate?.tabBarDidRequestNewTab()
            return
        }

        for index in tabs.indices {
            let tabRect = rectForTab(at: index)
            guard tabRect.contains(point) else { continue }

            if closeButtonHitRect(forTabAt: index).contains(point) {
                delegate?.tabBarDidCloseTab(at: index)
            } else {
                delegate?.tabBarDidSelectTab(at: index)
            }
            return
        }

        super.mouseDown(with: event)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaRef = trackingArea
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let hovered = tabs.indices.first(where: { closeButtonHitRect(forTabAt: $0).contains(point) })
        if hovered != hoveredCloseButton {
            hoveredCloseButton = hovered
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        if hoveredCloseButton != nil {
            hoveredCloseButton = nil
            needsDisplay = true
        }
    }

    private func drawTab(_ tab: Tab, at index: Int, in rect: NSRect, isActive: Bool) {
        if isActive {
            baseColor.setFill()
            rect.fill()
        }

        let closeRect = closeButtonRect(forTabAt: index)
        let titleRect = NSRect(
            x: rect.minX + tabPadding,
            y: 0,
            width: max(0, closeRect.minX - rect.minX - tabPadding * 2),
            height: rect.height
        )

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: isActive ? .medium : .regular),
            .foregroundColor: isActive ? textColor : subtext0Color,
            .paragraphStyle: Self.truncatingStyle
        ]

        NSString(string: tab.title).draw(
            in: titleRect.insetBy(dx: 0, dy: 7),
            withAttributes: attributes
        )

        let closePath = NSBezierPath()
        let inset: CGFloat = 3
        closePath.move(to: NSPoint(x: closeRect.minX + inset, y: closeRect.minY + inset))
        closePath.line(to: NSPoint(x: closeRect.maxX - inset, y: closeRect.maxY - inset))
        closePath.move(to: NSPoint(x: closeRect.maxX - inset, y: closeRect.minY + inset))
        closePath.line(to: NSPoint(x: closeRect.minX + inset, y: closeRect.maxY - inset))
        (hoveredCloseButton == index ? redColor : overlay0Color).setStroke()
        closePath.lineWidth = 1.5
        closePath.stroke()

        if !isActive && index < tabs.count - 1 && index + 1 != selectedIndex {
            surface0Color.setFill()
            NSRect(x: rect.maxX - 0.5, y: 6, width: 1, height: rect.height - 12).fill()
        }
    }

    private func drawNewTabButton(atX x: CGFloat) {
        let rect = NSRect(x: x, y: 0, width: newTabButtonWidth, height: bounds.height - 1)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .light),
            .foregroundColor: overlay0Color
        ]
        let label = NSString(string: "+")
        let size = label.size(withAttributes: attributes)
        let origin = NSPoint(
            x: rect.midX - size.width / 2,
            y: rect.midY - size.height / 2
        )
        label.draw(at: origin, withAttributes: attributes)
    }

    private func calculateTabWidth() -> CGFloat {
        guard !tabs.isEmpty else { return tabMinWidth }
        let available = max(0, bounds.width - trafficLightInset - newTabButtonWidth - 8)
        let perTab = available / CGFloat(tabs.count)
        return max(tabMinWidth, min(tabMaxWidth, perTab))
    }

    private func rectForTab(at index: Int) -> NSRect {
        let width = calculateTabWidth()
        return NSRect(
            x: trafficLightInset + CGFloat(index) * width,
            y: 0,
            width: width,
            height: bounds.height - 1
        )
    }

    private func closeButtonRect(forTabAt index: Int) -> NSRect {
        let rect = rectForTab(at: index)
        return NSRect(
            x: rect.maxX - tabPadding - closeButtonSize,
            y: (rect.height - closeButtonSize) / 2,
            width: closeButtonSize,
            height: closeButtonSize
        )
    }

    private func closeButtonHitRect(forTabAt index: Int) -> NSRect {
        closeButtonRect(forTabAt: index).insetBy(dx: -4, dy: -4)
    }

    private func newTabButtonRect() -> NSRect {
        let x = trafficLightInset + calculateTabWidth() * CGFloat(tabs.count) + 4
        return NSRect(x: x, y: 0, width: newTabButtonWidth, height: bounds.height - 1)
    }
}
