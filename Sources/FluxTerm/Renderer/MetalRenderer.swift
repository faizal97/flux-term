import AppKit
import CoreText
import Foundation
import Metal
import QuartzCore
import SwiftTerm

final class MetalRenderer {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let glyphAtlas: GlyphAtlas
    var config: TerminalConfig

    private var bgPipeline: MTLRenderPipelineState!
    private var glyphPipeline: MTLRenderPipelineState!
    private var cursorPipeline: MTLRenderPipelineState!
    private var cursorBloomPipeline: MTLRenderPipelineState!
    private var sampler: MTLSamplerState!
    private var cachedFont: CTFont

    private let inflightCount = 3
    private var frameSemaphore: DispatchSemaphore
    private var frameIndex = 0
    private var instanceBuffers: [MTLBuffer] = []
    private var pendingGlyphAtlasClear = false

    private(set) var cellWidth: Float = 0
    private(set) var cellHeight: Float = 0
    private(set) var fontAscent: Float = 0

    init(device: MTLDevice, commandQueue: MTLCommandQueue, config: TerminalConfig) {
        self.device = device
        self.commandQueue = commandQueue
        self.config = config
        self.glyphAtlas = GlyphAtlas(device: device, commandQueue: commandQueue)
        self.frameSemaphore = DispatchSemaphore(value: inflightCount)
        self.cachedFont = config.font

        updateFontMetrics()
        buildPipelines()
        buildSampler()
        allocateBuffers()
    }

    func updateFontMetrics() {
        cachedFont = config.font
        let cell = config.cellSize
        cellWidth = Float(cell.width)
        cellHeight = Float(cell.height)
        fontAscent = Float(CTFontGetAscent(cachedFont))
    }

    func requestGlyphAtlasClear() {
        pendingGlyphAtlasClear = true
    }

    private func buildPipelines() {
        let library = loadMetalLibrary()

        let bgDesc = MTLRenderPipelineDescriptor()
        bgDesc.vertexFunction = library.makeFunction(name: "bg_vertex")
        bgDesc.fragmentFunction = library.makeFunction(name: "bg_fragment")
        let bgColorAttachment = bgDesc.colorAttachments[0]!
        bgColorAttachment.pixelFormat = .bgra8Unorm
        bgColorAttachment.isBlendingEnabled = true
        bgColorAttachment.sourceRGBBlendFactor = .sourceAlpha
        bgColorAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        bgColorAttachment.rgbBlendOperation = .add
        bgColorAttachment.sourceAlphaBlendFactor = .sourceAlpha
        bgColorAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        bgColorAttachment.alphaBlendOperation = .add
        bgPipeline = try! device.makeRenderPipelineState(descriptor: bgDesc)

        let glyphDesc = MTLRenderPipelineDescriptor()
        glyphDesc.vertexFunction = library.makeFunction(name: "glyph_vertex")
        glyphDesc.fragmentFunction = library.makeFunction(name: "glyph_fragment")
        let glyphColorAttachment = glyphDesc.colorAttachments[0]!
        glyphColorAttachment.pixelFormat = .bgra8Unorm
        glyphColorAttachment.isBlendingEnabled = true
        glyphColorAttachment.sourceRGBBlendFactor = .sourceAlpha
        glyphColorAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        glyphColorAttachment.rgbBlendOperation = .add
        glyphColorAttachment.sourceAlphaBlendFactor = .one
        glyphColorAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        glyphColorAttachment.alphaBlendOperation = .add
        glyphPipeline = try! device.makeRenderPipelineState(descriptor: glyphDesc)

        let cursorDesc = MTLRenderPipelineDescriptor()
        cursorDesc.vertexFunction = library.makeFunction(name: "cursor_vertex")
        cursorDesc.fragmentFunction = library.makeFunction(name: "cursor_fragment")
        let cursorColorAttachment = cursorDesc.colorAttachments[0]!
        cursorColorAttachment.pixelFormat = .bgra8Unorm
        cursorColorAttachment.isBlendingEnabled = true
        cursorColorAttachment.sourceRGBBlendFactor = .sourceAlpha
        cursorColorAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        cursorColorAttachment.rgbBlendOperation = .add
        cursorColorAttachment.sourceAlphaBlendFactor = .one
        cursorColorAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        cursorColorAttachment.alphaBlendOperation = .add
        cursorPipeline = try! device.makeRenderPipelineState(descriptor: cursorDesc)

        let bloomDesc = MTLRenderPipelineDescriptor()
        bloomDesc.vertexFunction = library.makeFunction(name: "cursor_bloom_vertex")
        bloomDesc.fragmentFunction = library.makeFunction(name: "cursor_bloom_fragment")
        let bloomColorAttachment = bloomDesc.colorAttachments[0]!
        bloomColorAttachment.pixelFormat = .bgra8Unorm
        bloomColorAttachment.isBlendingEnabled = true
        bloomColorAttachment.sourceRGBBlendFactor = .sourceAlpha
        bloomColorAttachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        bloomColorAttachment.rgbBlendOperation = .add
        bloomColorAttachment.sourceAlphaBlendFactor = .one
        bloomColorAttachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        bloomColorAttachment.alphaBlendOperation = .add
        cursorBloomPipeline = try! device.makeRenderPipelineState(descriptor: bloomDesc)
    }

