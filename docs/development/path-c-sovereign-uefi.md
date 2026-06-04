# Path C — Sovereign UEFI Bootloader (`gnoboot`)

> **Status**: Drafted 2026-05-13 | Approach: Cyrius-native UEFI Application replaces GRUB on the AGNOS boot path | Scope: NUC AMD (x86_64 UEFI) iron-boot MVP, brought forward from "long-term" to "MVP-critical" after Path A's GRUB W^X blocker (iron-nuc-zen log § *Diagnosis 2*)
> **Roadmap pin**: [[project-agnos-bootloader-roadmap]] — updated 2026-05-13 to make Path C the MVP path, not long-term
> **Repo home**: new `gnoboot` repo (Cyrius-native, sibling of `agnos` / `cyrius`)
> **NEXT AGENT — START HERE.** Path A is dead (GRUB-side bug under strict-W^X UEFI; not a cyrius bug; not fixable in our timeline). The MVP boot-to-shell-on-iron gate now runs through `gnoboot`. Sequence: (1) cyrius UEFI-emit issue is filed at `cyrius/docs/development/issues/2026-05-13-gnoboot-uefi-application-emit.md` and is the upstream blocker; (2) `gnoboot` repo + source follow once cyrius can emit; (3) agnos shim swaps from MB2 parsing to the sovereign struct; (4) install-usb.sh drops GRUB entirely. **Do NOT** edit cyrius — surface bugs via additional issue files only. **Do NOT** start an iron Attempt 5 against the current Path A build — it will reproduce Attempt 3/4 reset.

---

## What this plan is

The build plan for **`gnoboot`**, AGNOS's sovereign Cyrius-native UEFI bootloader
that replaces GRUB on the boot path. The kernel stays ELF64 (cyrius 5.11.43
`EMITELF64_KERNEL` work is preserved and reused — gnoboot reads and loads the
same ELF64 binary). The handoff protocol changes from multiboot2 to a sovereign
AGNOS boot-info struct. UEFI firmware loads `EFI/BOOT/BOOTX64.EFI` (= gnoboot)
directly; gnoboot does its own ESP file I/O, memmap, and ExitBootServices.

**Goal in one line**: AGNOS boots to scheduler + tier3 integration test on the
NUC AMD with `gnoboot` as the only thing between UEFI firmware and the kernel.

**NOT in scope:**
- aarch64 boot path — `gnoboot` is x86_64 UEFI only for MVP. Pi 4 secondary axis
  uses a different bootloader (TF-A / U-Boot / direct kernel load — TBD when
  Pi SSH testing resumes).
- Secure Boot signing — possible later; for MVP, BIOS-side Secure Boot is
  disabled on the test NUC AMD.
- File systems beyond FAT32 — gnoboot reads from the ESP only, which is FAT32
  per UEFI spec. ext4 / etc. is post-boot kernel territory.
- Removing the ELF64 + multiboot2 plumbing from cyrius — stays as latent
  capability per [[project-agnos-kernel-growth-rules]]. cyrius 5.11.43's
  `EMITELF64_KERNEL` continues to be the kernel emit; only the **handoff
  protocol** changes (MB2 register state → sovereign struct).

---

## Why this cut

Path A (ELF64 + multiboot2 via GRUB) was the chosen MVP bridge from
2026-05-13 morning until the QEMU OVMF gate exposed an intrinsic GRUB-side
bug: `grub_relocator64_efi_boot` writes kernel register state directly into
its own `.text` (the `grub_relocator64_efi_start` stub's embedded immediates
at .text 0x8AA-0x8F7), and under OVMF 2024+ / modern strict-W^X UEFI those
writes fault. Linux distros don't trip this because they boot via
`linuxefi`, not multiboot2 — making the multiboot2 + GRUB-EFI path
genuinely under-tested. Full chain in `iron-nuc-zen-log-mvp.md`
§ *Diagnosis 2 — 2026-05-13 GRUB relocator W^X*.

Three workarounds were considered before this commit (see iron-nuc-zen log
"Resolution options" in *Diagnosis 2*):

- **Patched GRUB vendored on the ESP** — refactor `_efi_boot` to copy
  the stub to a writable trampoline before patching. Smallest immediate
  scope, but ships a vendored fork of upstream GRUB indefinitely. Real
  maintenance tail. Rejected: not worth carrying a GRUB fork when we'll
  delete GRUB from the boot path anyway when Path C lands.
