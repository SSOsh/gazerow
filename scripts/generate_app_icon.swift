#!/usr/bin/env swift
import AppKit
import Foundation

/// keyCursor 앱 아이콘 PNG/iconset/icns를 생성한다.
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

func drawIcon(pixelSize: Int) -> NSImage {
    let size = CGFloat(pixelSize)
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    drawBackground(size: size)
    drawKeycap(size: size)
    drawCursor(size: size)
    image.unlockFocus()
    return image
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
    let keycap = NSBezierPath(
        roundedRect: NSRect(x: size * 0.20, y: size * 0.20, width: size * 0.60, height: size * 0.60),
        xRadius: size * 0.12,
        yRadius: size * 0.12
    )
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.20)
    shadow.shadowBlurRadius = size * 0.035
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.015)
    shadow.set()
    NSColor.white.withAlphaComponent(0.15).setFill()
    keycap.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSColor.white.withAlphaComponent(0.90).setStroke()
    keycap.lineWidth = size * 0.035
    keycap.stroke()
}

func drawCursor(size: CGFloat) {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: size * 0.35, y: size * 0.73))
    path.line(to: NSPoint(x: size * 0.35, y: size * 0.31))
    path.line(to: NSPoint(x: size * 0.71, y: size * 0.52))
    path.close()
    NSColor(calibratedRed: 1.0, green: 0.79, blue: 0.30, alpha: 1).setFill()
    path.fill()
    NSColor.white.withAlphaComponent(0.92).setStroke()
    path.lineWidth = size * 0.022
    path.stroke()
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(domain: "GenerateAppIcon", code: 1)
    }
    try png.write(to: url)
}
