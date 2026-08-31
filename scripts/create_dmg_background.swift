import Foundation
import AppKit
import CoreGraphics

let width: CGFloat = 660
let height: CGFloat = 440
let scale: CGFloat = 2.0
let pixelWidth = Int(width * scale)
let pixelHeight = Int(height * scale)

let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
    data: nil,
    width: pixelWidth,
    height: pixelHeight,
    bitsPerComponent: 8,
    bytesPerRow: pixelWidth * 4,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Could not create CGContext")
}

let graphicsContext = NSGraphicsContext(cgContext: context, flipped: false)
NSGraphicsContext.current = graphicsContext

context.scaleBy(x: scale, y: scale)

// 1. Base Dark Background
let baseRect = CGRect(x: 0, y: 0, width: width, height: height)
let bgGradientColors = [
    NSColor(red: 0.05, green: 0.055, blue: 0.09, alpha: 1.0).cgColor,
    NSColor(red: 0.08, green: 0.07, blue: 0.14, alpha: 1.0).cgColor,
    NSColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1.0).cgColor
] as CFArray
let bgLocations: [CGFloat] = [0.0, 0.55, 1.0]
if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgGradientColors, locations: bgLocations) {
    context.drawLinearGradient(bgGradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: width, y: 0), options: [])
}

// 2. Ambient Fluid Orbs
func drawGlowOrb(center: CGPoint, radius: CGFloat, color: NSColor, opacity: CGFloat) {
    context.saveGState()
    let orbColors = [
        color.withAlphaComponent(opacity).cgColor,
        color.withAlphaComponent(opacity * 0.4).cgColor,
        color.withAlphaComponent(0.0).cgColor
    ] as CFArray
    let orbLocations: [CGFloat] = [0.0, 0.45, 1.0]
    if let orbGradient = CGGradient(colorsSpace: colorSpace, colors: orbColors, locations: orbLocations) {
        context.drawRadialGradient(
            orbGradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: radius,
            options: [.drawsAfterEndLocation]
        )
    }
    context.restoreGState()
}

// Magenta / Pink Orb (Apple Music vibe)
drawGlowOrb(
    center: CGPoint(x: 180, y: 220),
    radius: 170,
    color: NSColor(red: 0.98, green: 0.18, blue: 0.45, alpha: 1.0),
    opacity: 0.35
)

// Electric Blue Orb (Spotify / Fullscreen vibe)
drawGlowOrb(
    center: CGPoint(x: 480, y: 220),
    radius: 170,
    color: NSColor(red: 0.22, green: 0.42, blue: 0.95, alpha: 1.0),
    opacity: 0.32
)

// Purple / Violet Accent Orb (Top center)
drawGlowOrb(
    center: CGPoint(x: 330, y: 320),
    radius: 200,
    color: NSColor(red: 0.62, green: 0.22, blue: 0.92, alpha: 1.0),
    opacity: 0.25
)

// 3. Subtle Target Docks under App & Applications
func drawDropDock(center: CGPoint, size: CGFloat) {
    let dockRect = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)
    let path = NSBezierPath(roundedRect: dockRect, xRadius: 28, yRadius: 28)
    
    context.saveGState()
    NSColor(white: 1.0, alpha: 0.05).setFill()
    path.fill()
    
    NSColor(white: 1.0, alpha: 0.12).setStroke()
    path.lineWidth = 1.5
    path.stroke()
    context.restoreGState()
}

drawDropDock(center: CGPoint(x: 180, y: 215), size: 140)
drawDropDock(center: CGPoint(x: 480, y: 215), size: 140)

// 4. Luminous Flow Arrow from App to Applications
context.saveGState()
let arrowStartX: CGFloat = 265
let arrowEndX: CGFloat = 395
let arrowY: CGFloat = 215

// Glow line
let glowPath = CGMutablePath()
glowPath.move(to: CGPoint(x: arrowStartX, y: arrowY))
glowPath.addLine(to: CGPoint(x: arrowEndX, y: arrowY))

