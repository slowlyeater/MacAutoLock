import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct IconSpec {
    let filename: String
    let pixels: Int
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "")
let specs: [IconSpec] = [
    .init(filename: "Icon-20@2x.png", pixels: 40),
    .init(filename: "Icon-20@3x.png", pixels: 60),
    .init(filename: "Icon-29@2x.png", pixels: 58),
    .init(filename: "Icon-29@3x.png", pixels: 87),
    .init(filename: "Icon-40@2x.png", pixels: 80),
    .init(filename: "Icon-40@3x.png", pixels: 120),
    .init(filename: "Icon-60@2x.png", pixels: 120),
    .init(filename: "Icon-60@3x.png", pixels: 180),
    .init(filename: "Icon-1024.png", pixels: 1024)
]

func color(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    let red = CGFloat((hex >> 16) & 0xff) / 255
    let green = CGFloat((hex >> 8) & 0xff) / 255
    let blue = CGFloat(hex & 0xff) / 255
    return CGColor(red: red, green: green, blue: blue, alpha: alpha)
}

func drawIcon(size: Int) -> CGImage {
    let dimension = CGFloat(size)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    context.setShouldAntialias(true)
    context.setAllowsAntialiasing(true)

    let backgroundGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [color(0x08151c), color(0x102b31), color(0x071014)] as CFArray,
        locations: [0, 0.58, 1]
    )!
    context.drawLinearGradient(
        backgroundGradient,
        start: CGPoint(x: dimension * 0.12, y: 0),
        end: CGPoint(x: dimension * 0.92, y: dimension),
        options: []
    )

    let glowGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [color(0x2bf7c7, alpha: 0.42), color(0x2bf7c7, alpha: 0)] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        glowGradient,
        startCenter: CGPoint(x: dimension * 0.55, y: dimension * 0.50),
        startRadius: 0,
        endCenter: CGPoint(x: dimension * 0.55, y: dimension * 0.50),
        endRadius: dimension * 0.62,
        options: [.drawsAfterEndLocation]
    )

    context.setLineCap(.round)
    context.setLineJoin(.round)

    let circuit = color(0x7af5dc, alpha: size >= 120 ? 0.18 : 0.10)
    context.setStrokeColor(circuit)
    context.setLineWidth(max(1, dimension * 0.012))
    let circuitPoints: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (0.14, 0.26, 0.31, 0.26),
        (0.19, 0.76, 0.38, 0.76),
        (0.69, 0.22, 0.86, 0.22),
        (0.72, 0.80, 0.88, 0.80),
        (0.18, 0.42, 0.26, 0.50),
        (0.77, 0.55, 0.88, 0.66)
    ]
    for line in circuitPoints {
        context.move(to: CGPoint(x: dimension * line.0, y: dimension * line.1))
        context.addLine(to: CGPoint(x: dimension * line.2, y: dimension * line.3))
        context.strokePath()
    }

    let center = CGPoint(x: dimension * 0.50, y: dimension * 0.53)
    context.setStrokeColor(color(0x40f1ce, alpha: 0.66))
    for radius in [0.28, 0.38] {
        context.setLineWidth(max(1.5, dimension * 0.018))
        context.addArc(
            center: center,
            radius: dimension * CGFloat(radius),
            startAngle: -.pi * 0.18,
            endAngle: .pi * 0.18,
            clockwise: false
        )
        context.strokePath()
        context.addArc(
            center: center,
            radius: dimension * CGFloat(radius),
            startAngle: .pi * 0.82,
            endAngle: .pi * 1.18,
            clockwise: false
        )
        context.strokePath()
    }

    let shield = CGMutablePath()
    shield.move(to: CGPoint(x: dimension * 0.50, y: dimension * 0.20))
    shield.addCurve(
        to: CGPoint(x: dimension * 0.28, y: dimension * 0.34),
        control1: CGPoint(x: dimension * 0.43, y: dimension * 0.22),
        control2: CGPoint(x: dimension * 0.34, y: dimension * 0.28)
    )
    shield.addCurve(
        to: CGPoint(x: dimension * 0.50, y: dimension * 0.82),
        control1: CGPoint(x: dimension * 0.28, y: dimension * 0.58),
        control2: CGPoint(x: dimension * 0.35, y: dimension * 0.73)
    )
    shield.addCurve(
        to: CGPoint(x: dimension * 0.72, y: dimension * 0.34),
        control1: CGPoint(x: dimension * 0.65, y: dimension * 0.73),
        control2: CGPoint(x: dimension * 0.72, y: dimension * 0.58)
    )
    shield.addCurve(
        to: CGPoint(x: dimension * 0.50, y: dimension * 0.20),
        control1: CGPoint(x: dimension * 0.66, y: dimension * 0.28),
        control2: CGPoint(x: dimension * 0.57, y: dimension * 0.22)
    )
    shield.closeSubpath()

    context.saveGState()
    context.addPath(shield)
    context.clip()
    let shieldGradient = CGGradient(
        colorsSpace: colorSpace,
        colors: [color(0x1de8c0, alpha: 0.82), color(0x11626f, alpha: 0.92)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        shieldGradient,
        start: CGPoint(x: dimension * 0.32, y: dimension * 0.20),
        end: CGPoint(x: dimension * 0.70, y: dimension * 0.86),
        options: []
    )
    context.restoreGState()

    context.addPath(shield)
    context.setStrokeColor(color(0xc5fff4, alpha: 0.84))
    context.setLineWidth(max(2, dimension * 0.024))
    context.strokePath()

    let lockRect = CGRect(x: dimension * 0.37, y: dimension * 0.49, width: dimension * 0.26, height: dimension * 0.20)
    let lockPath = CGPath(roundedRect: lockRect, cornerWidth: dimension * 0.045, cornerHeight: dimension * 0.045, transform: nil)
    context.addPath(lockPath)
    context.setFillColor(color(0x061014, alpha: 0.82))
    context.fillPath()

    context.setStrokeColor(color(0xe8fffb, alpha: 0.90))
    context.setLineWidth(max(2, dimension * 0.035))
    context.addArc(
        center: CGPoint(x: dimension * 0.50, y: dimension * 0.50),
        radius: dimension * 0.095,
        startAngle: .pi,
        endAngle: 0,
        clockwise: false
    )
    context.strokePath()

    context.setFillColor(color(0xe8fffb, alpha: 0.95))
    context.fillEllipse(in: CGRect(x: dimension * 0.475, y: dimension * 0.565, width: dimension * 0.05, height: dimension * 0.05))
    context.fill(CGRect(x: dimension * 0.49, y: dimension * 0.605, width: dimension * 0.02, height: dimension * 0.065))

    context.setFillColor(color(0x9fffee, alpha: 0.90))
    for point in [(0.24, 0.26), (0.84, 0.22), (0.19, 0.76), (0.84, 0.80)] {
        context.fillEllipse(in: CGRect(
            x: dimension * point.0 - dimension * 0.018,
            y: dimension * point.1 - dimension * 0.018,
            width: dimension * 0.036,
            height: dimension * 0.036
        ))
    }

    return context.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, image, nil)
    precondition(CGImageDestinationFinalize(destination), "Could not write \(url.path)")
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
for spec in specs {
    writePNG(drawIcon(size: spec.pixels), to: outputDirectory.appendingPathComponent(spec.filename))
}
