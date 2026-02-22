import simd

struct CellInstance {
    var gridPos: SIMD2<Float> = .zero
    var glyphUV: SIMD4<Float> = .zero
    var glyphBearing: SIMD2<Float> = .zero
    var glyphSize: SIMD2<Float> = .zero
    var fgColor: SIMD4<Float> = .init(1, 1, 1, 1)
    var bgColor: SIMD4<Float> = .init(0, 0, 0, 0)
    var flags: SIMD4<Float> = .zero  // x: underline (0 or 1), y-w: reserved
}

struct Uniforms {
    var viewportSize: SIMD2<Float> = .zero
    var cellSize: SIMD2<Float> = .zero
    var atlasSize: SIMD2<Float> = .zero
    var gridOrigin: SIMD2<Float> = .zero
}

struct CursorUniforms {
    var viewportSize: SIMD2<Float> = .zero
    var cellSize: SIMD2<Float> = .zero
    var gridOrigin: SIMD2<Float> = .zero
    var cursorPos: SIMD2<Float> = .zero
    var cursorColor: SIMD4<Float> = .init(1, 1, 1, 1)
}