- **Linux Boot Protocol pretender** — make AGNOS pretend to be a bzImage
  for GRUB's `linuxefi`. Wastes the multiboot2 plumbing in cyrius 5.11.43;
  worse, ties the AGNOS boot protocol to Linux's boot protocol in
  perpetuity. Anti-sovereignty. Rejected.
- **Loose-W^X OVMF rebuild** — purely diagnostic, doesn't unblock iron.

Path C dissolves the GRUB dependency entirely. It was always the
long-term destination per [[project-agnos-bootloader-roadmap]]; the
W^X blocker just brings the timeline forward to "now."

---

## Architecture

### Boot chain (after Path C)

```
UEFI firmware (NUC AMD AMI / OVMF)
    │
    ▼  (LoadImage + StartImage, MS x64 ABI)
EFI/BOOT/BOOTX64.EFI  ← gnoboot
    │
    │  1. Open ESP via SimpleFileSystemProtocol
    │  2. Read /boot/agnos (ELF64) into AllocatePages buffer
    │  3. Read /boot/initramfs (optional; format-neutral, kernel owns it)
    │  4. Parse ELF64 program headers, AllocatePages each PT_LOAD at
    │     its physical address, memcpy + zero-fill (BSS)
    │  5. Build sovereign AGNOS boot-info struct (see § Handoff)
    │  6. GetMemoryMap → finalize MMAP into the boot-info struct
    │  7. ExitBootServices(ImageHandle, MapKey)
    │  8. Jump to kernel entry with RDI = &boot_info  (SysV ABI)
    │
    ▼
agnos kernel (ELF64, entry 0x100000 + offset, long mode inherited)
```

### gnoboot internals (Cyrius modules)

Approximate scope estimate (each ~200-400 LoC):

| Module | Responsibility |
|---|---|
| `src/main.cyr` | `efi_main(ImageHandle, SystemTable)` entry, top-level orchestration |
| `src/uefi.cyr` | UEFI protocol GUIDs + struct definitions (SystemTable, BootServices, SimpleFileSystemProtocol, FileProtocol, LoadedImageProtocol, MemoryDescriptor) |
| `src/fs.cyr` | ESP file-read: locate SFS on LoadedImage.DeviceHandle, open the volume, traverse `/boot/...`, read into AllocatePages buffer |
| `src/elf.cyr` | ELF64 header + program-header parse, LOAD segment allocation + copy, entry-point extraction |
| `src/memmap.cyr` | GetMemoryMap + sovereign-struct memmap copy |
| `src/handoff.cyr` | Build sovereign boot-info struct, ExitBootServices, jump to kernel (asm sequence: RDI=struct, jmp \*entry) |
| `src/console.cyr` | Debug output via SystemTable.ConOut (early) and serial (post-init) for diagnostics |

Total estimate: **~2000-2500 LoC of cyrius**. Comparable to
`agnosticos/scripts/src/boot.cyr` (the existing sovereign build pipeline,
48 KB compiled).

---

## Handoff protocol — sovereign AGNOS boot-info struct

Designed for AGNOS's needs, not Linux's or multiboot's. Versioned, extensible
via tag-list (same idea as multiboot2 but our shape).

