# Dhvani

> **Dhvani** (Sanskrit: sound) — Core audio engine

- **Repository**: [github.com/MacCracken/dhvani](https://github.com/MacCracken/dhvani)
- **License**: GPL-3.0-only
- **Status**: Stable - See Repo
- **Language**: Rust

See the [libs registry](../README.md) for the full catalog and dependency context.

---

## What It Does

- Audio buffer management with sample-accurate timing
- DSP primitives (filters, envelopes, oscillators, FFT)
- Sample rate conversion and format resampling
- Multi-channel mixing with per-channel gain and panning
- Audio analysis (spectrum, RMS, peak detection) and capture from system devices

## Consumers

- **shruti** — DAW (primary consumer, full DSP pipeline)
- **jalwa** — Media player (playback and EQ)
- **kiran** — Game engine (spatial audio, sound effects)
- **goonj** — Acoustics simulation backend

## Architecture

- Core audio buffer types with generic sample formats (f32, i16, i24)
- Lock-free ring buffers for real-time audio threads
