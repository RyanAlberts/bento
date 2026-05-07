// Generates a bento-box themed app icon as a .iconset directory.
// Run via:  swift scripts/generate-icon.swift
//
// Then convert to .icns:  iconutil -c icns build/Bento.iconset -o build/AppIcon.icns
// build-app.sh handles both steps automatically.

import AppKit
import CoreGraphics

let outDir = URL(fileURLWithPath: "build/Bento.iconset")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

func draw(size: Int) -> NSImage {
    let s = CGFloat(size)
    let img = NSImage(size: NSSize(width: s, height: s))
    img.lockFocus()
    defer { img.unlockFocus() }
    guard let ctx = NSGraphicsContext.current?.cgContext else { return img }

    // Rounded-square outer "bento box"
    let radius = s * 0.225
    let outerInset = s * 0.06
    let outerRect = CGRect(x: outerInset, y: outerInset, width: s - 2 * outerInset, height: s - 2 * outerInset)
    let outerPath = CGPath(roundedRect: outerRect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    // Soft warm gradient: terracotta → pink (bento warmth)
    let colors = [
        CGColor(srgbRed: 0.95, green: 0.55, blue: 0.40, alpha: 1.0),
        CGColor(srgbRed: 0.92, green: 0.42, blue: 0.55, alpha: 1.0),
    ]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
    ctx.saveGState()
    ctx.addPath(outerPath)
    ctx.clip()
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: 0, y: s),
                           end: CGPoint(x: s, y: 0),
                           options: [])
    ctx.restoreGState()

    // Subtle outer rim for depth
    ctx.addPath(outerPath)
    ctx.setStrokeColor(CGColor(srgbRed: 0.85, green: 0.35, blue: 0.40, alpha: 0.35))
    ctx.setLineWidth(s * 0.012)
    ctx.strokePath()

    // 2x2 compartments (the "bento" cells)
    let cellInset = s * 0.18
    let gap = s * 0.04
    let usable = s - 2 * cellInset
    let cellSize = (usable - gap) / 2
    let cellRadius = cellSize * 0.18

    let cellColors: [CGColor] = [
        CGColor(srgbRed: 1.00, green: 0.97, blue: 0.92, alpha: 0.96),
        CGColor(srgbRed: 0.99, green: 0.93, blue: 0.78, alpha: 0.96),
        CGColor(srgbRed: 0.95, green: 0.83, blue: 0.78, alpha: 0.96),
        CGColor(srgbRed: 0.85, green: 0.92, blue: 0.79, alpha: 0.96),
    ]

    for row in 0..<2 {
        for col in 0..<2 {
            let x = cellInset + CGFloat(col) * (cellSize + gap)
            let y = cellInset + CGFloat(row) * (cellSize + gap)
            let rect = CGRect(x: x, y: y, width: cellSize, height: cellSize)
            let path = CGPath(roundedRect: rect, cornerWidth: cellRadius, cornerHeight: cellRadius, transform: nil)
            ctx.addPath(path)
            let idx = row * 2 + col
            ctx.setFillColor(cellColors[idx])
            ctx.fillPath()

            // tiny inner shadow for depth
            ctx.addPath(path)
            ctx.setStrokeColor(CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.06))
            ctx.setLineWidth(s * 0.005)
            ctx.strokePath()
        }
    }

    return img
}

func savePNG(_ img: NSImage, to url: URL) throws {
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icongen", code: 1, userInfo: nil)
    }
    try png.write(to: url)
}

for (name, px) in sizes {
    let img = draw(size: px)
    let url = outDir.appendingPathComponent(name)
    try savePNG(img, to: url)
    print("ok \(name) (\(px)x\(px))")
}

print("\nIconset written to \(outDir.path)")