```c
// At kernel entry: RDI = physical address of agnos_boot_info_t
// (SysV ABI x86_64 — agnos shim is already SysV; matches the existing
//  drafted Path A long-mode shim's expected register state with RDI
//  replacing RBX. Migration is ~10 lines of shim change in agnos.)

struct agnos_boot_info {
    uint32_t magic;          // 0x41474E4F ('AGNO')  — sovereign magic, not 0x36D76289
    uint32_t version;        // 2 (v1 had no inlined fb fields). Bumped on layout-breaking changes.
    uint32_t struct_size;    // = 120 (0x78): sizeof inlined fields + 8-byte END tag, for fwd-compat
    uint32_t flags;          // bit 0 = serial enabled, bit 1 = framebuffer present, ...

    // Inlined critical pointers (no tag-walk needed for these)
    uint64_t initramfs_phys; // phys addr of \boot\initramfs (raw bytes; kernel owns
                             //   the format — sovereign INDR, not Linux cpio.gz). 0 if absent.
    uint64_t initramfs_size; // bytes (0 if absent)
    uint64_t cmdline_phys;   // NUL-terminated kernel cmdline from \boot\cmdline (or 0 if none)

    uint64_t memmap_phys;    // physical address of memmap_entry[] array
    uint32_t memmap_count;   // number of entries
    uint32_t memmap_entsize; // sizeof(memmap_entry) — version-future-proofing

    uint64_t acpi_rsdp_phys; // RSDP pointer from UEFI config table (or 0)
    uint64_t efi_st_phys;    // UEFI SystemTable* (for runtime services post-ExitBootServices)

    // Framebuffer — inlined (v2). Originally tag-stream type=1, but the
    // agnos kernel canary reads fb_phys from raw asm at entry instruction
    // #1, before stack setup and before any cyrius fn call. Walking a
    // tag stream in raw asm is brutal; inlining at fixed offsets makes
    // the canary 26 bytes total (see agnos boot_shim.cyr ELF64 path).
    uint64_t fb_phys;        // 0x48 physical address of linear framebuffer (0 if absent)
    uint32_t fb_pitch;       // 0x50 bytes per scanline (PixelsPerScanLine × 4 for 32 bpp)
    uint32_t fb_width;       // 0x54 pixels (HorizontalResolution)
    uint32_t fb_height;      // 0x58 pixels (VerticalResolution)
    uint32_t fb_pixel_format;// 0x5C 0 = RGB888x, 1 = BGR888x, 2 = bitmask, 3 = blt-only
    uint32_t fb_mode_current;// 0x60 GOP Mode->Mode (which mode firmware booted; v2 overlay)
    uint32_t fb_mode_max;    // 0x64 GOP Mode->MaxMode (mode count available)
    uint64_t fb_size;        // 0x68 GOP Mode->FrameBufferSize (authoritative FB extent;
                             //   0 ⇒ kernel falls back to pitch × height)

    // Tag stream begins here (8-byte aligned), terminated by tag with type=0.
    // Tag header: { uint32_t type, uint32_t size }. Payload follows.
    // Reserved tag types:
    //   0 = END
    //   2 = boot_loader_name (UTF-8 string)
    //   3 = uefi_handle (handles we forward to the kernel for late use)
    // Tag type 1 (framebuffer) was reserved in v1 but is now inlined
    // above — kernel walkers MUST NOT expect a fb tag in the stream.
    uint8_t tags[];
};

struct memmap_entry {
    uint64_t phys_addr;
    uint64_t size_bytes;
    uint32_t type;       // 1 = usable, 2 = reserved, 3 = ACPI reclaim, 4 = ACPI NVS, 5 = bad, 6 = boot-services-code/data (now ours), 7 = runtime-services (UEFI keeps)
    uint32_t attributes; // UEFI memory attribute flags forwarded
};
```

**Magic = 0x41474E4F ('AGNO')** — sovereign, not multiboot2's 0x36D76289.
Kernel checks this magic to refuse foreign bootloaders. Bootloader is
authoritative; kernel trusts the struct iff magic matches.

**RDI vs RBX**: Path A's drafted agnos shim used RBX for the MBI pointer
per multiboot2's spec. Sovereign protocol moves to RDI per SysV convention
(arg 0 to a C-call). agnos shim diff: ~10 lines. The
"capture-the-pointer-immediately-after-entry" pattern (the `mbi_capture_rbx`
trick from Path A Step 5a) stays the same shape but reads RDI; SysV ABI
preserves RDI across the trampoline call.

---

## Scope by repo

### Cyrius (`/home/macro/Repos/cyrius/`)

**Status: hands-off for this agent. Issue filed.**

UEFI-application emit mode (sibling of `_TARGET_PE`). Full spec:
`cyrius/docs/development/issues/2026-05-13-gnoboot-uefi-application-emit.md`.
Estimated 150-300 LoC patch in `src/backend/pe/emit.cyr` + small plumbing
in `src/main.cyr` / `src/main_win.cyr`. Cyrius agent implements; this
agent does not touch cyrius.

Without this, gnoboot cannot be written. **Upstream blocker.**

### Gnoboot (`/home/macro/Repos/gnoboot/` — initialized 2026-05-13)

Cyrius-native, GPL-3.0-only, semver. Current directory state:

