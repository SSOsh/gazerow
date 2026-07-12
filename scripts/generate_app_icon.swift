#!/usr/bin/env swift
import AppKit
import Foundation

/// GazeRow 앱 아이콘 PNG/iconset/icns를 생성한다.
///
/// @author suho.do
/// @since 2026-07-12

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assetsDirectory = root.appendingPathComponent("Assets", isDirectory: true)
let iconsetDirectory = assetsDirectory.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icnsURL = assetsDirectory.appendingPathComponent("AppIcon.icns")

try FileManager.default.createDirectory(
    at: iconsetDirectory,
    withIntermediateDirectories: true
)

let iconEntries: [(name: String, pixels: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for entry in iconEntries {
    let image = drawIcon(pixelSize: entry.pixels)
    try writePNG(image, to: iconsetDirectory.appendingPathComponent(entry.name))
}

if FileManager.default.fileExists(atPath: icnsURL.path) {
    try FileManager.default.removeItem(at: icnsURL)
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = [
    "--convert",
    "icns",
    "--output",
    icnsURL.path,
    iconsetDirectory.path
]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(
        domain: "GenerateAppIcon",
        code: Int(process.terminationStatus),
        userInfo: [NSLocalizedDescriptionKey: "iconutil failed"]
    )
}

func drawIcon(pixelSize: Int) -> NSImage {
    let size = CGFloat(pixelSize)
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    NSGraphicsContext.current?.imageInterpolation = .high
    drawBackground(size: size)
    drawRowMarks(size: size)
    drawEye(size: size)
    drawPupil(size: size)

    image.unlockFocus()
    return image
}

func drawBackground(size: CGFloat) {
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let radius = size * 0.22
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.035, green: 0.125, blue: 0.165, alpha: 1),
        NSColor(calibratedRed: 0.035, green: 0.44, blue: 0.46, alpha: 1),
        NSColor(calibratedRed: 0.0, green: 0.70, blue: 0.61, alpha: 1)
    ])
    gradient?.draw(in: path, angle: 36)
}

func drawRowMarks(size: CGFloat) {
    let colors = [
        NSColor(calibratedRed: 1.0, green: 0.84, blue: 0.40, alpha: 0.96),
        NSColor(calibratedRed: 0.98, green: 0.40, blue: 0.33, alpha: 0.92),
        NSColor(calibratedRed: 0.63, green: 0.92, blue: 0.95, alpha: 0.86)
    ]
    let yValues = [size * 0.25, size * 0.18, size * 0.11]
    let widths = [size * 0.54, size * 0.42, size * 0.30]

    for index in 0..<yValues.count {
        colors[index].setFill()
        let rect = NSRect(
            x: (size - widths[index]) / 2,
            y: yValues[index],
            width: widths[index],
            height: size * 0.034
        )
        NSBezierPath(
            roundedRect: rect,
            xRadius: size * 0.017,
            yRadius: size * 0.017
        ).fill()
    }
}

func drawEye(size: CGFloat) {
    let rect = NSRect(
        x: size * 0.145,
        y: size * 0.39,
        width: size * 0.71,
        height: size * 0.31
    )

    let eye = eyePath(in: rect)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
    shadow.shadowBlurRadius = size * 0.045
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.018)
    shadow.set()

    NSColor.white.withAlphaComponent(0.96).setFill()
    eye.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSColor(calibratedRed: 0.68, green: 0.98, blue: 0.94, alpha: 0.86).setStroke()
    eye.lineWidth = size * 0.025
    eye.stroke()
}

func drawPupil(size: CGFloat) {
    let outer = NSRect(
        x: size * 0.405,
        y: size * 0.445,
        width: size * 0.19,
        height: size * 0.19
    )
    NSColor(calibratedRed: 0.03, green: 0.12, blue: 0.16, alpha: 1).setFill()
    NSBezierPath(ovalIn: outer).fill()

    let inner = NSRect(
        x: size * 0.462,
        y: size * 0.502,
        width: size * 0.076,
        height: size * 0.076
    )
    NSColor(calibratedRed: 0.0, green: 0.72, blue: 0.64, alpha: 1).setFill()
    NSBezierPath(ovalIn: inner).fill()

    let highlight = NSRect(
        x: size * 0.525,
        y: size * 0.565,
        width: size * 0.045,
        height: size * 0.045
    )
    NSColor.white.withAlphaComponent(0.92).setFill()
    NSBezierPath(ovalIn: highlight).fill()
}

func eyePath(in rect: NSRect) -> NSBezierPath {
    let path = NSBezierPath()
    path.move(to: NSPoint(x: rect.minX, y: rect.midY))
    path.curve(
        to: NSPoint(x: rect.midX, y: rect.maxY),
        controlPoint1: NSPoint(x: rect.minX + rect.width * 0.17, y: rect.maxY),
        controlPoint2: NSPoint(x: rect.midX - rect.width * 0.18, y: rect.maxY)
    )
    path.curve(
        to: NSPoint(x: rect.maxX, y: rect.midY),
        controlPoint1: NSPoint(x: rect.midX + rect.width * 0.18, y: rect.maxY),
        controlPoint2: NSPoint(x: rect.maxX - rect.width * 0.17, y: rect.maxY)
    )
    path.curve(
        to: NSPoint(x: rect.midX, y: rect.minY),
        controlPoint1: NSPoint(x: rect.maxX - rect.width * 0.17, y: rect.minY),
        controlPoint2: NSPoint(x: rect.midX + rect.width * 0.18, y: rect.minY)
    )
    path.curve(
        to: NSPoint(x: rect.minX, y: rect.midY),
        controlPoint1: NSPoint(x: rect.midX - rect.width * 0.18, y: rect.minY),
        controlPoint2: NSPoint(x: rect.minX + rect.width * 0.17, y: rect.minY)
    )
    path.close()
    return path
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let png = bitmap.representation(using: .png, properties: [:])
    else {
        throw NSError(
            domain: "GenerateAppIcon",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "Failed to render PNG"]
        )
    }

    try png.write(to: url)
}
