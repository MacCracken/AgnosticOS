# AGNOS Build Scripts

> Sovereign boot pipeline — written in Cyrius, compiled by cc5, zero bash dependencies.

## Quick Start

```bash
cd scripts/
cyrius build src/boot.cyr build/boot     # compile boot tool

# Interactive boot (default — fastest for development)
./build/boot

# Boot + validate AGNOS banner in serial output
./build/boot --test

# Show component versions and sizes across the sibling-repo tree
./build/boot --status

# Verify every component required for ISO assembly is present
./build/boot --iso-check

# Override the kernel path
./build/boot --kernel /path/to/agnos
```

## Programs

| Program | Purpose |
|---------|---------|
| `boot.cyr` | Assemble and boot AGNOS from sibling-repo components (kernel, toolchain, recipes). Sub-modes: `--test`, `--status`, `--iso-check`. |

## CLI

```
boot [OPTIONS]

Options:
  --test           Boot + validate AGNOS banner in serial output
  --status         Show component versions and sizes
  --iso-check      Verify all ISO components are present
  --kernel PATH    Path to AGNOS kernel binary
  -v, --verbose    Verbose output
  -h, --help       Show help
```

## How It Works

**Interactive boot** (default, fastest for development):
```
../../agnos/build/agnos → QEMU -kernel → serial output (Ctrl-A X to quit)
```

**Test boot** (`--test`):
```
../../agnos/build/agnos → QEMU -kernel → capture serial → search for "AGNOS" banner
```

**ISO check** (`--iso-check`): walks every required and optional subsystem
in the sibling-repo tree and reports `READY / MISS / SKIP` per component.

Full ISO assembly (squashfs + GRUB + xorriso) is Phase 13A work — not yet
implemented. `--iso-check` is the gate.

## Component Sources

| Component | Default Path | Override |
|-----------|--------------|----------|
| AGNOS kernel | `../../agnos/build/agnos` | `--kernel PATH` |
| Cyrius toolchain | `../../cyrius/build/cc5` | — (sibling repo) |
| Subsystems | `../../<name>/build/<name>` | — (sibling repo) |

Paths are relative to `scripts/` — the boot tool runs with `scripts/` as
its working directory and climbs `../../` to reach sibling repos.

## Testing

```bash
cyrius test tests/boot.tcyr
```

Tests cover path utilities, file-existence checks, vec-based arg building,
and the AGNOS-banner substring search pattern. They do not spawn QEMU;
full boot is an integration test.

## Archive

Pre-Cyrius bash scripts preserved at `archive-pre-cyrius/` for reference.
These were written for the Rust era (cargo build, Debian debootstrap,
Linux 6.6 kernel). They are not maintained and should not be used for
new work.

## License

GPL-3.0-only — Part of [AGNOS](https://agnosticos.org)