```
gnoboot/
├── README.md               # ✓ status table + build + test + architecture
├── LICENSE                 # ✓ GPL-3.0-only
├── CHANGELOG.md            # ✓ Keep a Changelog; all work under [Unreleased] until v0.1.0 tag
├── VERSION                 # ✓ 0.1.0 (will be the first official tag once Step 9 + Step 12 pass)
├── cyrius.cyml             # ✓ pin = cyrius 5.11.49 (UEFI Application emit mode)
├── .gitignore              # ✓ ignores /build/, editor cruft, secrets
├── .github/workflows/
│   ├── ci.yml              # ✓ build w/ CYRIUS_TARGET_EFI=1, structural + OVMF gates, artifact upload
│   └── release.yml         # ✓ v?X.Y.Z tag trigger, CI-gated, BOOTX64.EFI + SHA256SUMS to GH release
├── src/
│   ├── main.cyr            # ✓ Step 3 banner (kernel; + inline-asm walking ConOut)
│   └── test.cyr            # placeholder (cyrius [build].test entry)
├── tests/
│   ├── verify_pe.sh        # ✓ fast structural gate (DOS magic / PE sig / Char / Subsystem / DllChar)
│   └── ovmf_smoke.sh       # ✓ runtime gate (GPT/ESP/qemu+OVMF; cross-distro OVMF path probe)
└── (future at Step 7) docs/handoff-protocol.md
```

Modules per § *gnoboot internals* will grow under `src/` as Steps 4-7
land. For Step 3 (current state), the entire bootloader fits in one
inline-asm block — no fs/elf/memmap/handoff modules yet.

### Agnos (`/home/macro/Repos/agnos/`)

**Status: cross-repo edit — requires explicit per-edit approval per
[[feedback-per-action-consent]] when the time comes.**

Shim diff from Path A's drafted ELF64 shim:

| Path A shim expected | Path C shim expects |
|---|---|
| `RAX = 0x36D76289` (MB2 magic) | `RDI = &agnos_boot_info` (sovereign ptr) — and check `RDI->magic == 0x41474E4F` |
| `RBX = MBI pointer` (tag stream) | (unused) |
| MBI tag walker for cmdline, MMAP, modules | sovereign-struct field access (fixed offsets) + tag-walker for the small extensible tail |

The "ELF64 kernel + long mode entry" base of the shim (cyrius 5.11.43
emit, stack setup, GDT inheritance, segment reload via push-lea-push-retfq
per Path A Step 5a) is **unchanged**. Only the post-trampoline data
extraction changes — replace MBI parse with sovereign-struct read.
Probably ~50-100 line shim diff, plus deleting the MB2 tag-walker
boilerplate that Path A added in `mbi.cyr`.

Version: kernel ABI is changing (handoff protocol). Bump 1.29.x → 1.30.0
at the time of the shim swap, same as Path A had planned.

### Agnosticos (this repo)

**This agent handles:**

1. **`scripts/install-usb.sh` — strip GRUB entirely.**
   - Remove `grub-install --target=x86_64-efi`.
   - Remove `cat > grub.cfg <<'EOF'` block.
   - Replace with: `cp $GNOBOOT_BUILD/BOOTX64.EFI ${MOUNT_POINT}/EFI/BOOT/BOOTX64.EFI`.
   - Layout becomes: `/EFI/BOOT/BOOTX64.EFI` (gnoboot) + `/boot/agnos`
     (kernel) + `/boot/initramfs` (optional, format-neutral). No `/boot/grub/`.
   - Update the comments and `--update` mode accordingly.
2. **`scripts/test-uefi-qemu.sh` — drop the grub-mkimage path.**
   - Replace `grub-mkimage` + `grub.cfg` + module copying with a single
     `mcopy` of `gnoboot/build/BOOTX64.EFI` into the FAT image's
     `/EFI/BOOT/`. The `grub-file --is-x86-multiboot2` pre-check goes
     away (we no longer ship via GRUB). The OVMF + qemu invocation stays
     the same — that's what's correct.
3. **`docs/development/iron-nuc-zen-log-mvp.md`** — Attempt 5 entry
   when gnoboot is ready and the re-provisioned USB exists.
4. **CHANGELOG.md** + **`docs/development/state.md`** — update once
   gnoboot has a first boot-on-iron pass.
5. **Memory pin**: [[project-agnos-bootloader-roadmap]] — updated
   in-session (this commit) to reflect Path C as MVP.

