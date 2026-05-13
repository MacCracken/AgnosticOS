# Path A — ELF64 Multiboot2 Boot Kernel

> **Status**: Drafted 2026-05-13 | Approach: ELF64 kernel + multiboot2 + EFI64 entry tag | Scope: NUC AMD (x86_64 UEFI) iron-boot MVP
> **Diagnosis source**: `docs/development/iron-boot-testing-log.md` § *Diagnosis — 2026-05-13 GRUB source review*
> **Roadmap pin**: [[project-agnos-bootloader-roadmap]] memory — Path A is the MVP bridge; Path C (sovereign UEFI bootloader, no GRUB) is the long-term destination
> **NEXT AGENT — START HERE.** Steps 1-5a (cyrius + agnos) and Step 7 (install-usb.sh) landed; Step 5b (QEMU OVMF) **FAILED inside GRUB's relocator under strict-W^X UEFI** (see § *Status update — 2026-05-13* at the bottom and iron-boot log § *Diagnosis 2*). Iron Attempt 5 (Step 8) is on **HOLD** until the resolution path is chosen by the project leader (options 1-4 in the status update). **Do NOT** push iron Attempt 5 against the current build — it will reproduce Attempts 3/4 exactly. **Do NOT** edit cyrius — the language is hands-off per session feedback; cyrius work in this plan is correct and complete. Cross-repo changes (agnos, cyrius) require explicit per-edit approval.

---

## What this plan is

The build plan for switching the AGNOS boot kernel from **ELF32 + multiboot1**
(current) to **ELF64 + multiboot2 with `MULTIBOOT_HEADER_TAG_ENTRY_ADDRESS_EFI64`**
(target), so the kernel can boot through GRUB on UEFI x86_64 iron.

**Goal in one line**: agnos-1.30.0 boots through GRUB on the NUC AMD into
the existing scheduler + tier3 integration test, with no long-mode-exit
shim required.

**NOT in scope:**
- Sovereign UEFI bootloader (Path C — long-term, separate cycle).
- aarch64 boot path (different relocator; addressed when Pi SSH testing
  resumes — see iron-boot log carry-forward).
- Removing ELF32 emit from Cyrius — stays as latent capability per
  [[project-agnos-kernel-growth-rules]].

---

## Why this cut

Diagnosis confirmed 2026-05-13: GRUB-EFI on x86_64 invokes
`grub_relocator64_efi_boot` (lib/x86_64/efi/relocator.c) whose stub at
`grub_relocator64_efi_start` (lib/i386/relocator64.S:95-164) performs **no
long-mode-exit sequence** — no `cli`, no `lgdt`, no CR0.PG clear, no
CR4.PAE clear, no EFER.LME clear via `wrmsr`. The kernel is entered with
the CPU still in 64-bit long mode. Our ELF32 / EM_386 kernel triple-faults
at the first instruction because 32-bit opcodes are decoded as 64-bit in
long mode.

Three options were considered (see iron-boot log Attempt 4 for full
framing); Path A (this plan) was chosen over:

- **Path B** (long-mode-exit prologue keeping ELF32): hand-rolls the
  transition GRUB stopped doing. Fights firmware; no path toward Path C.
- **Path C** (sovereign UEFI bootloader, PE/COFF): right long-term answer
  but premature for MVP. Real PE/COFF + ExitBootServices engineering.

Path A inherits UEFI's long-mode state cleanly. The kernel shim becomes
*simpler*, not more complex.

---

## Scope by repo

### Cyrius (landed: 5.11.43, 2026-05-13)

**New function**: `EMITELF64_KERNEL` in `src/backend/x86/fixup.cyr`.
Sibling of existing `EMITELF_KERNEL` (line 664, ELF32) and references the
user-binary ELF64 emit at `EMITELF_USER` (line 827) for sizes/layout.

Emits:
- ELF64 header (64 bytes; `EI_CLASS=2 (ELFCLASS64)`, `e_machine=62 (EM_X86_64)`)
- PT_LOAD program header (56 bytes; PH64)
- **Multiboot2 header** (no longer multiboot1; see § Multiboot2 Header Layout)
- 5 section headers (.text + .rodata + .bss + .shstrtab + null) — same
  shape as Attempt 1's ELF32 fix, but ELF64 sh entries are 64 bytes
  (`shentsize = 64`)

