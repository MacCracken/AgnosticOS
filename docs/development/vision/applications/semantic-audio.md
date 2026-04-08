# Semantic Audio — Recipe-Based Sound Compression

> **Status**: Vision | **Last Updated**: 2026-04-05
>
> Audio as recipe, not recording. Describe the sound, transmit the recipe,
> regenerate perfectly at playback. 4,400x compression at higher fidelity than lossless.

---

## The Insight

Current audio compression stores **approximations of waveforms**. Even lossless formats store sampled snapshots of a continuous signal. The fundamental approach is: record → store samples → reconstruct from samples.

The semantic approach is different: **describe what the sound IS, then regenerate it**.

A piano note is not 44,100 samples per second. A piano note is an oscillator profile + an envelope + harmonics + a room response. If you have the synthesis engine, you only need to transmit the recipe.

---

## Compression Comparison

### Traditional (waveform-based)

| Format | Method | 3-min song | Quality |
|--------|--------|-----------|---------|
| WAV | Uncompressed PCM | ~31 MB | Perfect (sampled) |
| FLAC | Lossless entropy coding | ~15 MB | Perfect (sampled) |
| MP3 | Psychoacoustic lossy | ~3 MB | Lossy — frequencies discarded |
| Opus | Advanced lossy | ~1.5 MB | Better lossy — still discards |
| AAC | Apple lossy | ~2.5 MB | Lossy |

All of these store or approximate **waveforms** — the physical shape of the sound pressure over time.

### Semantic (recipe-based)

| Component | Size | What It Describes |
|-----------|------|-------------------|
| Instrument profile | ~2 KB | Oscillator type, harmonic series, attack/decay/sustain/release envelope (naad) |
| Score | ~4 KB | Note sequence with pitch, timing, velocity, duration (taal) |
| Room acoustics | ~500 B | Reverb profile, early reflections, RT60, room dimensions (goonj) |
| Mix parameters | ~200 B | Stereo position, EQ, compression, effects chain (dhvani) |
| Vocal description | ~3 KB | Glottal pulse model, formant tracks, phoneme sequence, prosody (svara) |
| **Total** | **~7 KB** | Complete description of a 3-minute song |

**7KB vs 31MB = 4,400x compression. At higher fidelity.**

### Why Higher Fidelity

This is not a marketing claim. It's math:

- **MP3/AAC/Opus**: throw away frequencies the psychoacoustic model says you "can't hear." You can. Audiophiles are not wrong — lossy compression is audibly worse.
- **FLAC/WAV**: store samples of a continuous waveform at 44.1/48/96 kHz. The sampling is an approximation — between samples, the true waveform is interpolated.
- **Semantic**: describes the **actual sound source** — the oscillator, the envelope, the harmonics, the room. Regeneration is mathematically perfect because it's synthesis from the source parameters, not reconstruction from samples.

The recipe IS the sound. Not a recording of the sound. The sound itself.

---

## AGNOS Crates Involved

The entire audio stack is already built:

| Crate | Role in Semantic Audio |
|-------|----------------------|
| **naad** (1.0.0) | Oscillator profiles — sine, saw, square, triangle, wavetable, FM, additive. The instrument engine. Every instrument is a naad parameter set. |
| **svara** (1.1.1) | Vocal synthesis — glottal pulse (Rosenberg model), formant tracks (Peterson & Barney), IPA phonemes, prosody contours. The voice IS the recipe. |
| **taal** (0.1.0) | Musical score — pitch, rhythm, timing, tempo, key signature, chord progressions. The composition IS the recipe. |
| **dhvani** (1.0.0) | Audio engine — mixing, DSP, effects chain, output. Regenerates the sound from all other crates' descriptions. |
| **goonj** (1.1.1) | Room acoustics — reverb modeling, room dimensions, surface materials, RT60. The space IS the recipe. |
| **garjan** (1.1.0) | Environmental sound — wind, rain, thunder, ambient. Environmental recipes. |
| **shravan** (1.0.1) | Codec interface — the encode/decode layer. Semantic codec lives here. |
| **shabda** (1.1.0) | Speech/G2P — text-to-phoneme for vocal track description. |

### The Codec

```
Encode (artist side):
  Live performance or DAW session
    → analysis: decompose into instrument profiles + score + room + mix
    → semantic representation: naad params + taal score + goonj room + dhvani mix
    → output: .sra file (Semantic Recipe Audio), ~7KB per song

Decode (listener side):
  .sra file
    → naad regenerates each instrument from oscillator profiles
    → svara regenerates vocals from glottal/formant/phoneme description
    → taal sequences the notes with correct timing
    → goonj applies room acoustics
    → dhvani mixes and outputs to speakers
    → result: mathematically perfect audio, synthesized live
```

### File Format: .sra (Semantic Recipe Audio)

