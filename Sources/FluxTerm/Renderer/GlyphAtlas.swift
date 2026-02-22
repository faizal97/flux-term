import CoreGraphics
import CoreText
import Metal

struct GlyphInfo {
    var atlasX: Int
    var atlasY: Int
    var width: Int
    var height: Int
    var bearingX: Float
    var bearingY: Float
    var advance: Float

    static let empty = GlyphInfo(
        atlasX: 0,
        atlasY: 0,
        width: 0,
        height: 0,
        bearingX: 0,
        bearingY: 0,
        advance: 0
    )
}

final class GlyphAtlas {
    struct CacheKey: Hashable {
        let glyph: CGGlyph
        let bold: Bool
        let italic: Bool
    }

    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    private(set) var texture: MTLTexture!

    private var atlasWidth: Int = 1024
    private var atlasHeight: Int = 1024
    private var cursorX: Int = 0
    private var cursorY: Int = 0
    private var rowHeight: Int = 0
    private var cache: [CacheKey: GlyphInfo] = [:]

    init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
        texture = createTexture(width: atlasWidth, height: atlasHeight)
    }

    private func createTexture(width: Int, height: Int) -> MTLTexture {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = [.shaderRead]
        desc.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: desc) else {
            fatalError("Failed to create glyph atlas texture")
        }
        return texture
    }

    func lookup(glyph: CGGlyph, font: CTFont, bold: Bool = false, italic: Bool = false) -> GlyphInfo {
        let key = CacheKey(glyph: glyph, bold: bold, italic: italic)
        if let cached = cache[key] {
            return cached
        }
        return rasterize(glyph: glyph, font: font, key: key)
    }

    private func rasterize(glyph: CGGlyph, font: CTFont, key: CacheKey) -> GlyphInfo {
        var g = glyph
        var bbox = CGRect.zero
        CTFontGetBoundingRectsForGlyphs(font, .default, &g, &bbox, 1)

        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .default, &g, &advance, 1)

        let pad = 1
        let bw = Int(ceil(bbox.width)) + 2 * pad
        let bh = Int(ceil(bbox.height)) + 2 * pad

        guard bw > 0, bh > 0 else {
            let info = GlyphInfo(
                atlasX: 0,
                atlasY: 0,
                width: 0,
                height: 0,
                bearingX: 0,
                bearingY: 0,
                advance: Float(advance.width)
            )
            cache[key] = info
            return info
        }

        let bytesPerRow = bw
        let byteCount = bw * bh
        let raw = UnsafeMutableRawPointer.allocate(byteCount: byteCount, alignment: 1)
        defer { raw.deallocate() }
        raw.initializeMemory(as: UInt8.self, repeating: 0, count: byteCount)

        guard let ctx = CGContext(
            data: raw,
            width: bw,
            height: bh,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return .empty
        }

        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        ctx.setFillColor(gray: 1.0, alpha: 1.0)

        var pos = CGPoint(x: CGFloat(pad) - bbox.origin.x, y: CGFloat(pad) - bbox.origin.y)
        CTFontDrawGlyphs(font, &g, &pos, 1, ctx)

        if cursorX + bw > atlasWidth {
            cursorX = 0
            cursorY += rowHeight
            rowHeight = 0
        }
        if cursorY + bh > atlasHeight {
            growAtlas()
        }

        let region = MTLRegion(
            origin: MTLOrigin(x: cursorX, y: cursorY, z: 0),
            size: MTLSize(width: bw, height: bh, depth: 1)
        )
        texture.replace(region: region, mipmapLevel: 0, withBytes: raw, bytesPerRow: bytesPerRow)

        let info = GlyphInfo(
            atlasX: cursorX,
            atlasY: cursorY,
            width: bw,
            height: bh,
            bearingX: Float(bbox.origin.x) - Float(pad),
            bearingY: Float(bbox.origin.y + bbox.height) + Float(pad),
            advance: Float(advance.width)
        )
        cache[key] = info

        cursorX += bw
        rowHeight = max(rowHeight, bh)

        return info
    }

    private func growAtlas() {
        let newHeight = atlasHeight * 2
        let newTexture = createTexture(width: atlasWidth, height: newHeight)

        guard let cmdBuf = commandQueue.makeCommandBuffer(),
              let blit = cmdBuf.makeBlitCommandEncoder() else {
            return
        }

        blit.copy(
            from: texture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: atlasWidth, height: atlasHeight, depth: 1),
            to: newTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        blit.endEncoding()
        cmdBuf.commit()
        cmdBuf.waitUntilCompleted()

        texture = newTexture
        atlasHeight = newHeight
    }

    func clearCache() {
        cache.removeAll()
        cursorX = 0
        cursorY = 0
        rowHeight = 0
        texture = createTexture(width: atlasWidth, height: atlasHeight)
    }
}
