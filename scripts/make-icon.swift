// Renders the app icon (eye symbol on the ocean gradient) to a 1024px PNG.
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments[1]

let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
    let inset = rect.insetBy(dx: size * 0.09, dy: size * 0.09)
    let path = NSBezierPath(roundedRect: inset, xRadius: size * 0.2, yRadius: size * 0.2)
    NSGradient(starting: NSColor(red: 0.05, green: 0.25, blue: 0.45, alpha: 1),
               ending: NSColor(red: 0.10, green: 0.55, blue: 0.65, alpha: 1))!.draw(in: path, angle: -45)

    let config = NSImage.SymbolConfiguration(pointSize: size * 0.4, weight: .regular)
    if let symbol = NSImage(systemSymbolName: "eye", accessibilityDescription: nil)?.withSymbolConfiguration(config) {
        let tinted = NSImage(size: symbol.size, flipped: false) { r in
            symbol.draw(in: r)
            NSColor.white.set()
            r.fill(using: .sourceAtop)
            return true
        }
        let origin = NSPoint(x: rect.midX - tinted.size.width / 2, y: rect.midY - tinted.size.height / 2)
        tinted.draw(at: origin, from: .zero, operation: .sourceOver, fraction: 1)
    }
    return true
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
