> **Last Updated**: 2026-05-14
> **Scope**: Comparison reference for AGNOS Path C (`gnoboot` sovereign UEFI bootloader) against mainstream and hobbyist OS UEFI boot paths.
> **Why this doc exists**: After the 2026-05-13 pivot from GRUB-multiboot2 to a sovereign UEFI application, we wanted an independent check on whether Path C is a sane endpoint or a reinvention of a thing everyone else abandoned. Short answer: sane. Long answer below.

# UEFI Boot Path Prior-Art Reference

## TL;DR

Path C (gnoboot loads kernel from ESP, locates GOP, captures memmap + RSDP, calls `ExitBootServices`, jumps to kernel with `RDI = &boot_info`) is **the same shape Linux, FreeBSD, OpenBSD, Windows, and Limine all use**. The only differences are stylistic — one PE binary vs two, flat struct vs request/response table, lower-half vs higher-half kernel mapping.

The thing AGNOS *abandoned* — GRUB-multiboot2-EFI handoff via `grub_relocator64_efi_boot` — is the path the industry has been quietly walking away from since 2023, and which the strict-NX OVMF cliff in late 2024 / early 2025 made explicitly broken. AGNOS hit the cliff on 2026-05-13 because OVMF 2024+ is the strict configuration. Linux distros don't trip this only because they boot via `linuxefi` / EFI stub, not multiboot2.

**Path C is mainstream. The "sovereign" framing is about toolchain (Cyrius vs C/edk2), not architecture.**

---

## 1. Linux — EFI stub (PE/COFF kernel)

The modern Linux UEFI boot path has **two layers that should not be confused**:

### (a) The EFI Handover Protocol — deprecated

A bootloader like GRUB loads the bzImage from disk itself, fills `boot_params` (`hdr.cmd_line_ptr`, `hdr.ramdisk_image`, `hdr.ramdisk_size`), then jumps to `startup_64 + handover_offset + 0x200` with `(handle, system_table, boot_params)` as arguments. `handover_offset` is at offset `0x264` of the kernel header (boot protocol 2.11+). Capability is advertised through xloadflags bits: `XLF_KERNEL_64` (bit 0), `XLF_EFI_HANDOVER_32` (bit 2), `XLF_EFI_HANDOVER_64` (bit 3). Boot services are still active at handoff; the kernel itself calls `ExitBootServices()`. Kernel docs now explicitly state: *"The EFI Handover Protocol is deprecated in favour of the ordinary PE/COFF entry point."*

### (b) The EFI Stub — the modern path

The bzImage **is itself a valid PE/COFF executable**. UEFI firmware (or systemd-boot, which is just a PE chainloader) loads it directly via `LoadImage`/`StartImage`. The stub:

1. Locates GOP via `LocateProtocol(EFI_GRAPHICS_OUTPUT_PROTOCOL_GUID)`.
2. Captures the memory map via `GetMemoryMap`.
3. Locates ACPI tables through the EFI configuration table.
4. Calls `ExitBootServices`.
5. Sets up its own page tables.
6. Jumps to the decompressor/kernel proper.

The shift accelerated through 2023-2024: v6.1 folded zboot decompression into the stub flow; v6.7 stabilized the x86 PE/COFF entry. By 2025 modern distros (Fedora 41+, Arch, Debian) ship UKIs ("Unified Kernel Images") — signed PE binaries chainloaded by systemd-boot or executed directly. The bootloader's role has shrunk to "find the file and call `StartImage`."

**Key files**:
- `arch/x86/boot/header.S` — PE header, handover offset, xloadflags
- `drivers/firmware/efi/libstub/x86-stub.c` — `efi_pe_entry`, `efi_main`, `exit_boot`
- `drivers/firmware/efi/libstub/efi-stub-helper.c` — `efi_get_memory_map`, GOP location
- `drivers/firmware/efi/libstub/screen_info.c` — framebuffer info into `screen_info` struct
- `arch/x86/boot/compressed/head_64.S` — what runs after `ExitBootServices`

