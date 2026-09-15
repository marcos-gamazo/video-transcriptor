#!/usr/bin/env /usr/bin/swift

import AppKit
import Foundation

let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Assets/AppIcon.iconset"

let fm = FileManager.default
try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

let sizes: [(Int, String)] = [
    (16, "icon_16x16"),
    (16, "icon_16x16@2x"),
    (32, "icon_16x16@2x"),
    (32, "icon_32x32"),
    (32, "icon_32x32@2x"),
    (64, "icon_32x32@2x"),
    (128, "icon_128x128"),
    (128, "icon_128x128@2x"),
    (256, "icon_128x128@2x"),
    (256, "icon_256x256"),
    (256, "icon_256x256@2x"),
    (512, "icon_256x256@2x"),
    (512, "icon_512x512"),
    (1024, "icon_512x512@2x"),
]

func drawIcon(in context: CGContext, size: CGFloat) {
    let rect = CGRect(x: 0, y: 0, width: size, height: size)

    let bgPath = CGPath(roundedRect: rect, cornerWidth: size * 0.2, cornerHeight: size * 0.2, transform: nil)
    context.addPath(bgPath)
    context.clip()

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [CGColor(red: 0.15, green: 0.45, blue: 0.82, alpha: 1.0),
                  CGColor(red: 0.12, green: 0.34, blue: 0.68, alpha: 1.0)]
    let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 1])!
    context.drawLinearGradient(gradient,
                               start: CGPoint(x: 0, y: size),
                               end: CGPoint(x: size, y: 0),
                               options: [])

    let waveColor = CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.95)
    context.setStrokeColor(waveColor)
    context.setLineWidth(size * 0.045)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    let barWidth = size * 0.06
    let spacing = size * 0.08
    let totalBars = 5
    let totalWidth = CGFloat(totalBars) * barWidth + CGFloat(totalBars - 1) * spacing
    let startX = (size - totalWidth) / 2
    let centerY = size / 2

    let amplitudes: [CGFloat] = [0.45, 0.75, 1.0, 0.75, 0.45]
    for (i, amp) in amplitudes.enumerated() {
        let x = startX + CGFloat(i) * (barWidth + spacing)
        let halfH = size * 0.35 * amp
        let path = CGPath(roundedRect: CGRect(x: x, y: centerY - halfH, width: barWidth, height: halfH * 2),
                          cornerWidth: barWidth / 2,
                          cornerHeight: barWidth / 2,
                          transform: nil)
        context.addPath(path)
        context.setFillColor(waveColor)
        context.fillPath()
    }
}

for entry in sizes {
    let pixelSize = entry.0
    let filename = entry.1 + ".png"
    let outPath = (outputDir as NSString).appendingPathComponent(filename)

    let scale: CGFloat = (filename.contains("@2x")) ? 2.0 : 1.0
    let logicalSize = CGFloat(pixelSize) / scale

    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil,
                        width: Int(logicalSize * scale),
                        height: Int(logicalSize * scale),
                        bitsPerComponent: 8,
                        bytesPerRow: 0,
                        space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
    ctx.scaleBy(x: scale, y: scale)
    ctx.translateBy(x: 0, y: logicalSize)
    ctx.scaleBy(x: 1, y: -1)

    drawIcon(in: ctx, size: logicalSize)

    guard let image = ctx.makeImage() else { continue }

    let nsRep = NSBitmapImageRep(cgImage: image)
    nsRep.size = NSSize(width: logicalSize, height: logicalSize)
    let pngData = nsRep.representation(using: .png, properties: [:])!
    try! pngData.write(to: URL(fileURLWithPath: outPath))
    print("  → \(filename)")
}

print("Done. Iconset at \(outputDir)")