    private func loadMetalLibrary() -> MTLLibrary {
        if let lib = try? device.makeDefaultLibrary(bundle: .module) {
            return lib
        }
        if let lib = device.makeDefaultLibrary() {
            return lib
        }
        if let source = loadShaderSource(),
           let lib = try? device.makeLibrary(source: source, options: nil) {
            return lib
        }

        fatalError("Failed to load Metal library: default library missing and source fallback unavailable")
    }

    private func loadShaderSource() -> String? {
        let bundles: [Bundle] = [.module, .main]
        for bundle in bundles {
            if let url = bundle.url(forResource: "Shaders", withExtension: "metal"),
               let source = try? String(contentsOf: url, encoding: .utf8) {
                return source
            }
            if let url = bundle.url(forResource: "Shaders", withExtension: "metal", subdirectory: "Renderer"),
               let source = try? String(contentsOf: url, encoding: .utf8) {
                return source
            }
            if let urls = bundle.urls(forResourcesWithExtension: "metal", subdirectory: nil),
               let url = urls.first(where: { $0.lastPathComponent == "Shaders.metal" }),
               let source = try? String(contentsOf: url, encoding: .utf8) {
                return source
            }
            if let urls = bundle.urls(forResourcesWithExtension: "metal", subdirectory: "Renderer"),
               let url = urls.first(where: { $0.lastPathComponent == "Shaders.metal" }),
               let source = try? String(contentsOf: url, encoding: .utf8) {
                return source
            }
        }

        let cwd = FileManager.default.currentDirectoryPath
        let devPath = URL(fileURLWithPath: cwd).appendingPathComponent("Sources/FluxTerm/Renderer/Shaders.metal")
        if let source = try? String(contentsOf: devPath, encoding: .utf8) {
            return source
        }

        return nil
    }

    private func buildSampler() {
        let desc = MTLSamplerDescriptor()
        desc.minFilter = .linear
        desc.magFilter = .linear
        desc.sAddressMode = .clampToZero
        desc.tAddressMode = .clampToZero
        sampler = device.makeSamplerState(descriptor: desc)
    }

    private func allocateBuffers() {
        let maxCells = 360 * 180
        let size = MemoryLayout<CellInstance>.stride * maxCells
        for _ in 0..<inflightCount {
            if let buf = device.makeBuffer(length: size, options: .storageModeShared) {
                instanceBuffers.append(buf)
            }
        }
        if instanceBuffers.isEmpty {
            fatalError("Failed to allocate renderer instance buffers")
        }
    }