**For AGNOS**: the Linux design has converged on the same shape gnoboot uses — *the loader exits boot services, sets up its own page tables, locates GOP/memmap/RSDP itself.* The only structural difference is that Linux's stub is linked into the kernel image. gnoboot keeps the loader separate, which is closer to FreeBSD / Windows / Limine.

References:
- [The EFI Boot Stub — kernel.org docs](https://docs.kernel.org/admin-guide/efi-stub.html)
- [Linux/x86 Boot Protocol — kernel.org](https://www.kernel.org/doc/html/latest/arch/x86/boot.html)
- [LWN: efi/x86 avoid legacy decompressor](https://lwn.net/Articles/930063/)
- [LWN: avoid bare-metal decompressor](https://lwn.net/Articles/940693/)

---

## 2. FreeBSD — `loader.efi` with trampoline copy

FreeBSD's UEFI loader lives at `stand/efi/loader/` (formerly `sys/boot/efi`). The binary `loader.efi` is itself a PE/COFF UEFI application, installed as `/boot/loader.efi` and often copied to `EFI/BOOT/BOOTX64.EFI` for removable-media boot.

Flow:

1. `efi_main()` in `stand/efi/loader/main.c` initializes services.
2. Loads the kernel ELF and module preloads into a "staging area" while boot services are still alive.
3. Constructs metadata via `bi_load_efi_data()` in `stand/efi/loader/bootinfo.c` — packs the `modinfo` blob with `MODINFOMD_EFI_MAP`, `MODINFOMD_EFI_FB`, etc.
4. Calls `ExitBootServices`.
5. Historically: ran `amd64_tramp` → `efi_copy_finish()` to relocate the kernel to physical 2M *after* EBS. Caused the well-known "freezes on certain UEFI firmware" bugs because `efi_copy_finish` could overwrite its own code if firmware loaded the trampoline near 2M. Fixed in [D30828](https://reviews.freebsd.org/D30828); modern non-copying staging mode runs the kernel from staging directly if it's below 4G, 2M-aligned, and the low 4G is identity-mapped at handoff.

The kernel's `btext`/`hammer_time` reads `modinfo` via standard FreeBSD `kmdp` (kernel metadata preload) walking. Framebuffer info comes through `MODINFOMD_EFI_FB` — GOP captured in the loader, not self-located by the kernel.

References:
- [stand/efi/loader/bootinfo.c](https://github.com/freebsd/freebsd-src/blob/master/stand/efi/loader/bootinfo.c)
- [D30828 — EFI boot freeze fix](https://reviews.freebsd.org/D30828)
- [Klara Systems: FreeBSD Boot Process](https://klarasystems.com/articles/the-freebsd-boot-process/)

---

## 3. OpenBSD — `efiboot/BOOTX64.EFI`

OpenBSD's UEFI loader is in `sys/arch/amd64/stand/efiboot/`. Entry is `efi_main()` in `efiboot.c`; the kernel-launch sequence is in `exec_i386.c` (`run_loadfile`) and the asm trampoline in `start_amd64.S`.

Flow:

1. Load `bsd` ELF from FFS via the loader's filesystem layer.
2. Build the `boot_args` chain (`bootarg.h` — `BAPIV_EFI = 0x10` flag identifies EFI boot).
3. Append bootargs: `bootmac`, DDB settings, boot disk UUID, microcode address/size, softraid UUID/maskkey.
4. `efi_cleanup()` calls `GetMemoryMap` → `ExitBootServices`, **retrying once on `EFI_INVALID_PARAMETER`** (per UEFI spec the memory map can change between Get and Exit — a foot-gun gnoboot should make sure it handles too if it doesn't already).
5. `mem_pass()` packs the EFI memmap into the boot-args blob.
6. `run_i386(...)` invokes the kernel entry with `(howto, bootdev, BOOTARG_APIVER, end, extmem, cnvmem, ac, av)` on the stack.

On SEV-enabled platforms, `protect_writeable()` walks CR3-based page tables to add write permissions where needed. **OpenBSD inherits UEFI's identity map** rather than building its own at the loader stage — the kernel re-establishes its own page tables shortly after entry. Same pattern as gnoboot + agnos.

References:
- [start_amd64.S](https://github.com/openbsd/src/blob/master/sys/arch/amd64/stand/efiboot/start_amd64.S)
- [exec_i386.c](https://github.com/openbsd/src/blob/master/sys/arch/amd64/stand/efiboot/exec_i386.c)
- [OpenBSD UEFI bootloader howto](https://jasper.la/posts/openbsd-uefi-bootloader-howto/)

---

## 4. Windows — `bootmgfw.efi → winload.efi → ntoskrnl.exe`

Windows is a three-stage PE chain:

1. `\EFI\Microsoft\Boot\bootmgfw.efi` (Boot Manager) is loaded by firmware. Reads the BCD store at `\EFI\Microsoft\Boot\BCD` to find the OS entry, then `LoadImage`/`StartImage`s `winload.efi`.
2. `\Windows\System32\winload.efi` (OS Loader):
   - Reads the kernel and boot drivers using `EFI_BLOCK_IO_PROTOCOL` / `EFI_SIMPLE_FILE_SYSTEM_PROTOCOL`.
   - Constructs the `LOADER_PARAMETER_BLOCK` — the giant structure containing memory map, ACPI table addresses, GOP framebuffer info, registry hive pointers, kernel parameters.
   - Calls `ExitBootServices`.
   - Jumps into `ntoskrnl.exe` (`KiSystemStartup`) with `RCX` pointing at the loader block.

**Windows hands off with a struct pointer in a register, exits boot services in the loader, and passes a fully-cooked memory map and framebuffer info to the kernel.** Structurally identical to gnoboot's handoff, modulo ABI (RCX for MS x64 vs RDI for SysV).

References:
- [UEFI Plugfest: Windows Boot Environment (Ravirala, Microsoft)](https://uefi.org/sites/default/files/resources/UEFI-Plugfest-WindowsBootEnvironment.pdf)
- [Microsoft Learn: UEFI CA Memory Mitigation Requirements](https://learn.microsoft.com/en-us/windows-hardware/drivers/bringup/uefi-ca-memory-mitigation-requirements)

---

## 5. Limine / systemd-boot / hobbyist sovereign loaders

### Limine — the closest mainstream analog to gnoboot

[Limine](https://github.com/limine-bootloader/limine) is a UEFI application that loads an ELF kernel, locates GOP, captures the memory map, exits boot services, and jumps to the kernel. Differences from gnoboot's flat-struct design:

- **Request/response protocol, not a flat struct.** The kernel embeds tagged "request" structures (each with a magic ID, revision, and a `response` pointer field) anywhere in its image. Limine scans the loaded ELF for these tags and writes a response pointer into each one. Kernel reads `request.response->framebuffer_count`, `response->memmap_entries`, `response->rsdp_address`, etc. More extensible than a fixed struct, more complex.
- **Higher half mapping.** Limine maps kernels at or above `0xffffffff80000000` and provides a "Higher Half Direct Map" (HHDM) of all physical memory. AGNOS currently runs at `0x1000a8` physical — lower-half, which is fine for MVP but suggests adding a higher-half mapping when userspace lands.
- **Defined x86-64 entry state**: GDT loaded with null/16/32/64-bit code+data, IDT undefined (kernel loads its own), CR0.PG/PE/WP set, CR4.PAE set, EFER.LME/NX set, IF/DF cleared, all GPRs zeroed except RSP (≥64KiB stack provided by bootloader), 4-level paging by default, 5-level optional. **The kernel is entered via the ELF entry point — no struct in RDI**; data is fetched on demand from the request/response table.
- **C ABI**: SysV AMD64 (i.e., RDI is arg 0 if the kernel chose to use it, but Limine doesn't).

### systemd-boot — not a kernel loader

`sd-boot` is a PE-chainloader only. It locates a target `.efi` file (Linux EFI stub, GRUB, Windows BM) and calls `LoadImage`/`StartImage`. The EFI stub (or whatever the next stage is) does all the real boot work.

### Other small sovereign loaders

- [BOOTBOOT](https://wiki.osdev.org/BOOTBOOT) — Defines a fixed struct passed to the kernel; popular reference design.
- [Simple-UEFI-Bootloader](https://github.com/KunYi/Simple-UEFI-Bootloader) — Loads PE32+/ELF/Mach-O, single-binary, struct in RCX.
- [ajxs/uefi-elf-bootloader](https://github.com/ajxs/uefi-elf-bootloader) — Pedagogical "Kernel_Boot_Info struct" pattern. Most closely resembles gnoboot.

**Pattern match for gnoboot's design**: a fixed-layout struct passed in RDI is the *standard hobbyist OS pattern*. Limine's request/response is the more sophisticated variant; both are valid. AGNOS is not reinventing anything that was abandoned — it's adopting the same shape Limine and the BSDs use, just with a flat 112-byte struct instead of a request table.

References:
- [Limine PROTOCOL.md v8.x](https://github.com/limine-bootloader/limine/blob/v8.x/PROTOCOL.md)
- [OSDev: Limine Bare Bones](https://wiki.osdev.org/Limine_Bare_Bones)
- [BOOTBOOT spec](https://wiki.osdev.org/BOOTBOOT)
- [systemd-boot manpage](https://www.freedesktop.org/software/systemd/man/latest/systemd-boot.html)
- [systemd-stub manpage](https://www.freedesktop.org/software/systemd/man/latest/systemd-stub.html)

---

## 6. Common UEFI handoff contract — synthesis

Across Linux EFI stub, FreeBSD loader, OpenBSD efiboot, Windows winload, and Limine, the post-`ExitBootServices` state the kernel actually inherits is remarkably consistent.

| Property | Standard practice |
|---|---|
| **Page tables** | UEFI's identity map for all of low memory (per UEFI 2.10 §2.3.4: x64 must be in long mode with paging enabled, identity-mapped, PAE+NX on). Every kernel rebuilds its own page tables shortly after entry. **No loader hands off "proper" kernel page tables** — the firmware's identity map is the contract. |
| **GDT** | UEFI's GDT survives; every kernel reloads its own GDT immediately. No standard layout is contractual. |
| **IDT** | Undefined / firmware's. Every kernel installs its own. |
| **CR0** | `PG=1, PE=1, WP=1, NE=1`. Standard. |
| **CR4** | `PAE=1`. `OSFXSR`, `OSXMMEXCPT` typically set. SMEP/SMAP **NOT** guaranteed — kernel sets these. |
| **EFER** | `LME=1, LMA=1, NXE=1`. Standard. |
| **Interrupts** | Disabled (IF=0). |
| **Framebuffer** | Passed via struct (Windows loader block, FreeBSD modinfo, Limine response, gnoboot's struct). Linux stub self-locates GOP before EBS. Either pattern is valid. After EBS the framebuffer keeps displaying — just keep writing pixels. |
| **Memory map** | Passed via struct (everyone). Self-acquisition after EBS is impossible — `GetMemoryMap` requires boot services. **Must be captured before EBS.** |
| **ACPI RSDP** | Located via `EFI_CONFIGURATION_TABLE` while boot services are live (look for `ACPI_20_TABLE_GUID` or `ACPI_10_TABLE_GUID`). Passed via struct. |
| **Stack** | Loader's allocated stack (typically `EfiLoaderData`, 64KiB+). Kernel switches to its own immediately. |
| **Calling convention** | Linux/FreeBSD/OpenBSD/Limine: SysV AMD64 (RDI = first arg). Windows: MS x64 (RCX = first arg). |
| **Entry mode** | Long mode, ring 0, paging on, identity-mapped low memory. |

The two real degrees of freedom are:

- **(a)** Is the loader+kernel one PE binary (Linux UKI/stub) or two (gnoboot+agnos, Windows, FreeBSD, OpenBSD, Limine)?
- **(b)** Is data delivered via fixed struct (gnoboot, Windows, BOOTBOOT) or request/response tables (Limine) or modinfo blob (FreeBSD)?

Everything else is the firmware contract.

---

## 7. The GRUB MB2-EFI W^X issue — why Path A died

### Background

`grub_relocator64_efi_boot` lives in `grub-core/lib/i386/relocator.c` / `grub-core/lib/x86_64/efi/relocator.c` / `grub-core/lib/i386/relocator64.S`. It was added in 2016 ([grub-devel patch v6](https://lists.gnu.org/archive/html/grub-devel/2016-03/msg00304.html)) to let multiboot2 images request `MULTIBOOT_TAG_TYPE_EFI_BS` ("don't call `ExitBootServices` for me, hand off with boot services still live").

The relocator is shared with `grub_relocator64_start`, and it deliberately uses `mov imm64, %rax/%rbx` (`0x48 0xb8 …` / `0x48 0xbb …`) where GRUB *patches the immediates of its own .text* before jumping to the loaded image — so it can set RAX to the multiboot2 magic, RBX to the boot-info pointer, etc., per the multiboot2 EFI handoff spec.

### The problem under strict W^X

- OVMF (and increasingly real-iron UEFI firmware following Microsoft's UEFI CA mitigation requirements) is now configured with `PcdDxeNxMemoryProtectionPolicy = 0xC000000000007FD5` (strict) rather than `0xC000000000007FD1` (bug-compatible).
- The strict policy makes `EfiLoaderData` allocations non-executable AND makes loaded PE `.text` sections read-only at page granularity.
- GRUB's relocator patches its own `.text` (the immediates of those `movabs` instructions) → **page fault under strict W^X**.

This matches the class of bug described in [Gerd Hoffmann's W^X writeup (Dec 2023)](https://www.kraxel.org/blog/2023/12/uefi-nx-linux-boot/): *"grub.efi used to use memory types incorrectly. Fixed upstream years ago, case closed. However, upstream development moves slowly, and distros carry downstream patches, causing buggy versions to persist."* That "fix upstream" refers to GRUB's normal allocation paths — **the relocator's self-patching is a separate problem that Hoffmann does not call out by name**, but matches the same root cause: GRUB writing to memory it doesn't have W permission on.

### Timeline

- **Dec 2023**: Hoffmann writes up the W^X situation; OVMF strict builds available as opt-in.
- **2024**: Linux 6.7 lands clean PE/COFF compliance for x86 EFI stub.
- **Jan 15 2025**: [Fedora 42 change proposal](https://www.mail-archive.com/devel-announce@lists.fedoraproject.org/msg03449.html) — strict NX becomes default for secure-boot edk2 builds. Quote: *"linux kernels and boot loaders released in 2024 should work without any problems with the new firmware builds."* Older GRUB/multiboot2 paths are not in scope.
- **2026-05-13** (AGNOS): hits the wall with OVMF 2024+. Exactly the predicted breakage.

### Searched and not found

No GRUB bugzilla entry naming `grub_relocator64_efi_boot` + W^X specifically. Closest neighbors:
- [RH 1858364](https://bugzilla.redhat.com/show_bug.cgi?id=1858364) — multiboot2 module path issues on EFI+Xen
- [RH 1691559](https://bugzilla.redhat.com/show_bug.cgi?id=1691559) — multiboot2 module missing on EFI builds

The combination "multiboot2 + relocator + strict-W^X-OVMF" appears genuinely under-reported. AGNOS's empirical finding (2026-05-13 diagnosis) is a fresher datapoint than any public bug report we found. **Worth filing upstream** if anyone cares to — but the path is dying anyway, so the value is mostly archival.

References:
- [Kraxel: W^X in UEFI firmware and the linux boot chain (Dec 2023)](https://www.kraxel.org/blog/2023/12/uefi-nx-linux-boot/)
- [Fedora 42 strict edk2 change proposal (Jan 2025)](https://www.mail-archive.com/devel-announce@lists.fedoraproject.org/msg03449.html)
- [grub_relocator64_efi v6 patch (Mar 2016)](https://lists.gnu.org/archive/html/grub-devel/2016-03/msg00304.html)
- [Multiboot2 Specification 2.0](https://www.gnu.org/software/grub/manual/multiboot2/multiboot.html)
- [tianocore-docs: Memory Protection in UEFI BIOS](https://github.com/tianocore-docs/ATBB-Memory_Protection_in_UEFI_BIOS/blob/main/memory-protection-in-uefi.md)
- [UEFI 2.10 §2.3.4 x64 platforms](https://uefi.org/specs/UEFI/2.10/02_Overview.html)

---

## 8. AGNOS Path C delta

### Same as mainstream

- PE/COFF UEFI application loaded by firmware via standard `LoadImage`/`StartImage` — like Linux EFI stub, FreeBSD loader.efi, OpenBSD BOOTX64.EFI, Windows bootmgfw.efi, Limine.
- Locate GOP via `LocateProtocol` while boot services live.
- Capture memory map via `GetMemoryMap` immediately before EBS.
- Locate ACPI RSDP via `EFI_CONFIGURATION_TABLE` GUID walk.
- Call `ExitBootServices` in the loader, jump to kernel afterwards — same as Windows, FreeBSD, OpenBSD, Limine.
- Pass a struct pointer in the first SysV ABI argument register (RDI) — same shape as Limine's optional Entry Point feature, FreeBSD's `modinfo` blob, Windows's `LOADER_PARAMETER_BLOCK` (modulo ABI register).
- Inherit UEFI identity-mapped page tables — **same as every kernel; this is the UEFI 2.10 §2.3.4 contract.**

### Different from mainstream

- **Flat 112-byte struct (AGNO magic) vs. extensible request/response (Limine) or modinfo blob (FreeBSD).** Flat struct is simpler and matches the BOOTBOOT / Simple-UEFI-Bootloader / ajxs hobbyist tradition. Trade-off: harder to extend without versioning. The `version` field is already present (v1 → v2 happened when fb fields moved out of the tag stream — Attempt 7) — good.
- **Lower-half kernel entry at `0x1000a8` physical.** Most modern kernels (Linux, BSDs, Limine-protocol kernels) run in the higher half. Lower-half is fine for MVP but a higher-half mapping (e.g., `0xffffffff80000000`) belongs on the post-MVP list when userspace and a real virtual address space land.
- **Cyrius-native, ~35KB.** Comparable to a minimal C UEFI app. Limine is ~100-300KB depending on features; FreeBSD's loader.efi is ~700KB; GRUB-EFI is ~3MB+. Smaller is better for trust review.
- **Sovereign-language toolchain.** No C, no edk2 — comparable in spirit to writing a Hare/Rust/Zig UEFI app. The toolchain is novel; the architecture isn't.

### Genuinely novel

- **Cyrius-emitted UEFI PE/COFF.** Not novel as a category (Rust, Zig, Hare, Go all have UEFI hobby compilers), but the specific Cyrius toolchain producing PE/COFF is new ground (cyrius UEFI-emit issue dated 2026-05-13, landed 5.11.49).
- **The handoff design itself is not novel** — it's the BOOTBOOT pattern with an AGNOS-specific magic and field layout.

### One foot-gun to verify

OpenBSD's `efi_cleanup()` **retries `ExitBootServices` once on `EFI_INVALID_PARAMETER`** — UEFI spec allows the memory map to change between `GetMemoryMap` and `ExitBootServices`, in which case EBS returns `EFI_INVALID_PARAMETER` and the caller must re-call `GetMemoryMap` with the fresh key. gnoboot's Path C step-7 plan calls "GetMemoryMap×2 (initial + fresh-key)" which suggests this is already handled — but worth a code check that the **retry-on-INVALID-PARAMETER** path actually exists, not just a pre-emptive double-call. Iron firmwares are more likely than OVMF to mutate the memory map between calls.

### Foot-gun ruled out experimentally on archaemenid — OSDev #57150's SetMode workaround does not generalize to AMD Zen UEFI

OSDev forum thread [#57150](https://forum.osdev.org/viewtopic.php?t=57150) ("EFI GOP lying about screen resolution?") names a real mechanism — AMD display engines can leave the scanout buffer tiled or DCC-compressed at GOP handoff while reporting linear pitch via `Mode->Info`, breaking direct CPU framebuffer writes — and proposes a firmware-side workaround: call `gop->SetMode(...)` before trusting `FrameBufferBase`, on the observation that "*switching mode (even setting same mode) switches framebuffer to linear*."

**On archaemenid's AMD Zen iGPU firmware, neither call shape of that workaround works:**

| gnoboot release | Form | Iron result | Falsifying attempt |
|---|---|---|---|
| 0.4.1 | `SetMode(gop, cur_mode)` ("same-mode re-arm") | No CRTC work observable; Quiet Boot banded-glyph signature persists | Attempt 74 (2026-05-20) |
| 0.4.2 | `SetMode(gop, other_mode) → SetMode(gop, cur_mode)` ("different-mode bounce") | No mode-switch flicker on VGA or HDMI; Quiet Boot signature identical to 0.4.1 | Attempt 78 (2026-05-20) |

Both forms produced no visible mode-switch flicker — consistent with the firmware eliding the SetMode work regardless of whether the requested mode differs from the current mode. The mechanism OSDev #57150 names is real (corroborated by Linux's amdgpu DCN reset path and FreeBSD `drm-kmod` issue #60); the firmware-side mitigation it proposes is **not** a portable lever. AMD Zen UEFI optimizes both call shapes away.

**Implication for sovereign loaders on AMD iron**: the GOP-side `SetMode` workaround for tiled/DCC scanout is not a reliable tool. The kernel-side mitigation (direct DCN pipe reprogram via `drivers/gpu/drm/amd/display/` equivalent) is what Linux and FreeBSD actually ship, for exactly this reason. Hobby loaders that need linear scanout on AMD post-EBS should plan for kernel-side reprogram, not for a GOP-side `SetMode` call shape.

Sources: gnoboot 0.4.1 + 0.4.2 release notes (`gnoboot/CHANGELOG.md`), iron Attempts 73/74/77/78 (`iron-nuc-zen-log.md`).

#### Intel cross-check — structurally inconclusive (Attempt 79, 2026-05-20)

The natural follow-up question — *is this bug AMD-Zen-specific or general-firmware?* — couldn't be cleanly answered on currently-available Intel hardware:

| Surface | Outcome | Reason |
|---|---|---|
| ASRock z890 (Intel) — bare-metal USB boot | Did not run | z890 firmware didn't recognize the AGNOS-built USB drive as bootable. USB-C wrapper is a contributing factor. **Separate bootability issue, not an AGNOS defect.** |
| archintel — i9 desktop Arrow Lake-S `[8086:7d67]` + NVIDIA RTX 5080 `[10de:2c02]`, Arch Linux, SSH read-only | Structurally non-comparable | (a) **No BGRT table** on this firmware (`ls /sys/firmware/acpi/tables/BGRT` → ENOENT) — the trigger condition for archaemenid's bug isn't present. (b) **Hybrid GPU; NVIDIA dGPU ends up `fbcon` primary**, not the Intel iGPU. (c) **Linux uses `simpledrm`, not `efifb`** — the modern Linux path explicitly assumes the firmware FB may be tiled and routes writes through a CPU-side shadow buffer (per [LWN — SimpleDRM system memory framebuffers](https://lwn.net/Articles/910621/)). That's the architectural answer to this bug class, and it's the *opposite* of AGNOS's sovereign direct-paint design. |

Two indirect signals from the archintel cross-check that *are* load-bearing:

1. **Industry has standardized on shadow-buffered FB drivers** (`simpledrm`) precisely because firmware-left FB layout isn't trustable across vendors. AGNOS direct-paint is sovereign-divergent on purpose, but next-cycle work needs to know that the rest of the world has already moved.
2. **BGRT-table absence on modern Intel firmware** is itself worth flagging — the Quiet-Boot logo path that triggers archaemenid's bug may be AMD-firmware-class-specific (or at least more common on AMD's reference UEFI). Untested on a single-iGPU Intel box with a BGRT-publishing firmware, which is the parked future discriminator.

**Disposition**: H2 (AMD-Zen-specific tile/DCC scanout at GOP handoff) stays the strongest read on archaemenid evidence, but is **not** Intel-cross-confirmed at closeout. The bug carries forward as a known residual; next-cycle target is kernel-side (HUBP `clear_tiling` minimal port per amd-gfx ML, or architectural shadow-buffer adoption). Memory pin: `project_amd_zen_scanout_residue`.

---

## 9. Verdict — is AGNOS far off?

**No. Path C is the sane choice. It's where the industry has been heading since ~2014, and where strict-W^X is forcing everyone who hasn't already moved.**

Three convergent confirmations:

1. **Linux abandoned chainloading for EFI stub by v6.7 (late 2023).** The "GRUB chainloads bzImage via handover protocol" path is officially deprecated upstream. New systems use UKIs (PE blobs) loaded directly by firmware or chainloaded one-step by systemd-boot. Path C is the same architectural choice.
2. **The BSDs never used GRUB-multiboot — they always had loader.efi/efiboot, which is the same shape as gnoboot.** OpenBSD's `BOOTX64.EFI` doing exactly what gnoboot does is the existence proof.
3. **Limine is the explicit hobby-OS reference design and it matches gnoboot point-for-point**, except (a) request/response instead of flat struct, (b) higher-half default. Both are stylistic, neither is structural.

The thing AGNOS *did* abandon — GRUB-multiboot2-EFI — is the path that *everyone has been quietly abandoning since 2023*. The Fedora 42 strict-NX change in January 2025 was the explicit cliff edge for this approach. AGNOS hit the cliff on 2026-05-13 because OVMF 2024+ is the strict configuration and `grub_relocator64_efi_boot`'s self-patching `.text` is exactly the pattern strict-W^X kills.

**The only thing to watch**: when AGNOS eventually writes the *sovereign UEFI firmware* (per the [bootloader-roadmap](../../../../.claude/projects/-home-macro-Repos-agnosticos/memory/project_agnos_bootloader_roadmap.md) memory pin: "Path C is MVP, sovereign UEFI long-term"), that's a different wheel — a real ground-up project, not analogous to gnoboot. For now, Path C is gnoboot-loaded-by-OEM-UEFI, and that's a 10+-year-old shape: small PE binary, struct in register, identity-mapped jump. Mainstream. Boring. Correct.

---

## Related AGNOS docs

- [`iron-nuc-zen-log.md`](iron-nuc-zen-log.md) — active append-only attempt log (post-MVP). MVP-era arc (Attempts 1–68) at [`iron-nuc-zen-log-mvp.md`](iron-nuc-zen-log-mvp.md).
- [`path-a-elf64-multiboot2.md`](path-a-elf64-multiboot2.md) — the abandoned multiboot2-via-GRUB plan
- [`path-c-sovereign-uefi.md`](path-c-sovereign-uefi.md) — the current gnoboot-as-MVP plan
- gnoboot repo: `/home/macro/Repos/gnoboot/` (handoff protocol spec lives there once Step 7's `docs/handoff-protocol.md` is written)
- Memory pin `project_grub_mb2_efi_wx_blocker` — concise W^X analysis
- Memory pin `project_agnos_bootloader_roadmap` — Path C as MVP, sovereign UEFI long-term