---

## Implementation order (small bites)

| # | Step | Verification gate | Repo | Status |
|---|---|---|---|---|
| 0 | Cyrius issue filed describing UEFI-application emit | issue exists at `cyrius/docs/development/issues/2026-05-13-gnoboot-uefi-application-emit.md` | cyrius | ✓ Filed 2026-05-13 |
| 1 | Cyrius implements `_TARGET_EFI_APPLICATION` per the issue | `programs/efi_probe.cyr` boots under QEMU OVMF and prints to ConOut serial | cyrius | ✓ Landed 5.11.49 (3-slot arc: 5.11.47 emit + 5.11.48 structural gate + 5.11.49 RELOCS_STRIPPED fix + OVMF smoke gate in `check.sh`) |
| 2 | `gnoboot` repo created (locally); cyrius.cyml + README + LICENSE | `git init` (user does the commit) | gnoboot | ✓ User-init'd 2026-05-13 |
| 3 | gnoboot `src/main.cyr` — minimal `efi_main` that prints "gnoboot vX.Y.Z" to ConOut | QEMU OVMF shows the banner | gnoboot | ✓ 2026-05-13 — `tests/ovmf_smoke.sh PASS`; banner observed on ConOut between BdsDxe load and the fallback boot-manager menu. cyrius pin 5.11.47 → 5.11.49. Pattern: `kernel;` + inline-asm walking SystemTable→ConOut→OutputString (mirrors `efi_probe.cyr` — single-block, no DIR64 fixups needed at banner scale) |
| 3.5 | gnoboot CI/release scaffolding — `tests/verify_pe.sh` (structural), `tests/ovmf_smoke.sh` (runtime), `.github/workflows/{ci,release}.yml`, CHANGELOG | local: both gates PASS; CI: structural + OVMF gates green on `ubuntu-latest` with the `ovmf parted mtools qemu-system-x86` package set; Release: `v0.1.0` tag (when ready) → GH release with `BOOTX64.EFI` + `gnoboot-0.1.0-x86_64-efi.efi` + `SHA256SUMS` | gnoboot | ✓ 2026-05-13 — agnos-style install pattern (canonical `install.sh` + post-install smoke); cross-distro OVMF path probing (Arch `edk2-ovmf` + Ubuntu `ovmf`); accepts both `vX.Y.Z` and `X.Y.Z` tag styles |
| 4a | Infrastructure probe — *retrospectively a misread*: the printed "PASS" came from firmware-preserved RDX in the post-capture banner walk, not from the captured global. Step 4's disassembly proved the capture was a no-op — at top-level `kernel;` mode, `var X = expr;` is a global with deferred initializer, and cyrius emits the following asm BEFORE the `&expr` lea, so RAX is junk when the capture asm runs. The agnos shim's `var p = &foo; asm` register-capture pattern only works *inside a fn body*. | "step 4a probe ok" did print (PASS-as-displayed), but the displayed PASS was misleading | gnoboot | ⚠ 2026-05-13 — constraint logged in gnoboot CHANGELOG and applied to Step 4 (pure-asm rewrite) |
| 4 | `bs->HandleProtocol(ImageHandle, &LoadedImageGuid, &out)` returns EFI_SUCCESS. Now in clean cyrius (post-5.11.52): `fn efi_main(handle, st)` convention, byte-array literal globals for UTF-16LE strings and the LoadedImage GUID, `fncall2`/`fncall3` for MS x64 firmware calls. Six-byte corrective save asm at end of top-level patches cyrius 5.11.52's REX-prefix bug in the auto-emitted entry save (filed `cyrius/docs/development/issues/2026-05-13-efi-main-trampoline-save-rex-wrong.md`). | QEMU OVMF: `PASS: "step 4: HandleProtocol(LoadedImage) = ok" observed on ConOut` | gnoboot | ✓ 2026-05-13 — clean cyrius code, ~90 lines for the whole gnoboot Step 4 (down from ~280 in the pure-asm Step 4) |
| 5 | gnoboot `src/main.cyr` — open ESP via SimpleFileSystem, open `\boot\agnos`, read first 4 bytes, check ELF magic | QEMU OVMF: `PASS: "step 5: /boot/agnos magic = ELF" observed on ConOut` | gnoboot | ✓ 2026-05-13 — 5 firmware calls chained (HP×2 + OpenVolume + Open + Read), all clean cyrius (`fncall2`/`fncall3`/`fncall5`), no asm. `tests/ovmf_smoke.sh` extended to provision `\boot\agnos` on the test ESP from the agnos kernel build (or synthetic 4-byte stub). Cyrius 5.11.53 corrective-save asm removed — entry-save REX hotfix verified in disassembly. |
| 5b | gnoboot — parse ELF64 header, walk program headers, AllocatePages + copy each PT_LOAD | QEMU OVMF: `PASS: "step 5b: kernel mapped at 0x100000 = ok" observed on ConOut` | gnoboot | ✓ 2026-05-13 — single PT_LOAD covering AGNOS kernel: AllocatePages(AllocateAddress, EfiLoaderData) at 0x100000, 78 pages (310 KB inc. BSS), Read 245 KB filesz directly into place. Verified ELF magic at load addr. |
| 6 | gnoboot — GetMemoryMap into a 16 KB buffer; capture mm_key for ExitBootServices | QEMU OVMF: `PASS: "step 6: kernel @ 0x100000 + memmap = ok" observed on ConOut` | gnoboot | ✓ 2026-05-13 — single `bs->GetMemoryMap` call (`fncall5`), captures all 5 OUT params (`mm_size`, `mm_key`, `mm_dsz`, `mm_dver` + the buffer itself). 16 KB pre-allocated cyrius global holds ~400 descriptors of slack vs. OVMF's typical 30-80. |
| 6 | gnoboot `src/memmap.cyr` — GetMemoryMap, dump entry count + total RAM | QEMU OVMF: prints memory map summary | gnoboot | pending |
| 7 | gnoboot — build sovereign struct, ExitBootServices, **jump to kernel entry** with RDI = &boot_info | QEMU OVMF: `PASS: "AGNOS kernel v1.30.0" observed on ConOut` (kernel prints banner + 9 init lines through `Page tables: 1024MB mapped` post-EBS) | gnoboot | ✓ 2026-05-13 — gnoboot's MVP handoff verified end-to-end. Architecture: 80-byte sovereign struct (magic 0x41474E4F, version 1), GetMemoryMap×2 (initial + fresh-key), ExitBootServices, inline-asm jump with `mov rdi, &boot_info; mov eax, 0x1000A8; jmp rax`. Kernel-side stall past `Page tables` is a separate agnos investigation, documented in agnos's `docs/development/state.md`. |
| 8 | Agnos shim swap MB2 → sovereign struct (cross-repo agnos edit) | agnos 1.30.0 builds clean; kernel reads `RDI` instead of `RBX` at entry; kernel boots through 10 init checkpoints under gnoboot Step 7 | agnos | ✓ 2026-05-13 — 6 edits in agnos repo: `mbi.cyr` asm byte 0x18→0x38 (mov [rax],rbx → mov [rax],rdi), fn rename `mbi_capture_rbx → boot_info_capture_rdi`, global rename `mb_info_ptr → boot_info_ptr`, boot_shim.cyr comments + call-site update, VERSION 1.29.1 → 1.30.0, cyrius pin 5.11.43 → 5.11.53. |
| 8 | Agnos shim swap: replace MBI parse with sovereign struct read (RDI = &boot_info, magic check) | agnos kernel build still compiles; agnos `1.29.x → 1.30.0` bump | agnos | pending |
| 9 | End-to-end QEMU OVMF: gnoboot → agnos kernel → scheduler + tier3 test serial output | clean serial trace through "=== done ===" | gnoboot + agnos + scripts | pending |
| 10 | `scripts/install-usb.sh` — drop GRUB, copy gnoboot.efi into `/EFI/BOOT/` | `install-usb.sh` produces a USB with no `/boot/grub/`, just `/EFI/BOOT/BOOTX64.EFI` + `/boot/agnos` + initramfs | agnosticos | pending |
| 11 | `scripts/test-uefi-qemu.sh` — drop grub-mkimage, mcopy gnoboot.efi directly | `test-uefi-qemu.sh` boots gnoboot under OVMF without any GRUB on the image | agnosticos | pending |
| 12 | Iron Attempt 5 — full re-provision + boot NUC AMD with gnoboot in the chain | scheduler + tier3 serial output OR new failure mode (further than Attempts 1-4) | scripts | pending |