**Dispatch hook (as landed)**: kept the existing kernel-mode value
(`L64(S + 0x18FCA0) == 1`) and gated emit-class selection on the new
`_TARGET_ELF64_KERNEL` flag (sibling of `_TARGET_MACHO` / `_TARGET_PE`).
Set from `CYRIUS_ELF64_KERNEL=1`. Source language unchanged — `kernel;`
emits ELF32 multiboot1 by default, ELF64 multiboot2 with the env var.
Rejected the "new directive" approach (would have required lexer +
6× parser site changes + reserved-word risk) per
[[feedback-language-extension-invasiveness]] memory.

**Section-header lesson from Attempt 1**: `e_shoff` must be non-zero,
section table must be valid, otherwise GRUB's `grub_elf64_get_shnum`
rejects the binary the same way `grub_elf32_get_shnum` did. The
section-table code in `EMITELF_KERNEL` (lines 772-820) is the template,
but offsets/sizes change for ELF64 (sh entries 40 → 64 bytes, sh_offset
and sh_size are u64 instead of u32, etc.).

**Estimated size**: ~250 lines (slightly larger than ELF32 because PH64
and shdrs are bigger, and multiboot2 header has variable-length tags
vs multiboot1's fixed 12 bytes).

**Cycle slot**: 5.11.32 is the next free slot (carry-forward in iron-boot
log shows .32/.33 reserved for `EMITELF_USER` (x86) + `EMITELF` (aarch64)
shdr cleanup; that work is **not** boot-blocking, so this can pre-empt it
or land alongside).

### Agnos (target: 1.30.0 — kernel ABI change)

**1. Cyrius pin bump**: `agnos/cyrius.cyml` → `cyrius = "5.11.43"`.

**2. Build invocation**: `scripts/build.sh` (or wherever the kernel
build target is defined) sets `CYRIUS_ELF64_KERNEL=1` before invoking
`cyrius build`. Source unchanged — `kernel;` directive stays.

**3. Boot shim rewrite** (`kernel/main_x86.cyr` or wherever the entry is —
verify at execution time). New entry-state contract:

| Register / State | Value at kernel entry |
|------------------|------------------------|
| CPU mode | Long mode (64-bit), CPL=0 |
| Paging | ON — UEFI's identity-mapped tables (typically first 4GB) |
| GDT | UEFI's flat 64-bit GDT (CS = 64-bit code, DS/ES/SS = data) |
| IDT | UEFI's (do not trust — install our own before enabling interrupts) |
| Interrupts | Disabled (per multiboot2 spec) |
| RAX | `0x36d76289` (multiboot2 boot magic) |
| RBX | Physical address of MBI (multiboot info structure) |
| RSP | Unspecified — install our own stack before any non-trivial work |
| Direction flag | Clear |
| UEFI boot services | Terminated (GRUB called ExitBootServices) |
| UEFI runtime services | May be available (firmware-dependent) |

**Drops from current shim:**
- 32-bit protected-mode CR4 setup (UEFI already configured CR4 to its
  taste; touching it from long mode requires care — defer)
- 32-bit stack initialization (we're already in long mode with a stack)
- Multiboot1 magic check (becomes multiboot2 magic check)

**Adds:**
- MBI tag walker (multiboot2 MBI is a tag stream, not the fixed
  multiboot1 struct — see § MBI Tag Walker)
- Stack relocation to a known-safe region before consuming MBI
- Install our own GDT + IDT before main kernel work (UEFI's are
  ephemeral and may be in memory that we'll reclaim)

**Bump rationale**: ELF32 → ELF64 + multiboot1 → multiboot2 + new entry
state is a kernel ABI break. 1.29.x → 1.30.0.

### Scripts (this repo)

**Single file**: `scripts/install-usb.sh`. The generated grub.cfg currently
uses:

```
multiboot /boot/agnos
module /boot/initramfs.cpio.gz
```

Change to:

```
multiboot2 /boot/agnos
module2 /boot/initramfs.cpio.gz
```

Trivial textual change. No `boot.cyr` (sovereign pipeline) changes
expected unless that script also emits grub.cfg directly — verify at
execution time.

---

## Multiboot2 header layout

Replaces the current multiboot1 header (`0x1BADB002 / 0x00000003 / 0xE4524FFB`,
12 bytes total, hardcoded at fixup.cyr:738-740). Total new size: **48 bytes**.
Must appear within the first 32 KB of the kernel file and be 8-byte aligned.

```
Offset  Size  Field              Value             Notes
─────── ───── ────────────────── ───────────────── ─────────────────────────
0x00    4     magic              0xE85250D6        multiboot2 magic
0x04    4     architecture       0x00000000        i386 (covers x86_64 too)
0x08    4     header_length      0x00000030        48 (total header size)
0x0C    4     checksum           0x17ADAEFA        −(magic+arch+length) (u32); (0xE85250D6 + 0 + 0x30 + 0x17ADAEFA) & 0xFFFFFFFF == 0

# Tag: ENTRY_ADDRESS_EFI64  (type=9, override ELF entry for EFI64 case)
0x10    2     type               9
0x12    2     flags              0
0x14    4     size               12
0x18    4     entry_addr         <kernel_entry>    Physical address (u32; <4GB)
0x1C    4     (padding to 8-align)

# Tag: MODULE_ALIGN  (type=6, force initramfs page-alignment)
0x20    2     type               6
0x22    2     flags              0
0x24    4     size               8

# Tag: END  (type=0, terminator)
0x28    2     type               0
0x2A    2     flags              0
0x2C    4     size               8

(End of header at 0x30 = 48 bytes)
```

**Tags deliberately omitted**:
- `EFI_BS` (tag 7) — *not* requested. Means GRUB calls ExitBootServices
  before handoff. Simpler post-EBS state inherited.
- `INFORMATION_REQUEST` (tag 1) — accept whatever MBI tags GRUB provides;
  walk and consume what we recognize.
- `FRAMEBUFFER` (tag 5) — we use serial + VGA text; no framebuffer
  console.
- `CONSOLE_FLAGS` (tag 4) — same reason.
- `RELOCATABLE` (tag 10) — not yet; kernel loads at fixed 0x100000 for
  symmetry with current build. Revisit when needed.

---

## Kernel entry-state contract

See agnos § "Boot shim rewrite" table above. The single most important
invariant for the new shim:

**We are already in long mode. Do not try to enter it.** Do not touch
CR0.PG, do not touch CR4.PAE, do not touch EFER.LME. UEFI set them
correctly; GRUB left them alone; we inherit them. Any attempt to "set
up paging" from the shim will fault.

---

## MBI tag walker

Multiboot2 MBI is at `physical(RBX)`. Structure:

```
0x00  u32  total_size       (includes header)
0x04  u32  reserved         (always 0)
0x08  ...  tag stream       (tags 8-byte aligned, terminated by END)
```

Each tag:

```
0x00  u32  type
0x04  u32  size             (includes this header; payload size = size - 8)
0x08  ... payload
```

Tags we care about (parse, store pointers; ignore the rest):

| Tag | Type | What |
|-----|------|------|
| BOOT_CMDLINE | 1 | Kernel cmdline string |
| BOOT_LOADER_NAME | 2 | "GRUB <ver>" — useful for debug print |
| MODULE | 3 | initramfs location + size (multiple tags possible) |
| BASIC_MEMINFO | 4 | mem_lower, mem_upper (legacy) |
| MMAP | 6 | E820-style memory map (preferred over BASIC_MEMINFO) |
| EFI_MMAP | 17 | UEFI memory map (preferred over MMAP when present) |
| EFI64 | 12 | EFI system table pointer (64-bit) |
| ACPI_NEW / ACPI_OLD | 15 / 14 | RSDP pointer |
| END | 0 | Stop |

For MVP shim: parse MODULE (initramfs), MMAP or EFI_MMAP (memory map).
Everything else can be ignored or deferred.

---

## Implementation order (small bites)

| # | Step | Verification gate | Repo | Status |
|---|------|-------------------|------|--------|
| 1 | `EMITELF64_KERNEL` in `src/backend/x86/fixup.cyr` — ELF64 + PH64 + multiboot2 + section table | check.sh green | cyrius | ✓ Landed 5.11.43 |
| 2 | `_TARGET_ELF64_KERNEL` target flag + `CYRIUS_ELF64_KERNEL=1` env-var dispatch in main.cyr; `EMITELF` routes kernel-mode based on flag | ELF32 default path unchanged; flag-on selects EMITELF64_KERNEL | cyrius | ✓ Landed 5.11.43 |
| 3 | Cyrius version bump → 5.11.43; CHANGELOG entry; install-snapshot refresh | `cc5 --version` reports 5.11.43; check.sh 68 passed, 0 failed | cyrius | ✓ Landed 2026-05-13 |
| 4a | agnos: bump `cyrius.cyml` pin to 5.11.43 (no flag — sanity check) | Build succeeds; output **bit-identical** to 5.11.29 build (same sha256, same 250968 bytes, ELF32/EM_386/entry 0x100060/5 sections, multiboot1 PASS) | agnos | ✓ Landed 2026-05-13 |
| 4b | agnos: build invocation sets `CYRIUS_ELF64_KERNEL=1` (in `scripts/build.sh` x86 branch; python validator extended to handle both ELF32/multiboot1 and ELF64/multiboot2) | Build produces 251160-byte ELF64/EM_X86_64 kernel, entry 0x1000a8, 5×64B section headers; multiboot2 header bytes verified at file offset 120; `grub-file --is-x86-multiboot2 build/agnos` PASS | agnos | ✓ Landed 2026-05-13 |
| 5a | agnos: kernel shim rewrite for long-mode entry — `#ifndef ELF64_KERNEL` wraps legacy 32-bit shim; `#ifdef ELF64_KERNEL` adds new 64-bit shim (stack at 0x200000 / UART verbatim / GDT verbatim / lgdt + push-lea-push-retfq for CS reload / segment reload). New `mbi.cyr` with `fn mbi_capture_rbx()` called immediately after shim (SysV ABI preserves RBX across call; local `var p = &mb_info_ptr;` loads RAX; raw `48 89 18` stores RBX → mb_info_ptr). `var mb_info_ptr[8];` in boot_data.cyr (uninitialized array → bypasses EMIT_GVAR_INITS clobber). `scripts/build.sh` prepends `#define ELF64_KERNEL` when env var set. | Build produces 251128-byte ELF64 with structurally-identical pattern to legacy (123-byte enum-init gap between trampoline target and shim start); `call mbi_capture_rbx` at virtual 0x11A05C resolves to virtual 0x1000AD ✓ | agnos | ✓ Drafted 2026-05-13 |
| 5b | QEMU OVMF UEFI emulation boot test | Boots into scheduler + tier3 test under emulated UEFI (the `grub_relocator64_efi_boot` path) | scripts/agnos | ✗ FAIL 2026-05-13 — #PF inside GRUB's relocator (W^X). See iron-boot log § *QEMU OVMF gate* + *Diagnosis 2*. |
| 6 | agnos version bump 1.29.x → 1.30.0; release | CI green; release artifact | agnos | **HOLD** (blocked on 5b resolution) |
| 7 | scripts/install-usb.sh: grub.cfg `multiboot` → `multiboot2`, `module` → `module2` | `install-usb.sh` writes a parseable grub.cfg (boot menu shows entries) | scripts | ✓ Landed 2026-05-13 (multiboot/module → multiboot2/module2 in all 3 menuentries + the surrounding comment block) |
| 8 | Full re-provision `/dev/sdb` (not `--update`); iron Attempt 5 on NUC AMD | Iron boots into the scheduler/tier3 test serial output OR fails with new symptom (further along boot chain than Attempt 4) | scripts | **HOLD** (would re-hit iron Attempt 3/4 reset until 5b resolved) |

---

## Status update — 2026-05-13

Path A's cyrius + agnos work landed (Steps 1-5a), and the in-repo
install-usb.sh change landed (Step 7). **Step 5b — the QEMU OVMF
emulation gate — failed inside GRUB's relocator before any byte of
the kernel executed.** Diagnosis: GRUB's `grub_relocator64_efi_boot`
issues six `movabs %rax, <addr_inside_stub>` writes patching kernel
register state directly into `.text` of the loaded `relocator.mod`
(positions verified via .rela.text at offsets 0x342B-0x3471 mapping
to `grub_relocator64_{rax,rbx,rcx,rdx,rip,rsi}` at .text 0x8AA-0x8F7).
Under OVMF 2024+ strict-W^X (UEFI Memory Attributes Protocol), those
writes fault. Linux distros skip this path entirely — they boot via
`linuxefi` / `grub_linux_boot`, not multiboot2.

The bit-identical "WARNING: no console will be available to OS" +
reset on iron Attempts 3/4 is almost certainly the same fault — on
bare iron with no exception handlers, it cascades to triple-fault →
reset. OVMF caught it cleanly.

**This means Path A as drafted will not boot through GRUB on
strict-W^X UEFI**, and the resolution requires one of:

1. **Bring Path C (sovereign UEFI bootloader) forward** — pre-empts the
   long-term roadmap item but removes the GRUB dependency entirely.
2. **Vendor a patched GRUB** with `grub_relocator64_efi_boot`
   refactored to allocate a writable trampoline + copy-before-patch,
   OR to call `MemoryAttributesProtocol->SetMemoryAttributes` to drop
   the RO bit on the relocator pages before writing.
3. **Linux Boot Protocol pretender** — synthesize a bzImage-shaped
   header on the AGNOS kernel so GRUB's `linuxefi` command takes the
   well-tested (and W^X-correct) Linux-protocol path. Wastes the
   multiboot2 plumbing we just put in cyrius 5.11.43, but reuses
   GRUB without patching it.
4. **Loose-W^X OVMF rebuild** — confirm the diagnosis end-to-end
   under emulation. If the kernel boots cleanly under loose-W^X
   OVMF, the analysis is fully validated and we know real-iron success
   depends on whatever the NUC AMD firmware does with W^X.

Cyrius work is **not** at fault. `EMITELF64_KERNEL` produces a
correct ELF64 multiboot2 kernel that GRUB *accepts* — RAX magic was
loaded, the handoff was prepared. The fault is upstream of any cyrius
emission, in GRUB's design. No cyrius issue to file from this gate.

**Decision needed** before iron Attempt 5 is re-attempted. Resolution
options 1-4 above are not equivalent in scope — pick the path before
spending more cyrius/agnos work.

**Each step is a separate verification gate.** Steps 1-3 are cyrius
work; 4-6 are agnos work; 7-8 are this repo. Per `CLAUDE.md` § DO NOT:
the user handles all commits and tagging.

---

## Test plan

**QEMU UEFI emulation** (step 5 gate): Boot under OVMF firmware
(`qemu-system-x86_64 -bios /usr/share/edk2-ovmf/x64/OVMF.fd -drive ...`)
to exercise the same `grub_relocator64_efi_boot` path the NUC AMD's
firmware will use. The `-kernel` flag is *not* equivalent — it
bypasses GRUB and uses QEMU's Linux-protocol shim (which is what
masked the Attempt 1-4 problem in the first place).

OVMF firmware may need to be installed on the devbox if not present:
- Arch: `pacman -S edk2-ovmf`
- Verify path: `/usr/share/edk2-ovmf/x64/OVMF.fd` or `/usr/share/OVMF/OVMF_CODE.fd`

**Iron Attempt 5** (step 8 gate): Full `install-usb.sh` re-provision
(not `--update`, since grub.cfg changes), boot the NUC AMD, observe.

Possible outcomes and what they mean:

| Observed | Implication |
|----------|-------------|
| Boots into scheduler + tier3 test (clean serial output) | Path A success. Closed-beta MVP gate cleared on NUC AMD. Move to kybernet + agnoshi integration. |
| Boots partway (banner visible, then hang/fault) | Path A architecturally correct; remaining bug is in our shim's MBI walker or stack setup. Bisect with serial output. |
| Same `WARNING: no console will be available` + reset | grub.cfg didn't switch to multiboot2, OR kernel still has multiboot1 header (verify with `grub-file --is-x86-multiboot2 build/agnos`), OR section table is malformed (verify with `readelf -h`). Diagnosis-bisectable. |
| Different error / different reset point | Capture verbatim; new failure class, separate diagnosis. |

---

## Open decisions

These should be resolved with Robert before cyrius work begins:

1. **64-bit-kernel mode signaling in cyrius.** Magic value (`L64(S+0x18FCA0)==4`)
   is consistent with the existing pattern but is opaque. A compiler flag or
   directive would be more discoverable. Decision needed.
2. **Section-table sh_entsize for ELF64.** ELF64 spec says 64 bytes; the
   `EMITELF_USER` path at line 827 (already ELF64) should be reused as the
   template. Verify at implementation time.
3. **Stack-pointer policy in the new shim.** Multiboot2 doesn't specify
   where RSP points. Linux's EFI stub installs its own stack immediately;
   we should do the same. Where do we put it — fixed address, or pulled
   from a known-safe range in the memmap? MVP: fixed address (e.g. 0x90000,
   below the kernel). Revisit when relocatable.
4. **CR4 SMEP/SMAP in long mode.** The v1.29.1 CPUID-gated CR4 logic is
   for the *32-bit* shim path. In long mode under UEFI, CR4.SMEP and
   CR4.SMAP are already set by firmware. Leave them alone in the MVP
   shim. Revisit when we install our own page tables and need to
   re-establish them.
5. **Cyrius cycle ordering.** If 5.11.32 is needed urgently for
   iron-boot, does it pre-empt the queued user-binary ELF shdr cleanup
   (`EMITELF_USER` x86 + aarch64 `EMITELF`)? Or land alongside? Project
   leader's call.

---

## Doc trail

- Diagnosis: `iron-boot-testing-log.md` § *Diagnosis — 2026-05-13 GRUB
  source review* — files examined, root cause, hypotheses mapping
- Decision: this doc + [[project-agnos-bootloader-roadmap]] memory
- Execution: log each step's verification in the iron-boot log;
  Attempt 5 is the integration gate
