#!/usr/bin/env swift
// Erzeugt build/AppIcon.icns — aufgeschlagenes Buch mit Kompassnadel, violetter Verlauf
// nach TOKENS.md (accent #B45CFF → accent2 #7B3BE8, Nadel in cyan #4FD8E8).
// Rein CoreGraphics, keine externen Assets.
// Aufruf: swift Scripts/generate_icon.swift   (aus dem Repo-Wurzelverzeichnis)

import AppKit
import CoreGraphics
import Foundation

let canvas = 1024.0

func color(_ hex: UInt32, _ a: Double = 1) -> CGColor {
    CGColor(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255, alpha: a)
}

let accent = color(0xB45CFF)
let accent2 = color(0x7B3BE8)
let deepTop = color(0x28104E)
let deepBottom = color(0x150A2C)
let paper = color(0xFFFFFF, 0.95)
let paperEdge = color(0xFFFFFF, 0.55)
let cyan = color(0x4FD8E8)

func drawIcon(into ctx: CGContext) {
    ctx.setAllowsAntialiasing(true)
    let body = CGRect(x: 0, y: 0, width: canvas, height: canvas)
    let space = CGColorSpaceCreateDeviceRGB()

    // Körper: dunkelvioletter Verlauf + Akzent-Glow oben links (wie bgLayers)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: body, cornerWidth: canvas * 0.2237,
                       cornerHeight: canvas * 0.2237, transform: nil))
    ctx.clip()
    if let grad = CGGradient(colorsSpace: space, colors: [deepTop, deepBottom] as CFArray,
                             locations: [0, 1]) {
        ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: body.maxY),
                               end: CGPoint(x: canvas, y: 0), options: [])
    }
    if let glow = CGGradient(colorsSpace: space,
                             colors: [color(0x5A2497, 0.85), color(0x5A2497, 0)] as CFArray,
                             locations: [0, 1]) {
        ctx.drawRadialGradient(glow, startCenter: CGPoint(x: canvas * 0.12, y: canvas * 1.02),
                               startRadius: 0, endCenter: CGPoint(x: canvas * 0.12, y: canvas * 1.02),
                               endRadius: canvas * 0.9, options: [])
    }
    ctx.restoreGState()

    // Aufgeschlagenes Buch: zwei Seiten, leicht nach außen gewölbt
    let cx = canvas * 0.5, baseY = canvas * 0.34, topY = canvas * 0.66
    let halfW = canvas * 0.30
    func page(mirrored: Bool) -> CGPath {
        let s: Double = mirrored ? -1 : 1
        let p = CGMutablePath()
        p.move(to: CGPoint(x: cx, y: baseY + canvas * 0.03))
        p.addLine(to: CGPoint(x: cx, y: topY))
        p.addCurve(to: CGPoint(x: cx + s * halfW, y: topY - canvas * 0.05),
                   control1: CGPoint(x: cx + s * halfW * 0.45, y: topY + canvas * 0.02),
                   control2: CGPoint(x: cx + s * halfW * 0.80, y: topY - canvas * 0.01))
        p.addLine(to: CGPoint(x: cx + s * halfW, y: baseY - canvas * 0.02))
        p.addCurve(to: CGPoint(x: cx, y: baseY + canvas * 0.03),
                   control1: CGPoint(x: cx + s * halfW * 0.80, y: baseY - canvas * 0.05),
                   control2: CGPoint(x: cx + s * halfW * 0.45, y: baseY - canvas * 0.01))
        p.closeSubpath()
        return p
    }
    for mirrored in [false, true] {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -canvas * 0.014), blur: canvas * 0.035,
                      color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.45))
        ctx.addPath(page(mirrored: mirrored))
        ctx.setFillColor(paper)
        ctx.fillPath()
        ctx.restoreGState()
        ctx.addPath(page(mirrored: mirrored))
        ctx.setStrokeColor(paperEdge)
        ctx.setLineWidth(canvas * 0.008)
        ctx.strokePath()
    }

    // Kompassnadel über dem Buchrücken
    let nR = canvas * 0.145
    let nC = CGPoint(x: cx, y: canvas * 0.52)
    func needle(_ fill: CGColor, rotated: Bool) {
        let p = CGMutablePath()
        let long = rotated ? -nR : nR
        p.move(to: CGPoint(x: nC.x, y: nC.y + long))
        p.addLine(to: CGPoint(x: nC.x + nR * 0.30, y: nC.y))
        p.addLine(to: CGPoint(x: nC.x, y: nC.y - long * 0.18))
        p.addLine(to: CGPoint(x: nC.x - nR * 0.30, y: nC.y))
        p.closeSubpath()
        ctx.addPath(p)
        ctx.setFillColor(fill)
        ctx.fillPath()
    }
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: canvas * 0.05, color: color(0xB45CFF, 0.7))
    needle(accent, rotated: false)
    ctx.restoreGState()
    needle(cyan, rotated: true)

    // Ring um die Nadel
    ctx.setStrokeColor(color(0xFFFFFF, 0.30))
    ctx.setLineWidth(canvas * 0.014)
    ctx.strokeEllipse(in: CGRect(x: nC.x - nR * 1.25, y: nC.y - nR * 1.25,
                                 width: nR * 2.5, height: nR * 2.5))

    // Akzentkante unten (Buchschnitt)
    ctx.saveGState()
    ctx.setStrokeColor(accent2)
    ctx.setLineWidth(canvas * 0.022)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: cx - halfW, y: baseY - canvas * 0.045))
    ctx.addLine(to: CGPoint(x: cx + halfW, y: baseY - canvas * 0.045))
    ctx.strokePath()
    ctx.restoreGState()
    _ = accent
}

func renderPNG(size: Int) -> Data? {
    guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                              bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
    ctx.scaleBy(x: Double(size) / canvas, y: Double(size) / canvas)
    drawIcon(into: ctx)
    guard let img = ctx.makeImage() else { return nil }
    return NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])
}

let fm = FileManager.default
let buildDir = "build"
let isetDir = "\(buildDir)/AppIcon.iconset"
try? fm.createDirectory(atPath: isetDir, withIntermediateDirectories: true)

let slots: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for (name, px) in slots {
    guard let data = renderPNG(size: px) else {
        FileHandle.standardError.write("Render fehlgeschlagen: \(name)\n".data(using: .utf8)!)
        exit(1)
    }
    try data.write(to: URL(fileURLWithPath: "\(isetDir)/\(name).png"))
}
try renderPNG(size: 1024)?.write(to: URL(fileURLWithPath: "\(buildDir)/AppIcon-preview.png"))

let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", isetDir, "-o", "\(buildDir)/AppIcon.icns"]
try p.run()
p.waitUntilExit()
guard p.terminationStatus == 0 else {
    FileHandle.standardError.write("iconutil fehlgeschlagen (\(p.terminationStatus))\n".data(using: .utf8)!)
    exit(1)
}
print("OK: \(buildDir)/AppIcon.icns")
