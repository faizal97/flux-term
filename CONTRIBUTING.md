# Contributing to FluxTerm

Thanks for your interest in contributing to FluxTerm.

## Getting Started

**Prerequisites**
- macOS 14 (Sonoma) or later
- Swift 5.9+ (included with Xcode 15+)
- A Metal-capable GPU (all modern Macs)

**Build**

```bash
git clone https://github.com/faizal97/flux-term.git
cd flux-term
swift build
```

**Run**

```bash
swift run FluxTerm
```

**Test**

```bash
swift test
```

## Project Structure

| Directory | Purpose |
|-----------|---------|
| `Sources/FluxTerm/App/` | App entry point, delegate, menu bar |
| `Sources/FluxTerm/Renderer/` | Metal rendering pipeline, shaders, glyph atlas |
| `Sources/FluxTerm/Terminal/` | Terminal session, keyboard encoding, config |
| `Sources/FluxTerm/UI/` | Window configuration |
| `Tests/FluxTermTests/` | Unit tests |

## Making Changes

1. Fork the repo and create a branch from `main`
2. Make your changes
3. Run `swift test` and make sure all tests pass
4. Run `swift build -c release` to verify the release build compiles
5. Open a pull request

## Code Style

- Follow existing patterns in the codebase
- Use Swift naming conventions (camelCase for variables/functions, PascalCase for types)
- Keep Metal shader code in `Shaders.metal` — match the existing SIMD type conventions in `ShaderTypes.swift`
- Add tests for new keyboard encoding or config logic

## Areas for Contribution

- Additional color themes
- Font configuration UI
- Tabs and split panes
- Settings persistence
- Performance profiling and optimization
- Additional test coverage

## Reporting Issues

Open an issue at [github.com/faizal97/flux-term/issues](https://github.com/faizal97/flux-term/issues) with:

- macOS version and Mac model
- Steps to reproduce
- Expected vs actual behavior
- Console output if applicable (`swift run FluxTerm 2>&1`)