**Each step is a separate verification gate.** Step 1 (cyrius UEFI emit)
is the upstream blocker. Steps 2-9 are gnoboot + agnos work; steps 10-12
are this repo's work. Per `CLAUDE.md` § DO NOT: the user handles all
commits and tagging.

---

## Open decisions

These can be resolved when the gnoboot repo is being created — flagging
now so they don't ambush implementation:

1. **gnoboot version scheme.** `agnos` uses SemVer for the kernel
   (currently 1.31.4); cyrius uses SemVer (currently 6.0.1); agnosticos
   uses SemVer (currently 0.1.0 — flipped from CalVer at the 0.1.0 cut
   2026-05-21 because daily-update cadence stopped fitting the date
   stamp; CalVer may return later once cadence normalizes). gnoboot
   uses SemVer too (currently 0.4.2). The whole AGNOS family is on
   SemVer for now.
2. **License.** GPL-3.0-only matches AGNOS family (kernel, cyrius,
   agnosticos). Lock that in.
3. **gnoboot ↔ agnos sovereign-struct version negotiation.** What
   happens when an old gnoboot tries to boot a new agnos? Magic
   matches, but `version` field disagrees. Recommend:
   `agnos kernel refuses with a clear ConOut message if `boot_info->version`
   is older than what kernel expects` — gnoboot's job is to be
   forward-compatible (always emit the latest known version it can).
