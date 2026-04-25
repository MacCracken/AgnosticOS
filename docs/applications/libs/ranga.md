# Ranga

> **Ranga** (Sanskrit: color) — Core image processing library

- **Version**: 1.0.0
- **Repository**: [github.com/MacCracken/ranga](https://github.com/MacCracken/ranga)
- **License**: GPL-3.0-only
- **Status**: v1.0+ stable

See the [shared-crates registry](../../development/applications/shared-crates.md) for full context and dependency graph.

---

## What It Does

- Color space conversions (sRGB, linear RGB, HSL, HSV, CMYK, CIE Lab)
- Blend modes (normal, multiply, screen, overlay, soft light, and more)
- Pixel buffer operations with generic pixel formats
- Image filters (blur, sharpen, edge detect, color correction)
- GPU-accelerated compute path via ai-hwaccel when available

## Consumers

- **rasa** — AI-native image editor (primary consumer)
- **selah** — Screenshot and annotation tool (image manipulation)
- **aethersafha** — Desktop compositor (compositing pipeline)

## Architecture

- Pure-language core with optional GPU compute backend
- Generic over pixel type for zero-copy interop
- Optional dependency on ai-hwaccel