    func draw(
        terminal: Terminal,
        drawable: CAMetalDrawable,
        scale: Float,
        isSelected: ((Int, Int) -> Bool)? = nil,
        isURLCell: ((Int, Int) -> Bool)? = nil,
        isHoveredURLCell: ((Int, Int) -> Bool)? = nil,
        cursorVisible: Bool = true,
        cursorOpacity: Float = 1.0,
        cursorDisplayPos: SIMD2<Float> = .zero
    ) {
        frameSemaphore.wait()
        if pendingGlyphAtlasClear {
            glyphAtlas.clearCache()
            pendingGlyphAtlasClear = false
        }

        let instanceBuffer = instanceBuffers[frameIndex % inflightCount]
        let cellCount = buildInstances(
            terminal: terminal,
            into: instanceBuffer,
            isSelected: isSelected,
            isURLCell: isURLCell,
            isHoveredURLCell: isHoveredURLCell
        )
        frameIndex += 1

        let viewportWidthPoints = Float(drawable.texture.width) / max(1.0, scale)
        let viewportHeightPoints = Float(drawable.texture.height) / max(1.0, scale)

        var uniforms = Uniforms(
            viewportSize: SIMD2(viewportWidthPoints, viewportHeightPoints),
            cellSize: SIMD2(cellWidth, cellHeight),
            atlasSize: SIMD2(Float(glyphAtlas.texture.width), Float(glyphAtlas.texture.height)),
            gridOrigin: SIMD2(Float(config.padding), Float(config.padding))
        )

        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = drawable.texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        let bg = config.backgroundColor
        pass.colorAttachments[0].clearColor = MTLClearColor(
            red: Double(bg.x),
            green: Double(bg.y),
            blue: Double(bg.z),
            alpha: 1.0
        )

        guard let cmdBuf = commandQueue.makeCommandBuffer(),
              let enc = cmdBuf.makeRenderCommandEncoder(descriptor: pass) else {
            frameSemaphore.signal()
            return
        }

        if cellCount > 0 {
            enc.setRenderPipelineState(bgPipeline)
            enc.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            enc.setVertexBuffer(instanceBuffer, offset: 0, index: 1)
            enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: cellCount)

            enc.setRenderPipelineState(glyphPipeline)
            enc.setFragmentTexture(glyphAtlas.texture, index: 0)
            enc.setFragmentSamplerState(sampler, index: 0)
            enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4, instanceCount: cellCount)
        }

        if cursorVisible {
            var cursorColor = config.cursorColor
            cursorColor.w *= cursorOpacity

            // Draw bloom first (behind cursor).
            var bloomUniforms = CursorUniforms(
                viewportSize: uniforms.viewportSize,
                cellSize: uniforms.cellSize,
                gridOrigin: uniforms.gridOrigin,
                cursorPos: cursorDisplayPos,
                cursorColor: cursorColor
            )
            enc.setRenderPipelineState(cursorBloomPipeline)
            enc.setVertexBytes(&bloomUniforms, length: MemoryLayout<CursorUniforms>.stride, index: 0)
            enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)

            // Draw cursor on top.
            var cursorUniforms = CursorUniforms(
                viewportSize: uniforms.viewportSize,
                cellSize: uniforms.cellSize,
                gridOrigin: uniforms.gridOrigin,
                cursorPos: cursorDisplayPos,
                cursorColor: cursorColor
            )
            enc.setRenderPipelineState(cursorPipeline)
            enc.setVertexBytes(&cursorUniforms, length: MemoryLayout<CursorUniforms>.stride, index: 0)
            enc.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        }

        enc.endEncoding()
        cmdBuf.present(drawable)
        cmdBuf.addCompletedHandler { [weak self] _ in
            self?.frameSemaphore.signal()
        }
        cmdBuf.commit()
    }

    private func buildInstances(
        terminal: Terminal,
        into buffer: MTLBuffer,
        isSelected: ((Int, Int) -> Bool)?,
        isURLCell: ((Int, Int) -> Bool)?,
        isHoveredURLCell: ((Int, Int) -> Bool)?
    ) -> Int {
        let maxCapacity = buffer.length / MemoryLayout<CellInstance>.stride
        let ptr = buffer.contents().bindMemory(to: CellInstance.self, capacity: maxCapacity)
        let font = cachedFont
        let defaultFg = config.foregroundColor
        let defaultBg = config.backgroundColor
        let opacity = config.backgroundOpacity

        var count = 0
        for row in 0..<terminal.rows {
            guard let line = terminal.getLine(row: row) else { continue }
            for col in 0..<terminal.cols {
                if count >= maxCapacity {
                    return count
                }

                let cell = line[col]
                if cell.width == 0 {
                    continue
                }

                var instance = CellInstance()
                instance.gridPos = SIMD2(Float(col), Float(row))

                instance.fgColor = resolveColor(cell.attribute.fg, defaultColor: defaultFg, isBackground: false)
                var bg = resolveColor(cell.attribute.bg, defaultColor: defaultBg, isBackground: true)
                bg.w = opacity
                instance.bgColor = bg

                if cell.attribute.style.contains(.inverse) {
                    let tmp = instance.fgColor
                    instance.fgColor = instance.bgColor
                    instance.fgColor.w = 1.0
                    instance.bgColor = tmp
                    instance.bgColor.w = opacity
                }

                let isURL = isURLCell?(col, row) == true
                let isHoveredURL = isHoveredURLCell?(col, row) == true
                if isURL || isHoveredURL {
                    instance.fgColor = config.urlColor
                    if isHoveredURL {
                        instance.flags.x = 1.0
                    }
                }

                if isSelected?(col, row) == true {
                    instance.bgColor = config.selectionColor
                }

                let char = terminal.getCharacter(for: cell)
                if char != " " && char != "\0" && !String(char).unicodeScalars.isEmpty {
                    let glyphID = getGlyph(for: char, font: font)
                    if glyphID != 0 {
                        let glyph = glyphAtlas.lookup(
                            glyph: glyphID,
                            font: font,
                            bold: cell.attribute.style.contains(.bold),
                            italic: cell.attribute.style.contains(.italic)
                        )
                        if glyph.width > 0 {
                            instance.glyphUV = SIMD4(
                                Float(glyph.atlasX),
                                Float(glyph.atlasY),
                                Float(glyph.atlasX + glyph.width),
                                Float(glyph.atlasY + glyph.height)
                            )
                            instance.glyphBearing = SIMD2(glyph.bearingX, fontAscent - glyph.bearingY)
                            instance.glyphSize = SIMD2(Float(glyph.width), Float(glyph.height))
                        }
                    }
                }

                ptr[count] = instance
                count += 1
            }
        }

        return count
    }

    private func getGlyph(for char: Character, font: CTFont) -> CGGlyph {
        var chars = Array(String(char).utf16)
        guard !chars.isEmpty else { return 0 }
        var glyphs = Array(repeating: CGGlyph(0), count: chars.count)
        CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count)
        return glyphs.first(where: { $0 != 0 }) ?? 0
    }

    private func resolveColor(_ color: Attribute.Color, defaultColor: SIMD4<Float>, isBackground: Bool) -> SIMD4<Float> {
        switch color {
        case .defaultColor:
            return isBackground ? config.backgroundColor : defaultColor
        case .defaultInvertedColor:
            return isBackground ? config.backgroundColor : config.foregroundColor
        case .trueColor(let red, let green, let blue):
            return SIMD4(Float(red) / 255.0, Float(green) / 255.0, Float(blue) / 255.0, 1.0)
        case .ansi256(let code):
            return colorForANSI256(code: Int(code))
        }
    }

    private func colorForANSI256(code: Int) -> SIMD4<Float> {
        if code < config.colors.count {
            return config.colors[code]
        }

        if code >= 16 && code <= 231 {
            let idx = code - 16
            let r = idx / 36
            let g = (idx / 6) % 6
            let b = idx % 6
            let table: [Float] = [0, 95, 135, 175, 215, 255]
            return SIMD4(table[r] / 255.0, table[g] / 255.0, table[b] / 255.0, 1.0)
        }

        if code >= 232 && code <= 255 {
            let gray = Float(8 + (code - 232) * 10) / 255.0
            return SIMD4(gray, gray, gray, 1.0)
        }

        return config.foregroundColor
    }

    func gridSize(for viewSize: CGSize) -> (cols: Int, rows: Int) {
        Self.computeGridSize(
            viewSize: viewSize,
            padding: config.padding,
            cellWidth: cellWidth,
            cellHeight: cellHeight
        )
    }

    static func computeGridSize(
        viewSize: CGSize,
        padding: CGFloat,
        cellWidth: Float,
        cellHeight: Float
    ) -> (cols: Int, rows: Int) {
        let paddingPoints = Float(padding) * 2.0
        let widthPoints = Float(viewSize.width) - paddingPoints
        let heightPoints = Float(viewSize.height) - paddingPoints
        let cols = max(1, Int(widthPoints / max(1, cellWidth)))
        let rows = max(1, Int(heightPoints / max(1, cellHeight)))
        return (cols, rows)
    }
}