4. **Multiple `boot_info` allocations.** Sovereign struct lives in
   memory that gnoboot allocated via AllocatePages with type
   `EfiBootServicesData` (will become "reclaimable" post-EBS). Kernel
   should treat the memmap entry containing `&boot_info` as
   "reclaimable after read." Document in `gnoboot/docs/handoff-protocol.md`.
5. **Secure Boot.** Punt to post-MVP. For iron testing, BIOS Setup →
   Secure Boot Disabled on the NUC AMD.

---

## Test plan

**QEMU OVMF** (steps 3, 5, 7, 9): existing
`agnosticos/scripts/test-uefi-qemu.sh`, post-step-11 form (no GRUB).
Boot under OVMF firmware (same `grub_relocator64_efi_boot`-equivalent
firmware path that NUC AMD uses — without GRUB, there's no relocator,
firmware calls gnoboot directly). Serial → stdout.

**Iron Attempt 5** (step 12): full `install-usb.sh` re-provision (post
step 10), boot NUC AMD.

Possible outcomes:

| Observed | Implication |
|---|---|
| Boots into scheduler + tier3 test (clean serial output) | Path C success. Closed-beta MVP gate cleared on NUC AMD. Move to kybernet + agnoshi integration. |
| gnoboot banner appears, but it doesn't read the kernel / hangs in ELF parse | gnoboot bug. Bisect with QEMU OVMF (same path); add stage prints. |
| gnoboot banner appears, ExitBootServices reported OK, kernel never prints | Either the kernel entry was never reached (jmp issue), or kernel faulted before its first serial write. Add a port-0x80 POST at kernel entry; bisect handoff. |
| No gnoboot banner | UEFI firmware rejected `BOOTX64.EFI`. Check subsystem byte, base relocations, NX_COMPAT — see cyrius issue acceptance criteria. |
| Same `WARNING: no console will be available` + reset | Should NOT happen — that message is GRUB's. If it appears, GRUB is somehow still on the boot chain (install-usb.sh regression). |

---

## Doc trail

- Path A history + GRUB diagnosis (the *why* for Path C):
  - `docs/development/prior-art/path-a-elf64-multiboot2.md` § *Status update — 2026-05-13*
  - `docs/development/iron-nuc-zen-log-mvp.md` § *Diagnosis 2 — 2026-05-13 GRUB relocator W^X*
- Cyrius dependency: `cyrius/docs/development/issues/2026-05-13-gnoboot-uefi-application-emit.md`
- Memory pins:
  - [[project-agnos-bootloader-roadmap]] — updated 2026-05-13 to Path C as MVP
  - [[project-grub-mb2-efi-wx-blocker]] — the W^X analysis that drove the cut
  - [[project-monolithic-by-design]] — why gnoboot is its own repo
  - [[feedback-language-extension-invasiveness]] — why the cyrius change is a build flag, not a directive
  - [[feedback-cyrius-hands-off]] — why this agent only files issues, never edits cyrius
