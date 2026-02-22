import CoreGraphics
import CoreText
import Foundation
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
    private enum AtlasSlotReservation {
        case placed(x: Int, y: Int, generation: UInt64)
        case pendingGrowth
        case oversized
    }

    struct CacheKey: Hashable {
        let glyph: CGGlyph
        let bold: Bool
        let italic: Bool
    }

    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    private(set) var texture: MTLTexture!

    private let initialAtlasWidth: Int = 1024
    private let initialAtlasHeight: Int = 1024
    private let maxTextureDimension: Int = 8192
    private let stateLock = NSLock()
    private var atlasWidth: Int
    private var atlasHeight: Int
    private var cursorX: Int = 0
    private var cursorY: Int = 0
    private var rowHeight: Int = 0
    private var growthInFlight = false
    private var atlasGeneration: UInt64 = 0
    private var cache: [CacheKey: GlyphInfo] = [:]

    init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
        self.atlasWidth = initialAtlasWidth
        self.atlasHeight = initialAtlasHeight
        texture = createTexture(width: atlasWidth, height: atlasHeight)
    }

    private func withStateLock<T>(_ body: () -> T) -> T {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body()
    }

    private func createTexture(width: Int, height: Int) -> MTLTexture {
        guard let texture = makeTexture(width: width, height: height) else {
            fatalError("Failed to create glyph atlas texture")
        }
        return texture
    }

    private func makeTexture(width: Int, height: Int) -> MTLTexture? {
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = [.shaderRead]
        desc.storageMode = .shared
        return device.makeTexture(descriptor: desc)
    }

    func lookup(glyph: CGGlyph, font: CTFont, bold: Bool = false, italic: Bool = false) -> GlyphInfo {
        let key = CacheKey(glyph: glyph, bold: bold, italic: italic)
        if let cached = withStateLock({ cache[key] }) {
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
            let info = makeAdvanceOnlyGlyphInfo(advance: advance)
            withStateLock { cache[key] = info }
            return info
        }

        if bw > maxTextureDimension || bh > maxTextureDimension {
            let info = makeAdvanceOnlyGlyphInfo(advance: advance)
            withStateLock { cache[key] = info }
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

        let reservation = reserveSlot(width: bw, height: bh)
        switch reservation {
        case .pendingGrowth:
            return makeAdvanceOnlyGlyphInfo(advance: advance)
        case .oversized:
            let info = makeAdvanceOnlyGlyphInfo(advance: advance)
            withStateLock { cache[key] = info }
            return info
        case .placed(let atlasX, let atlasY, let generation):
            return withStateLock {
                guard atlasGeneration == generation else {
                    return makeAdvanceOnlyGlyphInfo(advance: advance)
                }

                let region = MTLRegion(
                    origin: MTLOrigin(x: atlasX, y: atlasY, z: 0),
                    size: MTLSize(width: bw, height: bh, depth: 1)
                )
                texture.replace(region: region, mipmapLevel: 0, withBytes: raw, bytesPerRow: bytesPerRow)

                let info = GlyphInfo(
                    atlasX: atlasX,
                    atlasY: atlasY,
                    width: bw,
                    height: bh,
                    bearingX: Float(bbox.origin.x) - Float(pad),
                    bearingY: Float(bbox.origin.y + bbox.height) + Float(pad),
                    advance: Float(advance.width)
                )
                cache[key] = info
                return info
            }
        }
    }

    private func makeAdvanceOnlyGlyphInfo(advance: CGSize) -> GlyphInfo {
        GlyphInfo(
            atlasX: 0,
            atlasY: 0,
            width: 0,
            height: 0,
            bearingX: 0,
            bearingY: 0,
            advance: Float(advance.width)
        )
    }

    private func reserveSlot(width: Int, height: Int) -> AtlasSlotReservation {
        withStateLock {
            if growthInFlight {
                return .pendingGrowth
            }

            var slotX = cursorX
            var slotY = cursorY
            var candidateRowHeight = rowHeight

            if slotX + width > atlasWidth {
                slotX = 0
                slotY += candidateRowHeight
                candidateRowHeight = 0
            }

            let requiredWidth = max(atlasWidth, width)
            let requiredHeight = slotY + height
            if requiredWidth > atlasWidth || requiredHeight > atlasHeight {
                if requiredWidth > maxTextureDimension || requiredHeight > maxTextureDimension {
                    return .oversized
                }

                _ = scheduleGrowthLocked(minWidth: requiredWidth, minHeight: requiredHeight)
                return .pendingGrowth
            }

            cursorX = slotX + width
            cursorY = slotY
            rowHeight = max(candidateRowHeight, height)

            return .placed(x: slotX, y: slotY, generation: atlasGeneration)
        }
    }

    private func scheduleGrowthLocked(minWidth: Int, minHeight: Int) -> Bool {
        let targetWidth = grownDimension(current: atlasWidth, minimum: minWidth)
        let targetHeight = grownDimension(current: atlasHeight, minimum: minHeight)

        guard targetWidth <= maxTextureDimension, targetHeight <= maxTextureDimension else {
            return false
        }

        let oldTexture = texture!
        let oldWidth = atlasWidth
        let oldHeight = atlasHeight
        let generation = atlasGeneration

        guard let newTexture = makeTexture(width: targetWidth, height: targetHeight) else {
            return false
        }

        guard let cmdBuf = commandQueue.makeCommandBuffer(),
              let blit = cmdBuf.makeBlitCommandEncoder() else {
            return false
        }

        growthInFlight = true

        blit.copy(
            from: oldTexture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: oldWidth, height: oldHeight, depth: 1),
            to: newTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        blit.endEncoding()

        cmdBuf.addCompletedHandler { [weak self] buffer in
            guard let self else { return }
            self.withStateLock {
                defer { self.growthInFlight = false }

                guard self.atlasGeneration == generation else {
                    return
                }
                guard buffer.status == .completed else {
                    return
                }

                self.texture = newTexture
                self.atlasWidth = targetWidth
                self.atlasHeight = targetHeight
            }
        }
        cmdBuf.commit()

        return true
    }

    private func grownDimension(current: Int, minimum: Int) -> Int {
        var dimension = max(1, current)
        while dimension < minimum {
            if dimension >= maxTextureDimension {
                return maxTextureDimension
            }
            dimension = min(dimension * 2, maxTextureDimension)
        }
        return dimension
    }

    func clearCache() {
        withStateLock {
            cache.removeAll()
            cursorX = 0
            cursorY = 0
            rowHeight = 0
            atlasGeneration &+= 1
            growthInFlight = false
            atlasWidth = initialAtlasWidth
            atlasHeight = initialAtlasHeight
            texture = createTexture(width: atlasWidth, height: atlasHeight)
        }
    }
}
