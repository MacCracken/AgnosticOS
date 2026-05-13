# Path C — Sovereign UEFI Bootloader (`gnoboot`)

> **Status**: Drafted 2026-05-13 | Approach: Cyrius-native UEFI Application replaces GRUB on the AGNOS boot path | Scope: NUC AMD (x86_64 UEFI) iron-boot MVP, brought forward from "long-term" to "MVP-critical" after Path A's GRUB W^X blocker (iron-boot log § *Diagnosis 2*)
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
genuinely under-tested. Full chain in `iron-boot-testing-log.md`
§ *Diagnosis 2 — 2026-05-13 GRUB relocator W^X*.

Three workarounds were considered before this commit (see iron-boot log
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
    │  3. Read /boot/initramfs.cpio.gz
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
    uint32_t version;        // 1 for MVP. Bumped on layout-breaking changes.
    uint32_t struct_size;    // sizeof(this struct including tag stream) for fwd-compat
    uint32_t flags;          // bit 0 = serial enabled, bit 1 = framebuffer present, ...

    // Inlined critical pointers (no tag-walk needed for these)
    uint64_t initramfs_phys; // physical address of initramfs.cpio.gz in memory
    uint64_t initramfs_size; // bytes
    uint64_t cmdline_phys;   // NUL-terminated kernel cmdline (or 0 if none)

    uint64_t memmap_phys;    // physical address of memmap_entry[] array
    uint32_t memmap_count;   // number of entries
    uint32_t memmap_entsize; // sizeof(memmap_entry) — version-future-proofing

    uint64_t acpi_rsdp_phys; // RSDP pointer from UEFI config table (or 0)
    uint64_t efi_st_phys;    // UEFI SystemTable* (for runtime services post-ExitBootServices)

    // Tag stream begins here (8-byte aligned), terminated by tag with type=0.
    // Tag header: { uint32_t type, uint32_t size }. Payload follows.
    // Reserved tag types:
    //   0 = END
    //   1 = framebuffer (gop_mode_info_t)
    //   2 = boot_loader_name (UTF-8 string)
    //   3 = uefi_handle (handles we forward to the kernel for late use)
    // Kernel walks until type==0.
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

### Gnoboot (`/home/macro/Repos/gnoboot/` — to be created)

New repo. Modules per § *gnoboot internals* above. Initial directory shape:

```
gnoboot/
├── README.md
├── LICENSE                 # GPL-3.0-only (matching AGNOS family)
├── CHANGELOG.md
├── VERSION                 # 0.1.0 to start (gnoboot uses semver, not CalVer)
├── cyrius.cyml             # build manifest; cyrius pin once UEFI emit lands
├── src/
│   ├── main.cyr            # efi_main entry
│   ├── uefi.cyr            # UEFI protocol/struct defs
│   ├── fs.cyr              # ESP read
│   ├── elf.cyr             # ELF64 parse + LOAD
│   ├── memmap.cyr          # GetMemoryMap + sovereign-struct memmap
│   ├── handoff.cyr         # struct build + ExitBootServices + jmp
│   └── console.cyr         # debug print
├── tests/
│   └── ovmf_smoke.sh       # boot under QEMU+OVMF and verify serial output
└── docs/
    └── handoff-protocol.md # sovereign boot-info struct spec (authoritative)
```

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
     (kernel) + `/boot/initramfs.cpio.gz`. No `/boot/grub/`.
   - Update the comments and `--update` mode accordingly.
2. **`scripts/test-uefi-qemu.sh` — drop the grub-mkimage path.**
   - Replace `grub-mkimage` + `grub.cfg` + module copying with a single
     `mcopy` of `gnoboot/build/BOOTX64.EFI` into the FAT image's
     `/EFI/BOOT/`. The `grub-file --is-x86-multiboot2` pre-check goes
     away (we no longer ship via GRUB). The OVMF + qemu invocation stays
     the same — that's what's correct.
3. **`docs/development/iron-boot-testing-log.md`** — Attempt 5 entry
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
| 1 | Cyrius implements `_TARGET_EFI_APPLICATION` per the issue | `programs/efi_probe.cyr` or similar boots under QEMU OVMF and prints to ConOut serial | cyrius | **BLOCKING** |
| 2 | `gnoboot` repo created (locally); cyrius.cyml + README + LICENSE | `git init` (user does the commit) | gnoboot | pending |
| 3 | gnoboot `src/console.cyr` + minimal `efi_main` that prints "gnoboot vX.Y.Z" to ConOut and waits | QEMU OVMF shows the banner | gnoboot | pending |
| 4 | gnoboot `src/fs.cyr` — open ESP, read `/boot/agnos` into memory, print sha256 to console | QEMU OVMF: banner + matching sha256 vs `sha256sum agnos/build/agnos` | gnoboot | pending |
| 5 | gnoboot `src/elf.cyr` — parse ELF64 header, walk program headers, AllocatePages + copy each PT_LOAD | QEMU OVMF: banner + "ELF parsed: entry=0x1000a8 N segments mapped" | gnoboot | pending |
| 6 | gnoboot `src/memmap.cyr` — GetMemoryMap, dump entry count + total RAM | QEMU OVMF: prints memory map summary | gnoboot | pending |
| 7 | gnoboot `src/handoff.cyr` — build sovereign struct, ExitBootServices, **jump to kernel entry** (with current agnos kernel that still expects MB2 — will fault, that's fine) | QEMU OVMF: kernel jumped to (any sign of life from the kernel side, even a fault) | gnoboot | pending |
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

1. **gnoboot version scheme.** `agnos` uses CalVer for the kernel
   (1.29.x); cyrius uses semver (5.11.46); agnosticos uses CalVer
   (2026.5.13). gnoboot is closer to cyrius (a tool, not a calendar
   release). Recommend **semver starting 0.1.0**.
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
  - `docs/development/path-a-elf64-multiboot2.md` § *Status update — 2026-05-13*
  - `docs/development/iron-boot-testing-log.md` § *Diagnosis 2 — 2026-05-13 GRUB relocator W^X*
- Cyrius dependency: `cyrius/docs/development/issues/2026-05-13-gnoboot-uefi-application-emit.md`
- Memory pins:
  - [[project-agnos-bootloader-roadmap]] — updated 2026-05-13 to Path C as MVP
  - [[project-grub-mb2-efi-wx-blocker]] — the W^X analysis that drove the cut
  - [[project-monolithic-by-design]] — why gnoboot is its own repo
  - [[feedback-language-extension-invasiveness]] — why the cyrius change is a build flag, not a directive
  - [[feedback-cyrius-hands-off]] — why this agent only files issues, never edits cyrius