context.setStrokeColor(NSColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.25).cgColor)
context.setLineWidth(4.0)
context.setLineCap(.round)
context.addPath(glowPath)
context.strokePath()

// Arrowhead
let arrowHead = CGMutablePath()
arrowHead.move(to: CGPoint(x: arrowEndX - 10, y: arrowY + 9))
arrowHead.addLine(to: CGPoint(x: arrowEndX, y: arrowY))
arrowHead.addLine(to: CGPoint(x: arrowEndX - 10, y: arrowY - 9))

context.setStrokeColor(NSColor(white: 1.0, alpha: 0.65).cgColor)
context.setLineWidth(3.0)
context.setLineCap(.round)
context.setLineJoin(.round)
context.addPath(arrowHead)
context.strokePath()
context.restoreGState()

// 5. Header: App Name & Subtitle
let titleString = "Lyric Fever"
let titleFont = NSFont.systemFont(ofSize: 26, weight: .bold)
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: titleFont,
    .foregroundColor: NSColor.white
]
let titleSize = titleString.size(withAttributes: titleAttrs)
let titleRect = CGRect(
    x: (width - titleSize.width) / 2,
    y: height - 62,
    width: titleSize.width,
    height: titleSize.height
)
(titleString as NSString).draw(in: titleRect, withAttributes: titleAttrs)

let subtitleString = "Real-time Synced Lyrics for Spotify & Apple Music"
let subtitleFont = NSFont.systemFont(ofSize: 12, weight: .medium)
let subtitleAttrs: [NSAttributedString.Key: Any] = [
    .font: subtitleFont,
    .foregroundColor: NSColor(white: 1.0, alpha: 0.65)
]
let subtitleSize = subtitleString.size(withAttributes: subtitleAttrs)
let subtitleRect = CGRect(
    x: (width - subtitleSize.width) / 2,
    y: height - 84,
    width: subtitleSize.width,
    height: subtitleSize.height
)
(subtitleString as NSString).draw(in: subtitleRect, withAttributes: subtitleAttrs)

// 6. Bottom Instruction Pill Badge
let instructionString = "Drag Lyric Fever to Applications to install"
let instructionFont = NSFont.systemFont(ofSize: 11.5, weight: .semibold)
let instructionAttrs: [NSAttributedString.Key: Any] = [
    .font: instructionFont,
    .foregroundColor: NSColor(white: 1.0, alpha: 0.85)
]
let instrSize = instructionString.size(withAttributes: instructionAttrs)
let pillWidth = instrSize.width + 36
let pillHeight: CGFloat = 30
let pillRect = CGRect(x: (width - pillWidth) / 2, y: 42, width: pillWidth, height: pillHeight)

let pillPath = NSBezierPath(roundedRect: pillRect, xRadius: 15, yRadius: 15)
context.saveGState()
NSColor(white: 1.0, alpha: 0.08).setFill()
pillPath.fill()
NSColor(white: 1.0, alpha: 0.15).setStroke()
pillPath.lineWidth = 1.0
pillPath.stroke()

let textDrawRect = CGRect(
    x: (width - instrSize.width) / 2,
    y: 42 + (pillHeight - instrSize.height) / 2 - 0.5,
    width: instrSize.width,
    height: instrSize.height
)
(instructionString as NSString).draw(in: textDrawRect, withAttributes: instructionAttrs)
context.restoreGState()

// 7. Save Image as PNG (both @1x and @2x)
guard let cgImage = context.makeImage() else {
    fatalError("Failed to make CGImage")
}

let rep = NSBitmapImageRep(cgImage: cgImage)
rep.size = NSSize(width: width, height: height) // set logical point size
guard let pngData = rep.representation(using: .png, properties: [:]) else {
    fatalError("Failed to create PNG representation")
}

let outputDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let outputURL = URL(fileURLWithPath: outputDir).appendingPathComponent("background.png")
let output2xURL = URL(fileURLWithPath: outputDir).appendingPathComponent("background@2x.png")

try pngData.write(to: outputURL)
try pngData.write(to: output2xURL)
print("Background generated successfully at \(outputURL.path)")
