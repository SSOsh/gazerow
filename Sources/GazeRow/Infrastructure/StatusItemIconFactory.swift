import AppKit

/// 메뉴바 status item용 template icon을 만든다.
///
/// @author suho.do
/// @since 2026-07-12
enum StatusItemIconFactory {
    static let iconSize = NSSize(width: 18, height: 18)

    static func makeIcon() -> NSImage {
        let image = NSImage(size: iconSize)
        image.lockFocus()

        NSColor.black.setStroke()
        NSColor.black.setFill()

        drawEye(in: NSRect(x: 2.1, y: 6.1, width: 13.8, height: 7.2))
        drawRows()

        image.unlockFocus()
        image.isTemplate = true
        image.accessibilityDescription = AppIconConfiguration.accessibilityDescription
        return image
    }

    private static func drawEye(in rect: NSRect) {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: rect.midY))
        path.curve(
            to: NSPoint(x: rect.midX, y: rect.maxY),
            controlPoint1: NSPoint(x: rect.minX + 2.4, y: rect.maxY),
            controlPoint2: NSPoint(x: rect.midX - 2.2, y: rect.maxY)
        )
        path.curve(
            to: NSPoint(x: rect.maxX, y: rect.midY),
            controlPoint1: NSPoint(x: rect.midX + 2.2, y: rect.maxY),
            controlPoint2: NSPoint(x: rect.maxX - 2.4, y: rect.maxY)
        )
        path.curve(
            to: NSPoint(x: rect.midX, y: rect.minY),
            controlPoint1: NSPoint(x: rect.maxX - 2.4, y: rect.minY),
            controlPoint2: NSPoint(x: rect.midX + 2.2, y: rect.minY)
        )
        path.curve(
            to: NSPoint(x: rect.minX, y: rect.midY),
            controlPoint1: NSPoint(x: rect.midX - 2.2, y: rect.minY),
            controlPoint2: NSPoint(x: rect.minX + 2.4, y: rect.minY)
        )
        path.lineWidth = 1.55
        path.stroke()

        NSBezierPath(ovalIn: NSRect(x: 7.1, y: 7.55, width: 3.8, height: 3.8)).fill()
    }

    private static func drawRows() {
        let rowRects = [
            NSRect(x: 4.2, y: 3.2, width: 9.6, height: 1.25),
            NSRect(x: 5.8, y: 1.15, width: 6.4, height: 1.25)
        ]

        for rect in rowRects {
            NSBezierPath(roundedRect: rect, xRadius: 0.6, yRadius: 0.6).fill()
        }
    }
}
