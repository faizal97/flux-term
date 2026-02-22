#include <metal_stdlib>
using namespace metal;

struct CellInstance {
    float2 gridPos;
    float4 glyphUV;
    float2 glyphBearing;
    float2 glyphSize;
    float4 fgColor;
    float4 bgColor;
    float4 flags;  // x: underline (0 or 1)
};

struct Uniforms {
    float2 viewportSize;
    float2 cellSize;
    float2 atlasSize;
    float2 gridOrigin;
};

struct BgOut {
    float4 position [[position]];
    float4 color;
    float4 fgColor;
    float2 cellUV;  // 0-1 within cell
    float underline;
};

vertex BgOut bg_vertex(
    uint vid [[vertex_id]],
    uint iid [[instance_id]],
    constant Uniforms &u [[buffer(0)]],
    constant CellInstance *cells [[buffer(1)]]
) {
    float2 unit;
    unit.x = (vid & 1) == 0 ? 0.0 : 1.0;
    unit.y = (vid & 2) == 0 ? 0.0 : 1.0;

    CellInstance cell = cells[iid];
    float2 pixel = u.gridOrigin + cell.gridPos * u.cellSize + unit * u.cellSize;

    float2 ndc;
    ndc.x = (pixel.x / u.viewportSize.x) * 2.0 - 1.0;
    ndc.y = 1.0 - (pixel.y / u.viewportSize.y) * 2.0;

    BgOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.color = cell.bgColor;
    out.fgColor = cell.fgColor;
    out.cellUV = unit;
    out.underline = cell.flags.x;
    return out;
}

fragment float4 bg_fragment(BgOut in [[stage_in]]) {
    float4 color = in.color;
    // Draw underline at bottom 1px-ish of cell.
    if (in.underline > 0.5 && in.cellUV.y > 0.92) {
        color = float4(in.fgColor.rgb, 1.0);
    }
    return color;
}

struct GlyphOut {
    float4 position [[position]];
    float2 texCoord;
    float4 fgColor;
};

vertex GlyphOut glyph_vertex(
    uint vid [[vertex_id]],
    uint iid [[instance_id]],
    constant Uniforms &u [[buffer(0)]],
    constant CellInstance *cells [[buffer(1)]]
) {
    float2 unit;
    unit.x = (vid & 1) == 0 ? 0.0 : 1.0;
    unit.y = (vid & 2) == 0 ? 0.0 : 1.0;

    CellInstance cell = cells[iid];
    float2 cellOrigin = u.gridOrigin + cell.gridPos * u.cellSize;
    float2 glyphOrigin = cellOrigin + cell.glyphBearing;
    float2 pixel = glyphOrigin + unit * cell.glyphSize;

    float2 ndc;
    ndc.x = (pixel.x / u.viewportSize.x) * 2.0 - 1.0;
    ndc.y = 1.0 - (pixel.y / u.viewportSize.y) * 2.0;

    float2 uv;
    uv.x = mix(cell.glyphUV.x, cell.glyphUV.z, unit.x) / u.atlasSize.x;
    uv.y = mix(cell.glyphUV.y, cell.glyphUV.w, unit.y) / u.atlasSize.y;

    GlyphOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.texCoord = uv;
    out.fgColor = cell.fgColor;
    return out;
}

fragment float4 glyph_fragment(
    GlyphOut in [[stage_in]],
    texture2d<float> atlas [[texture(0)]],
    sampler s [[sampler(0)]]
) {
    float coverage = atlas.sample(s, in.texCoord).r;
    return float4(in.fgColor.rgb, in.fgColor.a * coverage);
}

struct CursorUniforms {
    float2 viewportSize;
    float2 cellSize;
    float2 gridOrigin;
    float2 cursorPos;
    float4 cursorColor;
};

struct CursorOut {
    float4 position [[position]];
    float4 color;
};

vertex CursorOut cursor_vertex(
    uint vid [[vertex_id]],
    constant CursorUniforms &u [[buffer(0)]]
) {
    float2 unit;
    unit.x = (vid & 1) == 0 ? 0.0 : 1.0;
    unit.y = (vid & 2) == 0 ? 0.0 : 1.0;

    float2 pixel = u.gridOrigin + u.cursorPos * u.cellSize + unit * u.cellSize;

    float2 ndc;
    ndc.x = (pixel.x / u.viewportSize.x) * 2.0 - 1.0;
    ndc.y = 1.0 - (pixel.y / u.viewportSize.y) * 2.0;

    CursorOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.color = u.cursorColor;
    return out;
}

fragment float4 cursor_fragment(CursorOut in [[stage_in]]) {
    return in.color;
}

// Cursor bloom/glow effect.
struct BloomOut {
    float4 position [[position]];
    float2 uv;  // -1 to 1 within bloom quad
    float4 color;
};

vertex BloomOut cursor_bloom_vertex(
    uint vid [[vertex_id]],
    constant CursorUniforms &u [[buffer(0)]]
) {
    float2 unit;
    unit.x = (vid & 1) == 0 ? 0.0 : 1.0;
    unit.y = (vid & 2) == 0 ? 0.0 : 1.0;

    // Bloom extends 4px beyond cursor in each direction.
    float bloomPad = 4.0;
    float2 bloomOrigin = u.gridOrigin + u.cursorPos * u.cellSize - bloomPad;
    float2 bloomSize = u.cellSize + bloomPad * 2.0;
    float2 pixel = bloomOrigin + unit * bloomSize;

    float2 ndc;
    ndc.x = (pixel.x / u.viewportSize.x) * 2.0 - 1.0;
    ndc.y = 1.0 - (pixel.y / u.viewportSize.y) * 2.0;

    BloomOut out;
    out.position = float4(ndc, 0.0, 1.0);
    out.uv = unit * 2.0 - 1.0;  // Map to -1..1.
    out.color = u.cursorColor;
    return out;
}

fragment float4 cursor_bloom_fragment(BloomOut in [[stage_in]]) {
    // Gaussian-ish falloff from center.
    float dist = length(in.uv);
    float glow = exp(-dist * dist * 2.5);
    return float4(in.color.rgb, in.color.a * glow * 0.25);
}
