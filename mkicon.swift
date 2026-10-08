// Turns icon.png into an .iconset folder for iconutil, rounding the corners the way the Dock does.
// Usage: swift mkicon.swift icon.png build/mini.iconset   (build.sh runs this)
import Cocoa

let args = CommandLine.arguments
guard args.count == 3, let png = NSImage(contentsOfFile: args[1]) else {
    FileHandle.standardError.write("usage: swift mkicon.swift icon.png out.iconset\n".data(using: .utf8)!)
    exit(1)
}
// Same mask as the bare binary applies at runtime: the shape fills 824 of a 1024 canvas.
let side: CGFloat = 1024, inset: CGFloat = 100
let shape = NSRect(x: inset, y: inset, width: side - 2 * inset, height: side - 2 * inset)
let masked = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
    NSBezierPath(roundedRect: shape, xRadius: shape.width * 0.2237, yRadius: shape.width * 0.2237).addClip()
    png.draw(in: shape)
    return true
}

let out = URL(fileURLWithPath: args[2])
try! FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
let sizes: [(String, Int)] = [("16x16", 16), ("16x16@2x", 32), ("32x32", 32), ("32x32@2x", 64),
                              ("128x128", 128), ("128x128@2x", 256), ("256x256", 256), ("256x256@2x", 512),
                              ("512x512", 512), ("512x512@2x", 1024)]
for (name, px) in sizes {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    masked.draw(in: NSRect(x: 0, y: 0, width: px, height: px), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("icon_\(name).png"))
}
