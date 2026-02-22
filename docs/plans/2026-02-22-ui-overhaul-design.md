# FluxTerm UI Overhaul Design — Premium Glass Terminal

## Vision

Transform FluxTerm from a functional terminal with basic glass aesthetics into a premium, polished glass terminal that feels like a native macOS first-class citizen. Leverage the existing Metal GPU pipeline to implement visual effects that would be impossible in CPU-rendered terminals.

## Design Direction

**Premium Glass Terminal** — refined blur effects, smooth animations, warm Catppuccin Mocha palette, subtle cursor glow, polished typography. Every detail considered. The kind of terminal that makes you want to keep it visible on your desktop.

## Architecture

All visual effects are implemented in the Metal shader pipeline (shader-first approach). The CPU manages animation state (cursor interpolation, blink timing) and passes it to the GPU via uniforms. No AppKit overlay hacks.

## Changes

### 1. Color Palette — Catppuccin Mocha

Replace the current Nord/One Dark palette with Catppuccin Mocha:

| Role | Hex | RGB |
|------|-----|-----|
| Background (Base) | `#1E1E2E` | (30, 30, 46) |
| Foreground (Text) | `#CDD6F4` | (205, 214, 244) |
| Cursor (Rosewater) | `#F5E0DC` | (245, 224, 220) |
| URL (Blue) | `#89B4FA` | (137, 180, 250) |
| Selection (Surface0) | `#313244` | (49, 50, 68) @ 70% opacity |
| Black | `#45475A` | (69, 71, 90) |
| Red | `#F38BA8` | (243, 139, 168) |
| Green | `#A6E3A1` | (166, 227, 161) |
| Yellow | `#F9E2AF` | (249, 226, 175) |
| Blue | `#89B4FA` | (137, 180, 250) |
| Magenta | `#F5C2E7` | (245, 194, 231) |
| Cyan | `#94E2D5` | (148, 226, 213) |
| White | `#BAC2DE` | (186, 194, 222) |
| Bright Black | `#585B70` | (88, 91, 112) |
| Bright Red | `#F38BA8` | same |
| Bright Green | `#A6E3A1` | same |
| Bright Yellow | `#F9E2AF` | same |
| Bright Blue | `#89B4FA` | same |
| Bright Magenta | `#CBA6F7` | (203, 166, 247) — Mauve |
| Bright Cyan | `#94E2D5` | same |
| Bright White | `#A6ADC8` | (166, 173, 200) |

### 2. Smooth Cursor Animation

**Positional glide:** Cursor smoothly interpolates from old position to new position using ease-out timing (~100ms duration). CPU tracks `currentCursorPos` and `targetCursorPos`, interpolates each frame, passes interpolated position to cursor shader via uniforms.

**Smooth blink:** Instead of hard on/off toggling, cursor opacity follows a sinusoidal fade: `opacity = 0.5 + 0.5 * cos(phase)` where phase advances over the blink cycle. This creates a gentle breathing effect.

**Subtle bloom:** A new shader pass renders a soft glow around the cursor. Implementation: render a slightly larger quad behind the cursor with the cursor color at very low opacity (~0.15), with a gaussian-ish falloff computed in the fragment shader. The bloom extends ~3px beyond the cursor bounds.

### 3. Window Chrome Refinement

- **Padding:** Increase from 8pt to 14pt for breathing room
- **Glass material:** Switch from `.hudWindow` to `.sidebar` material (slightly more translucent, warmer)
- **Background opacity:** Reduce from 0.85 to 0.78 to let the glass effect show through more
- **Traffic lights:** Inset from top-left with custom positioning (16pt from top, 14pt from left)
- **Window shadow:** Let the system handle this (already good with transparent windows)
- **Inner vignette:** Very subtle darkening at window edges via shader (optional, low priority)

### 4. Selection & Interaction Polish

**Selection highlight:** Instead of color-inverting selected cells (current behavior), use a distinct selection background color (Surface0 `#313244` at 70% opacity) with the foreground text preserved. This looks cleaner than inversion.

**URL hover:** When hovering a detected URL, render an underline decoration below the text (1px line at bottom of cell) in the URL color. Already have hover detection; just need the underline rendering.

### 5. Typography Refinements

- **Default font:** Switch from MesloLGS NF to JetBrains Mono (cleaner, more modern, excellent terminal font). Keep MesloLGS NF as first fallback for Nerd Font icon support.
- **Line spacing:** Add a `lineSpacingMultiplier` config (default 1.15) to add slight breathing room between lines. Applied by multiplying `cellHeight` after computing from font metrics.
- **Font size:** Increase default from 14pt to 14.5pt (subtle, but JetBrains Mono reads slightly smaller than Meslo).

## Files Affected

| File | Change |
|------|--------|
| `TerminalConfig.swift` | All color values, font, padding, line spacing, opacity |
| `Shaders.metal` | New cursor bloom pass, selection rendering, URL underline |
| `ShaderTypes.swift` | New CursorUniforms fields (bloom), selection uniforms |
| `MetalRenderer.swift` | Cursor animation state, bloom pipeline, selection rendering |
| `TerminalViewController.swift` | Cursor position interpolation, smooth blink timing |
| `MainWindow.swift` | Glass material, padding, traffic light positioning |

## What We're NOT Doing

- No tabs, split panes, or settings UI (v2+)
- No particle effects or excessive animation
- No custom titlebar drawing (leverage NSWindow's existing titlebar transparency)
- No ligature support (separate effort)
- No emoji/RGBA rendering (separate effort)
