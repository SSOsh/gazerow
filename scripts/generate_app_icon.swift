#!/usr/bin/env swift
import AppKit
import Foundation

/// gazerow 앱 아이콘 PNG/iconset/icns를 생성한다.
///
/// @author suho.do
/// @since 2026-07-13

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assetsDirectory = root.appendingPathComponent("Assets", isDirectory: true)
let iconsetDirectory = assetsDirectory.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icnsURL = assetsDirectory.appendingPathComponent("AppIcon.icns")

try FileManager.default.createDirectory(at: iconsetDirectory, withIntermediateDirectories: true)

let iconEntries: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]

for entry in iconEntries {
    try writePNG(drawIcon(pixelSize: entry.pixels), to: iconsetDirectory.appendingPathComponent(entry.name))
}

if FileManager.default.fileExists(atPath: icnsURL.path) {
    try FileManager.default.removeItem(at: icnsURL)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["--convert", "icns", "--output", icnsURL.path, iconsetDirectory.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "GenerateAppIcon", code: Int(process.terminationStatus))
}

func drawIcon(pixelSize: Int) -> NSBitmapImageRep {
    let size = CGFloat(pixelSize)
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    bitmap.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    drawBackground(size: size)
    drawKeycap(size: size)
    drawCursor(size: size)
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap
}

func drawBackground(size: CGFloat) {
    let path = NSBezierPath(
        roundedRect: NSRect(x: 0, y: 0, width: size, height: size),
        xRadius: size * 0.22,
        yRadius: size * 0.22
    )
    NSGradient(colors: [
        NSColor(calibratedRed: 0.03, green: 0.22, blue: 0.28, alpha: 1),
        NSColor(calibratedRed: 0.02, green: 0.52, blue: 0.55, alpha: 1)
    ])?.draw(in: path, angle: 45)
}

func drawKeycap(size: CGFloat) {
    let keyboardPlate = NSBezierPath(
        roundedRect: NSRect(x: size * 0.14, y: size * 0.14, width: size * 0.72, height: size * 0.72),
        xRadius: size * 0.13,
        yRadius: size * 0.13
    )
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
    shadow.shadowBlurRadius = size * 0.04
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.018)
    shadow.set()
    NSColor(calibratedWhite: 0.05, alpha: 0.28).setFill()
    keyboardPlate.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSColor.white.withAlphaComponent(0.55).setStroke()
    keyboardPlate.lineWidth = max(1, size * 0.016)
    keyboardPlate.stroke()

    let keySize = size * 0.135
    let gap = size * 0.045
    let gridOrigin = NSPoint(x: size * 0.2525, y: size * 0.2525)
    for row in 0..<3 {
        for column in 0..<3 {
            let keyRect = NSRect(
                x: gridOrigin.x + CGFloat(column) * (keySize + gap),
                y: gridOrigin.y + CGFloat(row) * (keySize + gap),
                width: keySize,
                height: keySize
            )
            let key = NSBezierPath(
                roundedRect: keyRect,
                xRadius: size * 0.025,
                yRadius: size * 0.025
            )
            let isGazeTarget = row == 2 && column == 2
            (isGazeTarget
                ? NSColor(calibratedRed: 1.0, green: 0.78, blue: 0.24, alpha: 1)
                : NSColor.white.withAlphaComponent(0.82)
            ).setFill()
            key.fill()
        }
    }
}

func drawCursor(size: CGFloat) {
    let gazeCenter = NSPoint(x: size * 0.68, y: size * 0.68)
    let gazeRadius = size * 0.105
    let ring = NSBezierPath(
        ovalIn: NSRect(
            x: gazeCenter.x - gazeRadius,
            y: gazeCenter.y - gazeRadius,
            width: gazeRadius * 2,
            height: gazeRadius * 2
        )
    )

    NSGraphicsContext.saveGraphicsState()
    let glow = NSShadow()
    glow.shadowColor = NSColor.black.withAlphaComponent(0.30)
    glow.shadowBlurRadius = size * 0.02
    glow.set()
    NSColor.white.withAlphaComponent(0.96).setStroke()
    ring.lineWidth = max(1, size * 0.024)
    ring.stroke()
    NSGraphicsContext.restoreGraphicsState()

    let pupilRadius = size * 0.026
    let pupil = NSBezierPath(
        ovalIn: NSRect(
            x: gazeCenter.x - pupilRadius,
            y: gazeCenter.y - pupilRadius,
            width: pupilRadius * 2,
            height: pupilRadius * 2
        )
    )
    NSColor(calibratedRed: 0.02, green: 0.23, blue: 0.28, alpha: 0.95).setFill()
    pupil.fill()
}

func writePNG(_ bitmap: NSBitmapImageRep, to url: URL) throws {
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "GenerateAppIcon", code: 1)
    }
    try png.write(to: url)
}
