# AGNOS Build Scripts

> Sovereign boot pipeline — written in Cyrius, compiled by cc3, zero bash dependencies.

## Quick Start

```bash
cd scripts/
cyrius deps                              # resolve stdlib
cyrius build src/boot.cyr build/boot     # compile boot tool

# Dev: boot kernel directly (fastest)
./build/boot --direct

# Dev: boot + validate
./build/boot --test

# Release: build bootable ISO
./build/boot --iso-only

# Phase 13A: self-hosting ISO (includes toolchain + source + recipes)
./build/boot --selfhost --test
```

## Programs

| Program | Purpose |
|---------|---------|
| `boot.cyr` | Assemble and boot AGNOS from components (kernel, toolchain, recipes) |
| `validate.cyr` | Selfhost validation — prove AGNOS can rebuild itself (Phase 13A) |

## How It Works

**Direct boot** (default, fastest for development):
```
../agnos/build/agnos → QEMU -kernel → serial output → validate banner
```

**ISO boot** (for real hardware and release):
```
../agnos/build/agnos → ELF fixup → GRUB config → grub-mkrescue → ISO → QEMU -cdrom
```

**Self-hosting ISO** (Phase 13A — proves sovereignty):
```
kernel + Cyrius toolchain (cc3 + seed) + zugot recipes + source → ISO
Boot → rebuild everything from source inside the booted system → validate
```

## Component Sources

| Component | Default Path | Override |
|-----------|-------------|---------|
| AGNOS kernel | `../agnos/build/agnos` | `--kernel PATH` |
| Cyrius toolchain | `../cyrius/` | `--toolchain PATH` |
| Zugot recipes | `../zugot/` | `--recipes PATH` |
| Output | `output/` | `--output PATH` |

## Archive

Pre-Cyrius bash scripts preserved at `archive-pre-cyrius/` for reference.
These were written for the Rust era (cargo build, Debian debootstrap, Linux 6.6 kernel).
They are not maintained and should not be used for new work.

## License

GPL-3.0-only — Part of [AGNOS](https://agnosticos.org)