```
[meta]
title = "Song Title"
artist = "Artist Name"
duration_ms = 180000
sample_rate = 48000
channels = 2

[instruments]
piano = { profile = "grand_steinway", naad_preset = "..." }
bass = { profile = "fretless_jaco", naad_preset = "..." }
drums = { profile = "jazz_kit", naad_preset = "..." }

[score]
# taal-compatible score format
# Each entry: instrument, pitch, velocity, start_ms, duration_ms
piano = [
  { pitch = "C4", vel = 80, start = 0, dur = 500 },
  { pitch = "E4", vel = 75, start = 500, dur = 500 },
  ...
]

[vocals]
# svara-compatible vocal description
track_1 = { phonemes = "...", prosody = "...", formants = "..." }

[room]
# goonj-compatible room profile
type = "concert_hall"
rt60 = 2.1
dimensions = [30, 20, 12]

[mix]
# dhvani-compatible mix parameters
piano = { pan = -0.3, gain = 0.8, eq = "..." }
bass = { pan = 0.1, gain = 0.7 }
```

---

## Challenges

### The Analysis Problem

Encoding from a live recording to a semantic recipe requires **sound source separation** — decomposing a mixed audio signal into individual instruments, vocals, and room characteristics. This is an active research area:

- **Demucs** (Meta, 2019-2023): state-of-the-art source separation, 4-stem (drums, bass, vocals, other)
- **Music Information Retrieval (MIR)**: pitch detection, onset detection, instrument classification
- **Room impulse response estimation**: from reverb tail analysis

This is the hard part. Synthesis (decode) is solved by naad/svara/taal. Analysis (encode) is where hoosh (LLM inference) and AI come in — using trained models to decompose recordings into semantic descriptions.

### The Hybrid Approach

Not all audio can be fully semanticized. Ambient recordings, field recordings, speech with background noise — some content needs waveform storage alongside the semantic recipe:

```
Fully semantic:    synthesized music, voice, sound design → 7KB
Hybrid:            semantic score + waveform residual → 50-500KB
Waveform fallback: field recording, ambient noise → FLAC/Opus (existing)
```

The format supports all three. The encoder chooses the optimal representation per track.

### Instrument Fidelity

A "piano" preset in naad must sound exactly like the intended piano. This requires:
- High-quality instrument sampling → wavetable profiles for naad
- Physical modeling parameters (string tension, hammer velocity, soundboard resonance)
- Artist-provided presets (the artist defines exactly how their instrument sounds)

This is where the creator economy connects: artists publish their instrument profiles alongside their music. The fan gets the recipe AND the instruments to play it. The artist's sonic identity is portable.

---

## Implications

### For Music Distribution

```
Current:  stream 3MB per song × billions of plays = massive bandwidth + server farms
Semantic: transmit 7KB per song × billions of plays = negligible bandwidth, no servers needed

The $2 SD card holds not thousands of compressed songs but MILLIONS of semantic recipes.
```

### For Artists

The semantic recipe is the ultimate stems release. The fan doesn't just listen — they can:
- Isolate any instrument
- Change the room acoustics (hear it in a cathedral vs a club)
- Adjust the mix
- Learn from the score (taal data is readable)
- Study the synthesis parameters

The recipe is open by nature. The artist shares the actual construction of the sound, not a flattened recording. This is radical transparency.

### For Preservation

A semantic recipe never degrades. There's no generation loss, no format obsolescence (the synthesis is mathematical), no bitrot. A .sra file from 2026 plays perfectly in 2126 because the oscillator math doesn't change.

The Library of Alexandria's music collection didn't survive because the recordings (wax cylinders, vinyl) degraded. Semantic recipes are math. Math doesn't degrade.

### For Bandwidth

A 7KB song transmits in milliseconds on any connection. Over the deep space relay network (see [space-infrastructure.md](../research/space-infrastructure.md)), an entire music library transmits in the time it currently takes to buffer one streaming song.

Voyager could receive the complete works of every musician on Earth. At 160bps, the entire semantic music library of humanity would take days, not centuries.

---

## Relationship to Other Vision Items

| Vision Item | Connection |
|-------------|-----------|
| **$2 SD Card** | Millions of albums in semantic format. The entire history of recorded music on one card. |
| **Creator Economy** | Artists publish .sra recipes via mela. vinimaya handles payment. No streaming platform. |
| **Holodeck** | Dynamic soundtrack generated live from semantic recipes, responsive to user actions |
| **Space Infrastructure** | Music library transmittable to orbital/deep space nodes at minimal bandwidth |
| **Conscious Objects** | A musical instrument with embedded AGNOS could load .sra recipes and play them physically |

---

## Prior Art & References

- Demucs: Défossez, A. et al. "Music Source Separation in the Waveform Domain." (2019, Meta/FAIR)
- MIDI: Musical Instrument Digital Interface (MMA, 1983) — the original "recipe" format, limited by synthesis quality
- Rosenberg, A.E. "Effect of Glottal Pulse Shape on Quality of Natural Vowels." *JASA* 49(2B), 1971 — svara's vocal model
- Peterson, G.E. & Barney, H.L. "Control Methods Used in a Study of the Vowels." *JASA* 24(2), 1952 — svara's formant data
- Smith, J.O. "Physical Audio Signal Processing." Stanford CCRMA, 2010 — physical modeling synthesis theory

---

*Last Updated: 2026-04-05*
