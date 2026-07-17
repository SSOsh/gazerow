import AppKit

/// 메뉴바 status item용 template icon을 만든다.
///
/// @author suho.do
/// @since 2026-07-13
enum StatusItemIconFactory {
    static let iconSize = NSSize(width: 18, height: 18)

    static func makeIcon() -> NSImage {
        let image = NSImage(size: iconSize)
        image.lockFocus()

        NSColor.black.setStroke()
        NSColor.black.setFill()
        drawKeycap(in: NSRect(x: 2.5, y: 2.5, width: 13, height: 13))
        drawCursor()

        image.unlockFocus()
        image.isTemplate = true
        image.accessibilityDescription = AppIconConfiguration.accessibilityDescription
        return image
    }

    private static func drawKeycap(in rect: NSRect) {
        let path = NSBezierPath(roundedRect: rect, xRadius: 3.2, yRadius: 3.2)
        path.lineWidth = 1.35
        path.stroke()
    }

    private static func drawCursor() {
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 6.2, y: 13.3))
        path.line(to: NSPoint(x: 6.2, y: 5.7))
        path.line(to: NSPoint(x: 12.8, y: 9.5))
        path.close()
        path.fill()
    }
}
