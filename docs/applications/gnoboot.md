# gnoboot

> **gnoboot** — AGNOS sovereign UEFI bootloader. Cyrius-native, replaces GRUB.

| Field | Value |
|-------|-------|
| Status | Released — v0.1.0 (2026-05-13) |
| Version | [`VERSION`](https://github.com/MacCracken/gnoboot/blob/main/VERSION) |
| Repository | `MacCracken/gnoboot` |
| Runtime | UEFI Application (~6 KB PE32+ EFI, x86_64) |
| Recipe | Not in zugot — boot loaders ship via `agnosticos/scripts/install-usb.sh` |
| MCP Tools | None (pre-kernel; no AGNOS userland to host MCP) |
| Agnoshi Intents | None |
| Cyrius pin | 5.11.53 |
| Pairs with | agnos ≥ 1.30.0 |

---

## Why First-Party

The AGNOS sovereignty pattern is: **own your stack**. Cyrius replaced gcc/clang/llvm; agnos replaced Linux; gnoboot replaces GRUB. Until gnoboot existed, AGNOS depended on a third-party bootloader whose multiboot2-EFI relocator broke under modern strict-W^X UEFI (see [iron-nuc-zen log § Diagnosis 2](../development/iron-nuc-zen-log.md)). gnoboot dissolves that dependency — AGNOS boots end-to-end on its own.

## What It Does

- UEFI firmware loads gnoboot at `\EFI\BOOT\BOOTX64.EFI`
- gnoboot opens `\boot\agnos` from the ESP via `SimpleFileSystemProtocol`
- Parses the ELF64 program header; AllocatePages per PT_LOAD at the kernel's physical address (`0x100000` for agnos)
- Reads kernel segment data directly into place
- Builds the AGNOS sovereign boot-info struct (magic `'AGNO' = 0x41474E4F`, version 1, memmap + EFI SystemTable pointer + END tag — 80 bytes total)
- Calls `bs->GetMemoryMap` (fresh `mm_key`), then `bs->ExitBootServices(handle, mm_key)`
- Jumps to kernel entry with `RDI = &boot_info` (sovereign-struct handoff contract)

After ExitBootServices, ConOut is gone; any further diagnostic comes from the kernel's own UART driver.

## Architecture

See [Path C plan](../development/path-c-sovereign-uefi.md) for the full architecture, struct layout, and rationale.

Key invariants:
- **`fn efi_main(handle, st)` entry convention** — cyrius 5.11.52+ auto-emits the firmware-arg-capture trampoline (RCX → R14, RDX → R15) around `gvar_inits` + the call
- **`lib/fnptr.cyr` MS-x64 dispatch** — under `CYRIUS_TARGET_EFI=1`, cyrius predefines `CYRIUS_TARGET_WIN` too, so `fncallN`'s MS-x64 ABI branches fire for firmware calls
- **Byte-array literal globals** — UTF-16LE strings and EFI GUIDs declared as `var foo[N] = { 0x.., ... };` (cyrius 5.11.51+)

## Verification

- **QEMU OVMF**: `tests/ovmf_smoke.sh` in the gnoboot repo. Builds a GPT-disk-with-ESP, boots under `qemu-system-x86_64 -cpu max -machine q35` + OVMF firmware. Verified 2026-05-13: gnoboot delivers agnos 1.30.0's banner + 9 init checkpoints through `Activating scheduler`.
- **Iron (NUC AMD)**: pending Attempt 5. Provisioning via `agnosticos/scripts/install-usb.sh`.

## Status

- ✓ MVP handoff verified on QEMU OVMF emulation (2026-05-13)
- ⏳ Iron Attempt 5 on NUC AMD — pending
- ⏳ Full boot-info field population (cmdline, initramfs, ACPI RSDP) — gnoboot v0.3.0–v0.4.0
- ⏳ aarch64 UEFI port (Pi 4) — gnoboot v0.9.0
- 🔒 Handoff contract freeze at gnoboot v1.0.0

Full roadmap: [gnoboot/docs/development/roadmap.md](https://github.com/MacCracken/gnoboot/blob/main/docs/development/roadmap.md).

## Cross-references

- [agnos](agnos.md) (when added) — the kernel gnoboot loads. agnos 1.30.0 cuts the sovereign-struct ABI break that pairs with gnoboot v0.1.0.
- [cyrius](https://github.com/MacCracken/cyrius) — toolchain. gnoboot's bring-up filed 4 cyrius issues (3 landed in v5.11.49–v5.11.53, 1 pending for v5.11.54).
- [Path C plan](../development/path-c-sovereign-uefi.md) — full architecture
- [Iron-boot test log](../development/iron-nuc-zen-log.md) — running log of iron boot attempts; gnoboot is Attempt 5+

## Related ADRs (in gnoboot)

- [0001 — Sovereign boot-info struct over multiboot2](https://github.com/MacCracken/gnoboot/blob/main/docs/adr/0001-sovereign-struct-over-multiboot2.md)
