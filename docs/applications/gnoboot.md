# gnoboot

> **gnoboot** — AGNOS sovereign UEFI bootloader. Cyrius-native, replaces GRUB.

| Field | Value |
|-------|-------|
| Status | Released — v0.4.2 (post-MVP, FB-handoff observability + Quiet-Boot scanout work). Live version in [`VERSION`](https://github.com/MacCracken/gnoboot/blob/main/VERSION). |
| Repository | `MacCracken/gnoboot` |
| Runtime | UEFI Application (PE32+ EFI, x86_64) |
| Recipe | Not in zugot — boot loaders ship via `agnosticos/scripts/install-usb.sh` |
| MCP Tools | None (pre-kernel; no AGNOS userland to host MCP) |
| Agnoshi Intents | None |
| Cyrius pin | 6.0.1 |
| Pairs with | agnos ≥ 1.30.0 (current agnos 1.31.4 open) |

---

## Why First-Party

The AGNOS sovereignty pattern is: **own your stack**. Cyrius replaced gcc/clang/llvm; agnos replaced Linux; gnoboot replaces GRUB. Until gnoboot existed, AGNOS depended on a third-party bootloader whose multiboot2-EFI relocator broke under modern strict-W^X UEFI. gnoboot dissolves that dependency — AGNOS boots end-to-end on its own.

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

See the Path C plan for the full architecture, struct layout, and rationale.

Key invariants:
- **`fn efi_main(handle, st)` entry convention** — cyrius 5.11.52+ auto-emits the firmware-arg-capture trampoline (RCX → R14, RDX → R15) around `gvar_inits` + the call
- **`lib/fnptr.cyr` MS-x64 dispatch** — under `CYRIUS_TARGET_EFI=1`, cyrius predefines `CYRIUS_TARGET_WIN` too, so `fncallN`'s MS-x64 ABI branches fire for firmware calls
- **Byte-array literal globals** — UTF-16LE strings and EFI GUIDs declared as `var foo[N] = { 0x.., ... };` (cyrius 5.11.51+)

## Verification

- **QEMU OVMF**: `tests/ovmf_smoke.sh` in the gnoboot repo. Builds a GPT-disk-with-ESP, boots under `qemu-system-x86_64 -cpu max -machine q35` + OVMF firmware. Verified continuously through every minor release.
- **Iron (NUC AMD archaemenid)**: iron-validated end-to-end. MVP gate cleared on real hardware (2026-05-18, agnos 1.30.9) — `agnos> echo "Assembly Up!"` echoed on iron USB Logitech keyboard. Storage iron debuts followed: NVMe (Crucial P3 2 TB), AHCI/SATA (WD Blue SA510 2 TB), USB-MS (Silicon Motion stick, full INQUIRY/TUR/RC10).

## Status

- ✓ MVP handoff verified on QEMU OVMF emulation (2026-05-13)
- ✓ Iron MVP gate cleared on archaemenid NUC AMD (2026-05-18)
- ✓ FB-handoff observability bundle (GOP mode capture, serial diagnostic, CMOS stamp) — 0.3.0 → 0.4.x
- ⏳ AMD Zen Quiet-Boot scanout residue carry-forward (HUBP clear_tiling port or shadow-buffer eval) — parked at 0.4.2 closeout (2026-05-20)
- ⏳ aarch64 UEFI port (Pi 4) — gnoboot v0.9.0
- 🔒 Handoff contract freeze at gnoboot v1.0.0

Full roadmap: [gnoboot/docs/development/roadmap.md](https://github.com/MacCracken/gnoboot/blob/main/docs/development/roadmap.md).

## Cross-references

- [agnos](agnos.md) (when added) — the kernel gnoboot loads. agnos 1.30.0 cut the sovereign-struct ABI break that originally paired with gnoboot v0.1.0; current pairing is agnos 1.31.4 + gnoboot 0.4.2.
- [cyrius](https://github.com/MacCracken/cyrius) — toolchain. gnoboot's bring-up surfaced multiple cyrius issues that landed across v5.11.49 → v5.11.69 and into v6.0.x.
- Sovereign UEFI plan — full architecture
- Iron-boot test log — active iron boot log (post-MVP). gnoboot ships from early in the iron boot arc; full MVP-era arc is tracked in the iron boot log.

## Related ADRs (in gnoboot)

- [0001 — Sovereign boot-info struct over multiboot2](https://github.com/MacCracken/gnoboot/blob/main/docs/adr/0001-sovereign-struct-over-multiboot2.md)
