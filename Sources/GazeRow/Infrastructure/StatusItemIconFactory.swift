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
        drawKeyboardPlate()
        drawKeyboardGrid()
        drawGazeRing()

        image.unlockFocus()
        image.isTemplate = true
        image.accessibilityDescription = AppIconConfiguration.accessibilityDescription
        return image
    }

    private static func drawKeyboardPlate() {
        let path = NSBezierPath(
            roundedRect: NSRect(x: 1.5, y: 2.25, width: 15, height: 13.5),
            xRadius: 2.6,
            yRadius: 2.6
        )
        path.lineWidth = 1.15
        path.stroke()
    }

    private static func drawKeyboardGrid() {
        let keySize: CGFloat = 2.3
        let gap: CGFloat = 1.4
        let origin = NSPoint(x: 3.2, y: 4)

        for row in 0..<3 {
            for column in 0..<3 where !(row == 2 && column == 2) {
                let rect = NSRect(
                    x: origin.x + CGFloat(column) * (keySize + gap),
                    y: origin.y + CGFloat(row) * (keySize + gap),
                    width: keySize,
                    height: keySize
                )
                NSBezierPath(roundedRect: rect, xRadius: 0.55, yRadius: 0.55).fill()
            }
        }
    }

    private static func drawGazeRing() {
        let center = NSPoint(x: 12.3, y: 11.9)
        let radius: CGFloat = 2.65
        let ring = NSBezierPath(
            ovalIn: NSRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            )
        )
        ring.lineWidth = 1.15
        ring.stroke()

        NSBezierPath(
            ovalIn: NSRect(x: center.x - 0.65, y: center.y - 0.65, width: 1.3, height: 1.3)
        ).fill()
    }
}
