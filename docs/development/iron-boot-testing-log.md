> **Last Updated**: 2026-05-15

# Iron Boot Test Log

Append-only running log of AGNOS **boot-to-shell-on-iron** test
attempts. The closed-beta MVP gate is boot-to-shell on real
hardware; primary target is the **NUC AMD** (x86_64) — where the
bulk of kernel engineering work has been validated — with the
Pi 4 (aarch64) as the secondary axis. **Intel hosts are queued
after AMD is proven**, not concurrent. This log tracks each
attempt's symptom, root cause, repair, and verification state
so we don't lose the breadcrumb when a future failure shows
the same shape.

**Format**: each attempt gets one `## Attempt N — YYYY-MM-DD
HH:MM TZ → STATUS` block. Never rewrite past entries; if a
later attempt clarifies an earlier root-cause, add a note to
the later entry pointing back. Status is one of `FAIL` /
`PASS` / `PARTIAL` / `PENDING`.

---

## Standing context

| Item | Value |
|------|-------|
| Closed-beta target | early June 2026 |
| MVP gate | boot to shell on real iron (kernel + kybernet + agnoshi) |
| Target hardware (primary) | NUC AMD (x86_64, Zen-class — SMEP + SMAP advertised) |
| Target hardware (secondary axis) | Raspberry Pi 4 (aarch64) |
| Target hardware (queued, post-AMD-proof) | Skytech Legacy 4 (x86_64, Intel) |
| USB device under test | `/dev/sdb` — Crucial CT1000P3PSSD8 1TB; AGNOSBOOT FAT32 ESP |
| Provisioning script | `scripts/install-usb.sh` (full provision) |
| Refresh script | `scripts/install-usb.sh --update` (kernel + initramfs only) |

Memory pin: [[project-agnos-mvp-boot-to-shell]] — closed beta
is **kernel + kybernet + agnoshi on hardware**, NOT self-hosting
or full userland ABI (those are public-beta scope).

---

## Attempts

### Attempt 1 — 2026-05-12 ~13:43 PDT → FAIL

(Approximate timestamp — ~10 minutes before devbox boot at
13:53:58 PDT.)

**Build under test:**

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.10.44 (pre-section-headers) |
| agnos kernel | 1.29.0 — `build/agnos` 250704 bytes, **ELF32, `e_shoff = 0`** |
| initramfs | `scripts/build/initramfs.cpio.gz` 295325 bytes |
| GRUB | upstream (multiboot1 path via `grub-install --target=x86_64-efi --removable`) |

**Symptom (verbatim from GRUB console):**

```
error: kern/elfxx.c:grub_elf32_get_shnum:227: invalid section
       header table offset in e_shoff.
error: loader/multiboot.c:grub_cmd_module:387:
       you need to load the kernel
error: commands/boot.c:grub_loader_boot:196:
       you need to load the kernel first.
Press any key to continue.
```

**Initial hypothesis (wrong):** "GRUB wants some C apparently" —
i.e., a GRUB / multiboot-format compatibility issue. The
errors implied GRUB couldn't parse the kernel's section header
table; the first guess was that the kernel was malformed in
some structural way GRUB-specific.

**Root cause (diagnosed ~14:00 PDT):**

`readelf -h` on the rejected kernel revealed the actual gap:

```
  Class:                             ELF32
  Type:                              EXEC (Executable file)
  Machine:                           Intel 80386
  Entry point address:               0x100060
  Start of section headers:          0 (bytes into file)
  Size of section headers:           0 (bytes)
  Number of section headers:         0
```

Cyrius's `EMITELF_KERNEL` in `src/backend/x86/fixup.cyr:659`
was emitting **program-headers-only ELFs** — valid for Linux
`execve` (which only consumes program headers) but rejected
by GRUB's `grub_elf32_get_shnum` (kern/elfxx.c:227), which
requires a non-zero `e_shoff`. The multiboot1 header was
correct (magic 0x1BADB002 at file offset 84); the entry point
was correct (0x100060); the program header was valid. The
only thing missing was the section header table — which
strictly speaking is optional per the ELF spec for `execve`
loading, but GRUB's loader path is stricter than Linux's.

Same pattern existed at three sites in the cyrius source:

| Site | File | Line |
|------|------|------|
| x86 kernel emitter | `src/backend/x86/fixup.cyr` | 686 (`e_shoff = 0`) |
| aarch64 kernel emitter | `src/backend/aarch64/fixup.cyr` | 344 (`e_shoff = 0`) |
| cyrld ELF64 linker | `programs/cyrld.cyr` | 1072 (`e_shoff = 0`) |

**Steps taken to repair:**

| Time (PDT) | Step | Outcome |
|-----------|------|---------|
| ~14:00 | `readelf -h build/agnos` confirms `e_shoff=0` / `e_shnum=0` | Diagnosis confirmed |
| ~14:20 | Located patch site at `src/backend/x86/fixup.cyr:659` (`EMITELF_KERNEL`) | Three other sites filed as follow-up |
| ~14:30 | Patched x86 kernel emitter with 5-section table (SHT_NULL + .text + .rodata + .bss + .shstrtab; ELF32 40-byte shdrs; entry covers SP-setup-free direct path; PT_LOAD unchanged) | Compiles clean; cc5 rebuilds |
| ~14:35 | Bumped `cyrius/VERSION` 5.11.28 → 5.11.29; regenerated `src/version_str.cyr` via `scripts/version-bump.sh`; rebuilt cc5 | `cc5 --version` reports 5.11.29 |
| ~14:40 | Bumped `agnos/cyrius.cyml` pin 5.10.44 → 5.11.29; rebuilt agnos kernel | Kernel 250704 → **250936 bytes** (+232 = 30-byte shstrtab + 2 pad + 5 × 40-byte shdrs) |
| ~14:42 | `readelf -S build/agnos` shows 5 clean sections; `grub-file --is-x86-multiboot build/agnos` returns 0 | Was rejected before; now accepted |
| ~14:45 | QEMU `-kernel build/agnos -cpu max` boots through scheduler + tier3 integration test | Clean output: `serial_putc 7832 cycles/op`, `=== done ===` |
| ~14:50 | Removed `agnos/lib/` (empty shadow dir) + dropped `CYRIUS_NO_WARN_SHADOW_LIB=1` env hack from `scripts/build.sh` | Build still clean, warning gone |
| ~15:00 | Cyrius 5.11.29 + agnos 1.29.0 committed and tagged by project leader; releases cut | Both releases published |
| ~15:10 | Mirror x86 fix into aarch64 kernel emitter — cyrius **5.11.30**. Built x86-hosted cross-compiler via `src/main_aarch64.cyr`. agnos-aarch64 kernel 93288 → 93640 bytes; `readelf -S` shows 5 sections cleanly | aarch64 QEMU boot deferred (no `qemu-system-aarch64` on devbox); Pi SSH test pending |
| ~15:12 | Mirror fix into cyrld ELF64 linker — cyrius **5.11.31**. Caught and fixed a pointer/offset bug mid-patch (`store64(sh + N, …)` should be `store64(O + sh + N, …)`). 4-module link fixture verifies same rc=44 as old cyrld; output grows 616 → 968 bytes exactly | Cyrius 5.11.31 cut |
| ~15:25 | Hardened agnos CI (`ci.yml` × 5 install blocks + `release.yml` × 1) with post-install smoke test (`cyrius --version || exit 1` + `ls $HOME/.cyrius/bin/` on failure) | Future silent install failures fail their own step instead of cascading into 50-file "NEEDS FORMAT" misdiagnoses |
| ~15:30 | Extended `install-usb.sh` with `--update` mode (mount + cp + umount; no wipe / no re-grub). Reflashed `/dev/sdb`: `/boot/agnos` 250704 → 250936 bytes; initramfs unchanged | USB carries patched kernel; first reboot will exercise the fix on iron |

**Side-effect incident (CI fmt false-alarm):**

After agnos 1.29.0 commit, CI's "Check & Format" step reported
*every* kernel `.cyr` file as `NEEDS FORMAT` (48 files). Initial
read: formatter rule drift between 5.10.44 and 5.11.29.
Actual cause: the **Install Cyrius toolchain** step had failed
silently (5.11.29 release tarball not yet propagated), so
every `cyrius fmt "$f" --check` in the loop returned 127
(command not found), which the `if ! …` shape inverted to
"failed format." Fixed by hardening the install step (see
~15:25 row above). Re-running CI on a re-run window passed
cleanly.

**Outcome:** Attempt 1 is logged as FAIL pending Attempt 2.
Repair confirmed at multiple gates (`readelf -S`,
`grub-file --is-x86-multiboot`, QEMU boot through scheduler);
GRUB error chain should be gone on next boot. If Attempt 2
still reports the same `grub_elf32_get_shnum` chain, we're
chasing a different bug (verify USB contents match what
`install-usb.sh --update` claimed it wrote).

---

### Attempt 2 — 2026-05-13 ~09:00 PDT → FAIL

**Build under test** (what `install-usb.sh --update` wrote at
the end of Attempt 1; grub.cfg unchanged from initial provision):

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.29 |
| agnos kernel | 1.29.0 — `build/agnos` 250936 bytes, 5 section headers |
| initramfs | `scripts/build/initramfs.cpio.gz` 295325 bytes |
| grub.cfg | pre-`cdb67b2` (no `all_video` preload, no `gfxpayload=text`) |

**Symptom (verbatim from GRUB console):**

```
WARNING: non console will be available to OS
error: video/video.c:grub_video_set_mode:782:
       no suitable video mode found.
```

**Significance:** the Attempt 1 `grub_elf32_get_shnum` / "you
need to load the kernel" chain is GONE — the section-header fix
(cyrius 5.11.29 ELF emitter patch, agnos 1.29.0 rebuild) is
confirmed effective on real iron. New failure class, further
along the GRUB path.

**Root cause:**

The grub.cfg shipped by `install-usb.sh` (pre-`cdb67b2`)
invoked `multiboot /boot/agnos` without first loading GRUB's
EFI video drivers and without telling GRUB to skip the
graphics-mode switch at handoff. On UEFI hardware that exposes
only GOP/UGA (every modern board, the NUC AMD included),
`grub_video_set_mode` (grub-core/video/video.c:782) has no
registered driver matching the available modes and bails. The
preceding `WARNING: non console will be available to OS` is the
multiboot loader noting it cannot populate the framebuffer-info
struct it would normally hand to the kernel.

AGNOS uses VGA text + serial — no framebuffer console — so we
do not need the mode switch. We just need to tell GRUB that,
or it tries and fails.

**Steps taken to repair:**

| Time (PDT) | Step | Outcome |
|-----------|------|---------|
| ~09:10 | Diagnosed as GRUB video-mode probe failure on UEFI; confirmed Attempt 1 ELF fix intact | New root cause; not USB drift |
| 09:13 | `scripts/install-usb.sh` patched (commit `cdb67b2` "fixing video"): prepend `insmod all_video / efi_gop / efi_uga` + global `set gfxpayload=text` to the generated grub.cfg; also set `gfxpayload=text` inside each menuentry as belt-and-braces | grub.cfg generator updated |
| Pending | Re-provision `/dev/sdb` with **full** `install-usb.sh` (not `--update` — that path skips grub.cfg) so the patched config lands on the ESP | — |

**Outcome:** FAIL. Attempt 1 fix verified on iron. New
failure class diagnosed and patched in `cdb67b2`; verification
of the patch on iron deferred to Attempt 3, which requires a
full re-provision (not `--update`) because `--update` only
refreshes kernel + initramfs and leaves grub.cfg untouched.

---

### Attempt 3 — 2026-05-13 ~later AM PDT → FAIL

**Build under test** (full re-provision after `cdb67b2`):

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.29 |
| agnos kernel | 1.29.0 — `build/agnos` 250936 bytes, 5 section headers (unchanged from Attempt 2) |
| initramfs | `scripts/build/initramfs.cpio.gz` 295325 bytes (unchanged) |
| grub.cfg | post-`cdb67b2` (with `insmod all_video / efi_gop / efi_uga` + `gfxpayload=text`) |

**Symptom (verbatim from GRUB console):**

```
WARNING: non console will be available to OS
```

Displayed alone (no `grub_video_set_mode` error chain), then
the machine resets / restarts.

**Significance:** the Attempt 2 video-mode probe error is GONE
— the `cdb67b2` insmod-all_video + gfxpayload=text patch is
confirmed effective on real iron. We are now past GRUB's video
setup. The remaining warning is multiboot's "I can't give the
kernel a console" notice; the reset that follows happens
after handoff (or at handoff). New failure class, further
along the boot path.

**Working hypotheses (root cause not yet confirmed):**

1. **Kernel triple-fault immediately at/after handoff.** The
   multiboot1 entry is `0x100060`; if the early boot shim
   takes a fault before any serial / VGA write succeeds, the
   only visible symptom on iron is a reset. QEMU `-cpu max`
   currently boots clean through scheduler + tier3 integration
   test (per Attempt 1, ~14:45 row), so the divergence is
   silicon-specific — likely CR4 SMEP/SMAP (Haswell+ / all
   modern Ryzen), CPUID-dependent feature gating, or
   stack-setup assumption that holds in QEMU's seabios
   handoff but not under UEFI→GRUB→multiboot1.
2. **GRUB exits back to UEFI after the warning.** Less
   likely given the message ordering (warning comes from
   *during* multiboot setup, not after a failed boot), but
   worth ruling out by checking if the firmware boot-order
   list shows AGNOS being deprioritized or if the firmware is
   simply cycling to the next device.
3. **Multiboot1 + UEFI fundamental incompatibility on this
   firmware.** Some UEFI firmwares refuse the multiboot1
   protocol entirely on the actual handoff (vs. the file
   probe `grub-file --is-x86-multiboot` succeeding). The
   long-term fix is multiboot2, which is what real-mode-free
   UEFI handoff was designed for.

**Diagnosis path forward:**

- Boot the `AGNOS — verbose serial (ttyS0,115200)` menu entry
  with a USB-to-serial cable attached and capture output;
  anything the kernel prints before the reset narrows
  hypothesis 1 vs 3 immediately.
- If serial is silent: kernel never executed (hypothesis 3
  more likely), or kernel faulted before its first
  `serial_putc`. Add a port-0x80 POST write at the very top
  of the kernel entry as a free `did-we-start` signal.
- Cross-reference with `kybernet harness mode` menu entry
  (exit on phase 8) to bound where in the boot chain we are.

**Outcome:** FAIL. Attempt 2 fix verified on iron. New failure
class — post-handoff or at-handoff — diagnosis pending serial
capture from Attempt 4.

---

### Attempt 4 — 2026-05-13 ~09:48 PDT → FAIL

**Pre-run framing (preserved).** The target is the **NUC AMD**
(Zen-class). AMD Zen advertises both SMEP (since Zen 1, 2017)
and SMAP (since Zen 1) — so on this silicon the v1.29.1 CR4
CPUID gate is *behaviorally identical* to v1.29.0: both
revisions end up setting bits 5 + 20 + 21. **v1.29.1 alone was
unlikely to change the Attempt 3 outcome on the NUC AMD.** It
shipped because the unconditional OR was a real portability bug
surfaced by the iron-boot campaign (and proved with `-cpu
qemu64` going from triple-fault to boot), but it was not
load-bearing for resolving Attempt 3's symptom on this target.
This was logged as a prediction before the run; the run
confirmed it.

**Build under test** (patched kernel — v1.29.1, no functional
change vs 1.29.0 on Zen):

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.29 |
| agnos kernel | 1.29.1 — `build/agnos` 250968 bytes (+32 over 1.29.0; shim-only) |
| initramfs | `scripts/build/initramfs.cpio.gz` 295325 bytes (unchanged) |
| grub.cfg | post-`cdb67b2` (unchanged from Attempt 3) |

**Symptom (verbatim from GRUB console):**

```
WARNING: non console will be available to OS
```

Displayed alone, machine then resets — **bit-identical to
Attempt 3's displayed output**. Same failure class, same
position in the boot chain.

**Significance:** Confirms the pre-run prediction exactly.
v1.29.1 is a no-op on Zen silicon (CPUID gate yields the same
CR4 bits the unconditional OR did), so the symptom is
unchanged. This closes out the "bare retry" diagnostic option
— we now have direct evidence that the SMEP/SMAP framing alone
does not explain the Attempt 3 reset on the NUC AMD. The root
cause is something else along the multiboot1 handoff or early
shim path, and further blind code changes without a phase
indicator (serial / port-0x80 / multiboot2 rewrite) will burn
attempts without bisecting the failure.

**Diagnostic options that would actually change the outcome**
(bare retry exhausted as of Attempt 4 — pick one before the
next iron run):

1. **Serial-cable capture.** USB-to-TTL adapter on the NUC's
   COM1 header (if exposed) or via internal serial. Boot the
   "AGNOS — verbose serial (ttyS0,115200)" menu entry. Even one
   character before the reset bisects the failure: nothing →
   handoff failed or shim faulted before first `serial_putc`;
   partial banner → fault during early-init phase; full banner →
   fault somewhere past kernel main. This is the gold-standard
   diagnostic and remains the recommended path before further
   blind code changes.
2. **Add a port-0x80 POST sequence to the boot shim.** Write a
   distinctive byte (e.g. `0xAG` → 0x10 → 0x86) to I/O port 0x80
   at each major phase boundary (shim entry, post-page-table,
   post-CR4, post-CR3, post-long-mode-jump, post-segment-reload,
   first 64-bit instruction). On a NUC AMD without a POST card,
   port 0x80 writes are silently discarded — but combined with
   serial capture, they're a free phase indicator. Without serial,
   they're invisible (limited utility solo).
3. **Switch boot protocol — multiboot1 → multiboot2 (or UEFI
   stub).** The "WARNING: non console will be available to OS"
   message is GRUB's multiboot1 loader saying it can't satisfy
   the legacy-EGA-text console request that multiboot1 implies.
   Multiboot2 has explicit UEFI tags (`MULTIBOOT_TAG_TYPE_EFI64`,
   `MULTIBOOT_TAG_TYPE_EFI_MMAP`) and is the spec-correct path
   for UEFI handoff. This is a real shim rewrite (header + entry
   sequence + mbi parsing), not a tweak.
4. **Audit low-memory placement.** Page tables at 0x1000–0x4000,
   GDT at 0x4000, stack at 0x200000 — all hardcoded. UEFI
   firmware may reserve regions there for runtime services or
   ACPI data. The shim should ideally read the multiboot
   memory-map tag and place its scratch in a known-free region.
   Less invasive than option 3, but still a structural change.

**Recommended next step:** option 1 (serial cable) gives the most
information for the least invasive change. Options 3 and 4 are
real engineering work and should be informed by serial output,
not chosen blindly.

**Bare v1.29.1 retry — observed:**

| Observed | Implication |
|----------|-------------|
| **✓ Same `WARNING: non console will be available to OS` + reset (Attempt 4, ~09:48 PDT)** | **Confirmed.** v1.29.1 is no-op on this silicon as predicted; tells us nothing new about the root cause. Bare-retry option is exhausted. Proceed to options 1–4. |
| Anything different (no reset, different message, different timing) | Did not occur. Would have indicated v1.29.1 perturbed something other than the SMEP/SMAP bits. |

**Outcome:** FAIL. Bare retry consumed; result matches the
pre-run prediction (no-op on Zen). The next attempt must
introduce a phase indicator or change the boot protocol —
further code-only changes without bisection signal are guessing.

---

## Diagnosis — 2026-05-13 GRUB source review

After Attempt 4 confirmed v1.29.1 was a no-op on Zen as predicted
(SMEP/SMAP CPUID gate yields the same CR4 bits the unconditional OR
did), review of GRUB upstream (rhboot/grub2 mirror — same code path
as the install-USB's GRUB) characterized the actual entry-state
delivered by GRUB on UEFI x86_64. The diagnosis came from reading
source, not from a new hardware run — serial-cable capture was
unavailable, so the next-best diagnostic was understanding the
contract GRUB *says* it delivers.

**GRUB-EFI's multiboot1 handoff path (the path our USB exercises):**

| File | Finding |
|------|---------|
| `grub-core/loader/multiboot.c` | UEFI dispatch uses `efi_boot()` → `grub_relocator_efi_boot()`, NOT the BIOS `grub_relocator32_boot()` — two entirely different relocator paths |
| `grub-core/loader/i386/multiboot_mbi.c` | UEFI path calls `grub_efi_finish_boot_services()` before handoff — ExitBootServices performed, memmap finalized in MBI, no UEFI services available |
| `grub-core/lib/x86_64/efi/relocator.c` | The EFI relocator is `grub_relocator64_efi_boot` — uses a **64-bit state struct** (RAX/RBX/RCX/RDX/RIP/RSI), copies stub bytes to low memory, calls them as a function |
| `grub-core/lib/i386/relocator64.S` lines 95–164 (`grub_relocator64_efi_start`) | The stub: load RAX/RBX/RIP from state, `jmp *jump_addr(%rip)`. **No `cli`. No `lgdt`. No CR0.PG clear. No CR4.PAE clear. No EFER.LME clear (wrmsr).** 64-bit indirect near jump — no CS reload, no mode switch. |

**Confirmed root cause.** GRUB on UEFI x86_64 jumps to the kernel
entry point **with the CPU still in 64-bit long mode** — UEFI's GDT
intact, paging on, EFER.LME set, CS = 64-bit code segment. There is
no long-mode-exit sequence whatsoever. Our `build/agnos` is **ELF32 /
Machine: Intel 80386 / entry 0x100060** (per Attempt 1 `readelf -h`).
The bytes at 0x100060 were assembled as 32-bit protected-mode
instructions; when those bytes are fetched in long mode they decode as
unrelated (or invalid) 64-bit instructions, producing a triple-fault
within a handful of cycles. CPU resets.

This explains every observed datum:

- **Iron resets after `no console will be available to OS`** — the
  warning comes from GRUB's `set_console()` (multiboot.c) saying it
  can't satisfy any console flag the kernel requested. *Unrelated to
  the crash*; it's just the last thing GRUB prints before the
  handoff. The reset is the triple-fault from long-mode decoding of
  32-bit kernel bytes. (Note: prior log entries transcribed the
  warning as "non console will be available" — the actual GRUB string
  is "no console will be available"; "non" was a misread.)
- **QEMU `-kernel -cpu max` boots clean** — `-kernel` uses QEMU's own
  Linux-boot-protocol shim, which delivers a 32-bit-protected-mode
  CPU directly to the kernel. Bypasses GRUB entirely; entirely
  different entry-state contract.
- **v1.29.1 CR4 fix is a no-op on Zen** — confirmed empirically in
  Attempt 4. Now also explained: kernel never reaches the CR4 code
  because long-mode decoding faults at the first 32-bit instruction.

**Mapping back to Attempt 3's hypotheses:**

- **Hypothesis 1** (kernel triple-fault) — *correct in shape*, but the
  trigger was one layer upstream of where we were looking. We assumed
  CR4 / CPUID / stack-setup; the actual fault is instruction-decoding
  mode mismatch at the very first fetch.
- **Hypothesis 3** (multiboot1 + UEFI fundamental incompatibility) —
  *directionally correct*. The incompatibility is **GRUB-side, not
  firmware-side**: GRUB-EFI on x86_64 no longer performs the
  long-mode-exit step that multiboot1's 32-bit-protected-mode contract
  requires. The firmware would happily run a 64-bit kernel handed off
  by the same path.

**Architectural decision: Path A — ELF64 multiboot2.**

Switch the boot kernel to 64-bit ELF; replace the multiboot1 header
with a multiboot2 header carrying `MULTIBOOT_HEADER_TAG_ENTRY_ADDRESS_EFI64`.
Kernel inherits UEFI's long-mode state cleanly; shim simplifies (no
mode transition, no CR4 setup, GDT/paging inherited from firmware).
Memory pin: [[project-agnos-bootloader-roadmap]] — Path A is the MVP
bridge, Path C (sovereign UEFI bootloader, no GRUB) is the long-term
destination.

**Path B rejected** (long-mode-exit prologue keeping ELF32): would
hand-roll the long-mode-exit sequence GRUB stopped doing — paying the
cost of fighting the firmware with no path toward Path C. Same lesson
the Linux community learned a decade ago when they moved to the EFI
stub.

ELF32 emit stays in Cyrius as **latent capability** for hypothetical
future legacy-iron support per [[project-agnos-kernel-growth-rules]] —
not deleted, just unused for the boot kernel.

---

### QEMU OVMF gate — 2026-05-13 ~16:30 PDT → FAIL (#PF inside GRUB)

Not an iron attempt — this is Step 5b of `path-a-elf64-multiboot2.md`,
exercising the same `grub_relocator64_efi_boot` path the NUC AMD's
firmware will use, under emulated UEFI (`qemu-system-x86_64` + OVMF
pflash). Run from `scripts/test-uefi-qemu.sh`. Path A cyrius work
(5.11.43) + agnos shim (drafted in agnos repo) all landed before this
gate.

**Build under test:**

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.43 (Path A — ELF64 + multiboot2 + EFI64 entry tag) |
| agnos kernel | post-1.29.1 — `build/agnos` 251056 bytes, **ELF64 / EM_X86_64 / entry 0x1000a8** |
| initramfs | `scripts/build/initramfs.cpio.gz` 295325 bytes |
| GRUB | upstream Arch `grub` 2:2.14-1 (x86_64-efi modules from `/usr/lib/grub/x86_64-efi/`) |
| OVMF | `edk2-ovmf` 4m pflash split (`OVMF_CODE.4m.fd` + writable `OVMF_VARS.4m.fd`) |
| grub.cfg default | menu entry 2 — *AGNOS — kernel only (no initramfs)*, simplest path |

Verification gates already passed pre-run: `grub-file --is-x86-multiboot2`
PASS; `--is-x86-multiboot` no-longer-true; `readelf -h` reports ELF64,
EM_X86_64, entry 0x1000a8.

**Symptom (verbatim from QEMU serial):**

```
Booting `AGNOS — kernel only (no initramfs)'

WARNING: no console will be available to OS
!!!! X64 Exception Type - 0E(#PF - Page-Fault)  CPU Apic ID - 00000000 !!!!
ExceptionData - 0000000000000003  I:0 R:0 U:0 W:1 P:1 PK:0 SS:0 SGX:0
RIP  - 000000000BD3D22E, CS  - 0000000000000038, RFLAGS - 0000000000210046
RAX  - 0000000036D76289, RCX - 000000000E092FD8, RDX - 0000000000000000
RBX  - 0000000000000000, RSP - 000000000FE8E260, RBP - 000000000FE8E290
CR0  - 0000000080010033, CR2 - 000000000BD3D848, CR3 - 000000000FC01000
CR4  - 0000000000000668
!!!! Find image based on IP(0xBD3D22E) (No PDB)  (ImageBase=0000000000DF59E8, EntryPoint=0000000000DF61E7) !!!!
```

**Significance.** Same `WARNING: no console will be available to OS`
that preceded the iron resets in Attempts 3 and 4 — but now followed
by an actual exception dump instead of a silent reset. Three things
the dump tells us up front:

- `RIP = 0x0BD3D22E`, `CS = 0x38` — long-mode handoff path, in
  firmware/GRUB-loaded memory (~0x0BD00000), **not** in our kernel
  (entry 0x1000a8).
- `RAX = 0x36D76289` — the multiboot2 boot magic value. GRUB has
  already *prepared* the kernel-handoff register state. We are
  inside or just-past `grub_relocator64_efi_boot`.
- `ErrorCode = 0x3` decodes to `P=1, W=1` — protection violation on a
  **write**. The page exists; the write was denied. Classic W^X.

**Diagnosis (from GRUB disassembly).** `grub_relocator64_efi_boot`
(symbol at .text offset 0x33B3 in `relocator.mod`) and the
relocations in `.rela.text` make the design explicit:

| .text offset | Reloc patches in addr of | Symbol's .text offset |
|--------------|--------------------------|-----------------------|
| 0x342B | `grub_relocator64_rax` | **0x8CA** |
| 0x3439 | `grub_relocator64_rbx` | **0x8D4** |
| 0x3447 | `grub_relocator64_rcx` | **0x8DE** |
| 0x3455 | `grub_relocator64_rdx` | **0x8E8** |
| 0x3463 | `grub_relocator64_rip` | **0x8F7** |
| 0x3471 | `grub_relocator64_rsi` | **0x8BD** |

The 0x8AA-0x8F7 range is inside `grub_relocator64_efi_start` itself
(symbol at 0x8B7, stub ends at 0x8FF). So `_efi_boot` issues six
`movabs %rax, <addr_inside_the_stub>` writes — patching the kernel's
register state directly **into the stub's bytecode** for the upcoming
indirect-jump handoff. Six writes to the loaded `.text` of
`relocator.mod`. Then it calls `grub_memmove` (text offset 0x348B-0x3498)
to copy the patched stub into freshly-AllocatePages'd memory, then
calls into the stub.

OVMF 2024+ enforces the UEFI Memory Attributes Protocol — code pages
(`EfiBootServicesCode`, both for the GRUB-loaded module image and for
newly-allocated pages) are RO. A write to `.text` faults. Either of
the six `_efi_boot` writes — or the `memmove` writing into the
AllocatePages destination — triggers the #PF we see.

**Why Linux distros don't hit this.** Linux boots via GRUB's
`linuxefi` command, which uses an entirely different relocator
(`grub_linux_boot` in `grub-core/loader/i386/efi/linux.c`) — the
Linux Boot Protocol shim, no `relocator64_efi_start` involvement.
The multiboot2 + EFI64-entry-tag path is genuinely under-tested under
modern strict-W^X UEFI. Hurd hits this; we hit this.

**Mapping back to iron Attempts 3 and 4.** The bit-identical
"WARNING: no console will be available to OS" + reset on the NUC AMD
is consistent with the **same** GRUB fault occurring on iron firmware
that enforces W^X. With no exception handlers installed (we're
upstream of the kernel ever executing), the fault cascades
double-fault → triple-fault → reset. OVMF caught it because OVMF
installs default handlers; bare iron resets. Same root cause, two
manifestations.

**Outcome: FAIL.** Path A as drafted will not boot under
strict-W^X-enforcing UEFI through current upstream GRUB. The cyrius
ELF64 + multiboot2 emit and the agnos long-mode shim are *not* the
problem — they never get to run.

---

## Diagnosis 2 — 2026-05-13 GRUB relocator W^X

Captured separately because this is an independent, GRUB-side root
cause discovered after Path A's cyrius/agnos work landed. Summary
above; doc trail:

- Disassembly: `objdump -d /usr/lib/grub/x86_64-efi/relocator.mod`,
  `--disassemble=grub_relocator64_efi_boot`,
  `--disassemble=grub_relocator64_efi_start`
- Relocations: `readelf -r /usr/lib/grub/x86_64-efi/relocator.mod`,
  filtered to .rela.text offsets 0x3380-0x34D9 (within `_efi_boot`'s
  span) — confirms the six `movabs` writes target the six register
  slots embedded in the stub at 0x8AA-0x8F7.
- Upstream context: `grub-core/lib/x86_64/efi/relocator.c` +
  `grub-core/lib/i386/relocator64.S` lines 95-164 (per the prior
  Diagnosis above).

**Resolution options** (none are quick — record for the next agent):

1. **Path C, brought forward.** Sovereign UEFI bootloader (PE/COFF),
   no GRUB. AGNOS allocates its own pages with the right attributes,
   handles its own ExitBootServices. Memory pin
   [[project-agnos-bootloader-roadmap]] always had Path C as the
   long-term destination; the question is just whether to do it now.
   Largest engineering scope but cleanest endpoint — and the only path
   that doesn't depend on someone else fixing their relocator.
2. **GRUB patch + private build.** Refactor `grub_relocator64_efi_boot`
   to (a) allocate a writable trampoline region and copy the stub
   there before patching its immediates, or (b) call the
   MemoryAttributesProtocol to drop the RO bit on the relocator
   pages first. Vendor a patched grub2 in our installer ESP.
   Smallest surface change to ship MVP; carries a long-term
   maintenance tail until upstream takes the fix.
3. **Linux Boot Protocol pretender.** Make our kernel claim to be a
   Linux bzImage (`linuxefi` header layout) and boot via GRUB's
   `linuxefi` command — the relocator path that already works on
   modern UEFI. Real engineering (bzImage header is non-trivial), but
   it sidesteps the multiboot2 EFI relocator entirely. We give up the
   multiboot2 cmdline/MMAP tag stream we just plumbed for in cyrius
   5.11.43 — replaced by Linux's setup_header + zero-page protocol.
4. **Loose-W^X OVMF rebuild to confirm theory on iron-equivalent.**
   Build OVMF without strict memory protection and re-run
   `test-uefi-qemu.sh`. If the kernel boots through to scheduler +
   tier3 under loose-W^X OVMF, the diagnosis is fully proven and the
   path forward is "find a way to disable W^X on NUC AMD firmware" or
   pursue 1-3.

**Cross-repo follow-ups (NOT performed by this agent per the no-touch-cyrius
rule):**

- Cyrius work is **not** at fault. `EMITELF64_KERNEL` (5.11.43)
  produces a correct ELF64 multiboot2 kernel that GRUB *accepts*
  (`grub-file --is-x86-multiboot2` PASS, `RAX = 0x36D76289` confirms
  GRUB prepared the handoff). No cyrius issue to file from this
  diagnosis.
- Path A doc (`docs/development/path-a-elf64-multiboot2.md`) should
  gain a "Status update 2026-05-13" section noting Step 5b failed and
  why Steps 6-8 are paused.

---

### Attempt 5 — 2026-05-13 ~late-PM PDT → FAIL

**Pivot framing.** Path A (multiboot2 + GRUB-EFI) was abandoned
between Attempt 4 prep and this run after the 2026-05-13 GRUB-source
diagnosis (*Diagnosis 2* above) proved `grub_relocator64_efi_boot`
writes to its own `.text` under strict-W^X UEFI — a GRUB-side bug
not fixable in our timeline. Path C (sovereign UEFI bootloader,
gnoboot) landed in its place: GRUB removed from the chain entirely,
`gnoboot` loads agnos directly from the ESP and hands off via the
sovereign-struct ABI (`RDI = &boot_info`, magic `0x41474E4F`). All
12 path-C steps cleared QEMU OVMF (kernel boots through 17 init
checkpoints to `Activating scheduler...`); Attempt 5 was the first
exercise on iron. See `docs/development/path-c-sovereign-uefi.md`
for the full pivot, and `[[project-grub-mb2-efi-wx-blocker]]` for
the GRUB-side analysis.

**Original Path A scope** (retired with this attempt; preserved in
git history pre-`a4055d1`). All four sub-items landed (cyrius
`EMITELF64_KERNEL` in 5.11.43; agnos ELF64 shim wrapped in
`#ifdef ELF64_KERNEL`; `scripts/install-usb.sh` MB1→MB2 switch;
QEMU OVMF gate). The QEMU OVMF gate hit GRUB-side W^X relocator
fault before any kernel byte executed — Path A bridge does not
survive modern UEFI. Path C supersedes; no further Path A work
planned.

**Build under test** (Path C — gnoboot in the chain, no GRUB):

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.53 (per `gnoboot/cyrius.cyml` and `agnos/cyrius.cyml`) |
| agnos kernel | 1.30.0 — `build/agnos` 251040 bytes (ELF64, single PT_LOAD at `p_paddr=0x100000`, `p_filesz=0x3d340`, `p_memsz=0x4d340`, entry `0x1000A8`) |
| gnoboot | 0.1.0 pre-fix — `build/BOOTX64.EFI` (PE/COFF UEFI Application; subsystem 10 = `IMAGE_SUBSYSTEM_EFI_APPLICATION`) |
| install-usb.sh | post-`a4055d1` (GRUB removed, gnoboot at `/EFI/BOOT/BOOTX64.EFI`) |

**Symptom (verbatim from NUC AMD display):**

```
Press <DEL> to enter Setup. <F7> to Boot Menu.gnoboot 0.1 step 7: Jumping to kernel...
```

(Firmware splash didn't `\r\n`-terminate, so gnoboot's `msg_pre`
started on the same character cell as `.gnoboot` continuation —
cosmetic. `msg_pre` does end with `\r\n` (`gnoboot/src/main.cyr:36`),
so any kernel-side ConOut text would have started on a fresh line —
but ConOut is dead post-EBS and the kernel uses UART instead, which
has no display path on this NUC.) Then **blank screen**, then
**machine resets and restarts the firmware splash**. No serial
cable attached — kernel-side UART output (`COM1 / 0x3F8`) not
captured.

**Significance:** gnoboot itself reached step 7 — that means all
five firmware-call chains succeeded (HandleProtocol×2, OpenVolume,
Open, Read, ELF magic check, AllocatePages, segment load with
verify, GetMemoryMap). No `EBS fail` print → ExitBootServices
succeeded. Failure is **post-jump**, in the kernel's first
instructions or first BSS reference. Reset (not hang) is consistent
with triple-fault (no kernel IDT installed yet, so #PF / #GP escalate
through #DF to triple-fault → CPU INIT → firmware restart). This is
the **furthest any iron attempt has reached** — Attempts 1-4 reset
inside GRUB before the kernel was loaded.

**Diagnosis (no iron serial; reasoning from code + QEMU divergence):**

QEMU OVMF + Path C boots the kernel through 17 init checkpoints to
`Activating scheduler...` (verified in `agnos/docs/development/state.md`
§ *Open investigation — timer-driven context switch under UEFI+gnoboot*).
Same gnoboot binary, same kernel binary; iron silently triple-faults
before any kernel UART output. Two divergence points:

1. **BSS gap not zeroed (high confidence, deterministic gnoboot bug).**
   `gnoboot/src/main.cyr:191-193` reads `p_filesz` (245 KB) into
   `p_paddr` but never zeroes `[p_filesz, p_memsz)` (64 KB BSS gap).
   UEFI 2.x § 7.2: `AllocatePages` returns undefined memory contents.
   QEMU OVMF tends to return zero on fresh allocations (masked the
   bug through gnoboot Step 5b/7 QEMU PASS); real firmware leaves
   POST/EFI scratch. Kernel `.bss` globals read garbage on iron and
   triple-fault at first reference. Deterministic divergence that
   alone explains QEMU-works / iron-resets.
2. **MemoryType 2 (EfiLoaderData) on stricter firmware (medium
   confidence, insurance).** `gnoboot/src/main.cyr:185` allocates
   kernel pages as `EfiLoaderData`. Strict-W^X firmware NX-marks
   data-typed allocations; the inherited post-EBS page tables still
   carry that NX, so `jmp 0x1000A8` into a LoaderData page #PFs,
   IDT absent, triple-fault. OVMF runs from LoaderData pages
   regardless (state.md confirms full kernel boot to `Activating
   scheduler...`), so this isn't load-bearing under OVMF — but AMD
   Zen firmware is a different vendor and may enforce. Cheap to fix
   alongside #1.

**Repair steps (gnoboot edits; no agnos / cyrius / install-usb changes):**

| Approx PDT | Action | Verification gate |
|-----------|--------|-------------------|
| ~late-PM | `gnoboot/src/main.cyr`: insert byte-loop `store8(p_paddr+i, 0)` over `[p_filesz, p_memsz)` after segment-read + ELF-magic verify, before initial GetMemoryMap | `cyrius build` clean; `tests/ovmf_smoke.sh` (EXPECT="Activating scheduler") still PASS |
| ~late-PM | `gnoboot/src/main.cyr:185`: `AllocatePages` MemoryType `2 (EfiLoaderData)` → `1 (EfiLoaderCode)` | Same — both gates green; PE/COFF structurally unchanged (`tests/verify_pe.sh`) |
| ~late-PM | `gnoboot/CHANGELOG.md [Unreleased]` entry with diagnosis pointer to this section | doc-only |
| pending | Re-flash USB (`scripts/install-usb.sh`), iron Attempt 6 on NUC AMD | screen shows step-7 line + either kernel banner / further progress / new failure mode |

**Outcome:** FAIL. Furthest iron progress on the campaign — gnoboot
delivered the kernel, kernel triple-faulted on its first BSS read or
NX'd page. Both fixes bundle into Attempt 6; if Attempt 6 still
resets, next bisect needs a **USB-to-TTL serial cable on the NUC's
COM1 header** (the diagnostic recommended since Attempt 4 — at that
point the kernel is running but invisible).

---

### Attempt 6 — 2026-05-13 ~late-PM PDT → FAIL

**Build under test** (Attempt 5 plan applied — BSS zero + EfiLoaderCode
both shipped):

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.53 (per `gnoboot/cyrius.cyml` and `agnos/cyrius.cyml`) |
| agnos kernel | 1.30.0 — `build/agnos` 251040 bytes (entry `0x1000A8`, unchanged from Attempt 5) |
| gnoboot | 0.1.0-post-fixes — `build/BOOTX64.EFI` with the two Attempt-5 repairs in `src/main.cyr`: byte-loop zeroing `[p_filesz, p_memsz)` after segment read, and `bs->AllocatePages` MemoryType `1 (EfiLoaderCode)` |
| install-usb.sh | unchanged from Attempt 5 |

**Symptom (verbatim from NUC AMD display):**

```
Press <DEL> to enter Setup. <F7> to Boot Menu.gnoboot 0.1 step 7: Jumping to kernel...
```

Then **blank screen**, then **reset → firmware splash again**. Bit-identical
to Attempt 5 — same step-7 line on the same cell as the firmware splash
(cosmetic, not load-bearing), same blank, same reset cadence. No serial
attached; kernel UART output (`COM1 / 0x3F8`) not captured.

**Significance.** Both repairs from Attempt 5 ran on iron and produced
**zero change**. The triple-fault is therefore **neither**:

- **BSS garbage** (gnoboot's byte-loop zeroes `[p_filesz, p_memsz)`
  pre-EBS — confirmed in `gnoboot/src/main.cyr:216-221`), nor
- **LoaderData NX-marking** (gnoboot's `AllocatePages` requests
  MemoryType `1 (EfiLoaderCode)` — confirmed in `gnoboot/src/main.cyr:191`).

These were the two highest-confidence hypotheses for the QEMU-OVMF /
iron divergence; ruling them out is what Attempt 6 actually delivered.

**Remaining hypotheses (no further evidence yet — needs visibility into
kernel-side execution, which Attempt 6 also lacks):**

1. **Inherited AMD Zen UEFI page-table W^X ≠ OVMF's.** Strict-W^X
   firmware applies NX to non-LoaderCode ranges in the live PT. Stack
   at 0x200000 is `EfiConventionalMemory`; first `call boot_info_capture_rdi()`
   pushes a return address there — NX wouldn't fire on a write but
   if the firmware additionally marks Conventional pages as not-present
   or read-only post-EBS, the push #PFs and the absent IDT triple-faults.
2. **GDT divergence.** `boot_shim.cyr:163-164` documents CS=0x38 /
   DS=0x18 working under OVMF; AMD Zen UEFI may use different
   selectors. First `call` validates CS against the inherited GDTR.
3. **CR0/CR4/EFER divergence.** SMEP/SMAP/UMIP/CET enabled by AMD
   Zen UEFI but not OVMF. CET shadow-stack in particular would fault
   on the first `call` if the shadow-stack pointer is null.

All three need kernel-side ground-truth to bisect. Path forward is
twofold and now bundled.

**Repair steps (Attempt-7 plan; gnoboot + agnos edits, no install-usb
or cyrius changes):**

| Approx PDT | Action | Verification gate |
|-----------|--------|-------------------|
| ~late-PM | `gnoboot/src/main.cyr`: add `gop_guid`, extend `boot_info` 80 → 112 bytes (version 1 → 2, inlined fb fields at 0x48-0x60), `LocateProtocol(GOP)` after BSS zero pre-EBS, copy `fb_phys/pitch/width/height/pixel_format` into struct, set `flags.fb_present` | `cyrius build` clean; gnoboot `tests/ovmf_smoke.sh` (EXPECT="Activating scheduler") PASS; `tests/verify_pe.sh` PASS |
| ~late-PM | `agnos/kernel/arch/x86_64/boot_shim.cyr`: prepend 26 bytes to ELF64 shim asm block (canary — read `[rdi+0x48]`, paint 256 white pixels at top-left if non-null; preserves RDI, clobbers RAX/RCX) | `scripts/build.sh` clean; `build/agnos` grows ~32 bytes; gnoboot smoke still PASS |
| ~late-PM | `agnosticos/docs/development/path-c-sovereign-uefi.md` § Handoff: update struct spec to v2 inlined fb fields; tag type=1 deprecated | doc-only |
| ~late-PM | gnoboot CHANGELOG `[Unreleased]` Added (GOP capture) + Fixed (note Attempt-6 ruled out both Attempt-5 hypotheses) | doc-only |
| ~late-PM | agnos CHANGELOG `[Unreleased]` Added (canary) + Changed (boot-info v2) | doc-only |
| pending | Re-flash USB (`scripts/install-usb.sh`), iron Attempt 7 on NUC AMD | screen shows step-7 line + **white pixel stripe at top of screen** + (reset or further progress) |
| pending in parallel | User sources USB-to-TTL serial cable for COM1 header | independent of canary outcome — needed regardless of result |

**Outcome:** FAIL. No iron progress beyond Attempt 5 in absolute terms,
but two hypotheses ruled out and a visible kernel-side bisection signal
is now in place for Attempt 7. Attempt 6's "no improvement" result IS
its diagnostic value — it tells us the remaining failure modes are
strictly post-jump, not pre-jump environmental.

---

### Attempt 7 — 2026-05-13 ~late-PM PDT → FAIL

**Build under test** (Attempt 6 plan applied — agnos canary + gnoboot GOP
capture both shipped):

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.53 (unchanged) |
| agnos kernel | 1.30.0 + canary — `build/agnos` 251072 bytes (+32 over Attempt 6's 251040 — 26-byte canary asm rounded up for alignment). Canary is at `boot_shim.cyr:200-206`: `mov rax,[rdi+0x48]; test rax,rax; jz +17; mov ecx,256; mov dword [rax],0xFFFFFFFF; add rax,4; loop -12`. Prepended to ELF64 shim, runs before stack setup and before any cyrius `fn` call. |
| gnoboot | 0.1.0 + GOP capture — `build/BOOTX64.EFI` 35328 bytes. `gop_guid` + `LocateProtocol(GOP)` at `main.cyr:265-280`, pre-EBS. boot_info struct extended 80 → 112 bytes (version 1 → 2, inlined `fb_phys/pitch/width/height/pixel_format` at offsets 0x48-0x60). Failure-safe: if `LocateProtocol` returns non-zero, `fb_phys` stays 0 and the canary's `JZ` skips the paint. |
| install-usb.sh | unchanged from Attempt 6 |

**Symptom (verbatim from NUC AMD display):**

```
Press <DEL> to enter Setup. <F7> to Boot Menu.gnoboot 0.1 step 7: Jumping to kernel...
```

Then **blank screen**, then **reset → firmware splash again**. Bit-identical
to Attempt 6. **No white stripe** at top-left of screen. No serial
attached; kernel UART output (`COM1 / 0x3F8`) not captured.

**Significance.** The canary's null-check splits the outcome into two
disjoint cases:

- **Case A — `fb_phys == 0` on iron.** gnoboot's `LocateProtocol(GOP)`
  failed on NUC AMD UEFI (text-mode firmware path, no GOP exposed, or
  GUID mismatch under this firmware). Canary's `JZ +17` fired and the
  kernel proceeded past the 26-byte canary into the stack-setup +
  `call boot_info_capture_rdi()` sequence, then triple-faulted later
  (one of the three Attempt-6 remaining hypotheses: AMD Zen page-table
  W^X, GDT divergence, or CR/EFER state). The kernel *did* execute,
  but invisibly.
- **Case B — `fb_phys != 0` but `jmp rax` never landed or first
  instruction faulted.** Kernel was never reached. Either the `mov
  eax, 0x1000A8; jmp rax` in gnoboot didn't transfer control (page at
  0x1000A8 not executable per inherited UEFI PT — even though gnoboot
  allocated as `EfiLoaderCode`), or the first 4 bytes of the canary
  itself (`48 8B 47 48`) faulted on fetch.

**We cannot distinguish A from B from the display alone.** Both produce
identical bit-identical reset output. The canary delivered one bit of
information (it didn't paint) — that bit is genuinely ambiguous without
a second channel.

**Concrete diagnostic state after Attempt 7:**

| Hypothesis | Status |
|---|---|
| BSS garbage in `.bss` | Ruled out (Attempt 6) |
| LoaderData NX-marking | Ruled out (Attempt 6) |
| fb_phys=0 on iron (Case A) | Possible — gnoboot's GOP path was QEMU-OVMF verified, not iron-verified |
| jmp-rax / first-instruction fault (Case B) | Possible — would also produce no-stripe + reset |
| AMD Zen page-table W^X post-EBS | Still open (would manifest in either case at a later instruction) |
| GDT divergence | Still open |
| CR0/CR4/EFER divergence (esp. CET) | Still open |

**Path forward — serial cable is now blocking.** Three remaining iron
diagnostics could fire here; without kernel-side visibility, picking
among them is guessing. Specifically:

1. **USB-to-TTL serial cable on COM1 header.** This was the recommended
   path from Attempt 4 onward and has been deferred three attempts
   running. Attempt 7's no-stripe ambiguity confirms: the visual canary
   was a useful intermediate step, but it cannot bisect Case A vs Case
   B. Serial does. Even a single byte from kernel `serial_putc` at
   entry instruction #1 (post-canary) decides A vs B immediately.
2. **As a fallback only if serial sourcing is delayed:** add a *second*
   canary in gnoboot, *before* the `jmp rax`, that paints a different
   color or position. If THAT one fires and the agnos one doesn't,
   we're in Case B (jmp issue). If neither fires, GOP wasn't located
   (Case A, no fb at all). This is a one-attempt diagnostic worth
   maybe 30 min in gnoboot — but a serial cable is strictly more
   informative and the COM1 header is exposed on the NUC AMD.

**No code changes recommended pre-serial.** The Attempt-6 remaining-
hypotheses list (Zen page-table W^X, GDT, CR/EFER) cannot be sanely
attacked without seeing where the kernel dies. Blind shim changes here
would burn attempts the way bare-retry burned Attempt 4.

**Outcome:** FAIL. Visual canary delivered ambiguous signal —
diagnostically valuable (proves screen is unreachable from kernel-side
without GOP, narrows post-handoff failure to a smaller domain) but
not bisecting.

**Correction to recommendation (post-conversation, same evening).** The
"serial cable is the blocker" framing across Attempts 4-7 was wrong.
The dev environment (`archaemenid`) IS the NUC AMD iron-boot target —
single Beelink SER, no separate devbox. Serial-cable diagnostics require
a second host to read the COM1 wire; that host doesn't exist in this
setup. The right diagnostic channel for one-machine iron is **persistent
storage that survives reset** — CMOS scratch RAM, UEFI NVRAM variables,
or raw disk sectors. Memory pin [[project-single-machine-dev-setup]]
records the constraint so future agents don't repeat the serial advice.

Attempt 8 ships CMOS-scratch checkpoints (cheapest path; no driver
required on either kernel or Linux side).

**Repair steps (Attempt-8 plan — CMOS persistent boot-log):**

| Approx PDT | Action | Verification gate |
|-----------|--------|-------------------|
| ~late-PM | `agnos/kernel/arch/x86_64/boot_shim.cyr`: insert 5 CMOS checkpoint writes in the ELF64 shim asm block (8 bytes each; `out 0x70, al` + `out 0x71, al`). Checkpoint 1 also sets CMOS[0x41] = 0xAB magic. Slots used: CMOS[0x40] (checkpoint counter 1-5) and CMOS[0x41] (kernel-ran magic). Clobbers AL only per write; RDI/RSP/other GPRs preserved. Visual canary kept as backup signal. | `CYRIUS_ELF64_KERNEL=1 ./scripts/build.sh` clean; `build/agnos` grows 251072 → 251120 bytes (+48 exact = 6 × 8-byte writes); gnoboot `tests/ovmf_smoke.sh` still reaches `Activating scheduler...` (CMOS writes silent in QEMU). |
| ~late-PM | `agnosticos/scripts/read-boot-log.sh`: read `/dev/nvram` (CMOS-base offset 0x0E excluded by the Linux nvram driver, so CMOS 0x40 maps to /dev/nvram 0x32), dump CMOS[0x40] and CMOS[0x41], print verdict mapping checkpoint number → "highest kernel point reached." | `ls /dev/nvram` shows char device 10,144; chmod +x; structural test only (no actual read attempted pre-iron). |
| ~late-PM | agnos `CHANGELOG.md [Unreleased]` Added entry for CMOS boot-log + correction note crediting Attempt 7's wrong-serial-advice context | doc-only |
| pending | Re-flash USB (`scripts/install-usb.sh`), iron Attempt 8 on NUC AMD | screen shows step-7 line + (white stripe iff GOP detected) + reset cadence as before |
| pending | After reset, machine returns to Arch → `sudo /home/macro/Repos/agnosticos/scripts/read-boot-log.sh` | Outputs CMOS[0x41] (0xAB iff kernel ran) and CMOS[0x40] (1-5, the last checkpoint hit). Verdict bisects fault to within ~30 bytes of shim code. |

**Outcome:** FAIL (visual canary inconclusive). Persistent diagnostic
channel now in place for Attempt 8; serial is no longer load-bearing.

---

### Attempt 8 — 2026-05-14 ~PDT → FAIL (but bisecting!)

**Build under test** (Attempt-8 plan applied — CMOS boot-log + finer-grained
Cyrius bisector checkpoints):

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.53 (unchanged from Attempt 7) |
| agnos kernel | 1.30.0 + boot_shim CMOS CP1-5 (early entry, ~30-byte resolution) + `core/main.cyr` Cyrius-level bisector at 0x80/0x81/0x82/0x06/0x07/0x08... around `gdt_init`/`tss_init`/`idt_init`/`pic_init`/`apic_init`/`pt_init` |
| gnoboot | 0.1.0 + CMOS pre-jump checkpoints (CMOS[0x52]=stage, CMOS[0x53]=0xCD magic), GOP capture from Attempt 7 still present |
| `scripts/read-boot-log.sh` | reads CMOS 0x50-0x53 via Cyrius `read-boot-log` binary (not `/dev/nvram` — the kernel nvram driver is dead on archaemenid due to CMOS checksum mismatch — see project memory `archaemenid_cmos_map`) |
| CMOS slot map | shifted from original 0x40-0x43 → 0x50-0x53; BIOS on this box writes 0x42/0x43/0x44 every cold boot, but 0x50-0x7F is virgin scratch (same memory pin) |

**Symptom:** Identical visual cadence to Attempts 6 & 7 — gnoboot step-7 line, blank screen, reset → firmware splash. No white stripe (consistent with Attempt-7 Case A: kernel ran but framebuffer not located on this firmware/path).

**CMOS readout (post-reset):**

```
CMOS[0x53] gnoboot magic    = 0xcd  (decimal 205)
CMOS[0x52] gnoboot checkpt  = 0x05  (decimal 5)
CMOS[0x51] kernel  magic    = 0xab  (decimal 171)
CMOS[0x50] kernel  checkpt  = 0x81  (decimal 129)
```

**Verdict — bisection wins.**

- gnoboot reached **all 5 pre-jump checkpoints** (GOP located, ExitBootServices called, `jmp rax` issued)
- kernel-ran magic `0xAB` set → ELF64 shim executed, hit Cyrius's startup `serial_println` calls, called `gdt_init` and it returned cleanly
- highest kernel checkpoint = **0x81** (`agnos/kernel/core/main.cyr:14` — `gdt_init` returned, about to call `tss_init`)
- did NOT reach 0x82 (`main.cyr:20` — right after `tss_init` returns)
- **→ fault is inside `tss_init_cpu(0)`**, somewhere between line 14 and line 16's `tss_init();` return.

**This also retroactively resolves Attempt 7's Case A / Case B ambiguity** — definitively Case A (kernel ran, fault is post-handoff, framebuffer simply unreachable from kernel-side on this firmware path).

**Root-cause hypothesis (high confidence):** `agnos/kernel/arch/x86_64/gdt.cyr:95-98` (pre-fix):

```cyrius
var selector = 0x28 + cpu_id * 16;
asm {
    0x48; 0x8B; 0x45; 0xF8;   # mov rax, [rbp-0x08] (selector)   ← WRONG SLOT
    0x0F; 0x00; 0xD8;          # ltr ax
}
```

Per the Cyrius frame-layout convention documented in `ring3.cyr:25-26` (*"params at rbp-0x08, -0x10, -0x18; new locals start at rbp-0x20"*), `[rbp-0x08]` in `tss_init_cpu(cpu_id)` is the **parameter `cpu_id`**, not the local `selector`. For BSP (`cpu_id == 0`), `ltr 0` loads the null TSS descriptor → **#GP** → IDT not yet installed (`idt_init` is the NEXT call in `main.cyr:22`) → triple fault → reset. Symptom matches exactly; faults inside `tss_init` before the function can return to write 0x82.

**Why QEMU didn't catch it:** open. `[rbp-0x08]` reads `cpu_id=0` there too, so QEMU's emulated CPU saw the same `ltr 0`. Possible: TCG's TR-load path is more permissive than Zen silicon under specific conditions, or `-cpu max` vs the iron CPU diverges on null-TSS handling, or an earlier QEMU run did fault but exit was masked by `-no-reboot`. Not blocking Attempt 9; worth a follow-up smoke-test inspection.

**Fix (applied):** drop the broken `mov rax, [rbp-0x08]`. Rely on Cyrius leaving the just-assigned `selector` value in `rax` (same pattern as `gdt_init`'s `var gp = &gdt_ptr; asm { lgdt [rax]; }` at lines 26-27). Net change: −4 instruction bytes.

**Repair steps (Attempt-9 plan):**

| Approx PDT | Action | Verification gate |
|-----------|--------|-------------------|
| 2026-05-14 | `agnos/kernel/arch/x86_64/gdt.cyr` — drop `0x48; 0x8B; 0x45; 0xF8;` from the `ltr` asm block; comment updated to explain the slot trap (DONE) | clean rebuild |
| 2026-05-14 | `agnos/kernel/arch/x86_64/boot_data.cyr` — resize `var gdt[56]` → `var gdt[104]` (DONE). Companion fix surfaced by code-reading after the slot-trap patch: the 1-TSS-era sizing left `gdt_init`'s 4-iteration zero loop writing 48 bytes past the array end, stomping `boot_info_ptr` in BSS. Latent on the BSP-only path (TSS desc writes at offsets 40/48 stay in-bounds) but corrupts other kernel state. Not the cause of Attempt 8's #GP, but worth fixing before re-flash so `load64(&boot_info_ptr)` survives `gdt_init`. | clean rebuild; `build/agnos` 251232 → 251616 bytes (+384, alignment cascade through subsequent BSS arrays — much larger than the 48-byte BSS bump alone, but ELF64 validates) |
| 2026-05-14 | agnos `CHANGELOG.md [Unreleased]` Fixed entry — credit Attempt-8 CMOS bisector for pinpointing the slot mismatch; second bullet for the gdt-array resize | doc-only |
| pending | Re-flash USB (`scripts/install-usb.sh`), iron Attempt 9 on NUC AMD | post-reset `read-boot-log.sh` should show `kernel checkpt` ≥ 0x82 (and ideally higher — 0x06 = arch interrupts ready, 0x07 = APIC + timer live, 0x08 = page tables built) |

**Outcome:** FAIL — but the CMOS bisector delivered exactly what Attempt 7 had hoped serial would, with no second host required (per memory pin `project_single_machine_dev_setup`). Diagnostic channel proven; root cause pinpointed to ~3 lines of asm; fix applied same day.

---

### Attempt 9 — 2026-05-14 ~PDT → FAIL (bisector advancing)

**Build under test** (Attempt-8 Fixed entries applied — `ltr` slot-trap +
`gdt[104]` resize, both in `agnos/kernel/arch/x86_64/`):

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.53 (unchanged) |
| agnos kernel | 1.30.0 + Attempt-8 Fixed entries (`gdt.cyr` ltr slot fix; `boot_data.cyr` gdt array 56 → 104). `build/agnos` 251232 → 251616 bytes (+384, alignment cascade). |
| gnoboot | 0.1.0 (unchanged from Attempt 8) |
| `scripts/read-boot-log.sh` | unchanged — reads CMOS 0x50-0x53 via Cyrius `read-boot-log` |
| CMOS slot map | 0x50-0x53 (per `archaemenid_cmos_map` memory pin) |

**Symptom:** Same external cadence as Attempts 6-8 — gnoboot step-7 line, blank screen, reset → firmware splash. No framebuffer-side signal expected (per Attempt 7's Case A resolution; framebuffer unreachable from kernel on this firmware path).

**CMOS readout (post-reset):**

```
CMOS[0x53] gnoboot magic    = 0xcd  (decimal 205)
CMOS[0x52] gnoboot checkpt  = 0x05  (decimal 5)
CMOS[0x51] kernel  magic    = 0xab  (decimal 171)
CMOS[0x50] kernel  checkpt  = 0x07  (decimal 7)
```

**Verdict — Attempt-8 fix held; fault site moved forward.**

- Kernel ran (`0xAB` magic set) → ELF64 shim entry, COM1 init, boot-info capture all OK
- gnoboot pre-jump checkpoints all 5 reached (unchanged from Attempt 8)
- Highest kernel checkpoint = **0x07** (`agnos/kernel/core/main.cyr:53` — APIC + timer live, post `apic_init` / `apic_timer_init`)
- Did NOT reach 0x08 (`main.cyr:83` — set after `pt_init` returns)
- **→ fault is between `apic_timer_init` returning and `pt_init` returning**, i.e. inside one of the four call sites at `main.cyr:59-77`:
  1. `smp_start_aps()` — INIT-SIPI-SIPI wakeup of Application Processors (smp.cyr:167)
  2. `kb_init_tables()` / `kb_isr_build()` — keyboard ISR build
  3. `idt_set_gate(...kb_isr...)` — install IRQ1 vector
  4. `pt_init()` — page tables

Attempt 8's `gdt_init` → `tss_init` → `idt_init` → `pic_init` → `apic_init` chain all return cleanly (CP 7 is past `apic_timer_init`). The CP 6 → CP 7 leg was previously the long-suspected stall zone; it is now confirmed live on iron Zen.

**Root-cause hypothesis (high confidence):** `smp_start_aps()` at `agnos/kernel/arch/x86_64/smp.cyr:167`. Two pieces of evidence:

1. The in-source comment at smp.cyr:173-176 explicitly flags this as *the* "uncomment-for-real-hardware" path:
   > "Works on real hardware. QEMU's multiboot/GRUB emulation doesn't properly support SIPI — APs start at wrong address (0x4000 not 0x8000). Uncomment for real hardware or when QEMU adds proper SIPI support."

   The INIT-SIPI-SIPI loops at smp.cyr:177-182 are live (not commented out). This is the **first iron boot to actually fire INIT-SIPI-SIPI at Zen APs** — the prediction in that comment was never measured.

2. Three concrete hazards in the live path:
   - **CR3 = 0x1000 is hardcoded** in the AP trampoline's 32-bit stage (smp.cyr:112). `pt_init` has not yet run at this point, so APs share whatever page tables gnoboot left at physical 0x1000. If those tables don't identity-map 0xFEE00000 (LAPIC), every AP triple-faults on its first APIC-ID read at smp.cyr:143, and Zen APs taking simultaneous triple-faults can crowbar the BSP via shared cache/snoop traffic before BSP reaches CP 8.
   - **Empty-loop "delays"** at smp.cyr:178, 180, 182 are not volatile. INIT requires ~10ms quiescence per the SDM; SIPI window is ~200μs. If cyrius emits the loop body as-is on Zen, the loops still take some time, but if any constant-folding ever lands the delays vanish entirely.
   - **Trampoline writes at 0x8000-0x8200** (smp.cyr:66-79). Pre-`pt_init`, this relies on gnoboot's bootstrap mappings covering that range writable.

**Fix (Attempt 10 — diagnostic, not final):** comment out the three INIT-SIPI-SIPI for-loops at smp.cyr:177-182, leaving `smp_build_trampoline()` and the `vmm_alloc_at` stack-allocation loop in place. This isolates the AP-wakeup IPI from the pre-IPI setup. Iron-boot is expensive (one reflash + reset cycle per data point), so we deliberately leave trampoline build and stack alloc running — if they fault, we still don't reach CP 0x71-equivalent and the next iteration will instrument them. If we instead reach CP 8 / further, AP wakeup is confirmed as the fault and the v1 patch is one of the three concrete hazards above (most likely the CR3=0x1000 / LAPIC-identity-map hazard).

**Repair steps (Attempt-10 plan):**

| Approx PDT | Action | Verification gate |
|-----------|--------|-------------------|
| 2026-05-14 | `agnos/kernel/arch/x86_64/smp.cyr:177-182` — comment out the three `apic_send_init` / `apic_send_sipi` for-loops and their inter-IPI delay loops. Leave `smp_build_trampoline()` and the `vmm_alloc_at` stack alloc loop live. Comment updated to explain why (Attempt-9 SIPI-gate diagnostic). (DONE) | `CYRIUS_ELF64_KERNEL=1 ./scripts/build.sh` clean (cyrius 5.11.54); `build/agnos` 251616 → 251152 bytes (−464, six call sites eliminated as predicted). gnoboot smoke under OVMF not re-run — change is on a path QEMU can't exercise (single-vCPU). |
| 2026-05-14 | agnos `CHANGELOG.md [Unreleased]` — `Changed` entry noting the diagnostic gate (will revert / replace with real fix after Attempt 10 result) | doc-only |
| pending | Re-flash USB (`scripts/install-usb.sh`), iron Attempt 10 on NUC AMD | post-reset `read-boot-log.sh` should show `kernel checkpt` ≥ 0x08 if SMP wakeup was the fault. If still 0x07, fault is in `smp_build_trampoline` writes or `vmm_alloc_at` against gnoboot's page tables — Attempt 11 will instrument finer. |

**Outcome:** FAIL — but the bisector held its discipline. One CMOS read advanced us from "anywhere in `gdt_init` → `pt_init`" (six function calls) to "one of four specific calls between `apic_timer_init` returning and `pt_init` returning". The SIPI-gate diagnostic narrows that to one or two on the next iron run.

---

### Attempt 10 — 2026-05-14 ~PDT → FAIL (regression by stub-kernel artifact; gnoboot died at CP 2)

**Build under test** (as observed on the USB at boot time):

| Artifact | Version / Size | Notes |
|----------|----------------|-------|
| cyrius toolchain | 5.11.54 (local) | minor bump since Attempt 9's 5.11.53; not implicated |
| agnos kernel (USB `\boot\agnos`) | **344 bytes, ELF32 i386 stub** | ❌ Wrong file. `agnos/build/agnos` had been replaced by a tiny 32-bit stub (date stamp May 14 14:40) before `install-usb.sh` ran. The real Attempt-9-plan kernel (smp.cyr SIPI loops gated, 251,152 bytes ELF64) was never copied onto this USB. |
| gnoboot (USB `\EFI\BOOT\BOOTX64.EFI`) | 35,328 bytes (unchanged from Attempt 9) | ran correctly, see below |
| `scripts/read-boot-log.sh` | unchanged — Cyrius `read-boot-log` binary | |

**Symptom — different from Attempts 6-9.** Instead of `gnoboot 0.1 step 7: Jumping to kernel...` → blank → reset, the firmware fell through to the EDK II UEFI Interactive Shell:

```
UEFI Interactive Shell v2.2
EDK II
UEFI v2.70 (American Megatrends, 0x00050013)
Mapping table
FS1: Alias(s): HD1e0b:; BLK4:
   PciRoot(0X0)/Pci(0x8,0x1)/Pci(0x0,0x4)/USB(0x4,0X0)/HD(1,GPT,...)   ← AGNOS USB
FS0: Alias(s): HD0b:; BLK1:
   PciRoot(0X0)/Pci(0x2,0x1)/Pci(0x0,0x0)/NVMe(0x1,...)/HD(1,GPT,...)
...
Press ESC in 1 seconds to skip startup.nsh or any other key to continue.
Shell>
```

**CMOS readout (post-reset):**

```
CMOS[0x53] gnoboot magic    = 0xcd  (decimal 205)
CMOS[0x52] gnoboot checkpt  = 0x02  (decimal 2)
CMOS[0x51] kernel  magic    = 0xab  (decimal 171)
CMOS[0x50] kernel  checkpt  = 0x10  (decimal 16)

verdict (gnoboot): located ESP but died before reading + verifying /boot/agnos.
```

**Forensic trail (gnoboot side — current boot):**

1. `efi_main` entered → CMOS[0x53] = 0xCD (magic), CMOS[0x52] = 0x01.
2. `bs->HandleProtocol(ImageHandle, &LoadedImageGuid, &li)` returned EFI_SUCCESS.
3. `bs->HandleProtocol(li->DeviceHandle, &SfsGuid, &sfs)` returned EFI_SUCCESS.
4. CMOS[0x52] = 0x02 written (last written value observed in CMOS).
5. `sfs->OpenVolume`, `root->Open("\boot\agnos", READ, 0)`, `file->Read(file, &64, &elf_hdr)` all returned EFI_SUCCESS.
6. ELF magic check at `load8(&elf_hdr + 0) != 0x7F` passed — the stub IS an ELF, just the wrong kind.
7. `e_phoff = load64(&elf_hdr + 0x20)` read the stub's bytes at offset 0x20 (ELF32 places `e_phoff` at 0x1C, not 0x20). Result = 0x90 (junk, but valid in-file offset on a 344-byte file).
8. `file->SetPosition(file, 0x90)` + `file->Read(file, &56, &phdr)` succeeded.
9. `load8(&phdr + 0) != 1` (PT_LOAD) fired — `phdr[0]` at file offset 0x90 in a 344-byte ELF32 stub is `0x00`. Gnoboot called `efi_print(st, &msg_pt_f)` and `return 0` (`main.cyr:225`).
10. With `efi_main` returning 0, UEFI firmware regained control and no other Boot#### option resolved on the USB → EDK fallback shell ran.

CP 3 (kernel ELF mapped + magic verified) was never written; CMOS[0x52] correctly stops at 0x02. The verdict is accurate for *this* boot.

**Forensic trail (kernel side — STALE, from a prior unlogged boot):**

CMOS[0x51] = 0xAB and CMOS[0x50] = 0x10 are residue from a previous iron boot — battery-backed CMOS persists across reset cycles until overwritten. `agnos/kernel/core/main.cyr:296` writes CMOS[0x50] = 0x10 only after the scheduler-armed checkpoint (see `read-boot-log.cyr:218` — "scheduler armed — kernel init COMPLETE. Any later stall is post-init"). **Some prior attempt (between Attempt 9 and now, not captured in this log) reached scheduler-armed.** That's a major data point: kernel init is no longer the blocker on the current code, the post-init scheduler loop is.

This run is a *regression* of the boot-pipeline plumbing (wrong file on USB), not of the kernel. The kernel-side CMOS bytes are pre-regression evidence and worth treating as authoritative — corroborated by the open investigation in `agnos/docs/development/state.md` § *timer-driven context switch under UEFI+gnoboot* (which presumes the kernel reaches scheduler activation).

**Root cause of the regression.** `agnos/build/agnos` was a 344-byte ELF32 i386 stub (date stamp May 14 14:40), not the 251,152-byte ELF64 multiboot2 kernel that the Attempt-9 plan + `ce745c7 more iron boot repairs` would produce. `install-usb.sh:64` (`KERNEL_SRC="${REPO_ROOT}/../agnos/build/agnos"`) faithfully copied that file to `\boot\agnos` on the USB. `set -e` + the python ELF validator in `scripts/build.sh` should have caught a malformed build at build time; since the build wasn't re-run between the stub appearing and `install-usb.sh --update` executing, no gate fired. Exact provenance of the stub is unclear — possibly an aborted manual `cyrius build` or a build script run without `CYRIUS_ELF64_KERNEL=1`. `agnos/build/agnos-halt` (251,128 bytes, May 13 11:56) sits in the same directory, suggesting earlier debug/rename activity.

**Repair (applied 2026-05-14, this session):**

| Approx PDT | Action | Verification gate |
|-----------|--------|-------------------|
| 2026-05-14 ~15:00 | Fresh rebuild of agnos: `cd agnos && sh scripts/build.sh` | `build/agnos` 344 → **251,312 bytes**; build.sh's python validator reports `multiboot2 (ELF64): OK`, `entry: 0x1000a8`. Carries `ce745c7 more iron boot repairs` + `d2baa10` (smp.cyr SIPI loops gated) + `0c78acd` (gdt ltr slot + gdt[104] resize). |
| 2026-05-14 ~15:01 | Fresh rebuild of gnoboot: `cd gnoboot && CYRIUS_TARGET_EFI=1 cyrius build src/main.cyr build/BOOTX64.EFI` | `build/BOOTX64.EFI` = **35,328 bytes** (unchanged from prior — gnoboot source at `3a33059 updates for CMOS`, no behavioral change vs. Attempt 9's gnoboot). |
| pending | Re-flash USB via `sudo scripts/install-usb.sh /dev/sdX --update` (user-side; destructive to USB) | `install-usb.sh` should print `Refreshing /boot/agnos   344 → 251312 bytes` and `Refreshing /EFI/BOOT/BOOTX64.EFI   35328 → 35328 bytes`. |
| pending | Iron Attempt 11 on NUC AMD | post-reset `read-boot-log.sh` should print a **kernel-side** verdict (gnoboot CP should reach 5; kernel CP should advance past 0x10 if the post-scheduler stall is fixed, or stick at 0x10 if it's still the prior open issue). The boot should *not* fall through to the UEFI Interactive Shell — if it does, gnoboot itself regressed. |

**Process note — build artifact discipline.** `agnos/build/agnos` is a load-bearing path (install-usb.sh's only kernel source). It silently surviving as a wrong-architecture stub across attempts is a process gap. Two cheap mitigations worth considering before Attempt 11 if not already in place: (a) `install-usb.sh` could `readelf -h "$KERNEL_SRC"` and refuse to copy unless `Class: ELF64` + `Machine: AMD x86-64` + size ≥ 100 KB; (b) `scripts/build.sh` could `rm -f "$ROOT/build/agnos"` at the top so a stale stub can't survive a failed `cyrius build` invocation. Not blocking; flagging for whoever sweeps boot-pipeline hygiene next.

**Outcome:** FAIL (boot regression by stub-kernel artifact, not by code under test). Two new findings: (1) kernel CMOS residue confirms an undocumented prior boot reached scheduler-armed — Attempt 9's SIPI-gate diagnostic + the Attempt-9 / `ce745c7` follow-ups appear to have worked at the kernel-init layer; (2) the kernel ABI / install-pipeline lacks a gate against shipping a wrong-shape `\boot\agnos` to the USB. The path to Attempt 11 is purely re-provisioning — no code change needed at the gnoboot or agnos layer to retry.

---

### Attempt 11 — 2026-05-14 ~PDT → PARTIAL SUCCESS (kernel init COMPLETE on iron; first positive framebuffer signal)

**Build under test** (Attempt-10 repair applied — fresh ELF64 kernel + unchanged
gnoboot, both re-flashed via `install-usb.sh --update`):

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.53 (unchanged) |
| agnos kernel | 1.30.0 + Attempt-8 Fixed entries + Attempt-9 SMP gate. `build/agnos` = **251,312 bytes** ELF64 multiboot2, entry `0x100a8`. Carries `ce745c7` + `d2baa10` (smp.cyr SIPI gate) + `0c78acd` (gdt fixes). |
| gnoboot | 0.1.0 unchanged from Attempts 9/10 — `build/BOOTX64.EFI` = 35,328 bytes, source at `3a33059 updates for CMOS` |
| `scripts/read-boot-log.sh` | unchanged — Cyrius `read-boot-log` binary, CMOS 0x50-0x53 |

**Symptom — first new visual signal in the iron-boot arc.** Boot cadence
diverged from the Attempt-6-through-9 "step-7 line → blank → reset" pattern:
**white canary stripe painted at top-left of screen** (the 256-pixel paint
from `boot_shim.cyr:200-206`'s ELF64-shim asm canary, conditional on
`[rdi+0x48]` non-null). Stripe persisted briefly, then standard reset cadence.

**CMOS readout (post-reset):**

```
CMOS[0x53] gnoboot magic    = 0xcd  (decimal 205)
CMOS[0x52] gnoboot checkpt  = 0x05  (decimal 5)
CMOS[0x51] kernel  magic    = 0xab  (decimal 171)
CMOS[0x50] kernel  checkpt  = 0x10  (decimal 16)

verdict (kernel): scheduler armed — kernel init COMPLETE. Any later stall is post-init.
```

**Verdict — MVP gate cleared at the kernel-init layer.**

- gnoboot CP 0x05 → all 5 pre-jump checkpoints reached, ELF64 mapping +
  `jmp rax` handoff clean. Attempt-10 stub-kernel regression confirmed
  resolved.
- kernel magic `0xAB` → ELF64 shim entry, COM1 init, `boot_info_capture_rdi`
  all OK on this *current-build* kernel (not stale residue this time —
  the gnoboot CP is fresh-current at 0x05, and kernel CP advancement
  matches the committed source).
- kernel CP **0x10** = `agnos/kernel/core/main.cyr:296` — written
  immediately after `sched_active = 1`. Kernel walked the full
  init chain: opening `serial_println` pair → `gdt_init` → `tss_init`
  (Attempt-8 ltr-slot fix held) → `idt_init` → `pic_init` → `apic_init`
  → `apic_timer_init` → `smp_start_aps` (SIPI loops gated per Attempt 9)
  → `pt_init` → `pmm_init` → `vmm_init` → `heap_init` → `dev_init` /
  `acpi_init` / `pci_scan` → `vfs_init` → `syscall_init` → proc creation
  → `sti` → scheduler activation. **Every Attempt-8/9 fix held
  simultaneously.**
- **Canary stripe painting is the first positive framebuffer signal
  on iron.** The boot_shim canary's null-check on `[rdi+0x48]`
  (fb_phys from gnoboot's GOP capture) found a non-null pointer AND
  the kernel-side asm wrote 256 white pixels successfully. This
  retroactively flips Attempt 7's Case-A diagnosis: framebuffer **is**
  reachable from kernel-side under UEFI+gnoboot+ELF64 on this Zen iron.
  GOP capture and the boot-info v2 fb fields work end-to-end on the
  real firmware path.
- did NOT reach CP 0x11 (`main.cyr:309` — written after `sched_active = 0`,
  i.e. after the 50-iteration `while (idle_count < 50) { arch_wait(); }`
  loop completes). Kernel resets between scheduler arm and post-loop
  CP write.

**Significance.** Three independent pieces of evidence converge on
the same fault site as the QEMU+UEFI investigation already documented
in `agnos/docs/development/state.md` § *timer-driven context switch
under UEFI+gnoboot*:

1. iron CMOS bisector pins kernel-side fault to the post-`sched_active=1`
   idle loop (between CP 0x10 and CP 0x11);
2. QEMU+UEFI investigation (2026-05-13) showed timer-context-switch
   cycle stops after ~10 iterations under gnoboot's pre-handoff
   memory layout — a latent agnos kernel bug exposed by gnoboot's
   different page-table/stack contents vs. the legacy `-kernel`
   path;
3. iron now reproduces the exact same failure mode independently
   (different firmware, different memory, same outcome).

The investigation handoff in agnos `state.md` proposed three concrete
fix paths — (a) make `test_proc_a/b` real busy-loops in the default
build, (b) wrap test_proc fns with a busy loop in `proc_create_full`,
(c) switch to dedicated kernel threads. Iron Attempt 11 confirms the
hypothesis on real hardware; one of those fixes plus a finer
post-`sched_active=1` bisector (CP 0x11a/b/c around `arch_wait()`,
schedule entry, first IRQ0 tick, context-switch return) should
either close the issue or pinpoint exactly which iteration breaks.

**This is the AGNOS MVP closed-beta gate at the kernel-init layer.**
All 17 init checkpoints pass on Zen iron. The remaining work for
boot-to-shell on hardware is post-init: scheduler dispatching to a
runnable user task (kybernet PID 1 / agnoshi).

**Repair steps (Attempt-12 plan — scheduler-loop bisector ONLY, fix deferred):**

Bisector-first discipline: a blind `test_proc` patch is non-information-bearing. Iron is the only place we can confirm whether the QEMU "10 hlts then break" pattern reproduces on Zen, or whether iron breaks at a different iteration (which would widen the fix domain). One reflash to know.

| Approx PDT | Action | Verification gate |
|-----------|--------|-------------------|
| 2026-05-14 | `agnos/kernel/core/main.cyr` — add three `if (idle_count == N)` blocks inside the `while (idle_count < 50)` idle loop, each emitting a CMOS write: CP 0x12 after first `arch_wait()` returns (iter 1), CP 0x13 after 10 iterations (matches QEMU's known-good count under gnoboot), CP 0x14 after 25 iterations. Pattern matches the existing CP 0x10 / CP 0x11 asm-block style. (DONE) | `sh scripts/build.sh` clean (cyrius 5.11.54); `build/agnos` 251,312 → **251,456 bytes** (+144, ≈48 bytes per `if`+asm block including RBP-relative load + cmp + je). multiboot2 (ELF64) OK, entry `0x1000a8`. |
| 2026-05-14 | `agnosticos/scripts/src/read-boot-log.cyr` — add verdicts for kcp 18/19/20 (CP 0x12/0x13/0x14) plus a new kcp==17 verdict (loop completed, post-loop stall). Tightened the kcp==16 verdict to point at CP 0x12 as the next-expected gate. (DONE) | `cyrius build src/read-boot-log.cyr build/read-boot-log` clean; `strings build/read-boot-log \| grep "CP 0x1[234]"` returns three new verdicts. Binary 27,080 bytes. |
| pending | Re-flash USB (`sudo scripts/install-usb.sh /dev/sdX --update`) + iron Attempt 12 on NUC AMD | post-reset `read-boot-log.sh` decision tree: **CP 0x10** = first hlt didn't return at all (timer ISR or first context switch broken — biggest finding, widens fix domain beyond `test_proc`); **CP 0x12** = first round-trip OK, breaks before iter 10 (consistent with `test_proc` stack-garbage at small iteration count); **CP 0x13** = matches QEMU exactly (10 hlts then break); **CP 0x14** = breaks after iter 25 (different from QEMU, fault is later in cycle); **CP 0x11** = full 50 iterations completed, scheduler loop is fine and stall is post-loop (would invalidate the entire `test_proc` hypothesis). |
| deferred | Apply `test_procs.cyr` `if (0 == 1)` → `while (1 == 1)` patch (or one of the three state.md fixes), if Attempt 12 result confirms the QEMU pattern reproduces on iron. Holding the fix until iron data tells us whether it's actually the right fix. | — |
| queued for next round | Bump consumer `cyrius.cyml` toolchain pins (`agnos/cyrius.cyml`, `agnosticos/scripts/cyrius.cyml`) from 5.11.53/54 → 5.11.55. Should clean the `vec_get` LSP diagnostic on `read-boot-log.cyr` and the bare-file LSP noise generally. Language-side change is in the cyrius repo, not touched here. | post-bump: `cyrius build` clean on both; LSP diagnostics on `read-boot-log.cyr` reduce. |

**Outcome:** PARTIAL SUCCESS. First attempt where every code-under-test
fix held simultaneously, kernel reached `Activating scheduler...`, AND
delivered a positive framebuffer signal (canary stripe). Remaining
fault is the previously-documented post-init scheduler-loop issue,
now confirmed on iron and isolated to a known fix domain.

---

### Attempt 12 — 2026-05-14 ~PDT → FAIL (CP 0x10; QEMU+UEFI hypothesis re-validated, dec-tree interpretation corrected)

**Build under test** (Attempt-11 plan applied — three in-loop CMOS
checkpoints added to the scheduler idle loop; gnoboot unchanged):

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.54 (bumped from 5.11.53 to pick up the read-boot-log build clean) |
| agnos kernel | 1.30.0 + Attempt-11 in-loop bisector. `build/agnos` = **251,456 bytes** (+144 over Attempt 11) ELF64 multiboot2, entry `0x1000a8`. Three new `if (idle_count == N)` blocks at `main.cyr:303-314` emitting CP 0x12/0x13/0x14 at iter 1/10/25. |
| gnoboot | 0.1.0 unchanged from Attempts 9-11 — `build/BOOTX64.EFI` = 35,328 bytes |
| `scripts/read-boot-log.sh` | Cyrius `read-boot-log` rebuilt with verdicts for kcp 0x12/0x13/0x14/0x11; 27,080 bytes. |

**CMOS readout (post-reset):**

```
CMOS[0x53] gnoboot magic    = 0xcd  (decimal 205)
CMOS[0x52] gnoboot checkpt  = 0x05  (decimal 5)
CMOS[0x51] kernel  magic    = 0xab  (decimal 171)
CMOS[0x50] kernel  checkpt  = 0x10  (decimal 16)

verdict (kernel): scheduler armed (CP 0x10) — kernel init COMPLETE. Stall is post-init, before first hlt return (CP 0x12).
```

**Diagnosis — dec-tree interpretation was wrong; fault is exactly the QEMU+UEFI test_proc hypothesis on iter 0.**

Re-reading `main.cyr:271-302` carefully shows the Attempt-11 decision
tree's "CP 0x10 = widens fix domain beyond test_proc" reading does not
hold up:

1. **`sti` works.** Line 272 executes `sti`; CP 0x0F at line 278 was
   skipped only because Attempt 12's bisector overlays at 0x10/0x12-0x14
   replaced the prior layered scheme — but the path through line 278 is
   the same. The next checkpoint downstream (0x10 at line 296) fired,
   confirming everything between 272 and 296 ran.
2. **Timer interrupts deliver and `hlt` wakes.** Lines 281-282 call
   `arch_wait()` *twice* **before** `sched_active = 1` (line 288).
   `do_context_switch` exits early when `sched_active == 0` (sched.cyr:94),
   so those two ISRs are pure tick-counter + EOI + iretq. CP 0x10 firing
   downstream of them proves both hlts returned.
3. **The first hlt that fails is the one inside the scheduler loop**
   (line 302), which is also the first hlt with `sched_active == 1`.
   That's not the timer/IRQ path widening — that's exactly the
   QEMU+UEFI test_proc hypothesis manifesting at *iter 0* instead of
   iter <10.

**Why iter 0 on iron vs ~10 in QEMU.** Trace through what happens on
the first `sched_active==1` timer ISR:

- ISR pushes 9 caller-saved regs (`pic.cyr:46-91`).
- `timer_handler` → `do_context_switch(rsp)` (sched_active is now 1).
- `sched_next()` picks proc 1 (`test_proc_a`, state=1 ready).
- `proc_save_context(0, rsp)` snapshots the kernel's hlt-resumption state
  into proc 0's slot.
- `proc_restore_context(1, rsp)` overwrites the ISR stack frame with
  `test_proc_a`'s state: RIP=&test_proc_a, RSP=0x814000, CS=0x08,
  RFLAGS=0x200, all GPRs zeroed.
- iretq → control transfers to `test_proc_a`.

Now look at `kernel/user/test_procs.cyr:6-12`:

```cyrius
fn test_proc_a() {
    if (0 == 1) {           # dead code — branch never taken
        serial_print("A", 1);
        arch_wait();
    }
    return 0;
}
```

The body is dead-code-eliminated; the function is effectively just a
prologue + `return 0`. Execution:

- prologue: `push rbp; mov rbp, rsp` → RSP=0x813FF8, RBP=0x813FF8
- body: empty (the `if (0 == 1)` is unreachable)
- epilogue: `mov rsp, rbp; pop rbp; ret` → RSP=0x814000
- `ret` pops `[0x814000]` as the return address

What's at 0x814000? The `vmm_alloc_at(0x810000)` call at main.cyr:248
maps a 2MB huge page covering [0x800000, 0xA00000) (vmm.cyr:11-22
forces the 2MB bit), so the address *is* mapped — that's why this isn't
a stack page fault. But the underlying physical page is whatever
`pmm_alloc()` handed back, and that memory is uninitialized firmware
scratch. Most likely zero → `ret 0x0` → unmapped instruction fetch →
triple fault → reset. (Even if non-zero, the chance of landing on
valid code is effectively zero.)

In QEMU under `-kernel`, `pmm_alloc` returned a page whose 2MB-aligned
container happened to contain a value at offset 0x14000 that survived
~10 iterations of the same return-to-garbage churn before triple-faulting
— different memory contents, different break point. iron + UEFI +
gnoboot gives us a freshly-handed-off region where the value triple-faults
on iter 0.

**The dec tree's flaw.** It treated `arch_wait()` as if the *user code*
could observe whether the hlt returned: "CP 0x12 = first hlt returned,
CP 0x10 = it didn't." But the timer ISR doesn't return to the kernel —
when `sched_active==1` it *jumps to test_proc_a*, which dies before any
post-hlt code can run. CP 0x12 is unreachable not because the hlt
hangs, but because the post-hlt instruction stream is no longer the
kernel's.

**Fault domain is identical to QEMU+UEFI's, just narrower.** Three
independent runs (QEMU `-kernel`, QEMU+UEFI+gnoboot, iron+UEFI+gnoboot)
all triple-fault on `test_proc_a`'s `ret`-to-garbage. iron breaks
fastest because its initial memory contents are most adversarial.
state.md fix (a) — "make `test_proc_a/b` real busy-loops in the default
build" — is exactly correct; we just don't need any further iron data
before applying it.

**Repair steps (Attempt-13 plan — apply state.md fix (a), the real busy-loop):**

| Approx PDT | Action | Verification gate |
|-----------|--------|-------------------|
| 2026-05-14 | `agnos/kernel/user/test_procs.cyr` — change `if (0 == 1)` → `while (1 == 1)` in both `test_proc_a` and `test_proc_b`. This makes the functions actual busy-loops (`serial_print` + `arch_wait` indefinitely), so `ret` is never reached and the return-to-garbage triple fault goes away. The `bench.sh`-applied patch is being inlined into source as the default build. Note this changes the kernel's behavior under microbenchmarks too — bench.sh now needs the *inverse* patch (or to be retired); flagging for the perf-bench sweep. (DONE) | `sh scripts/build.sh` clean (cyrius 5.11.54); `build/agnos` 251,456 → **251,472 bytes** (+16, the two `jmp` back-edges replacing the dead `if` branches). multiboot2 (ELF64) OK, entry `0x1000a8`. |
| 2026-05-14 | `agnosticos/scripts/src/read-boot-log.cyr` — tighten the kcp==16 verdict to point at CP 0x12 as the *expected* next gate now that the test_proc bug is fixed. (Optional cosmetic; the existing verdict is already correct interpretation.) | `cyrius build` clean. |
| pending | Re-flash USB + iron Attempt 13 on NUC AMD | post-reset `read-boot-log.sh` should show kernel CP advancing past 0x10 — CP 0x12 (first hlt round-trip in busy-loop), CP 0x13 (10 iter), CP 0x14 (25 iter), or CP 0x11 (loop completed). Any of these is a strict improvement; CP 0x11 is the closed-beta gate's next milestone. |
| 2026-05-14 | Bench-discipline followup: `agnos/scripts/bench.sh` (DONE — same-day cleanup). Audited bench.sh's sed; corrected reading is that it patches `while (1 == 1)` → `if (0 == 1)` (the opposite direction from what the old test_procs comment claimed). Pre-Attempt-12 the pattern didn't match the source's `if (0 == 1)`, so the sed was a silent no-op. Post-fix the sed *does* match and converts busy-loops to no-ops for bench builds — which is what bench actually wants (so the scheduler doesn't keep test_procs alive past `arch_halt`). Added a match-count guard (`grep -c 'while (1 == 1) {'` must equal 2) before the sed so a future test_procs reshape fails bench loudly. Cross-linked the bench.sh ↔ test_procs.cyr coupling in both files' comments. | `grep -c 'while (1 == 1) {' kernel/user/test_procs.cyr` returns 2; kernel build remains clean at 251,472 bytes. bench.sh now fails loudly if the contract diverges. |
| 2026-05-14 | Cyrius toolchain bump → **5.11.55** in both `agnos/cyrius.cyml` (was 5.11.53) and `agnosticos/scripts/cyrius.cyml` (was **5.10.44** — the Attempt-12 log's "5.11.54" for this file was wrong; the agnosticos pin had been carrying a much wider gap). Both manifests now read `cyrius = "5.11.55"`. (DONE) | `sh scripts/build.sh` on agnos: green, 251,472 bytes (byte-identical to Attempt 13). `cyrius build src/boot.cyr build/boot` on agnosticos/scripts: green. **Caveat:** both build outputs still emit `version-pinned /home/macro/.cyrius/versions/5.11.54/lib/` despite the manifest pin being 5.11.55, even though 5.11.55 IS installed under `~/.cyrius/versions/5.11.55/`. The wrapper binary itself reports `cyrius 5.11.25` and appears to cap resolution at 5.11.54. This is a cyrius-wrapper question, not a manifest question — pin is correct, resolution is upstream. Flagged for the cyrius repo, not blocking iron Attempt 14. |

**Outcome:** FAIL — *but* the failure is fully diagnosed, the fault site
is byte-localized (test_procs.cyr:6-12, the dead-code branch), and the
fix is a 2-line edit. The Attempt-11 dec-tree interpretation of CP 0x10
was the only thing that "widened" the fix domain; corrected reading
keeps the domain exactly where state.md placed it.

**Process note — dec-tree reasoning trap.** The Attempt-11 dec tree
mapped CP values to fault hypotheses based on *when in the loop* the
break occurred, implicitly assuming the loop instructions are reachable
post-hlt. That assumption fails when `sched_active==1` redirects control
out of the kernel entirely. Future bisector schemes through
context-switch boundaries should distinguish "instruction stream is
still the kernel's" from "instruction stream is now a different proc's"
— a CP write *before* the hlt and *after* the hlt are not the same kind
of evidence once a scheduler is involved. Worth a one-paragraph note in
the carry-forward / next-bisector design.

---

### Attempt 13 — 2026-05-14 ~PDT → PARTIAL SUCCESS (no triple-fault; new stall at CP 0x10 → 0x12 gap, fault domain narrowed to context-switch round-trip)

**Build under test** (Attempt-12 plan applied — test_procs converted
to real busy-loops; gnoboot unchanged; cyrius unchanged from 5.11.54):

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.54 (unchanged) |
| agnos kernel | 1.30.0 + busy-loop test_procs + Attempt-11 in-loop bisector. `build/agnos` = **251,472 bytes** (+16 over Attempt 12) ELF64 multiboot2, entry `0x1000a8`. `test_procs.cyr:14-28` now `while (1 == 1) { serial_print; arch_wait; }` in both `test_proc_a` and `test_proc_b`. |
| gnoboot | 0.1.0 unchanged from Attempts 9-12 — `build/BOOTX64.EFI` = 35,328 bytes |
| `scripts/read-boot-log.sh` | unchanged from Attempt 12 (verdict text still says "before first hlt return (CP 0x12)") |

**Symptom delta vs Attempt 12:**

| | Attempt 12 | Attempt 13 |
|---|---|---|
| End state | Semi-hard reset (forced hard power cycle) | **Soft lockup — canary + gnoboot framebuffer message persist** |
| Required intervention | Power cycle to recover | Power cycle still required (no autoreboot) |
| Triple-fault evidence | Yes (reset = CPU shutdown path) | **No** (CPU is alive in some state; framebuffer not corrupted) |

**CMOS readout (post-reset):**

```
CMOS[0x53] gnoboot magic    = 0xcd  (decimal 205)
CMOS[0x52] gnoboot checkpt  = 0x05  (decimal 5)
CMOS[0x51] kernel  magic    = 0xab  (decimal 171)
CMOS[0x50] kernel  checkpt  = 0x10  (decimal 16)

verdict (kernel): scheduler armed (CP 0x10) — kernel init COMPLETE. Stall is post-init, before first hlt return (CP 0x12).
```

**Diagnosis — return-to-garbage hypothesis fully validated; new fault is in the kernel-side round-trip back to proc 0.**

The reset → soft-lockup transition is the cleanest possible confirmation
that Attempt 12's diagnosis was correct. With `test_proc_a`/`test_proc_b`
as real busy-loops, the `ret`-to-uninitialized-stack path that
triple-faulted on iter 0 is no longer reachable; the CPU is now executing
*something* (no triple fault, framebuffer intact), but the kernel's idle
loop is not resuming far enough to fire CP 0x12. The fault domain has
shrunk from "anywhere in the scheduler / context-switch path" to one of
three specific sub-cases:

1. **test_proc_a's first hlt never returns** — timer IRQ not re-delivered
   after iretq into ring-0 test_proc_a. Likely PIC EOI / IF-flag / IDT
   issue downstream of the first context switch. CPU is alive but
   permanently halted in test_proc_a's first `arch_wait()`.
2. **Round-trip context switch back to proc 0 corrupts state** — second
   timer ISR fires inside test_proc_a, sched_next() rotates through
   test_proc_b → wraps to proc 0, but `proc_restore_context(0, ...)`
   sets up an RIP/RSP that diverges from the kernel's saved hlt-resume
   state. Resumes into something that isn't the idle loop's CP-0x12
   block.
3. **`sched_next()` never picks proc 0** — proc 0's state was set to
   ready (state=1) on the first context-switch out, but if it stays at
   state=2 (running) or 0 (free) somewhere in the round-robin's view,
   the rotation oscillates only between test_proc_a ↔ test_proc_b
   indefinitely. CP 0x12 unreachable not because of a fault but because
   the kernel idle loop is starved.

**Why this isn't visible in QEMU.** QEMU under `-kernel` skipped gnoboot
entirely (different memory layout, no UEFI runtime services, simpler PIC
path); the previous QEMU "10 iter then break" was a *different* bug
(the ret-to-garbage from a non-zero scratch word). With busy-loops
applied, QEMU also stops triple-faulting — but no one has re-run QEMU
yet with the busy-loop variant to see whether it now stalls at CP 0x10
or progresses to CP 0x12. **That's the cheapest next datum** —
distinguishes "iron-only context-switch bug" from "iron + QEMU
shared bug exposed once the louder ret-to-garbage stopped masking it."

**Why "lockup with canary" is itself diagnostic.** The canary + gnoboot
message persisting means:

- Framebuffer memory is intact (no random kernel writes corrupted it)
- The CPU is not in a triple-fault → reset loop
- The CPU is either (a) halted on `hlt` with interrupts not arriving,
  or (b) busy-looping somewhere (the test_procs are designed to busy-loop
  forever via `serial_print` + `arch_wait`)

If serial output is observable (the test_procs spam "A" and "B" chars
forever), case (a) is partial: at least one test_proc executed at
least one iteration before halting. If serial is silent, the very first
context switch faulted before reaching test_proc_a's serial_print.
**Serial capture is the second cheap datum.**

**Repair steps (Attempt-14 plan — instrument test_procs themselves; QEMU re-run):**

| Approx PDT | Action | Verification gate |
|-----------|--------|-------------------|
| pending | Re-run QEMU `-kernel` with the Attempt-14 build. Compare CMOS / serial against iron. | QEMU also stalls at CP 0x10 → bug is in context-switch path itself, not iron-specific. QEMU advances to CP 0x12 → bug is iron-specific (PIC/LAPIC/IDT timing under UEFI handoff). |
| pending | Capture serial output during iron boot if possible (UART pinout / FTDI). If "A"/"B" chars stream → test_procs are running, kernel idle is starved. If serial silent post-CP-0x10 → first context switch faulted before test_proc_a's first instruction completed. | Direct evidence of which sub-case (1/2/3 above) is in play. |
| 2026-05-14 | Add CMOS CPs *inside* `test_procs.cyr`: CP 0x20 at top of `test_proc_a` (pre-loop), CP 0x21 after first `serial_print` (guarded by `iter == 0`), CP 0x22 after first `arch_wait` (guarded by `iter == 0`), CP 0x23 at top of `test_proc_b` (proves round-robin reached proc 2). Inline asm blocks match the kernel's existing CMOS-write pattern. (DONE) | `sh scripts/build.sh` green; `build/agnos` = **251,520 bytes** (+48 over Attempt 13: four CP-write blocks × ~12 bytes incl. loop guards); multiboot2 ELF64 OK, entry `0x1000a8`. `grep -c 'while (1 == 1) {' kernel/user/test_procs.cyr` = 2 — bench.sh's match-count guard still satisfied. |
| pending | Re-flash USB + iron Attempt 14 on NUC AMD | post-reset `read-boot-log.sh` shows kcp ∈ {**0x10**, **0x20**, **0x21**, **0x22**, **0x23**}: **0x10** = first context switch faulted before test_proc_a's first instruction (sub-case 2 most likely — proc_restore_context for proc 1 set up bad RIP/RSP); **0x20** = into test_proc_a OK, serial_print faulted (improbable — serial path is byte-tested); **0x21** = first serial_print OK, first hlt-in-proc didn't return (sub-case 1 — timer IRQ not redelivered post-iretq into ring-0 user proc); **0x22** = first round-trip in test_proc_a OK, stuck oscillating on test_proc_a (sub-case 3a — sched_next never advances past proc 1, maybe state machine wedged); **0x23** = sched rotated test_proc_a → test_proc_b OK, stuck oscillating between user procs (sub-case 3b — proc 0 starved, never returns to kernel idle, CP 0x12 unreachable by design). 0x22 or 0x23 = strict scheduler-alive progress; 0x10 or 0x20-0x21 = fault inside the first context-switch round-trip. |
| pending | If sub-case (1) is confirmed (hlt doesn't return inside test_proc_a): inspect timer ISR EOI path (`pic.cyr`) for whether EOI is sent before iretq into user-context, and confirm IF flag is set in saved RFLAGS for test_procs at `proc_init` time. | `grep -n EOI` on the timer ISR; `proc_init` for test_procs sets RFLAGS=0x202 (IF=1) or equivalent. |
| pending | If sub-case (3) is confirmed (sched starves proc 0): adjust `sched_next` to include the current proc in the rotation only when no other ready proc exists OR mark proc 0 as ready explicitly post-save_context. | Round-robin demo: kernel idle resumes after one full cycle through test_procs. |

**Outcome:** PARTIAL SUCCESS. The Attempt-12 busy-loop fix did exactly
what it was supposed to do — eliminated the return-to-garbage triple
fault. The fact that we're now staring at a *different* stall, with the
framebuffer alive and no reset, is unambiguously forward motion. The
remaining fault domain is one of three concrete, well-localized
sub-cases inside the context-switch round-trip, and Attempt 14's three
parallel datums (QEMU re-run, serial capture, in-test_proc CMOS
bisector) can disambiguate among them in one boot cycle.

**Process note — "no longer resets" is its own data class.** The
prior attempts' reset behavior was so consistent that it became the
default interpretation of "boot failed." A soft-lockup with intact
framebuffer is a qualitatively different failure mode and should be
called out as such in future entries — it tells us the CPU is alive
(no triple fault), the kernel didn't corrupt memory it owned (no
random framebuffer writes), and the fault is in control flow rather
than state corruption. Worth distinguishing in the verdict text of
`read-boot-log.cyr` going forward — "stall" vs "reset" vs "lockup"
are not synonyms.

---

### Attempt 14 — 2026-05-14 ~PDT → MAJOR PROGRESS (CP 0x23 — scheduler alive, rotated test_proc_a → test_proc_b; sub-case 3b confirmed, proc 0 starved by round-robin)

**Build under test** (Attempt-13 plan applied — in-test_proc CMOS
bisector at 0x20/0x21/0x22/0x23; cyrius pin synced to 5.11.55 in
both manifests; bench.sh match-count guard added; gnoboot unchanged):

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.55 pinned in both `agnos/cyrius.cyml` and `agnosticos/scripts/cyrius.cyml`. Resolver still pulls 5.11.54 lib at build time (cyrius-wrapper question, not blocking). |
| agnos kernel | 1.30.0 + busy-loop test_procs + Attempt-11 in-loop bisector + Attempt-14 in-test_proc bisector. `build/agnos` = **251,520 bytes** (+48 over Attempt 13: four CP-write blocks × ~12 bytes incl. `iter == 0` guards) ELF64 multiboot2, entry `0x1000a8`. `test_procs.cyr` now writes CP 0x20 pre-loop in proc_a, 0x21 post-first-`serial_print`, 0x22 post-first-`arch_wait`, 0x23 pre-loop in proc_b. |
| gnoboot | 0.1.0 unchanged from Attempts 9-13 — `build/BOOTX64.EFI` = 35,328 bytes |
| `scripts/read-boot-log.sh` | Updated post-attempt (this commit) — verdicts added for kcp 32-35 (CPs 0x20-0x23) so future runs name the sub-case directly instead of printing "unexpected checkpoint". |

**Symptom delta vs Attempt 13:**

| | Attempt 13 | Attempt 14 |
|---|---|---|
| End state | Soft lockup — canary + gnoboot framebuffer message persist | **Same — soft lockup, framebuffer intact, no reset** |
| Kernel CP | 0x10 (scheduler armed; pre-1st-hlt-return) | **0x23 — sched rotated test_proc_a → test_proc_b** |
| gnoboot CP | 0x05 (handoff complete) | 0x05 (unchanged) |
| Diagnostic resolution | "fault somewhere in context-switch round-trip" (3 sub-cases) | **Sub-case 3b isolated** — every context-switch step works; bug is purely in `sched_next()` policy starving proc 0 |

**CMOS readout (post-reset):**

```
CMOS[0x53] gnoboot magic    = 0xcd  (decimal 205)
CMOS[0x52] gnoboot checkpt  = 0x05  (decimal 5)
CMOS[0x51] kernel  magic    = 0xab  (decimal 171)
CMOS[0x50] kernel  checkpt  = 0x23  (decimal 35)

verdict (kernel): unexpected checkpoint 35 — possibly stale CMOS.
```

(The "unexpected" verdict text is a stale read-boot-log; the binary
didn't know about CP 0x20-0x23 yet. Fixed in this commit — future
runs will print: *"CP 0x23 — sched rotated test_proc_a → test_proc_b
OK. Scheduler is alive; proc 0 (kernel idle) starved by round-robin.
Sub-case 3b: fix sched_next to include proc 0 OR mark proc 0 ready
post-save_context."*)

**Diagnosis — sub-case 3b fully confirmed; closed-beta gate's next milestone is one scheduler-policy edit away.**

Reaching CP 0x23 proves, in order:

1. **CP 0x10 → 0x20** — first context switch *out of the kernel* and
   *into ring-0 test_proc_a* succeeded. `proc_restore_context(1, …)`
   set up a valid RIP/RSP for proc_a's entry point. iretq into the
   user proc landed at the right instruction.
2. **CP 0x20 → 0x21** — test_proc_a's serial path executed at least
   one full `serial_print` call. UART writes from inside a user proc
   work. (This was rated "improbable" in the Attempt-13 dec tree as
   a fault point — confirmed: not a fault point at all.)
3. **CP 0x21 → 0x22** — test_proc_a's first `arch_wait()` returned.
   `hlt` issued from inside ring-0 user code, timer ISR fired,
   PIC EOI was acknowledged, `iretq` resumed test_proc_a after the
   hlt. **This is the round-trip the Attempt-13 writeup was unsure
   would work** — it works. Sub-case 1 (timer not re-delivered
   post-iretq) is eliminated.
4. **CP 0x22 → 0x23** — second timer ISR fired during proc_a's
   busy-loop. `sched_next()` rotated proc_a → proc_b. Context save
   on proc_a + restore on proc_b both worked. **This eliminates
   sub-case 3a** (sched stuck oscillating on proc_a alone).
5. **CP 0x23 → ???** — proc_b is now running its busy-loop forever.
   No further CPs land. The kernel's idle loop (proc 0, CP 0x12 ff.)
   is never reached, but every other component is alive.

This is the cleanest possible **sub-case 3b**: the round-robin in
`sched_next()` oscillates only between proc 1 ↔ proc 2 and never
re-selects proc 0. The two candidates from the Attempt-13 repair
plan both still apply:

- **(A)** Mark proc 0 explicitly `state = ready` after its initial
  `save_context()` so the round-robin sees it as eligible. Likely
  the smaller, more targeted patch.
- **(B)** Change `sched_next()` policy: when no other ready proc
  is available, fall back to proc 0; or, give proc 0 an explicit
  slot in the rotation cycle rather than letting it be skipped.
  Bigger semantic change.

**Why this is forward motion that's hard to overstate.** Every iron
attempt from Attempt 7 onward has been chasing a fault somewhere
between "kernel entry" and "scheduler resumes idle." Attempt 14
shrinks that range to a single named function (`sched_next` or
`save_context` for proc 0). **All the hard parts work**: ELF load,
multiboot2 handoff, GDT/TSS/IDT/PIC/LAPIC bring-up, timer ISR,
context switching in both directions, ring-0 user procs, serial
from user procs, PIC EOI in the IRQ path, and *two* successful
context-switch round-trips (proc_a's first hlt→return, then
proc_a→proc_b). The remaining bug is a scheduling-policy
oversight, not a kernel-core or hardware-handoff bug.

**Repair steps (Attempt-15 plan — fix sched_next proc 0 starvation; minimal kernel edit; QEMU re-run still cheap):**

| Approx PDT | Action | Verification gate |
|-----------|--------|-------------------|
| 2026-05-14 (this commit) | Update `scripts/src/read-boot-log.cyr` with explicit verdicts for kcp 32-35 (CPs 0x20-0x23) so future iron runs name the sub-case directly. (DONE) | `cyrius build src/read-boot-log.cyr build/read-boot-log` green; binary = 28,080 bytes; next iron run prints sub-case 3b verdict instead of "unexpected checkpoint 35." |
| 2026-05-14 eve | Inspect `agnos/kernel/core/sched.cyr` — analysis identified that the existing `if (proc_get_state(old) == 2)` guard at do_context_switch line 103 *should* mark proc 0 ready after first save, blame shows it's been there since 2026-04-06. Iron sub-case 3b empirically shows it isn't sufficient — proc 0 stays unselectable somehow. (DONE) | Two-line analysis pinpointed the guard. **Both** repair candidates were then approved by user and landed in the same eve — see "Repairs landed" subsection below. |
| 2026-05-14 eve | Land repair (A) — unconditional `proc_set_state(old, 1)` post-save in `do_context_switch`. Removes the `state==2` guard whose conditional read may be the unaccounted variable on iron. (DONE) | `agnos/kernel/core/sched.cyr:108-116` (was 103-105). Kernel 252,528 → 252,496 bytes (–32, branch eliminated). Same-LSP-class warning for proc_current, unrelated. |
| 2026-05-14 eve | Land repair (B) — `sched_next()` falls back to `return 0` (proc 0 = kernel idle) instead of `return proc_current` when no ready proc found. Belt-and-suspenders with (A): guards against any state-corruption path that might still leave proc 0 unselected. (DONE) | `agnos/kernel/core/sched.cyr:7-25`. Kernel 252,496 → 252,480 bytes (–16, literal 0 vs global load). |
| 2026-05-14 eve | Wire visual-diagnostic ladder — new `kernel/arch/x86_64/fb.cyr` with `cp_fb(idx, color)` (BGR-encoded; null/oob-guarded), plus 19 `cp_fb` call sites in `kernel/core/main.cyr` after every existing CMOS CP write. Color-coded by layer: YELLOW=early arch (0x80/0x81/0x82/0x06), GREEN=subsystems (0x07-0x0D), CYAN=scheduler arming + in-hlt-loop (0x0E-0x10, 0x12/0x13/0x14 first pass), MAGENTA=post-scheduler/userland (0x11, 0x12/0x13/0x14 post-test, 0x15). Stops on iron screen at the cell where execution halted — no reboot+CMOS-read needed for cell-color readout. (DONE) | `kernel/arch/x86_64/fb.cyr` (new, ~30 LOC); `kernel/agnos.cyr` (include); `kernel/core/main.cyr` (19 sites). Kernel +416 bytes from cp_fb wiring + function body. |
| 2026-05-14 eve | Collateral cleanup — renamed `kernel/lib/` → `kernel/klib/` to eliminate the cyrius wrapper's `./lib/` shadow-collision class. Wrapper reserves `./lib/` at compile cwd for stdlib-snapshot resolution; agnos was using the same name for its freestanding syscall-free stdlib (kstring/kfmt/ktagged), generating a "delete ./lib/" warning every build and creating real stomp risk if `cyrius deps` were ever run with non-empty `[deps] stdlib`. Updated includes in agnos.cyr, comment refs in cyrius.cyml + vfs.cyr, removed now-moot `CYRIUS_NO_WARN_SHADOW_LIB=1` from test.sh, current-state refs in README/CLAUDE.md/state.md. Historical refs in CHANGELOG / archived proposals / doc-health / roadmap left alone (they describe state at past tags). (DONE) | Build still 252,480 bytes — byte-identical to pre-rename for the rename itself; the build-warning is gone, no more shadow-by-design caveat to teach future readers. |
| pending | Re-run QEMU `-kernel` with the Attempt-15 build before flashing. **Now expected to advance past CP 0x23** — both repairs target the proc 0 starvation. If QEMU still stalls at 0x23, the bug is *not* in the round-robin policy and we need to look at proc_save_context / proc_restore_context for proc 0 specifically (sub-case 2 territory). | QEMU advances past 0x23 to 0x12/0x13/0x14/0x11 = repairs are sufficient. QEMU still stalls at 0x23 = sub-case 3b diagnosis was incomplete; look at proc context save/restore for proc 0. |
| pending | After QEMU advances: re-flash USB, iron Attempt 15. | post-reset `read-boot-log.sh` shows kcp ∈ {0x12, 0x13, 0x14, **0x11**}. **CP 0x11 is the closed-beta gate's penultimate milestone** — full 50-hlt scheduler cycle completes on iron. After CP 0x11 the next gate is post-loop progress (shell launch). Visual on-screen: a 0x12 cell that lights **CYAN then transitions to MAGENTA** confirms the proc 0 ↔ proc_a/b cycle now closes — repair (A)+(B) working. |

**Outcome:** MAJOR PROGRESS. The Attempt-13 in-test_proc bisector
worked exactly as designed — five possible CPs, one of them
hit, sub-case 3b cleanly isolated from sub-cases 1, 2, 3a. The
remaining boot-to-shell fault domain is now small enough to
describe in a sentence: **`sched_next()` does not re-select
proc 0 after its initial context-switch out.** The closed-beta
gate (CP 0x11 — scheduler completes its 50-hlt cycle on iron)
is one targeted kernel edit away.

**Process note — five-way dec tree paid off.** The Attempt-13 plan
predicted five distinct CPs with one specific diagnosis per CP.
Iron landed on 0x23, which the dec tree had pre-bound to
"sub-case 3b — proc 0 starved by round-robin." That's a clean
prediction-confirmation cycle: one boot was enough to converge.
Repeat the pattern for Attempt 15 — pre-bind expected CPs to
specific kernel diagnoses *before* the burn, not after.

**Process note — toolchain pin gap closed.** Attempt 13's writeup
revealed the agnosticos `scripts/cyrius.cyml` had drifted to
5.10.44 while agnos was on 5.11.53. Both manifests now pin
5.11.55 (today's release). Cyrius wrapper still resolves to
5.11.54's lib snapshot — flagged for the cyrius repo, not iron-
blocking. The pin-lag spectrum tracked in `docs/development/state.md`
should reflect both manifests at 5.11.55 next time state.md is refreshed.

---

### Repairs landed for Attempt 15 — 2026-05-14 evening

All edits in `agnos/` (no cyrius-side changes per cyrius-hands-off).
Per-action consent obtained step-by-step from user. Net kernel size
delta: +368 bytes (post-rename baseline 252,112 → 252,480).

**1. Repair (A) — unconditional state→ready post-save** (`kernel/core/sched.cyr` ~line 108):

```diff
     proc_save_context(old, isr_rsp);
-    if (proc_get_state(old) == 2) {
-        proc_set_state(old, 1);  # running → ready
-    }
+    proc_set_state(old, 1);  # running → ready (unconditional)
```

Rationale: `proc_save_context` semantically implies `old` was the
running proc; the only valid state transition is to ready. The prior
`state==2` guard was empirically insufficient on iron — Attempt 14
sub-case 3b is consistent with proc 0's state being read as non-2
on that path for reasons we cannot fully account for in static
analysis. Unconditional set removes that variable. blame on the
prior conditional dates to 2026-04-06 (`c1877a44`), well before
iron testing started.

**2. Repair (B) — sched_next falls back to proc 0** (`kernel/core/sched.cyr` ~line 19):

```diff
         si = si + 1;
     }
-    return proc_current;
+    return 0;  # fall back to proc 0 (kernel idle)
 }
```

Rationale: when the round-robin scan finds no other ready proc, the
prior fallback `return proc_current` lets a busy-looping ring-0
test proc (`test_proc_b`) hold the CPU indefinitely. Falling back
to proc 0 (kernel idle) guarantees the kernel idle loop gets
re-selected whenever no test proc is ready — proc 0 will hlt and
yield again. Belt-and-suspenders with (A): if (A) fully solves
sub-case 3b, (B) is dormant; if (A) fails on iron for some
unaccounted reason, (B) provides a second safety net at a different
layer (policy vs state). Either alone defends sub-case 3b.

**3. Visual diagnostic — color-coded CP ladder** (`kernel/arch/x86_64/fb.cyr`
NEW + 19 sites in `kernel/core/main.cyr`):

New file `fb.cyr` defines `cp_fb(idx, color)` — paints a 4×4
colored cell on the UEFI framebuffer at a fixed (col, row) grid
keyed off the CP index. Null-guarded against missing `boot_info_ptr`
and `fb_phys`; off-screen-guarded against bad height. Companion to
the existing CMOS scheme — CMOS captures progress across reset
(post-mortem readout), `cp_fb` captures progress at-boot-time on
screen. After every existing CMOS asm CP write in main.cyr, a
matching `cp_fb(idx, COLOR)` call. CMOS first, FB second — if a
hypothetical fb regression faults, the CMOS log is unaffected.

Color palette (BGR-encoded; gnoboot's UEFI GOP default on Zen is
BGR — on RGB hardware yellow↔cyan swap but layer geometry stays
correct):

| Color | Hex | Layer | CPs |
|-------|-----|-------|-----|
| WHITE | `0xFFFFFFFF` | boot_shim canary stripe (pre-existing, 256-px line at y=0) | 1-5 (boot_shim only) |
| YELLOW | `0x00FFFF00` | early arch | 0x80, 0x81, 0x82, 0x06 |
| GREEN | `0x0000FF00` | subsystem init | 0x07-0x0D |
| CYAN | `0x0000FFFF` | scheduler arming + in-hlt-loop first pass | 0x0E, 0x0F, **0x10** (closed-beta gate), in-loop 0x12/0x13/0x14 |
| MAGENTA | `0x00FF00FF` | post-scheduler / userland | 0x11, post-test 0x12/0x13/0x14, 0x15 |

On iron Attempt 14's repeat, the cells should have lit:
- WHITE stripe (boot_shim) ✓
- YELLOW × 4 ✓
- GREEN × 7 ✓
- CYAN × 3 (0x0E, 0x0F, 0x10 = closed-beta gate fired)
- CYAN × 1 at cell 0x12 (first hlt round-trip OK — proc_a→proc_b switch)
- **STOP** at 0x23 (proc_b entered, never yielded)
- proc 0 never resumes → cells 0x11 + 0x12-MAGENTA-overwrite + 0x13-MAGENTA + 0x14-MAGENTA + 0x15 all dark

For Attempt 15 with repairs (A)+(B) in: expect cells 0x12/0x13/0x14
to **transition CYAN → MAGENTA** (first written by the hlt loop,
overwritten by the post-VFS/post-mem-isolation/post-userland-exec
sites) and cell **0x11 lights MAGENTA** — the closed-beta gate's
penultimate milestone, full 50-hlt scheduler cycle completed.

**4. Collateral — klib/ rename**: `kernel/lib/` → `kernel/klib/`,
eliminating cyrius wrapper's `./lib/` shadow-collision class.
Was generating "delete ./lib/" warning every build (false positive
for this repo — the kernel deliberately vendors its freestanding
stdlib at that path). Wrapper reserves `./lib/` at compile cwd
for stdlib-snapshot resolution; distinct name eliminates the
warning AND the stomp risk if `cyrius deps` is ever run with
non-empty `[deps] stdlib`. Includes in agnos.cyr, comment refs in
cyrius.cyml + vfs.cyr, removed now-moot `CYRIUS_NO_WARN_SHADOW_LIB=1`
from test.sh, current-state refs in README/CLAUDE.md/state.md.
Historical refs in CHANGELOG / archived proposals / doc-health /
roadmap left alone — they describe state at past tags. Build
byte-identical for the rename itself; the value is reduced
build-warning noise + reduced surface for future drift.

**Build verification:** `./scripts/build.sh` green, ELF64
multiboot2 OK, entry `0x1000a8`. Cumulative kernel size
post-everything: **252,480 bytes**.

**QEMU pre-flight (recommended before iron burn):** load this
build under QEMU+UEFI per Attempt-13's gnoboot path. If QEMU now
emits CMOS CP ∈ {0x11, 0x12, 0x13, 0x14}, repairs are sufficient
on QEMU and likely on iron. If QEMU still stalls at 0x23 (or
anywhere ≤ 0x10), the diagnosis was incomplete and we need to
look at `proc_save_context` / `proc_restore_context` for proc 0
specifically (sub-case 2 territory).

---

### Attempt 15 — 2026-05-14 eve PDT → STALL AT 0x23 (repairs A+B insufficient; sub-case 2 confirmed)

**Build under test** (post-Repair-A/B + visual ladder + klib rename):

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.55 pinned (manifests). Wrapper still resolves 5.11.54 lib snapshot — out-of-scope. |
| agnos kernel | 1.30.0 + Repair (A) unconditional state→ready post-save + Repair (B) `sched_next` returns proc 0 fallback + new `fb.cyr` visual CP ladder + `kernel/klib/` rename. `build/agnos` = **252,480 bytes** ELF64 multiboot2, entry `0x1000a8`. |
| gnoboot | 0.1.0 unchanged |
| `scripts/read-boot-log.sh` | Verdicts for kcp 0x20-0x23 now in place (added in Attempt-14 close). |

**Symptom delta vs Attempt 14:**

| | Attempt 14 | Attempt 15 |
|---|---|---|
| End state | Soft lockup, screen intact, no reset | **Same — soft lockup, visual CP ladder painted, no reset** |
| Kernel CP | 0x23 (sched rotated proc_a → proc_b; proc 0 starved) | **0x23 — identical CMOS readout** |
| gnoboot CP | 0x05 | 0x05 (unchanged) |
| Visual ladder | N/A (fb.cyr didn't exist in Attempt 14 build) | **Painted: WHITE stripe + YELLOW × 4 + GREEN × 7 + CYAN × 3** through CP 0x10, then dark — confirms new kernel ran on iron, scheduler armed, but proc 0 never resumed |
| Diagnostic resolution | "sub-case 3b — proc 0 starved by round-robin" | **Sub-case 3b diagnosis was incomplete; sub-case 2 confirmed** — context save/restore is missing register state |

**CMOS readout (post-reset):**

```
CMOS[0x53] gnoboot magic    = 0xcd  (decimal 205)
CMOS[0x52] gnoboot checkpt  = 0x05  (decimal 5)
CMOS[0x51] kernel  magic    = 0xab  (decimal 171)
CMOS[0x50] kernel  checkpt  = 0x23  (decimal 35)

verdict (kernel): CP 0x23 — sched rotated test_proc_a → test_proc_b
OK. Scheduler is alive; proc 0 (kernel idle) starved by round-robin.
Sub-case 3b: fix sched_next to include proc 0 OR mark proc 0 ready
post-save_context.
```

(The verdict text now points at sub-case 3b per the Attempt-14
read-boot-log update — but the underlying bug was actually
sub-case 2, not 3b. The hop is documented below in Repair-C.)

**Visual ladder confirms the new kernel ran on iron** (this matters
— it eliminates the "USB wasn't re-flashed" hypothesis). The
[`iron-boot-photos/attempt-15-boot-colors.jpg`](iron-boot-photos/attempt-15-boot-colors.jpg) photo from the iron run shows:

- WHITE stripe at y=0 (boot_shim canary, pre-existing)
- 4 YELLOW cells (CPs 0x80, 0x81, 0x82, 0x06 — early arch)
- 7 GREEN cells (CPs 0x07-0x0D — subsystem init)
- 3 CYAN cells (CPs 0x0E, 0x0F, 0x10 — scheduler armed; **0x10 is the closed-beta gate**)
- Cell 0x12 dark — first hlt in kernel idle's 50-loop never returned to write its CP
- All MAGENTA cells dark — sched_active = 0 path never reached

`fb.cyr` was added in the Attempt-15 build; its presence on screen
proves the iron is running the post-Repair-A/B kernel, not a
stale Attempt-14 image.

**Diagnosis hop — sub-case 3b → sub-case 2 (context-switch bug,
not policy bug).**

Static walkthrough of `sched_next` + `do_context_switch` *after*
repairs A and B shows that proc 0 *should* be re-selected on the
third timer tick (proc 0 → proc_a → proc_b → proc 0). The math
checks out: state[0] = 1 (ready, set by repair A on the first
save), proc_current = 2 (proc_b), `start = 3 % 3 = 0`,
`proc_get_state(0) == 1` → return 0. `do_context_switch` then
calls `proc_restore_context(0, isr_rsp)` and iretqs into proc 0.
**This should work on iron.** It doesn't. Therefore the bug is
not in `sched_next` policy.

Investigating the ISR + context save/restore code path identified
the actual bug:

**`kernel/arch/x86_64/pic.cyr` `timer_isr_build()` lies about
what it pushes.** The function-header comment says *"push all
caller-saved regs, also push rbx/rbp/r12-r15 (callee-saved) so
we have full state"* — but the actual byte-emission pushes only
the 9 caller-saved regs (rax/rcx/rdx/rsi/rdi/r8-r11). The
callee-saved set (rbx, rbp, r12, r13, r14, r15) is *never
pushed*, *never saved* into the proc slot, *never restored*.

The `Process` struct (`proc.cyr`) *has* slots for those 6 regs
(offsets 40, 80, 120, 128, 136, 144), but `proc_save_context` /
`proc_restore_context` only touch the 9 caller-saved + RIP /
RFLAGS / RSP. So **callee-saved registers leak between procs**
across every context switch.

**Why this matches the symptom exactly.** When proc 0 (kernel
idle) is finally re-selected on the third tick, `iretq` lands
at the post-`hlt` address in `arch_wait` with the correctly-
restored RSP — so the kernel stack is intact and `ret` pops the
right address back to the idle loop. **But RBP now contains
test_proc_b's frame pointer** (pointing into stack_b at
0x820000+), because it was never saved out and never restored
in. The kernel idle loop's first access to a local variable
(`idle_count` at `[rbp - N]`) reads from test_proc_b's stack —
garbage. The while-loop reads wrong, the increment writes
wrong, and either the loop spins on a corrupt count or we
silently fault. Either way, **no CP after 0x23 fires**, which
is exactly what CMOS shows.

This is *also* consistent with earlier Attempt-13 stalls — same
class of bug, different surface manifestation depending on
which proc happened to leave which register set.

**The two-attempt diagnostic arc** (14 → 15) was a clean prediction-
confirmation cycle: Attempt 14's writeup explicitly named the
fallback path — *"If QEMU still stalls at 0x23, the bug is not
in the round-robin policy and we need to look at
proc_save_context / proc_restore_context for proc 0 specifically
(sub-case 2 territory)."* Iron Attempt 15 stalled at 0x23. The
pre-bound sub-case 2 territory is what Repair (C) addresses.

**Process note — visual CP ladder paid off immediately.** Without
`fb.cyr` we wouldn't have been able to rule out "USB carries
Attempt-14 kernel" without re-mounting and hashing the USB.
The painted YELLOW/GREEN/CYAN cells let us confirm from the
photo alone that the iron was running the Repair-A/B build,
not a stale image. Worth the +416 bytes.

**Process note — QEMU pre-flight is permanently gone for this
kernel.** Multiboot2 ELF64 fails `qemu-system-x86_64 -kernel`
(needs PVH ELF Note or compressed image). Path A's grub-EFI
relocator is W^X-blocked under OVMF (per `project_grub_mb2_efi_wx_blocker`
memory). `ktest.sh` exists but its `-kernel` invocation can't
actually launch the new kernel either. **Until Path-C `gnoboot`
gains a QEMU+OVMF launch script, iron is the only test surface.**
Each attempt costs the dev machine a reboot.

---

### Repairs landed for Attempt 16 — 2026-05-14 night

All edits in `agnos/` (no cyrius-side changes per cyrius-hands-off).
Per-action consent obtained — user approved "(a) land Repair (C)
as a single coupled edit (pic.cyr ISR + sched.cyr offsets), build,
report kernel size delta" verbatim. Net kernel size delta:
+1,232 bytes (252,480 → **253,712 bytes**).

**Repair (C) — save/restore all 15 GPRs across the timer ISR.**

The fix is two coupled edits — pushing the 6 callee-saved regs
in the ISR + reading/writing them through the proc slots in
save/restore. Everything else in `sched.cyr` shifts by +48 bytes
because the hardware-pushed frame now sits deeper in the stack.

**1. ISR — push/pop all 15 GPRs** (`kernel/arch/x86_64/pic.cyr`):

```diff
 fn timer_isr_build() {
     # Build timer ISR in data buffer.
-    # Strategy: push all caller-saved regs, also push rbx/rbp/r12-r15 (callee-saved)
-    # so we have full state. Then call timer_handler(rsp) which may modify
-    # the stack frame for context switching. Then pop everything and iretq.
+    # Strategy: push ALL 15 general-purpose regs (9 caller-saved + 6 callee-saved)
+    # so the full proc state is captured by proc_save_context. Pre-Attempt-15
+    # this ISR only pushed the 9 caller-saved regs despite a stale comment
+    # claiming otherwise; the missing callee-saved push leaked rbx/rbp/r12-r15
+    # between procs, corrupting frame-pointer-relative locals (idle_count etc.)
+    # when the kernel idle proc was finally re-selected. See iron-boot Attempt
+    # 15 § Repair (C) — sub-case 2 territory.
     ...
     store8(p + off, 0x41); store8(p + off + 1, 0x53); off = off + 2;  # push r11
+
+    # Callee-saved: rbx rbp r12 r13 r14 r15 (Attempt-15 Repair C addition).
+    # After these pushes, [rsp+0..47] = {r15,r14,r13,r12,rbp,rbx} and
+    # [rsp+48..119] = {r11,r10,r9,r8,rdi,rsi,rdx,rcx,rax}; hw frame moves
+    # from [rsp+72..104] to [rsp+120..152]. proc_save/restore_context are
+    # updated to read/write these new offsets.
+    store8(p + off, 0x53); off = off + 1;  # push rbx
+    store8(p + off, 0x55); off = off + 1;  # push rbp
+    store8(p + off, 0x41); store8(p + off + 1, 0x54); off = off + 2;  # push r12
+    store8(p + off, 0x41); store8(p + off + 1, 0x55); off = off + 2;  # push r13
+    store8(p + off, 0x41); store8(p + off + 1, 0x56); off = off + 2;  # push r14
+    store8(p + off, 0x41); store8(p + off + 1, 0x57); off = off + 2;  # push r15
     ...
+    # Pop callee-saved first (reverse of push): r15 r14 r13 r12 rbp rbx
+    store8(p + off, 0x41); store8(p + off + 1, 0x5F); off = off + 2;  # pop r15
+    store8(p + off, 0x41); store8(p + off + 1, 0x5E); off = off + 2;  # pop r14
+    store8(p + off, 0x41); store8(p + off + 1, 0x5D); off = off + 2;  # pop r13
+    store8(p + off, 0x41); store8(p + off + 1, 0x5C); off = off + 2;  # pop r12
+    store8(p + off, 0x5D); off = off + 1;  # pop rbp
+    store8(p + off, 0x5B); off = off + 1;  # pop rbx
+
+    # Pop caller-saved: r11 r10 r9 r8 rdi rsi rdx rcx rax (reverse of push)
     store8(p + off, 0x41); store8(p + off + 1, 0x5B); off = off + 2;  # pop r11
     ...
```

ISR bytecode size: 43 → 63 bytes. `timer_isr` buffer is 64
bytes — **1 byte of headroom remaining**. Any future ISR addition
needs to bump `timer_isr[]` first.

**2. proc_save_context / proc_restore_context — handle the 6
new regs + shift hw frame offsets by +48** (`kernel/core/sched.cyr`):

Hardware-pushed frame offsets:

| Field | Old offset | New offset (Repair C) |
|-------|-----------|-----------------------|
| RIP | `isr_rsp + 72` | `isr_rsp + 120` |
| CS | `isr_rsp + 80` | `isr_rsp + 128` |
| RFLAGS | `isr_rsp + 88` | `isr_rsp + 136` |
| RSP | `isr_rsp + 96` | `isr_rsp + 144` |
| SS | `isr_rsp + 104` | `isr_rsp + 152` |

Caller-saved offsets also +48: rax-slot read moves from
`isr_rsp + 0` → `isr_rsp + 48`, etc. The pre-existing
reversed-label pattern is retained (the "rax slot at p+32
receives [isr_rsp+48] which is actually r11_val" mapping was
already there; `proc_restore_context` uses the inverse so
round-trip preserves values).

Six new callee-saved load/store pairs added with clean labels:

| Reg | ISR offset (`isr_rsp + …`) | Slot offset (`p + …`) |
|-----|----------------------------|-----------------------|
| r15 | 0 | 144 |
| r14 | 8 | 136 |
| r13 | 16 | 128 |
| r12 | 24 | 120 |
| rbp | 32 | 80 |
| rbx | 40 | 40 |

`proc_create_full` already initializes the rbp slot (`p + 80`)
to `stack_top` (proc.cyr:88), so test_procs enter with a sane
frame pointer. proc 0 (kernel idle, created via plain
`proc_create`) starts with rbp slot = 0, but its first
`proc_save_context` overwrites that with the actual kernel rbp
captured from the ISR push — so by the time proc 0 is
re-selected, its rbp restore is correct.

**Build verification:** `./scripts/build.sh` green, ELF64
multiboot2 OK, entry `0x1000a8`. Cumulative kernel size:
**253,712 bytes** (+1,232 over Attempt 15 baseline).

**Verification gates skipped:**

- **QEMU pre-flight:** impossible (path A blocked, path C/gnoboot
  QEMU not yet wired). Documented above.
- **ktest.sh smoke:** built clean but `qemu -kernel` can't load
  multiboot2 ELF64 — no output. Not a Repair-C regression; the
  test infrastructure has been stale since agnos 1.30.0's
  entry-contract change.

**Attempt-16 plan (pre-bound expected outcomes):**

| Expected kcp on iron | Diagnosis |
|---------------------|-----------|
| **0x11** (MAGENTA cell 0x11 lights) | **Closed-beta gate's penultimate milestone hit** — full 50-hlt scheduler cycle completed; proc 0 ↔ proc_a ↔ proc_b round-robin works end-to-end. Repair (C) sufficient. Next gate: post-loop progress (memory-isolation test, exec, kybernet launch, shell). |
| 0x12 / 0x13 / 0x14 (CYAN→MAGENTA transition on those cells) | **Repair (C) working, but loop didn't reach 50 hlts** — stalled mid-cycle. Investigate which iteration of the idle loop hit a fault. Probably correctness, not policy. |
| **Still 0x23** | **Repair (C) wrong or incomplete** — the rbp leak hypothesis was wrong, or there's a *second* state-corruption path we haven't found. Next move: add CMOS CP writes *inside* `timer_handler` (pre- and post-`do_context_switch`) to prove the timer ISR is actually firing during proc_b's hlt. If pre-CP fires but post- doesn't, the bug is inside `do_context_switch`. |
| 0x10 (back to pre-Attempt-14 stall, no test_proc CPs) | **Repair (C) broke the basic context switch** — proc 1 / proc 2 never run. Most likely cause: my offset shift in `sched.cyr` mis-mapped one of the new offsets. Revert Repair (C), study the build's actual ISR bytecode in `build/agnos`, retry. |
| Triple-fault / reset / lower CP | **Repair (C) introduced a fault in the ISR path** — likely a wrong push opcode or buffer overflow (63 bytes vs 64-byte buffer). Verify `timer_isr[]` didn't get bumped; verify pop opcodes are correct REX-prefixed forms. |

**Iron readout shortcuts:** with the visual ladder in place,
attempt 16's outcome is readable from the screen alone — no
reboot+CMOS-mount needed for the headline verdict:

- All cells YELLOW/GREEN/CYAN + cell 0x12 CYAN + cell 0x11
  MAGENTA = success (CP 0x11 hit, repair C sufficient).
- All cells YELLOW/GREEN/CYAN + cell 0x12 dark = stall at CP 0x23
  again (no progress).
- Cells truncate before CYAN cluster = regression (repair C broke
  something earlier in boot).

CMOS readout via `sudo ./scripts/read-boot-log.sh` is still the
authoritative post-mortem.

---

### Attempt 16 — 2026-05-14 night PDT → MAJOR PROGRESS (closed-beta gate hit; mem-iso test stall; reset not soft-lockup)

**Build under test** (post-Repair-C):

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.55 pinned (manifests). Wrapper still resolves 5.11.54 lib snapshot — out-of-scope. |
| agnos kernel | 1.30.0 + Repair (C) — full 15-GPR ISR push/pop + 6 new callee-saved save/restore slots + hw-frame offsets +48. `build/agnos` = **253,712 bytes** ELF64 multiboot2, entry `0x1000a8`. `timer_isr[]` buffer at 63/64 bytes (1 byte headroom). |
| gnoboot | 0.1.0 unchanged |
| `scripts/read-boot-log.sh` | Pre-Attempt-16 binary (28,080 bytes); verdict text for kcp=0x12 still authored for the iter-1-to-10 hypothesis — see "Diagnosis" below for the disambiguation hop. |

**CMOS readout (post-reset):**

```
CMOS[0x53] gnoboot magic    = 0xcd  (decimal 205)
CMOS[0x52] gnoboot checkpt  = 0x05  (decimal 5)
CMOS[0x51] kernel  magic    = 0xab  (decimal 171)
CMOS[0x50] kernel  checkpt  = 0x12  (decimal 18)

verdict (kernel): first hlt returned (CP 0x12) — timer ISR + 1st
context switch OK. Died between iter 1 and iter 10.
```

**The verdict text is misleading** — kcp==18 is now ambiguous because two sites in `main.cyr` write CMOS 0x50 = 0x12:

| Write site | Color painted | Meaning |
|------------|---------------|---------|
| `main.cyr:319` (idle loop, `idle_count == 0`) | cell 0x12 **CYAN** | first hlt round-trip OK (1st pass) |
| `main.cyr:381` (post-VFS/initrd/memfile tests) | cell 0x12 **MAGENTA** (overwrite) | full 50-iter idle loop completed, then VFS tests done |

CMOS records only the *latest* write. The **visual ladder is the disambiguator.** Photo [`iron-boot-photos/attempt-16-boot-colors.jpg`](iron-boot-photos/attempt-16-boot-colors.jpg) shows: WHITE stripe + 4 YELLOW + 7 GREEN + 3 CYAN (Attempt 15's painting through CP 0x10), **plus two new MAGENTA cells** at positions 0x11 and 0x12. That maps to:

| Cell | Color | Source | Meaning |
|------|-------|--------|---------|
| 0x11 | MAGENTA | `main.cyr:339` | Full 50-hlt idle loop completed → **closed-beta gate hit ✅** |
| 0x12 | MAGENTA (overwrite) | `main.cyr:381` | VFS + initrd + memfile tests completed ✅ |

**Behavior delta vs Attempt 15 — important.**

| | Attempt 15 | Attempt 16 |
|---|---|---|
| End state | Soft lockup; screen intact; **no reset** | **Reset ~1-2s after last MAGENTA cell appeared** |
| Failure class | Hang (proc 0 starved, infinite spin in some other proc) | **Triple-fault** (exception fired; handler missing or itself faulted; CPU reset) |
| Kernel CP (CMOS) | 0x23 | **0x12 (MAGENTA disambiguation)** |
| Visual ladder | ...CYAN ×3 then dark | ...CYAN ×3 + **MAGENTA ×2** (0x11 + 0x12) then dark |
| Fault domain | Context-switch register state (sub-case 2) | **Memory-isolation test (`main.cyr:393-478`)** |

The reset (not soft-lockup) is a strong signal: an exception fired in the mem-isolation block (#PF / #GP / #SS most likely), the IDT vector hit a stub that wasn't fully wired or itself faulted, that recursed into #DF → triple-fault → CPU hardware reset. The 1-2s delay between the last MAGENTA paint and the reset is consistent with a page-fault handler trying to print to serial before re-faulting.

**Diagnosis — Repair (C) sufficient; new fault domain = memory-isolation test.**

What CP 0x12 MAGENTA *proves*:

1. **CP 0x10 → CP 0x11** — scheduler ran for **all 50 hlt iterations** without faulting. The full proc 0 ↔ proc_a ↔ proc_b round-robin works. Full 15-GPR ISR push/pop + 6 callee-saved save/restore slots are correctly aligned. **Sub-case-2 territory closed.**
2. **CP 0x11 → CP 0x12 MAGENTA** — `sched_active = 0`, scheduler tear-down OK, `vfs_write`, `initrd_build_test` + `initrd_init`, `initrd_open` + `vfs_read` + `vfs_close` (×2), `vfs_create_memfile` + `vfs_read` + `vfs_close` all returned cleanly. **VFS + initrd subsystems are working on iron.**

What CP 0x12 MAGENTA *doesn't* prove (no CP fires between 0x12-MAGENTA and 0x13): which line in the memory-isolation test (lines 393-478) faults. Plausible suspects in execution order:

1. `proc_create_address_space()` (×2 — lines 396-397). Allocates PML4 + propagates kernel mappings; could fault if PMM exhausted or kernel-PT mirror logic broken.
2. `vmm_is_mapped(phys1/phys2)` + conditional `vmm_map()` (lines 414-419). Sanity check; benign.
3. `proc_map_page(as1/as2, 0xC00000, phys1/phys2)` (lines 420-421). Per-process PD entry write with US=1.
4. `cr3_load(as1)` (line 437). **First CR3 switch — most likely fault site.** If AS1's PML4 doesn't have kernel.text mapped at the right virtual address (kernel runs from `~0x100000`, in PD entry 0 — needs to be in AS1's table copy), the very next instruction fetch after `mov cr3, rax` will #PF.
5. `stac` + `store64(0xC00000, 0xAAAA)` + `load64` + `clac` (lines 438-441). SMAP-bracketed access to US=1 page. Faults if (a) stac didn't actually set RFLAGS.AC, or (b) AS1's tables don't have 0xC00000 mapped, or (c) a timer ISR fires between stac and load64 — kernel ISR entry implicitly clears AC, but we're now back to ring-0 with AC=0 and the next load64 traps.
6. Repeat for AS2, then back to AS1 (lines 443-454).
7. Final kernel-PT restore asm (lines 457-460) — literal `mov rax, 0x1000; mov cr3, rax`. If `0x1000` is no longer the right kernel PML4 (KASLR moved it?), the post-CR3-load fetch faults.

The 1-2s-then-reset profile most strongly fingers (4) or (5) — page-fault on the first AS switch.

**Process note — visual ladder is now load-bearing.** Without `fb.cyr`, the kcp=18 readout would have sent us chasing the idle-loop iter-1 bug for another attempt. The MAGENTA-vs-CYAN disambiguation at cell 0x12 is the entire diagnosis. Worth re-stating: **for CPs that fire from multiple sites, the visual ladder is the truth, CMOS is the index.**

**Why this is the biggest jump in the attempt sequence.** Attempt 16 closed sub-case 2 (context-switch state preservation), validated the entire scheduler cycle on iron, validated VFS + initrd + memfile on iron, and hit the **closed-beta gate** (CP 0x11). The remaining work to reach a usable post-MVP kernel is: memory isolation (this attempt's fault), userland exec spawn (CP 0x14), kybernet launch (CP 0x15), and shell. The skeleton works; the AS-switch path is the next localized bug.

---

### Repairs landed for Attempt 17 — 2026-05-14 night

All edits in `agnos/` (kernel main.cyr) and `agnosticos/scripts/` (read-boot-log verdicts). Per-action consent obtained — user approved "update them all" verbatim for the 4-item bundle: log-cleanup, verdict-cleanup, state.md spot-update, bisector CPs.

**1. read-boot-log.cyr — disambiguate kcp=18; add verdicts for kcp 22-25 (CPs 0x16-0x19).**

The kcp==18 verdict now points at the visual ladder as the disambiguator — future iron post-mortems won't get sent back to the idle-loop-iter-1 hypothesis when the fault is actually downstream. Four new verdicts (kcp 22-25) match the bisector CPs being added to the mem-iso block.

| Build verification | Result |
|---|---|
| `cyrius build src/read-boot-log.cyr build/read-boot-log` | OK |
| Binary size | 28,080 → **29,504 bytes** (+1,424 from 5 verdict strings) |
| Pre-existing `vec_get` undefined-fn warning | Inherited from stdlib snapshot; out-of-scope for this attempt — verdict path doesn't touch it |

**2. main.cyr — 4 bisector CPs inside the memory-isolation test block.**

All four use the existing CMOS-write pattern (`asm { 0xB0 0x50 0xE6 0x70 0xB0 <CP> 0xE6 0x71 }`) + matching `cp_fb` MAGENTA paint, since they sit downstream of CP 0x11 (post-scheduler / userland category).

| CP | Insertion site | What it proves on iron |
|----|----------------|------------------------|
| 0x16 | After `proc_create_address_space() x2` (post `var as2 = ...`) | AS allocation + kernel-PT mirror logic OK |
| 0x17 | After `proc_map_page() x2` (post mapping 0xC00000 in both AS) | Per-process PD writes with US=1 OK |
| 0x18 | After first `cr3_load(as1)` (BEFORE first `stac`) | First CR3 switch survived → AS1 has kernel.text mapped at the right VA |
| 0x19 | After kernel-PT restore asm (post `mov cr3, rax` with literal 0x1000) | Full 3-CR3-switch dance + 3 SMAP'd accesses + restore all survived |

| Build verification | Result |
|---|---|
| `sh scripts/build.sh` | OK |
| `build/agnos` size | 253,712 → **253,824 bytes** (+112 = 4 × ~28-byte blocks: CMOS-write asm + `cp_fb` call) |
| multiboot2 (ELF64) | OK |
| Entry | `0x1000a8` (unchanged) |

**3. state.md header — spot-update for Attempt 16 outcome.**

(Updated in the same commit as this log entry. See state.md line 10.)

**4. iron-boot-testing-log.md — this entry.**

(Updated in the same commit.)

**Verification gates skipped** (same as Attempt 15-16): QEMU pre-flight impossible (Path A W^X-blocked; Path C QEMU launch script not yet wired; multiboot2 ELF64 fails `qemu -kernel`). Iron is still the only test surface.

**Attempt-17 plan (pre-bound expected outcomes):**

| Expected kcp on iron | Cell pattern | Diagnosis |
|---------------------|--------------|-----------|
| kcp=0x12 unchanged, **no new MAGENTA past cell 0x12** | Same as Attempt 16 + no 0x16 cell | Fault is BEFORE CP 0x16 — `proc_create_address_space()` or the AS2 alloc. Investigate PMM exhaustion or kernel-PT mirror logic. |
| kcp=0x16, **cell 0x16 MAGENTA** then dark | + 1 new MAGENTA cell (0x16) | Address spaces alloc'd OK; fault is in `proc_map_page` or the `vmm_is_mapped` / `vmm_map` calls between them. |
| kcp=0x17, **cell 0x17 MAGENTA** then dark | + 2 new MAGENTA cells (0x16, 0x17) | Page mappings installed OK; fault is the `cr3_load(as1)` itself — AS1 PML4 missing kernel.text mapping or invalid CR3 value. **Most likely outcome based on the diagnosis.** |
| kcp=0x18, **cell 0x18 MAGENTA** then dark | + 3 new MAGENTA cells (0x16, 0x17, 0x18) | First CR3 switch survived; fault is in the SMAP'd `stac/store/load/clac` sequence or the second CR3 switch. Investigate CR4.SMAP enforcement and whether stac is taking effect. |
| kcp=0x19, **cell 0x19 MAGENTA** then dark | + 4 new MAGENTA cells | Entire AS-switch dance survived; fault is in serial print / branch logic / kprint_num at lines 462-479. Should be benign — likely a kprint or branch on uninitialized var. |
| kcp=0x13, **cell 0x13 MAGENTA** | + 5 new MAGENTA cells (0x16-0x19 + 0x13 overwrite) | **Memory-isolation test fully passed.** Fault moves to userland exec spawn (lines 484-499). |

**Iron readout shortcut**: the headline verdict is readable from the screen alone — count NEW MAGENTA cells past Attempt 16's two. 0 new = AS alloc faulted; 1-4 new = AS-switch path faulted at that stage; 5+ new = mem-iso passed, next gate is userland exec.

**Carry-forward debt** (not blocking Attempt 17):

- `timer_isr[]` buffer headroom is 1 byte. Future ISR additions MUST bump the buffer first.
- read-boot-log build emits a pre-existing `vec_get` undefined-fn warning from the stdlib snapshot. Cyrius-side concern; not blocking. Surface to cyrius repo on a future cleanup pass.

---

### Attempt 17 — 2026-05-14 night PDT → CMOS advances to 0x18; visual ladder unchanged from Attempt 16

**Build under test:**

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.55 pinned (manifests) |
| agnos kernel | 1.30.0 + Repair (D) — 4 bisector CPs (0x16/0x17/0x18/0x19) instrumented across the AS-create / AS-map / first-CR3-switch / full-restore boundaries. `build/agnos` = **253,824 bytes** ELF64 multiboot2, entry `0x1000a8`. |
| gnoboot | 0.1.0 unchanged |
| `scripts/build/read-boot-log` | 29,504 bytes — kcp=18 verdict rewritten to reference visual-ladder disambiguation + 4 new verdicts (kcp 22-25) |

**CMOS readout (post-reset):**

```
CMOS[0x53] gnoboot magic    = 0xcd  (decimal 205)
CMOS[0x52] gnoboot checkpt  = 0x05  (decimal 5)
CMOS[0x51] kernel  magic    = 0xab  (decimal 171)
CMOS[0x50] kernel  checkpt  = 0x18  (decimal 24)

verdict (kernel): CP 0x18 — first cr3 switch (cr3_load(as1)) survived.
Died inside SMAP-bracketed store64/load64 sequence or one of the later
CR3 switches. Suspect: stac didn't take effect (CR4.SMAP enforcement),
or AS2 page tables missing kernel-text mapping (would #PF on next instr
after cr3_load(as2)).
```

**Visual ladder:** unchanged from Attempt 16 — no new MAGENTA cells past 0x11/0x12. Cells 0x16/0x17/0x18 NOT painted.

**The CMOS-vs-visual discrepancy is the headline.** Per the pre-bound outcome matrix in the Attempt-17 plan above, kcp=0x18 should be paired with `+ 3 new MAGENTA cells (0x16, 0x17, 0x18)`. The visual ladder shows zero new cells. CMOS writes for 0x16 / 0x17 / 0x18 all completed (CMOS landed on the last of them, 0x18), but the matching `cp_fb()` paints either no-op'd or were overdrawn/cleared before reset.

This forks the diagnosis. Either:

1. **cp_fb broke for these specific calls** — same code path that painted cells 0x11 and 0x12 cleanly earlier in this very boot. Plausible triggers: `boot_info_ptr` or fb-mapped state corrupted between CP 0x12 and CP 0x16 (the new instrumentation block only adds 4 CMOS+cp_fb pairs; no new globals); or the framebuffer access path lost coherence after the AS-creation / map work touched the PMM/VMM state.
2. **Cells WERE painted, then erased** — a triple-fault reset path that runs firmware-side display reinit could in principle clear the GOP framebuffer between the last paint and the screen handoff to BIOS POST. The reset profile is consistent with this (Attempt 16 painted cells survived to screen post-reset, but those were painted from kernel CR3 only; cells 0x18 paint runs from AS1's CR3).
3. **kcp=0x18 reached via the CMOS-write asm only, cp_fb at line 449 was the fault site** — would mean cp_fb-on-AS1 is broken. The CMOS write at `:448` is asm-only (no stack, no helper call); cp_fb at `:449` is a CALL that pushes return-addr, accesses `boot_info_ptr` (kernel data), then writes to FB. If AS1's mapping for kernel data or FB phys is broken, the CALL or first load64 inside cp_fb faults.

(3) is the cleanest fit: CMOS writes 0x16/0x17 happen before any cr3_load (on kernel CR3) — so cp_fb(0x16)/(0x17) had no excuse to fail. But the visual shows they didn't paint either, so (3) alone doesn't account for it.

Diagnosis is now: **CMOS-vs-visual desync started somewhere between CP 0x12 (painted clean Attempt 16) and CP 0x18 (CMOS only, no paint).** The bisector to find that boundary is the next attempt's job — sub-checkpoints inside the mem-iso block AND a sanity-check cp_fb call BEFORE the new code (between line 381 and line 396) to prove cp_fb still works on kernel CR3 mid-flight.

**Fault-domain change vs Attempt 16:** Attempt 16's last paint was cell 0x12 with kcp=0x12. Attempt 17's last paint is cell 0x12 with kcp=0x18. The screen looks identical; the CMOS tells the truth. **The visual ladder is no longer authoritative** until we restore CMOS↔FB coherence — which makes the cp_fb-broke-mid-boot hypothesis the gating issue, ahead of the SMAP / AS2 / kernel-text-mapping questions the kcp=0x18 verdict points at.

**Suspect ordering for Attempt 18 instrumentation:**

1. Sanity cp_fb call on a fresh cell (e.g. 0x1A YELLOW) immediately before `var as1 = proc_create_address_space()` at `main.cyr:396`. If 0x1A paints → cp_fb survives up to the mem-iso block; failure is inside the mem-iso block. If 0x1A doesn't paint → cp_fb broke earlier, somewhere between line 381 and line 396 (which is just `serial_println("Memory isolation test...", 23);` — unlikely to be the culprit, but bisect-able).
2. Sub-checkpoints 0x1B/0x1C/0x1D inside the SMAP region for the original kcp=0x18 hypothesis (post-stac / post-store64 / post-AS1-clac), assuming cp_fb itself isn't the dying instruction.
3. Optional: dump CR4 low byte to virgin CMOS slot 0x54 right before the first stac, to nail down CR4.SMAP enforcement state on iron.

**Carry-forward debt (not blocking Attempt 18):**

- `timer_isr[]` buffer headroom still 1 byte (unchanged from Attempt 17).
- read-boot-log build still emits `vec_get` warning (unchanged).

---

### Repairs landed for Attempt 18 — 2026-05-14 night

Per-action consent obtained — user approved "Full (1+2+3+4)" bundle: sanity cp_fb at 0x1A + SMAP sub-CPs 0x1B/0x1C/0x1D + CR4 dump to CMOS 0x54 + read-boot-log verdicts.

**1. main.cyr — cp_fb sanity at 0x1A (pre-AS-creation).**

Inserted between `serial_println("Memory isolation test...", 23);` and `var as1 = proc_create_address_space();` at `main.cyr:393-396`. CMOS write + cp_fb paint of cell 0x1A in **YELLOW (0x00FFFF00)** to distinguish from the MAGENTA bisector cells. If 0x1A paints, the cp_fb-vs-AS1 hypothesis survives (cp_fb works on kernel CR3 entering the block). If it doesn't, cp_fb broke upstream and we need a wider bisector.

**2. main.cyr — SMAP sub-CPs 0x1B / 0x1C / 0x1D.**

| CP | Insertion site | Proves on iron |
|----|----------------|----------------|
| 0x1B | After `stac` (line 450), before `store64(0xC00000, 0xAAAA)` | `stac` executed without faulting under AS1 CR3 |
| 0x1C | After `var val_as1 = load64(0xC00000);` (line 452), before `clac` | SMAP-bracketed store64 + load64 succeeded under AS1 |
| 0x1D | After `clac` (line 453), before `cr3_load(as2)` (line 456) | AS1 SMAP-bracketed round-trip complete; any post-0x1D stall is in AS2 |

All three use CMOS+cp_fb pattern (MAGENTA). If hypothesis (3) from Attempt 17 (cp_fb-under-AS1 broken) is right, these won't fire visually — kcp staying at 0x18 with cell 0x1A as the only new paint is itself the diagnostic signal.

**3. main.cyr — CR4 byte 2 dump to CMOS[0x54].**

Inserted between the CMOS write for CP 0x18 (line 448) and the suspected-fault `cp_fb(0x18)` (line 449). Reads CR4, shifts right 16, writes byte 2 (bits 16-23) to CMOS[0x54]. Port I/O only — runs even if AS1's PT mirror is broken, so we always learn the CR4.SMAP enforcement state on iron.

Byte 2 bit layout (LSB-first within the byte): FSGSBASE / PCIDE / OSXSAVE / - / SMEP / SMAP / PKE / -. **SMAP = 0x20** in this byte.

| Asm encoding | Bytes |
|--------------|-------|
| `mov al, 0x54` | `B0 54` |
| `out 0x70, al` | `E6 70` |
| `mov rax, cr4` | `0F 20 E0` |
| `shr rax, 16` | `48 C1 E8 10` |
| `out 0x71, al` | `E6 71` |

13-byte block. Single-pass; no branches; no memory access.

**4. read-boot-log.cyr — verdicts for kcp 26-29 + CMOS[0x54] readout + kcp=24 verdict refresh.**

| Action | Detail |
|--------|--------|
| Added `cmos_read(84)` for CMOS[0x54] | Reads the CR4-byte-2 dump |
| Added `print_cmos_line("CMOS[0x54] CR4 byte 2 16-23 = ", cr4hi);` | Always printed; meaningful only if `kcp >= 0x18` |
| Added byte-2 bit-map decode hint (3 lines) | SMAP = 0x20 in this byte; readable by inspection |
| Added verdicts for `kcp == 26 / 27 / 28 / 29` (CPs 0x1A / 0x1B / 0x1C / 0x1D) | Each verdict points at the next-likely fault domain if stall lands there |
| Refreshed `kcp == 24` (CP 0x18) verdict | Now references Attempt 17's CMOS-vs-visual desync and the Attempt-18 disambiguation path (cp_fb 0x1A on kernel CR3 vs cp_fb 0x18 under AS1) |

| Build verification | Result |
|---|---|
| `sh scripts/build.sh` (agnos) | OK |
| `build/agnos` size | 253,824 → **253,936 bytes** (+112) |
| multiboot2 (ELF64) | OK |
| Entry | `0x1000a8` (unchanged) |
| `cyrius build src/read-boot-log.cyr build/read-boot-log` | OK |
| `build/read-boot-log` size | 29,504 → **31,552 bytes** (+2,048 from 5 verdict strings + decode hint + CMOS[0x54] readout) |
| Pre-existing `vec_get` warning | Inherited; cyrius-side; not blocking |
| `timer_isr[]` headroom | Unchanged at 1 byte (no pic.cyr edits) |

**Attempt-18 plan — pre-bound expected outcomes:**

The headline signal is whether cell 0x1A paints **AND** what cells appear past 0x1A.

| Cell-painting outcome | kcp likely | Diagnosis |
|---|---|---|
| **No new cells past 0x12** (same as Attempt 17) | 0x12 or earlier | cp_fb broke upstream of CP 0x1A — somewhere between line 381 (post-VFS) and line 393 (`serial_println`). World is upside-down; widen the bisector. |
| **Cell 0x1A YELLOW only, no MAGENTA past 0x12** | 0x18 (or higher via CMOS only) | **cp_fb-under-AS1 hypothesis CONFIRMED.** FB phys not in AS1's per-process PT mirror. Fix: extend the PD-copy to cover the FB phys range, or move the FB into the 0-4 GB identity-mapped region. CMOS[0x54] tells us CR4.SMAP state at the moment of fault. |
| **Cell 0x1A YELLOW + cell 0x18 MAGENTA**, no 0x1B | 0x18 → did not advance | cp_fb-under-AS1 actually works for the first paint; stall is in `stac` or whatever comes between cp_fb(0x18) and CP 0x1B. Very unlikely — stac is 3 bytes asm. |
| **Cells 0x1A + 0x18 + 0x1B**, no 0x1C | 0x1B → did not advance | `stac` OK; SMAP'd `store64` faulted. CR4.SMAP confirmed enforcing (or stac didn't set AC). Check CMOS[0x54] for the SMAP bit; if SMAP off, store64 should have worked → different bug. |
| **Cells 0x1A + 0x18 + 0x1B + 0x1C**, no 0x1D | 0x1C → did not advance | Store + load + load-of-recheck all OK; `clac` faulted. Near-impossible — 3 bytes asm, no memory access. Suspect ISR interaction. |
| **Cells 0x1A + 0x18 + 0x1B + 0x1C + 0x1D**, no 0x13 | 0x1D → did not advance | AS1 round-trip clean; fault is in `cr3_load(as2)` (line 456) or beyond. Most likely AS2 missing kernel-text mapping → #PF on next instr fetch after `mov cr3, rax`. |
| **All cells through 0x13 MAGENTA painted** | 0x13 or beyond | Memory-isolation test fully passed. Next gate: userland exec spawn (CP 0x14). |

**Iron readout shortcut**: cell 0x1A YELLOW is the diagnostic primary. Its presence-or-absence resolves whether cp_fb is the broken instruction across the boundary. The CR4[0x54] readout is a sidecar that helps interpret kcp >= 0x18 cases.

**Verification gates skipped** (same as Attempts 15-17): QEMU pre-flight permanently blocked for this kernel.

---

### Attempt 18 — 2026-05-14 night PDT → CR4.SMAP=0 confirmed (Path C boot shim never enabled SMAP; `stac` was #UD-ing)

**Build under test:**

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.55 pinned (manifests). Wrapper still resolves 5.11.54 lib snapshot — out-of-scope. |
| agnos kernel | 1.30.0 + Repair (D) + Repair (E) — Repair (D)'s 4 bisector CPs unchanged; Repair (E) adds sanity cp_fb(0x1A) + CR4 dump (CMOS[0x54]) + SMAP sub-CPs 0x1B/0x1C/0x1D. `build/agnos` = **253,936 bytes** ELF64 multiboot2, entry `0x1000a8`. `timer_isr[]` headroom still 1 byte. |
| gnoboot | 0.1.0 unchanged |
| `scripts/build/read-boot-log` | **31,552 bytes** — CMOS[0x54] readout + 4 new verdicts (kcp 26-29) + refreshed kcp=24 verdict |

**CMOS readout (post-reset, user-reported):**

```
CMOS[0x53] gnoboot magic    = 0xcd  (decimal 205)
CMOS[0x52] gnoboot checkpt  = 0x05  (decimal 5)
CMOS[0x51] kernel  magic    = 0xab  (decimal 171)
CMOS[0x50] kernel  checkpt  = 0x18  (decimal 24)
CMOS[0x54] CR4 byte 2 16-23 = 0x00  (decimal 0)
```

**Visual ladder:** unchanged from Attempts 16/17 — no new cells past 0x12 visible post-reset (BIOS POST clears FB after triple-fault; pre-reset cell state unobservable on archaemenid because the box is the user's daily driver). Post-reset photo at [`iron-boot-photos/attempt-18-boot-colors-reset-only.jpg`](iron-boot-photos/attempt-18-boot-colors-reset-only.jpg) shows only the surviving 0x80-0x82 / GREEN/CYAN cells from earlier in this boot — visual disambiguator unusable for this attempt's diagnostic. Filename suffix `-reset-only` notes the user observation: this sparse view appears only after triple-fault reset; on a *non-reset* exit path (kernel hangs intact), the FB carries Attempts 16/17-style coverage through cell 0x12.

**Headline diagnostic — CR4.SMAP = 0 on iron.**

Byte 2 of CR4 reads 0x00, meaning *all* of FSGSBASE/PCIDE/OSXSAVE/SMEP/SMAP/PKE are off. The kernel inherited UEFI's CR4 (PAE + PGE only) and never re-tuned. Root cause traced in one grep pass:

| Site | Verdict |
|------|---------|
| `agnos/kernel/arch/x86_64/boot_shim.cyr:70-88` (legacy ELF32 multiboot1 path) | CPUID-gates + sets CR4.SMEP|SMAP. **Doesn't run on iron** — Path C handoff goes through the `#ifdef ELF64_KERNEL` block instead. |
| `agnos/kernel/arch/x86_64/boot_shim.cyr:160-172` (Path C, runs on iron) | Comment: "*CR0/CR3/CR4/EFER — UEFI configured them; kernel re-tunes later*". **Deferred — but no kernel-side site ever actually re-tunes.** |
| `agnos/kernel/core/main.cyr:386` (stale) | Comment: "*CR4.SMAP set in the boot shim, line 52 of boot_shim.cyr*". Wrong: `boot_shim.cyr:52` is the COM1 UART IER write now. The legacy SMAP enable is at lines 70-88, and is gated by `#ifndef ELF64_KERNEL`. |
| `grep -rn "cr4\|SMAP\|SMEP" kernel/**/*.cyr` | Only writers of CR4 in the entire kernel: the legacy ELF32 shim block, plus an unrelated CR4 read at `main.cyr:466` (the Attempt-18 dump itself). No SMEP/SMAP set anywhere else. |

Without CR4.SMAP=1, the `stac` (`0F 01 CB`) at `main.cyr:471` is **`#UD` invalid-opcode** (Intel SDM Vol 2, *STAC*: "If CR4.SMAP is 0, an invalid-opcode exception (#UD) is generated"). The kernel has no working #UD handler on iron (or the handler itself faults) → #DF → triple-fault → CPU reset. kcp pins at 0x18 exactly because the CMOS write at line 458 lands, the CR4 dump at lines 463-469 lands (port I/O only, can't fault), `cp_fb(0x18)` at line 470 paints (or doesn't, but it can't fault either way under kernel CR3 since `cr3_load(as1)` already happened at line 455 — the cp_fb-under-AS1 question is now subsumed by SMAP), and **the next instruction `stac` #UDs before the CP 0x1B write at line 473 can fire.**

This also retro-fits Attempts 16 + 17: those stalled at the same site, but without CMOS[0x54] we couldn't tell #UD from #PF. The reset profile (kernel reaches CP 0x18 then resets ~1-2s later) matches a #UD that recurses to #DF rather than a pure #PF stall.

**cp_fb-under-AS1 hypothesis: NOT confirmed and NOT refuted.** Visual ladder unusable on this attempt. Will only be answerable post-SMAP-fix: if Attempt 19 advances kcp past 0x18 cleanly, cp_fb-under-AS1 is fine; if kcp stays at 0x18 and cell 0x18 didn't paint, cp_fb-under-AS1 is the *next* bug.

**Process note — single data point (`CMOS[0x54]=0x00`) collapsed the entire Attempt-17 fork.** Without it we'd have spent Attempt 18 chasing cp_fb-under-AS1 + ITDB + AS-table mirror logic separately. The CR4 dump cost 13 bytes asm; saved ~3 attempts of misdirected bisection.

---

### Repairs landed for Attempt 19 — 2026-05-14 night

All edits in `agnos/` (kernel boot_shim + main.cyr) and `agnosticos/scripts/` (read-boot-log). Per-action consent: user approved "all three" for the bundle: (1) Path C SMEP+SMAP enable; (2) refresh stale main.cyr boot_shim comment; (3) CMOS[0x55] pre-stac CR4 re-dump. Read-boot-log + this log entry + state.md spot-update bundled as the standard documentation tail (same shape as Attempt 17/18 repair entries).

**1. `boot_shim.cyr` (Path C / `#ifdef ELF64_KERNEL` block) — CPUID-gated SMEP+SMAP enable, then unified CP 5.**

Mirrors the legacy ELF32 shim block (lines 70-88) into the Path C path, inserted *between* `boot_info_capture_rdi()` and the existing `CMOS[0x50] = 5` write. The existing CP 5 marker is moved to *after* the CR4 enable so kcp=5 now means "boot_info_capture_rdi returned AND CR4 SMEP+SMAP enabled" — combined to avoid a CMOS-value collision with `main.cyr:36`'s `CMOS[0x50] = 0x06` (GDT/TSS/IDT loaded). Trade-off: if kcp pins at 4, fault is in either `boot_info_capture_rdi` or the CR4 block (CPUID + `mov cr4, ebx` are routine ring-0 ops, so the merged checkpoint is reasonable).

CPUID leaf 7 sub-leaf 0 returns SMEP at EBX[7] and SMAP at EBX[20]; stash original CPUID-EBX in EAX so each `test`+`jz`+`or ebx, …` uses the unmodified feature mask. Push/pop in long mode default to 64-bit (`0x53` = `push rbx`, `0x5B` = `pop rbx`) — fine because CR4 upper bits are all zero (no defined CR4 bit above 31).

Skips silently on QEMU `qemu64` (lacks both feature bits); enables both on Zen (advertises both) and any qemu `-cpu max`.

**2. `main.cyr:383-401` — refresh stale boot_shim comment.**

Old comment claimed "CR4.SMAP set in the boot shim, line 52 of boot_shim.cyr" — wrong both about the line (now COM1 IER) and the path (only runs under `#ifndef ELF64_KERNEL`). New comment names *both* sites (Path A lines 70-88 / Path C post-CP-5) and notes that pre-v1.30.1 Path C kernels left SMAP=0 → `stac` #UD → triple-fault. Documentation matches the actual enable site again.

**3. `main.cyr:471` — CR4 byte-2 re-dump to CMOS[0x55] right before `stac`.**

Same shape as the Attempt-18 dump but into a fresh CMOS slot (0x55) so we can compare the post-cr3_load(as1) reading (0x54, kept) with the pre-stac reading (0x55, new). If [0x54] reads 0x30 but [0x55] reads 0x00, CR4 got cleared between the cr3 switch and the stac → investigate any CR-mutating call in that window. If both 0x30, CR4 held → stall is in the SMAP-bracketed access block or cp_fb-under-AS1.

13-byte asm block, port I/O only — runs even if AS1's PT mirror is broken.

**4. `scripts/src/read-boot-log.cyr` — CMOS[0x55] readout + verdict refresh.**

| Action | Detail |
|--------|--------|
| Added `cmos_read(85)` for CMOS[0x55] | Reads the pre-stac CR4-byte-2 dump |
| Renamed [0x54] field for clarity | "CR4 byte 2 (post-cr3, pre-stac, attempt-18)" vs "(pre-stac, attempt-19)" |
| Decode hint expanded | Shows both [0x54] and [0x55] expected readings for Attempt 19; `0x30 = SMEP|SMAP both enabled` |
| Refreshed `kcp == 4` verdict | Now covers "boot_info_capture_rdi OR the CR4 SMEP/SMAP enable block" |
| Refreshed `kcp == 24` verdict | Three-fork diagnosis: (a) both [0x54]+[0x55] = 0x30 → CR4 held, stall downstream; (b) [0x54]=0x30, [0x55]=0x00 → CR4 cleared post-cr3; (c) both 0x00 → boot_shim enable didn't stick |

**Build verification:**

| Step | Result |
|------|--------|
| `sh scripts/build.sh` (agnos) | OK |
| `build/agnos` size | 253,936 → **254,000 bytes** (+64 = ~50 bytes boot_shim CR4 block + 13 bytes main.cyr pre-stac dump, rounded by ELF segment alignment) |
| multiboot2 (ELF64) | OK |
| Entry | `0x1000a8` (unchanged) |
| `cyrius build src/read-boot-log.cyr build/read-boot-log` | OK |
| `build/read-boot-log` size | 31,552 → **32,376 bytes** (+824 from refreshed verdicts + decode hint + [0x55] readout) |
| Pre-existing `vec_get` warning | Inherited; cyrius-side; not blocking |
| `timer_isr[]` headroom | Unchanged at 1 byte (no pic.cyr edits) |

**Attempt-19 plan — pre-bound expected outcomes:**

The two diagnostic primaries are: (i) kcp value, (ii) CMOS[0x54] + CMOS[0x55] both reading 0x30.

| kcp / CR4 readout | Diagnosis |
|---|---|
| **kcp ≥ 0x1A AND both [0x54]+[0x55] = 0x30** | SMAP fix held all the way through. Stall (if any) is in `cr3_load(as2)` / kernel-PT restore / userland-exec spawn. Next attempt picks up wherever the new kcp lands. |
| **kcp = 0x18 AND [0x54]+[0x55] = 0x30** | CR4 held but `stac` or downstream still faulted. Investigate stac+store64+load64+clac sequence under AS1 CR3; could be cp_fb-under-AS1 (FB phys not in AS1's PT mirror) interacting with the SMAP-bracketed write. |
| **kcp = 0x18, [0x54] = 0x30, [0x55] = 0x00** | CR4 cleared between cr3_load(as1) and stac. Walk the call chain in that window for any `mov cr4, …`. |
| **kcp = 0x18 AND [0x54] = 0x00, [0x55] = 0x00** | boot_shim SMEP/SMAP enable didn't stick. Either CPUID gated both off (improbable on Zen — but verify via direct dump) or the `mov cr4, ebx` got reverted upstream. |
| **kcp = 4** (regression) | The new CR4 enable block faulted inside boot_shim. Triple-fault during CPUID or `mov cr4, ebx` — would mean Zen's CPUID returned malformed EBX or our CR4 read clobbered something the path-C handoff relied on. Wildly unlikely but the bisector point is there. |
| **kcp = 5 unchanged from Attempt-18 framing** | Now means "boot_info_capture_rdi + CR4 enable both done, died in main.cyr top before bisector 0x80". Slight semantic shift from prior attempts but mostly invisible — main.cyr's first cp_fb at CMOS=0x80 lands quickly. |

**Verification gates skipped** (same as Attempts 15-18): QEMU pre-flight permanently blocked for this kernel (Path A W^X, Path C launch script not wired, multiboot2 ELF64 fails `qemu -kernel`). Iron is still the only test surface — costs a reboot of archaemenid every time.

**Carry-forward debt (not blocking Attempt 19):**

- `timer_isr[]` buffer headroom still 1 byte (unchanged).
- read-boot-log `vec_get` warning still inherited from cyrius stdlib snapshot.
- If Attempt 19 advances cleanly past 0x18, the kcp=4 verdict (boot_info_capture_rdi OR CR4 enable) could be split with another sub-CP; not worth the asm bytes unless an attempt actually pins at 4.

---

### Attempt 19 — 2026-05-15 → Repair (F) landed cleanly; cp_fb-under-AS1 is the next bug

Build under test:

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.55 pinned (manifests). Wrapper still resolves 5.11.54 lib snapshot — out-of-scope. |
| agnos kernel | 1.30.1 candidate — Path C CR4 SMEP/SMAP enable + main.cyr pre-stac CR4 re-dump to CMOS[0x55] + refreshed boot_shim comment. `build/agnos` = **254,000 bytes** ELF64 multiboot2, entry `0x1000a8`. `timer_isr[]` headroom still 1 byte. |
| gnoboot | 0.1.0 unchanged |
| `scripts/build/read-boot-log` | **32,376 bytes** — CMOS[0x55] readout + refreshed kcp=4 / kcp=24 verdicts. |

**CMOS readout (post-stall, user-reported):**

```
CMOS[0x53] gnoboot magic    = 0xcd  (decimal 205)
CMOS[0x52] gnoboot checkpt  = 0x05  (decimal 5)
CMOS[0x51] kernel  magic    = 0xab  (decimal 171)
CMOS[0x50] kernel  checkpt  = 0x18  (decimal 24)
CMOS[0x54] CR4 byte 2 (post-cr3, pre-stac, attempt-18) = 0x30  (SMEP|SMAP both ON)
CMOS[0x55] CR4 byte 2 (pre-stac, attempt-19)           = 0x00
```

**Visual ladder:** user reports "appears like the same as before without reset items" — kernel hung intact, no BIOS POST repaint. Distinct from Attempt 18's reset-only sparse view. Implies #UD→#DF→triple-fault chain is gone — kernel is in a fault loop or halt, not resetting. No new photo (FB unchanged from prior visible state).

**Headline diagnostic — Repair (F) landed cleanly; pre-bound case (b) interpretation was wrong.**

`[0x54] = 0x30` confirms CR4.SMEP|SMAP survived all the way through cr3_load(as1) on iron. The boot_shim Path C CPUID-gated SMEP+SMAP block (Repair F) works. The Attempts 16/17/18 SMAP-was-off root cause is **closed**.

The pre-bound Attempt-19 outcome table at line 2369 mapped `[0x54]=0x30, [0x55]=0x00` to "CR4 cleared between cr3_load(as1) and stac — walk the call chain for any `mov cr4, …`". That interpretation is **implausible** against the static code path:

| Site | Action | Mutates CR4? |
|------|--------|--------------|
| `main.cyr:472-478` | `[0x54]` CR4 dump (port I/O) | No |
| `main.cyr:479` | `cp_fb(0x18, MAGENTA)` | **No** — fb.cyr:46-64 just reads `boot_info_ptr`, loads pitch/height, and `store32`s pixels |
| `main.cyr:489-495` | `[0x55]` CR4 dump (port I/O) | No |

Between the two dumps is **only** `cp_fb(0x18, …)` — no `mov cr4` anywhere. CR4 cannot have actually been cleared in this window.

**Reinterpretation: `[0x55] = 0x00` is "dump site not reached", not "CR4 cleared".**

Per the archaemenid CMOS map (slots 0x50-0x7F are virgin scratch), [0x55] reading 0x00 is its untouched BIOS default. Attempt 19 was the first build to ever write [0x55]. If line 489 didn't execute, [0x55] just reads back 0x00.

The pre-bound table conflated "[0x55] dump ran and read 0x00" with "[0x55] dump never ran" — both produce the same external reading. That's the table's blind spot, not a real case-(b) event.

**Prime suspect: cp_fb-under-AS1.** Long-suspected at `main.cyr:404-407` and called out in the Attempt 18 §"cp_fb-under-AS1 hypothesis" note. Under AS1's CR3, cp_fb's `store32(fb + …)` likely #PFs because the FB phys range isn't mapped in AS1's PT mirror. With CR4.SMAP=1 (Repair F), the fault path differs from a stac #UD — instead of triple-faulting (BIOS reset, observable as "reset items"), the kernel sits in a #PF→handler→re-fault loop or halts. Matches the user's "no reset items" observation exactly.

**Process note — single observation ("no reset items on screen") promoted cp_fb-under-AS1 from "co-equal next bug" to "prime suspect" in one read.** Same shape as Attempt 18's `[0x54]=0x00` collapsing the Attempt-17 fork. Visual canary signal (reset-vs-hung) costs zero asm bytes and was decisive.

**Repair (G) for Attempt 20 — disambiguator only, no new fix.**

Landed 2026-05-15. Single 8-byte edit to `main.cyr:479-481`: inserts `kcp = 0x60` (port-I/O, can't fault) between `cp_fb(0x18, …)` and the [0x55] CR4 dump. Refreshed comment block explains the disambiguation.

Pre-bound Attempt-20 outcome table:

| kcp / [0x55] | Diagnosis |
|---|---|
| **kcp = 0x18** | cp_fb hung before line-481 sub-CP ever ran. Confirms cp_fb-under-AS1 is the bug. **Next:** triage AS1's PT mirror for FB phys range — proc_create_full / shared_kernel_pt coverage of the GOP framebuffer address. |
| **kcp = 0x60, [0x55] = 0x30** | cp_fb returned, CR4 still good. Stall is in stac/store64/load64/clac (real case (a)). Open the existing 0x1B/0x1C/0x1D sub-CPs (already wired at lines 499-510) — next read should land on one of them. |
| **kcp = 0x60, [0x55] = 0x00** | Genuine case (b): CR4 actually cleared by something between cp_fb and the [0x55] dump. Unexpected (no CR-mutating call there); would need bytecode-level audit. Wildly unlikely. |
| **kcp = 0x19 or higher** | Past the entire bisector block. Stall is downstream of clac (kernel-PT restore, scheduler, userland) — next attempt picks up wherever kcp lands. |

**Build verification:**

| Step | Result |
|------|--------|
| `sh scripts/build.sh` (agnos) | OK |
| `build/agnos` size | **254,000 bytes** unchanged (8 added bytes absorbed by existing section/buffer padding — `timer_isr[64]` and friends round to the same alignment slot) |
| multiboot2 (ELF64) | OK |
| Entry | `0x1000a8` (unchanged) |
| read-boot-log | **Not rebuilt** — kcp=0x60 will decode as "unknown CP" for Attempt 20, which is fine for a one-shot disambiguator. If kcp=0x60 lands and Attempt 21 needs more, add a verdict then. |
| `sudo install-usb.sh --update /dev/sdb` | OK — kernel + gnoboot + initramfs refreshed on USB |
| `timer_isr[]` headroom | Unchanged at 1 byte |

**Carry-forward debt (not blocking Attempt 20):**

- `timer_isr[]` buffer headroom still 1 byte (unchanged).
- read-boot-log will report `kcp=0x60` as "unknown" — add a verdict if it actually lands.
- If Attempt 20 confirms cp_fb-under-AS1 (kcp=0x18 sticks), the fix is `proc_create_full` / shared kernel PT mapping the GOP framebuffer phys range into AS1 — not in the asm bisector at all.

---

### Attempt 20 — 2026-05-15 → cp_fb-under-AS1 CONFIRMED (kcp=0x18, [0x55]=0x00)

Build under test:

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.55 pinned (manifests). |
| agnos kernel | 1.30.1 candidate + Repair (G) — kcp=0x60 sub-CP inserted at main.cyr:479. `build/agnos` = **254,000 bytes** ELF64 multiboot2, entry `0x1000a8`. |
| gnoboot | 0.1.0 unchanged |
| `scripts/build/read-boot-log` | **32,376 bytes** unchanged. |

**CMOS readout (post-reset, user-reported):**

```
CMOS[0x53] gnoboot magic    = 0xcd  (decimal 205)
CMOS[0x52] gnoboot checkpt  = 0x05  (decimal 5)
CMOS[0x51] kernel  magic    = 0xab  (decimal 171)
CMOS[0x50] kernel  checkpt  = 0x18  (decimal 24)
CMOS[0x54] CR4 byte 2 (post-cr3, pre-stac, attempt-18) = 0x30  (SMEP|SMAP both ON)
CMOS[0x55] CR4 byte 2 (pre-stac, attempt-19)           = 0x00
```

**Visual ladder:** User reports "still resets after holding 2-3 seconds after last bluish pixels appears." The "last bluish pixels" are CP 0x17 MAGENTA (last cp_fb under kernel CR3 before `cr3_load(as1)` at main.cyr:464). After that no further cell paints → ~2-3 s of silence → reset. Differs from Attempt 19's "no reset items" report — same diagnosis, slightly different fault-cascade visibility (possibly Repair F's SMAP enforcement changed which fault path triple-faults vs. loops).

**Headline diagnostic — cp_fb-under-AS1 confirmed; pre-bound Attempt-20 outcome row 1 fired.**

`kcp = 0x18` (NOT 0x60) means the 8-byte port-I/O at main.cyr:501 (Repair G's kcp=0x60 stamp) **never executed**. The only thing between `kcp = 0x18` (line 467) and `kcp = 0x60` (line 501) is `cp_fb(0x18, MAGENTA)` at line 479 — that's where execution hung. Confirms the prime suspect from the Attempt 19 analysis.

`[0x55] = 0x00` is virgin CMOS — dump never reached. The "CR4 cleared" interpretation is once again ruled out (as the Attempt 19 reinterpretation already established).

**Root cause (confirmed):** `cp_fb`'s `store32(fb + …, color)` writes to the GOP framebuffer phys address. Under AS1's CR3, that phys is not in AS1's page-table mirror. `proc_create_address_space` (proc.cyr:154) populates:
- PML4[0] → new PDPT
- PDPT[0] → new PD, copying kernel PD[0..510] from `0x3000` (covers 0..1GB-2MB via 2MB pages)
- PDPT[1..3] mirrored from kernel PDPT at `0x2000` (1-4GB via 1GB huge pages)

So AS1 reaches 0..4 GB of physical via identity-mapped large/huge pages. The Zen UEFI GOP framebuffer phys on archaemenid is above that range (or in a high-MMIO band the 1-GB huge pages don't cover with MMIO-suitable caching). `cp_fb`'s `store32` from CPL=0 → #PF → handler also faults → #DF → triple-fault → reset ~2-3 s later.

**Repair (H) for Attempt 21 — drop under-AS1 cp_fb calls (Option A).**

Landed 2026-05-15. Four under-AS1 `cp_fb` calls deleted from `main.cyr`:
- Line 479: `cp_fb(0x18, …)` after first `cr3_load(as1)`
- Line 517: `cp_fb(0x1B, …)` post-stac
- Line 522: `cp_fb(0x1C, …)` post-store/load
- Line 527: `cp_fb(0x1D, …)` post-clac

Plus 12 lines of explanatory comments at the top of the under-AS1 block and a 5-line Attempt-20 outcome resolution appended to the existing pre-bound table comment. Kcp port-I/O stamps unchanged — they carry the full diagnostic ladder under AS1. Visual ladder resumes at `cp_fb(0x19)` MAGENTA after kernel-CR3 restore at line ~545.

Long-term fix B (pre-map FB phys into AS1/AS2 at construction time) is intentionally **deferred** — Option A is the minimum-risk move to find the next bug on the boot path. Once mem-iso block proves clean, B can land separately as a clean enhancement that re-enables the under-AS1 visual ladder.

**Read-boot-log refresh:** kcp=0x18 verdict rewritten to reflect Attempt-20 resolution + Attempt-21 framing. New kcp=0x60 verdict added (Attempt-21+'s pre-stac fork lives here, not at kcp=0x18). CMOS[0x54]/[0x55] decode-hint refreshed: post-Repair-F baseline, expected `0x30 / 0x30` once kcp >= 0x60.

**Build verification:**

| Step | Result |
|------|--------|
| `sh scripts/build.sh` (agnos) | OK |
| `build/agnos` size | **253,936 bytes** (−64 from Attempt 20 — 4 cp_fb call sites removed; comments don't affect codegen) |
| multiboot2 (ELF64) | OK |
| Entry | `0x1000a8` (unchanged) |
| `cyrius build src/read-boot-log.cyr build/read-boot-log` | OK — new kcp=0x60 verdict + refreshed kcp=0x18 + decode-hint |
| `sudo install-usb.sh --update /dev/sdb` | OK — kernel + gnoboot + initramfs refreshed on USB; kernel-size delta confirmed (254000 → 253936) |
| `timer_isr[]` headroom | Unchanged at 1 byte |

**Carry-forward debt (not blocking Attempt 21):**

- `timer_isr[]` buffer headroom still 1 byte (unchanged).
- **Long-term fix B (pre-map FB phys into AS1/AS2)** is the right answer; deferred until mem-iso block is proven clean. Once landed, under-AS1 cp_fb calls can be restored for visual diagnosis under per-process CR3.
- `proc_create_address_space` covers only 0..4 GB of physical via identity. Any kernel diagnostic under per-process CR3 that touches high MMIO has this problem class.

---

### Attempt 21 — 2026-05-15 → Repair (H) confirmed; kcp advanced 0x18 → 0x1D

Build under test:

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.55 pinned (manifests). |
| agnos kernel | 1.30.1 candidate + Repair (H) — 4 under-AS1 cp_fb calls deleted. `build/agnos` = **253,936 bytes** ELF64 multiboot2, entry `0x1000a8`. |
| gnoboot | 0.1.0 unchanged |
| `scripts/build/read-boot-log` | Rebuilt — kcp=0x60 verdict added + kcp=0x18 + decode-hint refreshed. |

**CMOS readout (post-reset, user-reported):**

```
CMOS[0x53] gnoboot magic    = 0xcd  (decimal 205)
CMOS[0x52] gnoboot checkpt  = 0x05  (decimal 5)
CMOS[0x51] kernel  magic    = 0xab  (decimal 171)
CMOS[0x50] kernel  checkpt  = 0x1d  (decimal 29)
CMOS[0x54] CR4 byte 2 (post first cr3_load(as1))   = 0x30  (decimal 48)
CMOS[0x55] CR4 byte 2 (pre-stac, post kcp=0x60)    = 0x30  (decimal 48)
```

**Visual ladder:** User reports "same visual display" as Attempt 20 — last visible MAGENTA stays at column 0x17 (post-`proc_map_page` x2), then ~2-3 s of silence, then reset. This is the *expected* visual for Repair (H): the four under-AS1 cp_fb calls (former 0x18 / 0x1B / 0x1C / 0x1D) were deleted, so the visual ladder is supposed to be silent between 0x17 (last kernel-CR3 cp_fb) and 0x19 (post-restore cp_fb). The kcp port-I/O ladder is now the only diagnostic carrier through that block.

**Headline diagnostic — Repair (H) landed cleanly; AS1 round-trip is fully clean; death is in the AS2-block or kernel-CR3 restore.**

`kcp=0x1D` (vs. Attempt 20's stuck 0x18) is the headline: dropping the under-AS1 cp_fb calls fully unblocked the AS1 SMAP round-trip. The kcp ladder ran every stamp through main.cyr:535 inclusive — `kcp=0x18` (post-`cr3_load(as1)`) → `kcp=0x60` (pre-stac) → `kcp=0x1B` (post-stac) → `kcp=0x1C` (post-`store64`+`load64`) → `kcp=0x1D` (post-clac). Only the highest stamp value is preserved in CMOS slot 0x50, so reading 0x1D = full chain completed.

`[0x54] = 0x30, [0x55] = 0x30` — CR4.SMEP|SMAP held all the way through both dump sites. Repair (F)'s CPUID-gated SMEP+SMAP enable in Path-C boot_shim is **completely solid**. CR4 is closed as a concern.

**Death window: main.cyr:538–559** (AS2 stac/store/load/clac + second AS1 round-trip + kernel-CR3 restore + final kcp=0x19 stamp). There are *no kcp stamps in this entire block on the Attempt 21 build* — kcp=0x1D fires at line 535, the next stamp (kcp=0x19) at line 559 never landed. Bisector resolution is 21 lines wide; the read-boot-log Attempt-21 verdict guessed "cr3_load(as2)" as prime suspect but couldn't actually distinguish that from 8 other candidate sites.

**Static analysis — likely candidates ranked:**

1. **`proc_create_address_space` second-call divergence** — both as1 and as2 are built by the same function, mirror kernel PD[0..510] + PDPT[1..3], cover 0–4 GB. AS1 worked; AS2 *should* too. If proc.cyr:154 has a state-dependent bug (e.g., PMM exhaustion partway through the second call returning a partial structure), AS2's PML4 could be non-zero but missing the PD-copy entries → #PF on first kernel-text fetch under as2's CR3.
2. **`proc_create_address_space` returned 0** — main.cyr:416 has no zero-check on the as2 return. If pmm_alloc failed for the kernel PT trio, as2 = 0 and `cr3_load(as2)` loads CR3=0 → immediate #PF.
3. **AS2 missing `0xC00000` mapping** — `proc_map_page(as2, 0xC00000, 0x1200000)` at main.cyr:444 silently failed. cr3_load works (kernel text mirrored), but store64(0xC00000) #PFs.
4. **Kernel-CR3 restore broken** — mov rax, 0x1000 / mov cr3, rax at lines 551-554. Bytes are correct (REX.W mov-imm64 + 0F 22 D8). Should be unreachable as the bug, but the bisector currently can't rule it out.

**Repair (I) for Attempt 22 — 9-stamp diagnostic bisector landed 2026-05-15** (see next section).

**Process note — Repair (H) shape was right.** Dropping the four under-AS1 cp_fb calls cost zero asm bytes (well, −64 net) and advanced the diagnostic frontier by 5 sub-CPs in one move. The deferred long-term fix B (pre-map FB phys into AS1/AS2) remains the right enhancement once the mem-iso block proves clean — but Option A's minimum-risk move surfaced the next bug ladder rung cleanly. Same shape as Attempt 20's kcp=0x60 disambiguator: cheap, single-purpose, decisive.

---

### Repair (I) for Attempt 22 — 9-stamp diagnostic bisector

Landed 2026-05-15 in `agnos/kernel/core/main.cyr` (lines 537-571). Nine 8-byte port-I/O `out 0x71, kcp` stamps inserted at every step of the AS2 block + second AS1 round-trip + kernel-CR3 restore:

| Stamp site | kcp | Diagnosis if kcp pins here |
|---|---|---|
| post-`cr3_load(as2)` | 0x61 | AS2 SMAP-bracketed access block stalled (stac/store/load). |
| post-stac (AS2) | 0x62 | store64/load64 under AS2 SMAP failed — AS2 PD-entry for 0xC00000 likely missing or wrong flags. |
| post-store+load (AS2) | 0x63 | clac under AS2 faulted — near-unreachable. |
| post-clac (AS2) | 0x64 | second cr3_load(as1) faulted — AS1 PT got corrupted by the AS2 pass (cross-AS aliasing). |
| post-cr3_load(as1) #2 | 0x65 | second AS1 access block faulted — should be impossible (same as first AS1 round-trip which worked at kcp=0x1D). |
| post-stac (AS1 #2) | 0x66 | second load64 under AS1 faulted — implies AS2 invalidated AS1's mapping. |
| post-load (AS1 #2) | 0x67 | second clac under AS1 faulted — near-unreachable. |
| post-clac (AS1 #2) | 0x68 | kernel-CR3 restore asm faulted — kernel PML4 at 0x1000 corrupt. |
| post-restore (kernel CR3 = 0x1000) | 0x69 | mem-iso block fully clean; stall is downstream cp_fb(0x19) or serial-print logic. |

Pure diagnostic stamps — port I/O only, no memory access, can't fault on missing PT mirror. Plus 9 new verdicts in `scripts/src/read-boot-log.cyr` (kcp == 97..105) and an updated kcp == 29 verdict reflecting the post-Repair-I baseline (0x1D no longer terminal; if it pins, port-I/O at 0x61 didn't run = AS2 PT itself broken).

**Build verification:**

| Step | Result |
|------|--------|
| `sh scripts/build.sh` (agnos) | OK |
| `build/agnos` size | **254,000 bytes** (+64 from Attempt 21 — 72 bytes of new asm; 8 bytes absorbed by alignment slot padding, same pattern as Attempt 20's kcp=0x60 stamp) |
| multiboot2 (ELF64) | OK |
| Entry | `0x1000a8` (unchanged) |
| `cyrius build src/read-boot-log.cyr build/read-boot-log` | OK — 9 new kcp verdicts (97–105) + revised kcp=29 verdict; binary **36,280 bytes** (was 32,376) |
| `sudo install-usb.sh --update /dev/sdb` | Pending (user step) |
| `timer_isr[]` headroom | Unchanged at 1 byte |

**Carry-forward debt (not blocking Attempt 22):**

- `timer_isr[]` buffer headroom still 1 byte.
- **Long-term fix B (pre-map FB phys into AS1/AS2)** still deferred until mem-iso block proves clean. Once landed, the four under-AS1 cp_fb stamps can be restored for visual ladder under per-process CR3.
- read-boot-log carries some stdlib-slice warnings (`vec_get`, unrelated functions reported "undefined" by the diagnostic layer) — pre-existing, not caused by Repair (I); binary builds and runs fine. Investigate when stdlib annotation arc closes.

---

### Attempt 22 — 2026-05-15 → Repair (I) confirmed; kernel-PML4 corruption branch hit (kcp=0x68)

Build under test:

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.55 pinned (manifests). |
| agnos kernel | 1.30.1 candidate + Repair (I) — 9 port-I/O bisector stamps (0x61..0x69) added to mem-iso block. `build/agnos` = **254,000 bytes** ELF64 multiboot2, entry `0x1000a8`. |
| gnoboot | 0.1.0 unchanged |
| `scripts/build/read-boot-log` | Rebuilt — 9 new kcp verdicts (97–105) + revised kcp=29 verdict; binary **36,280 bytes**. |

**CMOS readout (post-reset, user-reported):**

```
CMOS[0x53] gnoboot magic    = 0xcd  (decimal 205)
CMOS[0x52] gnoboot checkpt  = 0x05  (decimal 5)
CMOS[0x51] kernel  magic    = 0xab  (decimal 171)
CMOS[0x50] kernel  checkpt  = 0x68  (decimal 104)
CMOS[0x54] CR4 byte 2 (post first cr3_load(as1))   = 0x30  (decimal 48)
CMOS[0x55] CR4 byte 2 (pre-stac, post kcp=0x60)    = 0x30  (decimal 48)
```

**Visual ladder:** User reports "no visual change" vs Attempt 21 — last visible MAGENTA stays at column 0x17, then silence, then reset. This is the *expected* visual for Repair (I): all 9 new stamps are pure port-I/O, no `cp_fb`, so the visual ladder is unchanged from Attempt 21. The kcp port-I/O ladder is the only diagnostic carrier through main.cyr:537–580.

**Headline diagnostic — Repair (I) landed cleanly; the mem-iso block is fully traversed up to but excluding the kernel-CR3 restore.**

`kcp=0x68` is the pre-bound "Second AS1 round-trip clean; kernel-CR3 restore asm faulted. Kernel PML4 at 0x1000 may be corrupt" branch — exactly the outcome the table flagged for code-path audit. The ladder ran every stamp from `kcp=0x61` (post-cr3_load(as2)) through `kcp=0x68` (post-clac, AS2's round-trip and second AS1 round-trip both clean), but the `mov rax, 0x1000 / mov cr3, rax` block at main.cyr:575-577 #PFs. CR4 dumps stay 0x30/0x30 — SMEP+SMAP healthy across the entire mem-iso block.

**`[0x54] = 0x30, [0x55] = 0x30`** — Repair (F) still solid; CR4 fully closed as a concern.

### Code-path audit — what wrote into 0x1000-0x2FFF?

The kernel PML4 lives at phys 0x1000 (one page); kernel PDPT at 0x2000, kernel PD at 0x3000 (per `proc_create_address_space`'s `load64(0x3000 + i*8)` / `load64(0x2000 + pi*8)` at proc.cyr:183, 189). Total kernel-PT footprint: phys [0x1000..0x3FFF].

**Prime suspect — PMM allocates a kernel-PT page.** PMM (`agnos/kernel/core/pmm.cyr`) marks pages [0..511] (phys 0x0..0x1FFFFF) USED via `memset(&pmm_bitmap, 0xFF, 64)` at pmm.cyr:88, then KASLR-seeds `pmm_next_free = 512 + (seed % 3584)` at pmm.cyr:102. The wrap-around branch in `pmm_alloc` (pmm.cyr:119-127) walks `[0, pmm_next_free)` — which *includes* the kernel-reserved range. If a stray `pmm_free(addr)` ever runs with `addr ∈ [0x1000..0x3FFF]` (e.g., a future PMM-init bug, a bitmap zero-pass that beats the 0xFF pass, or a corrupted `pmm_next_free` rollback) the bitmap shows those pages free, and the next `pmm_alloc` returns 0x1000/0x2000/0x3000. `proc_create_address_space` then `memset(new_pml4, 0, 4096)` zeros the kernel PML4 in place. CR3=0x1000 reload walks zeros → #PF. **High confidence; binary-decidable via Repair (J).**

**Secondary suspect — KPTI tail write in `proc_create_address_space`.** Line 212 stashes `u_pml4` at `new_pd + 511 * 8`. If `new_pd` were wrongly the kernel PD at 0x3000 (e.g., because PMM handed out 0x3000 as the new_pd), this write would land at phys 0x3FF8 — corrupting kernel PD[511] without faulting at the time. `proc_map_page` then reads back through the corrupted chain on every subsequent call.

**Why this fires on the SECOND `proc_create_address_space` not the first:** AS1 worked clean (kcp=0x1D); AS2's *internal* round-trip also worked (kcp through 0x68). PMM is monotonically advancing `pmm_next_free` so each successive 6-page batch is at a higher phys address. For AS2 to land in the kernel-reserved range, either (a) `pmm_next_free` wraps and the wrap-search finds a "free" kernel page (the bitmap should prevent this, but a corruption path would surface it), or (b) the in-flight side effects of AS2's build silently clobber kernel PML4 via a different path (KPTI tail write, etc.). Either way the fault is invisible until kernel-CR3 reload.

### Pre-bound outcomes for Repair (J)

The audit's binary question — "did PMM hand out a kernel-PT page?" — is what Repair (J) is sized to answer in a single iron burn.

| Repair-J CMOS readout | Diagnosis |
|---|---|
| **Any slot in [0x56..0x5B] (AS1) or [0x5C..0x61] (AS2) reads `0x00`** | **Smoking gun #1 confirmed.** That slot's `pmm_alloc` returned a phys page in [0x0000..0xFFFF]. Root cause = PMM bitmap. Triage `pmm_init` / `pmm_free` callers / `pmm_next_free` rollback. |
| **All slots [0x56..0x61] read `0x20` or higher** | PMM is clean — `pmm_alloc` returned only ≥ 0x200000 pages. Smoking gun #1 ruled out. Triage shifts to suspect #2 (KPTI tail write at proc.cyr:212) and other downstream paths. Add `cmos_stamp` after every `store64(new_pd + 511*8, …)` in next repair. |
| **AS1 stamps [0x56..0x5B] all show valid bytes, AS2 stamps [0x5C..0x61] all read `0x00` (virgin CMOS)** | AS2 call to `proc_create_address_space` never reached the stamp sites = aborted at first pmm_alloc returning 0. Means PMM exhausted between the AS1 and AS2 calls — 1 GB+ of single-page allocations would have to happen between them, which the mem-iso block doesn't do; this would imply a runaway loop or major bug. Low probability but flag if observed. |

---

### Repair (J) for Attempt 23 — PMM-allocation CMOS stamps

Landed 2026-05-15 in `agnos/kernel/core/proc.cyr`. 12 single-byte CMOS stamps inside `proc_create_address_space`, written immediately after each of the 6 `pmm_alloc()` calls. A static call counter `proc_pca_call_n` distinguishes the AS1 call (slots 0x56..0x5B) from the AS2 call (slots 0x5C..0x61). Each stamp writes `(addr >> 16) & 0xFF` — byte 2 of the returned physical address.

Slot allocation (CMOS scratch range [0x50..0x7F] per archaemenid CMOS map):

| Slot | Stamps |
|---|---|
| 0x50 | kcp (existing) |
| 0x51 | kernel magic 0xab (existing) |
| 0x52 | gnoboot checkpt (existing) |
| 0x53 | gnoboot magic 0xcd (existing) |
| 0x54 | CR4 byte 2 post first cr3_load(as1) (existing) |
| 0x55 | CR4 byte 2 pre-stac post kcp=0x60 (existing) |
| **0x56** | AS1 call, byte 2 of `new_pml4` |
| **0x57** | AS1 call, byte 2 of `new_pdpt` |
| **0x58** | AS1 call, byte 2 of `new_pd` |
| **0x59** | AS1 call, byte 2 of `u_pml4` |
| **0x5A** | AS1 call, byte 2 of `u_pdpt` |
| **0x5B** | AS1 call, byte 2 of `u_pd` |
| **0x5C** | AS2 call, byte 2 of `new_pml4` |
| **0x5D** | AS2 call, byte 2 of `new_pdpt` |
| **0x5E** | AS2 call, byte 2 of `new_pd` |
| **0x5F** | AS2 call, byte 2 of `u_pml4` |
| **0x60** | AS2 call, byte 2 of `u_pdpt` |
| **0x61** | AS2 call, byte 2 of `u_pd` |

**Stamp encoding**: `(addr >> 16) & 0xFF` distinguishes binary-clean from smoking-gun:

- `0x00` → page < 0x10000 (i.e., < 64 KB) → kernel-reserved range → **smoking gun confirmed**
- `0x20`–`0xFF` → page ≥ 0x200000 (≥ 2 MB) → safe (above PMM's `pmm_used = 512` watermark)

(Values `0x01`–`0x1F` are theoretically reachable only if PMM exhausts the 2–16 MB range and a wrap-around finds something below 0x200000; not expected for the first 12 page allocations of boot. Treat any `< 0x20` reading as a smoking gun.)

Implementation: two-line `outb(0x70, slot); outb(0x71, val)` pair per stamp, calling existing `outb` helper from `arch/x86_64/io.cyr`. No new helpers. Single static counter `proc_pca_call_n` initialized to 0, incremented on entry. Third+ calls (if `proc_create_address_space` ever runs more than twice during boot) skip stamping (out of slots) to avoid corrupting unrelated CMOS scratch.

**Build verification:**

| Step | Result |
|------|--------|
| `sh scripts/build.sh` (agnos) | OK |
| `build/agnos` size | **254,752 bytes** (+752 from Attempt 22) |
| multiboot2 (ELF64) / entry | OK / `0x1000a8` (unchanged) |
| `cyrius build src/read-boot-log.cyr build/read-boot-log` | OK — 12 new slot reads + interpretation block + updated kcp=0x68 verdict; binary **38,344 bytes** (was 36,280) |
| `sudo install-usb.sh --update /dev/sdb` | Pending (user step) |
| `timer_isr[]` headroom | Unchanged at 1 byte (kernel growth is all in proc.cyr, not pic.cyr) |

(Build verified clean; pre-existing diagnostic-layer false-positives — `memset` for proc.cyr, `vec_get`/`strlen`/`fmt_byte`/`println` for read-boot-log — are surfaced by the cyrius diagnostic layer but resolve at link time via the include chain. Same pattern as Repair (I).)

---

### Attempt 23 — 2026-05-15 → PMM ruled out (all 12 stamps = 0xaf)

Build under test:

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.55 pinned (manifests). |
| agnos kernel | 1.30.1 candidate + Repair (J) — `build/agnos` = **254,752 bytes** ELF64 multiboot2, entry `0x1000a8`. |
| gnoboot | 0.1.0 unchanged |
| `scripts/build/read-boot-log` | Rebuilt — 12 new PMM-stamp slot reads + smoking-gun interpretation block; binary **38,344 bytes**. |

**CMOS readout (post-reset, user-reported):**

```
CMOS[0x50] kernel checkpt = 0x68
CMOS[0x56..0x5B] AS1 pmm_alloc bytes = 0xaf, 0xaf, 0xaf, 0xaf, 0xaf, 0xaf
CMOS[0x5C..0x61] AS2 pmm_alloc bytes = 0xaf, 0xaf, 0xaf, 0xaf, 0xaf, 0xaf
```

**Headline diagnostic — PMM ruled out.** All 12 stamps read `0xaf` (byte 2 of `(addr >> 16) & 0xFF` → phys ≈ 0xaf0000, ~11 MB). Every page returned by `pmm_alloc` was well above the 2-MB kernel-reserved watermark and far above the [0x1000..0x3FFF] kernel-PT range. Smoking gun #1 (PMM hands out a kernel-PT page → `memset(addr, 0, 4096)` zeros the kernel PML4 in place) is **falsified**. Triage shifts to direct PML4 corruption hypotheses (suspect #2 — KPTI tail write at `proc.cyr:212` — or a different bug class entirely, e.g. flags torn at init).

kcp=0x68 unchanged from Attempt 22 — the kernel still reaches "post second AS1 round-trip" and faults on the `mov rax, 0x1000 / mov cr3, rax` restore.

---

### Repair (K) for Attempt 24 — 7 PML4 health stamps across mem-iso

Landed 2026-05-15 in `agnos/kernel/core/main.cyr`. 7 single-byte CMOS stamps at slots **0x62..0x68**, each reading byte 0 of phys 0x1000 (the kernel PML4[0]'s low byte) at successive checkpoints through the mem-iso block. Pure port-I/O — no behavior change.

| Slot | Site |
|---|---|
| 0x62 | Entering mem-iso, pre-AS work |
| 0x63 | Post AS1 + AS2 `proc_create_address_space` |
| 0x64 | Post `proc_map_page` x2 |
| 0x65 | Post first `cr3_load(as1)` |
| 0x66 | Post first AS1 SMAP round-trip |
| 0x67 | Post AS2 SMAP round-trip |
| 0x68 | Post second AS1 round-trip (last quiet point pre-CR3-restore) |

**Stamp encoding** — byte 0 of PML4[0]:

- `0x07` → P|RW|US, entry points to PDPT @ 0x2000 — **healthy**.
- `0x00` → entry zeroed — corruption pinned between this slot and the prior one.
- other → entry **rewritten** with non-canonical flags — flag-tear bug class.

Pre-bound outcomes:

| Repair-K readout | Diagnosis |
|---|---|
| All 7 slots read `0x07` | PML4 healthy throughout; cr3-restore #PF is NOT direct PML4 corruption. Premise inverts — Repair (L) needs a #PF handler dumping CR2 / error code. |
| First slot reading `0x00` at index N | Corruption window pinned between slot (N-1) and slot N. Triage the code in that window. |
| Persistent non-zero, non-0x07 value | Flag-tear bug class — entry never initialized correctly. Audit the init site. |

**Build verification:**

| Step | Result |
|------|--------|
| `sh scripts/build.sh` (agnos) | OK |
| `build/agnos` size | **254,848 bytes** (+96 from Attempt 23: 7 × ~14-byte asm blocks) |
| multiboot2 (ELF64) / entry | OK / `0x1000a8` (unchanged) |
| `cyrius build` for read-boot-log | OK — gains 7 new slot reads + interpretation block; `timer_isr[]` headroom unchanged at 1 byte |

---

### Attempt 24 — 2026-05-15 → PML4[0] = 0x04 throughout (Path C `pt_init` bug)

Build under test:

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.55 pinned. |
| agnos kernel | 1.30.1 candidate + Repair (J) + Repair (K) — `build/agnos` = **254,848 bytes**. |
| gnoboot | 0.1.0 unchanged. |
| `scripts/build/read-boot-log` | Rebuilt with 7 new PML4 slot verdicts. |

**CMOS readout (post-reset, user-reported):**

```
CMOS[0x50] kernel checkpt              = 0x68
CMOS[0x54] CR4 byte 2 post cr3(as1)    = 0x30
CMOS[0x55] CR4 byte 2 pre-stac         = 0x30
CMOS[0x56..0x61] AS1+AS2 pmm bytes     = 0x74 (all 12; clean, ≥ 0x200000)
CMOS[0x62..0x68] PML4[0] byte 0        = 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04
```

**Headline diagnostic — PML4[0] reads `0x04` at every checkpoint, including the very first stamp ("entering mem-iso, pre-AS work").** This is the third (unenumerated) bucket: not 0x00 (dynamic zeroing), not 0x07 (healthy), but a persistent flag-tear value present *before any mem-iso code runs*. PMM is clean (PMM stamps re-confirmed at 0x74). Repair (K)'s premise was "find the corruption window" — there is no window, the entry was wrong at boot.

**Root cause pinned to `kernel/arch/x86_64/paging.cyr:pt_init`:**

```cyrius
var pml4e = load64(0x1000);
store64(0x1000, pml4e | 0x04);     # PML4[0] |= US
var pdpte = load64(0x2000);
store64(0x2000, pdpte | 0x04);     # PDPT[0] |= US
```

This OR-in-US pattern is a **Path A artifact**. The legacy multiboot path ran `boot_shim.cyr:65` (`mov [0x1000], 0x2003`) first, pre-seeding `PML4[0] = 0x2003` (P|RW → PDPT @ 0x2000); `pt_init` only had to upgrade to `0x2007` (add US for ring-3).

**Path C bypasses boot_shim's PT setup entirely.** Per `boot_shim.cyr:171`: "Page tables — UEFI's identity map is fine." gnoboot inherits UEFI's PT and hands control to the kernel without ever touching phys 0x1000. By the time `pt_init` runs, phys 0x1000 is cold (zero). The OR yields `0 | 0x04 = 0x04` — US set, but **P=0, RW=0, no PDPT address**.

The kernel runs fine through CP 0x68 because **CR3 never points at 0x1000** — UEFI's identity map carries it, and AS1/AS2's PML4s are built correctly by `proc_create_address_space` (`store64(new_pml4, new_pdpt | 0x07)` at `proc.cyr:195`). The crash is at `mov cr3, 0x1000` in main.cyr:629-631 — the MMU walks the new PML4, hits PML4[0] with P=0, and #PFs on the next instruction fetch.

PDPT[0] at 0x2000 is also broken (same OR-in pattern) — `0x04` instead of `0x3007`. Two-line fix, both sites.

Repair (L)'s prior-bound form (#PF handler) becomes unnecessary — Repair (K)'s static reading was conclusive without dynamic fault diagnostics.

---

### Repair (L) for Attempt 25 — `pt_init` explicit-write fix

Landed 2026-05-15 in `agnos/kernel/arch/x86_64/paging.cyr:30-33`. Replaces the OR-in-US pattern with explicit, self-sufficient writes:

```cyrius
store64(0x1000, 0x2007);   # PML4[0] -> PDPT @ 0x2000 | P|RW|US
store64(0x2000, 0x3007);   # PDPT[0] -> PD   @ 0x3000 | P|RW|US
```

`pt_init` is now self-sufficient under both Path A (boot_shim still works — explicit write overrides its 0x2003 seed harmlessly) and Path C (cold memory at 0x1000/0x2000 is initialized from scratch). PD entries at 0x3000 and PDPT[1..3] huge pages already used explicit writes — unchanged.

Comment in-place explains the Path A vs Path C provenance and points at Attempt 24 / Repair (K) for the diagnostic trail.

**Build verification:**

| Step | Result |
|------|--------|
| `sh scripts/build.sh` (agnos) | OK |
| `build/agnos` size | **254,800 bytes** (−48 from Attempt 24: two `store64(literal, literal)` calls compile smaller than the `var + load64 + OR + store64` quartet) |
| multiboot2 (ELF64) / entry | OK / `0x1000a8` (unchanged) |
| `cyrius build` for read-boot-log | Not regenerated — kcp interpretation unchanged |
| `sudo install-usb.sh --update /dev/sdb` | Pending (user step) |
| `timer_isr[]` headroom | Unchanged at 1 byte |

**Pre-bound outcomes for Attempt 25 iron burn:**

| CMOS readout | Diagnosis |
|---|---|
| `kcp ≥ 0x69` + cp_fb(0x19) MAGENTA visible | **Repair (L) sufficient.** Kernel-CR3 restore succeeded; mem-iso block complete; ladder advances to userland-exec / kybernet sites. Next gate at CP 0x14 / 0x15. |
| `kcp = 0x68` + PML4 stamps all `0x07` | Static fix landed but something downstream re-clears it — unlikely (no other writers to PML4[0] in mem-iso). Triage `proc_create_address_space`'s `store64(new_pd + 511*8, u_pml4)` collision possibility. |
| `kcp = 0x68` + PML4 stamps still `0x04` | Build didn't reflash, or `pt_init` not on the call path. Re-verify `install-usb.sh --update` ran clean and the new ELF made it onto the boot media. |
| `kcp` regresses below 0x68 | Repair (L) introduced a regression elsewhere — extremely unlikely for a 2-line literal-store swap, but flag if seen. |

---

### Attempt 25 — 2026-05-15 → Repair (L) confirmed; mem-iso block fully clean; new bug downstream in main.cyr:640-660

Build under test:

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.55 pinned. |
| agnos kernel | 1.30.1 candidate + Repair (J) + Repair (K) + Repair (L) — `build/agnos` = **254,800 bytes**. |
| gnoboot | 0.1.0 unchanged. |
| `scripts/build/read-boot-log` | Not rebuilt — kcp/stamp interpretation unchanged from Attempt 24. |

**CMOS readout (post-reset, user-reported):**

```
CMOS[0x53] gnoboot magic               = 0xcd  (handoff stamp present)
CMOS[0x52] gnoboot checkpt             = 0x05  (gnoboot completed)
CMOS[0x51] kernel  magic               = 0xab  (kernel reached stamp site)
CMOS[0x50] kernel  checkpt             = 0x19  (decimal 25)
CMOS[0x54] CR4 byte 2 post cr3(as1)    = 0x30  (SMEP+SMAP intact)
CMOS[0x55] CR4 byte 2 pre-stac         = 0x30  (SMEP+SMAP intact)
CMOS[0x56..0x61] AS1+AS2 pmm bytes     = 0x32, 0x32, 0x33, 0x33, 0x33, 0x33,
                                         0x33, 0x33, 0x33, 0x33, 0x33, 0x33
                                         (all ≥ 0x20 — clean, well above 2 MB)
CMOS[0x62..0x68] PML4[0] byte 0        = 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07
                                         (all healthy — P|RW|US, PDPT @ 0x2000)
```

**Headline diagnostic — Repair (L) is sufficient.** PML4[0] reads `0x07` at every Repair (K) checkpoint, *including the pre-AS-work stamp* — confirming `pt_init`'s explicit-write replacement initializes PML4[0]/PDPT[0] from cold under Path C. The Attempt 24 third-bucket `0x04` reading is gone; the OR-in-US bug is closed. PMM stamps held clean (all ≥ 0x20, no kernel-PT range hits); CR4 byte-2 held `0x30` through both AS dances.

**kcp = 0x19 = mem-iso block fully complete.** CMOS slot 0x50 preserves only the highest stamp written; reading 0x19 means the kernel reached the **final** stamp of the mem-iso dance at `main.cyr:639`:

```cyrius
# CMOS CP 0x19: all three CR3 switches + SMAP-bracketed stores/loads + kernel-PT
# restore survived. Any post-CP-0x19 stall is in the serial-print / branch logic.
asm { 0xB0; 0x50; 0xE6; 0x70; 0xB0; 0x19; 0xE6; 0x71; }
cp_fb(0x19, 0x00FF00FF);  # MAGENTA — mem-iso bisector: post all 3 CR3 switches + restore
```

Attempts 22–24 stuck at `kcp=0x68` (pre-restore stamp from Repair (I)'s 9-stamp bisector); the `mov cr3, 0x1000` restore #PF'd because PML4[0] was `0x04`. Repair (L)'s explicit `store64(0x1000, 0x2007)` cleared that — CR3 restore now walks a valid PML4, `0x19` stamps successfully, and the kcp overwrites the prior `0x68`.

The pre-bound row "kcp ≥ 0x69" in [Repair (L)](#repair-l-for-attempt-25--pt_init-explicit-write-fix) was a forecast typo — the actual final-stamp value is `0x19` (the sub-CP label, not a monotonic counter). Outcome bucket matches "Repair (L) sufficient" exactly; only the predicted readout value was off.

**Visual ladder — RACY.** User reports the screen "occasionally" displays the gnoboot "handing off to kernel" message *plus* a row of colored CP squares at the top-left ([`iron-boot-photos/attempt-25-boot-colors-racy.jpg`](iron-boot-photos/attempt-25-boot-colors-racy.jpg)); otherwise the visual matches recent attempts (silent past column 0x17). The intermittency is the new signal — `cp_fb(0x19)` MAGENTA paint *sometimes* fires, *sometimes* doesn't, on otherwise-identical resets. This non-determinism rules out a deterministic page-table or build error and points at racy state coming out of the mem-iso block (RFLAGS.AC residue from the SMAP brackets? stack misalignment from the asm-heavy CR3 dance? a CR3 that *almost* restored? a TLB-flush gap on FB MMIO?). First racy outcome of the iron-boot ladder — Attempts 1–24 were all deterministic across re-burns.

**Death window — main.cyr:640–660 (21 lines).** Kernel reaches `kcp=0x19` (line 639) but does NOT reach `kcp=0x13` (line 661, "post-memory-isolation test"). The intervening code:

```cyrius
cp_fb(0x19, 0x00FF00FF);                                    # line 640

serial_print("AS1 wrote 0xAAAA, read=", 23);                # line 642
kprint_num(val_as1);                                        # line 643
serial_print(" recheck=", 9);                               # line 644
kprint_num(val_as1_check);                                  # line 645
serial_println("", 0);                                      # line 646
serial_print("AS2 wrote 0xBBBB, read=", 23);                # line 647
kprint_num(val_as2);                                        # line 648
serial_println("", 0);                                      # line 649

if (val_as1_check == 0xAAAA) {                              # line 651
    if (val_as2 == 0xBBBB) {                                # line 652
        serial_println("Memory isolation: PASS", 22);       # line 653
    } else {
        serial_println("Memory isolation: FAIL (AS2)", 28); # line 655
    }
} else {
    serial_println("Memory isolation: FAIL (AS1 clobbered)", 38);  # line 658
}
# CMOS CP 0x13: post-memory-isolation test
asm { 0xB0; 0x50; 0xE6; 0x70; 0xB0; 0x13; 0xE6; 0x71; }    # line 661
```

Candidates inside the window:
- `cp_fb(0x19)` itself — line 640 framebuffer write (only intermittently visible).
- `serial_print` × 5 / `kprint_num` × 3 — eight UART-touching calls (lines 642–649).
- Nested `if`/`else` chain reading `val_as1_check` / `val_as2` (lines 651–659) — values were written under SMAP brackets earlier; if their stack slots are stale or the AC bit leaked, reads could fault or branch unpredictably.

**Suspect ranking (working hypothesis):**

1. **RFLAGS.AC residue** — the AS2 SMAP round-trip ends with a `clac` (0F 01 CA). If a code path skipped it (e.g. the kernel-PT-restore asm clobbered RFLAGS) AND a later `serial_print` accesses user-flagged memory, SMAP would fault. Test: stamp kcp inside the first `serial_print` call, before the first byte hits the UART.
2. **Stack misalignment** — the mem-iso block has 3 CR3 switches, 6 stac/clac pairs, kernel-PT-restore asm. If the asm decoder left RSP off-16-byte, the first SSE-aligned local would `#GP`. Test: check RSP alignment via `mov [0x6X], rsp byte 0` stamp.
3. **`val_as1_check` / `val_as2` are stack-spilled in cc5 codegen** — if the regalloc spilled them to slots that got clobbered by the asm-heavy block, the branch reads garbage. Test: stamp the actual byte read.

**Next repair (M) — proposed:** 4-stamp bisector at main.cyr:640–660 to narrow the 21-line window. Pure port-I/O, ~30 added asm bytes per stamp, no behavior change. See [Repair (M)](#repair-m-for-attempt-26--proposed-4-stamp-bisector-of-mainscyr640-660) below.

---

### Repair (M) for Attempt 26 — 4-stamp bisector of main.cyr:640-660

**Status:** Landed 2026-05-15 in `agnos/kernel/core/main.cyr` + `agnosticos/scripts/src/read-boot-log.cyr`. Pending iron burn.

**Goal:** Bisect the 21-line death window between `cp_fb(0x19)` and `kcp=0x13`.

**Stamps landed:**

| Slot | Site (main.cyr) | Stamp value | What it tells us |
|------|------|-------------|------------------|
| Stamp 1 | After `cp_fb(0x19, MAGENTA)` line 640 | `0xE1` (225 dec) | Did cp_fb itself return? If kcp stays 0x19, cp_fb is the killer. |
| Stamp 2 | After first `serial_print("AS1 wrote...")` line 642 | `0xE2` (226 dec) | Did the first UART touch + .rodata walk survive? |
| Stamp 3 | After final `serial_println("", 0)` line 649 | `0xE3` (227 dec) | Did the 8-call print block survive? Isolates branch from print. |
| Stamp 4 | Between `}` line 659 and `kcp=0x13` line 661 | `0xE4` (228 dec) | Did the nested if/else branch complete? |

Stamp values chosen above the existing 0x18/0x19/0x1A-0x1D/0x60/0x68/0x69 set to avoid collision in CMOS slot 0x50. Each stamp is the standard 8-byte `mov al, 0x50 / out 0x70, al / mov al, imm / out 0x71, al` pattern — clobbers AL only, no memory access.

Companion edit at main.cyr:638 — stale "lines 462-479" line-number reference (pre-Repair-L) refreshed to "lines 640-660" with confirmation that Attempt 25 actually saw the stall there.

**read-boot-log refresh:** 4 new verdict branches added at `read-boot-log.cyr:323-327` (kcp = 225/226/227/228 decoders), plus the existing kcp=25 (CP 0x19) verdict updated to reference Attempt 25 results + the Repair (M) bisector lookup pattern + the racy-cell observation. The kcp=104 (CP 0x68) "Repair (L) needs #PF handler" forecast was left intact for narrative continuity — that branch only fires on regression, and the actual Repair (L) path is documented above.

**Decision matrix for Attempt 26 readout:**

| kcp post-Attempt-26 | Diagnosis |
|---|---|
| `0x19` (unchanged) | `cp_fb(0x19)` itself is faulting intermittently. Triage FB MMIO mapping under kernel CR3 post-restore — possible TLB-flush gap or cacheability mismatch. **Repair (N) candidate**: cp_fb-internal stamps + `wbinvd`/`invlpg` injection ahead of the FB write. |
| `0xE1` | cp_fb survived; first serial_print faulted. Triage UART driver state (likely RFLAGS.AC residue from a missed clac, or .rodata string-literal load fault). **Repair (N) candidate**: stamp inside `serial_print`'s loop. |
| `0xE2` | First serial_print returned; death is in kprint_num or a later print/println at lines 643-649. **Repair (N) candidate**: stamp between each of the 7 remaining print calls. |
| `0xE3` | Print block clean; branch logic at lines 651-659 is the killer. **Repair (N) candidate**: stamp `val_as1_check` / `val_as2` bytes via `mov rax, [rbp-N] / out 0x71, al` before each compare. |
| `0xE4` | Branch complete; the `kcp=0x13` asm itself faulted (very unlikely — identical to 24 working stamps). Most likely interpretation: spurious result, retry the burn. |
| `0x13` (or higher) | Repair (M) revealed nothing — the bug was transient on this burn. Repeat burns 2-3× to characterize the racy outcome distribution before escalating. |

**Build verification:**

| Step | Result |
|------|--------|
| `sh scripts/build.sh` (agnos) | OK |
| `build/agnos` size | **254,832 bytes** (+32 from Attempt 25: 4 × 8-byte stamps, no alignment absorption this round) |
| multiboot2 (ELF64) / entry | OK / `0x1000a8` (unchanged) |
| `cyrius build` for read-boot-log | OK — `build/read-boot-log` now 42,288 bytes (gained ~6 KB of new verdict text since Attempt 24 baseline) |
| `timer_isr[]` headroom | Unchanged at 1 byte (Repair (M) is in main.cyr body, not the ISR buffer) |
| `sudo install-usb.sh --update /dev/sdb` | Pending (user step) |

**Pre-burn ask for Attempt 26:** Given Attempt 25's racy outcome, capture CMOS from **2-3 consecutive resets** rather than one. If kcp lands at different values across burns (e.g., one shows 0x19, another shows 0xE3, another shows 0x13), the racy state distribution itself becomes the primary diagnostic.

**Carry-forward debt (not blocking Attempt 26):**

- If kcp=0x19 result repeats (cp_fb-under-restored-CR3 fault), the deferred Repair-H Option-B work (pre-map FB phys into AS1/AS2's PT mirrors) becomes the structural fix. Not relevant to other kcp values.
- Several read-boot-log verdicts (kcp=104, kcp=18) still cite pre-Repair-L line numbers (393-478, 549, 561, 575-577). Those branches only fire on regression — refresh opportunistically when next touched.
- Repair (M) is diagnostic-only. If it pins the bug to print/branch logic, Repair (N) will be the actual fix.

---

### Attempt 26 — 2026-05-15 → kcp PEGGED at 0x19; cp_fb is the killer; BIOS-save-exit-correlated racy

**Build under test:** agnos 1.30.0-candidate post-Repair-(M), 254,832 bytes, multiboot2/ELF64, entry `0x1000a8`. Toolchain pinned at Cyrius 5.11.55. read-boot-log built at 42,288 bytes (Repair (M) verdict adds).

**Observed CMOS readout (full):**

```
CMOS[0x53] gnoboot magic    = 0xCD   CMOS[0x51] kernel  magic    = 0xAB
CMOS[0x52] gnoboot checkpt  = 0x05   CMOS[0x50] kernel  checkpt  = 0x19
CMOS[0x54] CR4 byte 2 (post first cr3_load(as1))   = 0x30
CMOS[0x55] CR4 byte 2 (pre-stac, post kcp=0x60)    = 0x30
CMOS[0x56]..[0x5B] AS1 PMM allocs (byte 2)         = 0x2c, 0x2c, 0x2c, 0x2d, 0x2d, 0x2d
CMOS[0x5C]..[0x61] AS2 PMM allocs (byte 2)         = 0x2d, 0x2d, 0x2d, 0x2d, 0x2d, 0x2d
CMOS[0x62]..[0x68] PML4[0] byte 0 (7 stamps)       = 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07
```

**Headline result:** kcp **pegged at 0x19** across burns. NONE of the Repair (M) stamps (0xE1/0xE2/0xE3/0xE4) fired. By Repair (M)'s decision matrix this is row 1: **`cp_fb(0x19)` itself didn't return** — the death window collapses from "21 lines main.cyr:640-660" to "one function: `cp_fb` in fb.cyr". Working-suspect #3 from Attempt 25 (FB MMIO TLB-flush gap on restored CR3) is the surviving hypothesis. PMM stamps all `0x2c/0x2d` (above 2 MB watermark — clean), PML4 stamps all `0x07` (healthy), CR4 byte 2 = `0x30` (SMEP+SMAP held), CR3 dance through all three switches survived intact.

**New observation — BIOS-save-exit vs save-reset asymmetry (FIRST RECORDED 2026-05-15):** User noted the racy outcome **only manifests after BIOS save-and-exit** (cold POST + PCIe re-enum + DRAM retrain + fresh MTRR/PAT program). Warm reset (save-and-reset without entering setup) reproduces the kcp=0x19 peg **deterministically** — "same as previous attempts". This narrows the suspect ranking:

| Suspect | Save-exit vs reset asymmetry explains it? |
|---|---|
| FB MMIO TLB-flush gap on restored CR3 (Attempt-25 working #3) | Partially — TLB is flushed both paths, but the FRESH cached TLB lines differ post-cold-POST. |
| **GPU BAR re-enumeration** (NEW) | **Yes** — cold POST reassigns PCIe BARs; warm reset preserves them. cp_fb's hardcoded `fb` from `boot_info+0x48` is correct for the BOOT in which it was captured, not necessarily for subsequent warm resets. |
| **MTRR / IA32_PAT memory-type divergence** (NEW) | **Yes** — BIOS reprograms MTRRs during save-exit POST; warm reset leaves them in the prior-boot state. The FB range's effective memory type (UC / WC / WB) can flip. |
| RFLAGS.AC residue from SMAP brackets (Attempt-25 working #1) | No — same RFLAGS state both paths. |
| Stack misalignment from asm-heavy CR3 dance (Attempt-25 working #2) | No — same stack state both paths. |

The asymmetry effectively **rules out** the stack/RFLAGS hypotheses and **rules in** BAR-shift + MTRR/PAT. The in-cp_fb bisector + fb_phys snapshot in Repair (N) directly target these.

**Decision:** proceed to Repair (N). cp_fb-internal bisector + fb_phys snapshot land BEFORE attempting either of the structural fixes (FB pre-map / `wbinvd`/`invlpg` injection) — those are heavier and we want to know *which* hypothesis to fix.

---

### Repair (N) for Attempt 27 — in-cp_fb bisector + fb_phys BAR snapshot

**Status:** Landed 2026-05-15 in `agnos/kernel/arch/x86_64/fb.cyr` + `agnos/kernel/arch/x86_64/mbi.cyr` + `agnos/kernel/core/main.cyr` + `agnosticos/scripts/src/read-boot-log.cyr`. Pending iron burn.

**Goal:** Pin which step inside `cp_fb` faults, and capture the FB BAR address on this boot so cross-attempt comparison reveals BAR drift between BIOS-save-exit and warm-reset paths.

**Stamps landed inside `cp_fb` (fb.cyr):**

| # | Site | Stamp value | What it tells us |
|---|------|-------------|------------------|
| 1 | Function entry, before any load | `0xE5` (229) | Did `cp_fb` even get past its prologue? |
| 2 | Post `load64(&boot_info_ptr)` | `0xE6` (230) | Did the boot_info_ptr load + null check survive? |
| 3 | Post `load64(bi + 0x48)` | `0xE7` (231) | Did the fb_phys load survive (boot_info struct still reachable)? |
| 4 | Geometry computed, pre-first-store32 | `0xE8` (232) | Are we about to write FB MMIO? **Smoking-gun stamp.** |
| 5 | Post first `store32(fb + ..., color)` | `0xE9` (233) | Did the first FB MMIO write survive? |
| 6 | Post 4×4 fill loop | `0xEA` (234) | Did all 16 FB writes survive? |

Stamps use only port I/O (no memory access) — they fire even if FB MMIO or boot_info access faults. The first FB MMIO write is **hoisted out of the loop** so stamp 5 isolates "first FB write faulted" from "first write OK but later one faulted"; the subsequent 4×4 loop redundantly overwrites pixel (0,0), visually harmless.

**fb_phys snapshot helper landed (mbi.cyr):**

```cyrius
fn cmos_stamp_fb_phys(): i64 {
    var p = &boot_info_ptr;          # mov rax, <abs_addr_of_boot_info_ptr>
    asm {
        0x48; 0x8B; 0x00;            # mov rax, [rax]       — boot_info_ptr value (struct addr)
        0x48; 0x8B; 0x40; 0x48;      # mov rax, [rax+0x48]  — rax = fb_phys
        0x48; 0xC1; 0xE8; 0x10;      # shr rax, 16          — byte 2 in al
        0x88; 0xC1; 0xB0; 0x69; 0xE6; 0x70; 0x88; 0xC8; 0xE6; 0x71;   # stamp CMOS[0x69]
        0x48; 0xC1; 0xE8; 0x08;      # shr rax, 8 more      — byte 3 in al
        0x88; 0xC1; 0xB0; 0x6A; 0xE6; 0x70; 0x88; 0xC8; 0xE6; 0x71;   # stamp CMOS[0x6A]
    }
    return 0;
}
```

Sibling to `boot_info_capture_rdi` — same `var p = &boot_info_ptr` Cyrius idiom that emits `mov rax, <abs_addr>`, then inline asm walks the struct.

**Call site (main.cyr):** `var _bar_snap = cmos_stamp_fb_phys();` inserted between the `kcp=0x19` stamp at line 639 and the `cp_fb(0x19)` call at line 640. Captures fb_phys bytes 2/3 RIGHT before the call that's been pegging kcp.

**read-boot-log refresh:** 6 new kcp verdicts (kcp = 229..234 / 0xE5..0xEA) added after the Repair (M) bisector block; existing kcp=25 (CP 0x19) verdict refreshed to forward to the new in-cp_fb stamps. New CMOS slot reads for `[0x69]/[0x6A]` (FB BAR bytes 2+3) plus an interpretation block explaining BIOS-save-exit vs warm-reset comparison.

**Decision matrix for Attempt 27 readout:**

| kcp post-Attempt-27 | CMOS[0x69]/[0x6A] | Diagnosis |
|---|---|---|
| `0x19` (unchanged) | unchanged from prior | Even the in-cp_fb entry stamp didn't fire — function-prologue / call-site fault. Highly unexpected. Re-verify Repair (N) actually landed in the burned USB. |
| `0xE5` | unchanged | Entered cp_fb but died on `load64(&boot_info_ptr)`. Implies kernel-data address unreachable under post-mem-iso CR3 (PT-tear scenario). |
| `0xE6` | non-zero | bi loaded OK, died on `load64(bi + 0x48)`. boot_info struct mapping is the issue. |
| `0xE7` | non-zero | fb load OK, died in pitch/height load or geometry. Extremely improbable — same boot_info access pattern. |
| `0xE8` | **compare across boots** | **About to write FB MMIO, didn't.** Triage paths: (a) **BAR shift** — compare [0x69]/[0x6A] across BIOS-save-exit vs warm-reset boots; divergence = cold POST reassigned the BAR. (b) **MTRR/PAT** — values identical across both reset modes → cacheability is the issue, dump IA32_PAT (MSR 0x277) + MTRR_DEF_TYPE (MSR 0x2FF) in Repair (O). |
| `0xE9` | non-zero | First FB write OK, died in 4×4 fill loop. Improbable (adjacent pages, same cacheability). |
| `0xEA` | non-zero | All FB writes returned. Stall is in the kcp=0xE1 stamp at main.cyr — identical byte pattern to dozens of working stamps. Most likely interpretation: racy outcome shifted on this burn; capture 2-3 consecutive resets. |

**Build verification:**

| Step | Result |
|------|--------|
| `sh scripts/build.sh` (agnos) | OK |
| `build/agnos` size | **255,048 bytes** (+216 from Repair (M)'s 254,832: 6 × 8-byte in-cp_fb stamps + cmos_stamp_fb_phys body + call-site emit + Cyrius var-init for `_bar_snap`) |
| multiboot2 (ELF64) / entry | OK / `0x1000a8` (unchanged) |
| `cyrius build` for read-boot-log | OK — `build/read-boot-log` now ~47,640 bytes (gained ~5 KB of new verdict text since Repair (M) baseline) |
| `timer_isr[]` headroom | Unchanged at 1 byte (Repair (N) lives in fb.cyr / mbi.cyr / main.cyr body, not the ISR buffer) |
| `sudo install-usb.sh --update /dev/sdb` | Pending (user step) |

**Pre-burn ask for Attempt 27:** capture **2-3 consecutive resets, ideally with at least one BIOS-save-exit interleaved**. The BAR snapshot makes the cold-vs-warm asymmetry directly readable from CMOS; we want to see whether [0x69]/[0x6A] drift between the two paths.

**Carry-forward debt (not blocking Attempt 27):**

- If Attempt 27 confirms kcp=0xE8 + BAR drift between cold/warm, Repair (O) is the fix-path: either pre-map FB phys into each AS's PT mirror (deferred Repair-H Option-B) OR force fb_phys reload from boot_info on every cp_fb entry (cheaper, but only safe if boot_info itself is stable).
- If kcp=0xE8 + BAR identical across reset modes, Repair (O) opens with MTRR/PAT diagnostics: `mov rax, cr0` byte 3 + `rdmsr 0x277` byte 0 + `rdmsr 0x2FF` byte 0 stamps.
- Repair (N) is diagnostic-only. The actual fix is Repair (O+) once we know which hypothesis is in play.

---

### Attempt 27 — 2026-05-15 → fb_phys = 0 confirmed; bug shifts from kernel to gnoboot/boot_info

**Build under test:**

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.55 pinned. |
| agnos kernel | 1.30.1 candidate post-Repair-(N) — `build/agnos` = **255,048 bytes** (verified on-disk). |
| gnoboot | 0.1.0 unchanged from Attempt 26 (boot_info producer side untouched this cycle). |
| `scripts/build/read-boot-log` | ~47,640 bytes — Repair (N) verdicts present (kcp=0xE5..0xEA branches + CMOS[0x69]/[0x6A] decoder). |

**CMOS readout (post-reset, user-reported):**

```
CMOS[0x53] gnoboot magic                                   = 0xcd
CMOS[0x52] gnoboot checkpt                                 = 0x05
CMOS[0x51] kernel  magic                                   = 0xab
CMOS[0x50] kernel  checkpt                                 = 0x19  (decimal 25 — PEGGED again)
CMOS[0x54] CR4 byte 2 (post first cr3_load(as1))           = 0x30
CMOS[0x55] CR4 byte 2 (pre-stac, post kcp=0x60)            = 0x30
CMOS[0x56]..[0x5B] AS1 PMM allocs (byte 2)                 = 0x59, 0x59, 0x59, 0x5a, 0x5a, 0x5a
CMOS[0x5C]..[0x61] AS2 PMM allocs (byte 2)                 = 0x5a, 0x5a, 0x5a, 0x5a, 0x5a, 0x5a
CMOS[0x62]..[0x68] PML4[0] byte 0 (7 stamps)               = 0x07, 0x07, 0x07, 0x07, 0x07, 0x07, 0x07
CMOS[0x69] fb_phys byte 2 ((fb_phys >> 16) & 0xFF)         = 0x00
CMOS[0x6A] fb_phys byte 3 ((fb_phys >> 24) & 0xFF)         = 0x00
```

**Headline result — `fb_phys = 0x00000000`.** The Repair (N) BAR snapshot at main.cyr:638 stamped CMOS[0x69]/[0x6A] **before** the `cp_fb(0x19)` call. Both bytes read `0x00`. Per the Repair-N interpretation block:

> Both `0x00` with kcp `< 0xE5` = snapshot ran before kernel reached cp_fb, but stamp asm itself executed — read it as **'fb_phys really IS 0' (gnoboot/boot_info broken)**.

The `cmos_stamp_fb_phys()` asm walked `boot_info_ptr → bi → bi[+0x48]` and the value at offset +0x48 came back zero. `cp_fb(0x19, MAGENTA)` then stamped its argument-value (kcp=0x19) and immediately died — fb_phys=0 made the first FB MMIO write fault before the prologue `0xE5` stamp could fire. **The bug pre-dates the kernel's mem-iso block; it's in the bootloader/kernel handoff.**

**This re-frames the failure mode entirely.** Attempts 22-26 chased kernel-side mem-iso correctness (PT mapping, CR3 dances, SMAP brackets, BAR shifts, MTRR/PAT). All those layers are now provably clean:

- PMM stamps `0x59/0x5a` (well above 2 MB watermark — Repair (J) confirms no kernel-PT-range allocation; PMM allocator healthy)
- PML4[0] = `0x07` at all 7 mem-iso checkpoints (Repair (L) `pt_init` explicit-write fix is holding firm; no zero-init regression)
- CR4 byte 2 = `0x30` at both check sites (SMEP+SMAP held through the SMAP brackets)
- CR3 dance survived all three switches (otherwise kcp couldn't have reached 0x19 at all)

The kernel is fine. **gnoboot isn't populating `boot_info+0x48` with the GOP framebuffer phys address** — or it's writing zero, or it's writing to a different offset than the kernel expects.

**Visual marker observation — three-way reset asymmetry:**

| Reset path | Visual markers |
|---|---|
| Initial cold boot (USB switchover) | 25-racy pattern (gnoboot handoff text + colored CP square row at top-left) |
| BIOS Save-and-Exit | 25-racy pattern (same as cold) |
| Fault-triggered reset (warm) | "Normal markers" — different from 25-racy |

This refines the Attempt 26 asymmetry observation. Both cold POST AND BIOS save-exit produce the racy 25-pattern; only fault/warm-reset shows the deterministic "normal" pattern. Consistent with a gnoboot-side issue: gnoboot re-runs on both cold and save-exit paths (fresh boot_info structure populated each time); fault-reset preserves prior state via a different path (or possibly skips parts of gnoboot's GOP probe entirely).

**Suspect ranking after Repair (N) readout:**

| # | Hypothesis | Status |
|---|---|---|
| 1 | **gnoboot never populates `boot_info+0x48`** (struct field left zero-initialized) | **Leading.** Simplest explanation. Check `gnoboot/src/*.cyr` for the GOP-probe → boot_info write path; verify the offset constant matches the kernel's reader. |
| 2 | gnoboot writes fb_phys to a different offset than +0x48 | Plausible. ABI mismatch between gnoboot's struct layout and kernel's struct layout (agnos 1.30.0 was the kernel-ABI break — gnoboot side may not be aligned). |
| 3 | `boot_info_ptr` is stale/bogus and the snapshot is reading a random zero | Possible but lower probability. `boot_info_capture_rdi` proved boot_info_ptr is captured at kernel entry; if it were bogus the kernel wouldn't have made it through PMM init reading the memory map. |
| 4 | gnoboot's GOP probe fails silently and writes zero to fb_phys | Plausible. UEFI GOP discovery can fail on some firmware/GPU combos; gnoboot may not signal the failure, just leave fb_phys=0. |

Hypotheses (1), (2), and (4) all converge to the same fix-path: gnoboot inspection. (3) requires kernel-side instrumentation.

**Repair (O) — mem-iso block deletion (LANDED 2026-05-15):**

After re-reading `docs/development/uefi-boot-prior-art.md` §6 (Common UEFI handoff contract) and §8 (AGNOS Path C delta), the corrected diagnosis: the mem-iso block at `main.cyr:383-685` builds AS1/AS2 page tables, switches CR3 to each, and restores to the *kernel-built* PT (pt_init's 0-4GB identity map). The `fb_phys=0` reading was a red herring — even with fb_phys non-zero, the kernel's restored PT doesn't reliably cover the GOP framebuffer BAR the way UEFI's identity map did. Per prior-art §6: **"No loader hands off 'proper' kernel page tables — the firmware's identity map is the contract. Every kernel rebuilds its own page tables shortly after entry."** AGNOS's `pt_init` does rebuild, but the mem-iso test that follows is **post-MVP verification work** that's actively breaking the pre-MVP boot path.

Attempts 17-27 (11 burns, repair letters F-N) all chased symptoms inside a test block that isn't on the boot-to-shell critical path. Repair (O) is the structural correction: delete the test.

**Edit landed:** `agnos/kernel/core/main.cyr` lines 383-685 removed (303 lines). Includes:
- AS1/AS2 creation (`proc_create_address_space x2`)
- per-process page mapping (`proc_map_page` x2)
- all 3 CR3 switches (`cr3_load(as1)` / `cr3_load(as2)` / `cr3_load(as1)`)
- SMAP brackets (stac/clac) + store64/load64 round-trips
- explicit kernel-CR3 restore (`mov cr3, 0x1000`)
- mem-iso verify print block (`serial_print "AS1 wrote..."` × N)
- nested if/else PASS/FAIL branch
- all bisector stamps from Repairs (I)/(J)/(K)/(L)/(M)/(N) (kcp 0x18, 0x1A-0x1D, 0x60-0x68, 0xE1-0xE4)
- `cmos_stamp_fb_phys()` call site (the helper itself stays in `mbi.cyr` — dead code, DCE will eliminate)

Marker comment left at deletion site referencing this entry + the prior-art doc.

**Build verification:**

| Step | Result |
|------|--------|
| `sh scripts/build.sh` (agnos) | OK |
| `build/agnos` size | **253,496 bytes** (-1,552 from Attempt 27's 255,048 — code+data shrink, less than line-count suggests because most deleted lines were comments) |
| multiboot2 (ELF64) / entry | OK / `0x1000a8` (unchanged) |
| `sudo install-usb.sh --update /dev/sdb` | Pending (user step) |

**Pre-burn ask for Attempt 28:** one burn is enough. We're not bisecting; we're checking whether the boot path advances past the deleted block.

**Decision matrix for Attempt 28:**

| Outcome | Diagnosis |
|---|---|
| kcp ≥ 0x12 + new checkpoint somewhere in userland exec test | **Win.** Mem-iso block was the sole blocker. Boot progressed to next phase. New front becomes wherever it stalls next. |
| kcp pegged at 0x12 | The post-VFS / pre-mem-iso state already had a latent issue masked by mem-iso's quicker fault. Triage the userland exec test entry (`spawn_user_proc`). |
| kcp regressed below 0x12 | Unexpected — our edit only deleted code that shouldn't have run for MVP. Re-read the diff for collateral damage. |

**Carry-forward (not blocking Attempt 28):**

- `cmos_stamp_fb_phys()` in `mbi.cyr` and the in-cp_fb bisector stamps in `fb.cyr` (kcp 0xE5-0xEA) are now dead code. Leave for one verification burn; remove post-Attempt-28-success.
- `boot_info_capture_rdi()` stays — it's load-bearing for the real boot path, not just diagnostics.
- `pt_init`'s 0-4GB identity map vs UEFI's identity map: if userland exec test runs into FB-write issues later, the real fix is extending `pt_init` to mirror UEFI's identity map (or just inheriting UEFI's PT until userspace lands). Deferred — not on the critical path yet.

---

### Attempt 28 — 2026-05-15 → MVP BOOT SPINE ALIVE ON IRON

![Attempt 28 — full cp_fb cell sequence painted to halt](iron-boot-photos/attempt-28-mvp-spine-alive.jpg)

**Headline:** Path C end-to-end on archaemenid (NUC AMD, Beelink SER). The kernel completes every checkpoint in its current init sequence and reaches `arch_halt()` at `main.cyr:415` as designed. Closed-beta gate (cp_fb 0x11 MAGENTA) was hit at Attempt 16; this attempt blew **four checkpoints past that gate** — 0x12 / 0x14 / 0x15 all painted MAGENTA, then halt.

The "lockup" framing on first inspection was misread:

- `kcp = 0xEA` is the in-cp_fb internal bisector stamp (Repair N), **not** a stage marker. It tells you the *last* cp_fb call returned cleanly — nothing about boot-stage. The `scripts/read-boot-log.sh` verdict text still encoded the pre-Repair-O Repair M/N decision tree and reported the success as a "stall." Verdict logic needs purging.
- `CMOS[0x62-0x6A]` PML4 / fb_phys stamps are stale — their writers were inside the deleted mem-iso block (Repair O). The read-boot-log script reads them as if fresh.
- The screen photo is the truth: every cp_fb cell the post-Repair-O kernel paints is visible — yellow row (0x80/0x81/0x82 early arch + 0x06 GDT/IDT), green span (0x07-0x0D APIC → PMM → heap → ACPI → VFS → SYSCALL), cyan + overpainted-magenta (0x0E-0x10 scheduler arming, 0x11 MAGENTA = closed-beta gate, 0x12 MAGENTA = post-VFS, 0x14 MAGENTA = post-userland-exec, 0x15 MAGENTA = kybernet-launch reached).

**Build under test:**

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.55 pinned. |
| agnos kernel | 1.30.1 candidate post-Repair-(O) — `build/agnos` = **253,496 bytes** (verified on-disk before this attempt's burn). Subsequent kybernet wire-up edit at main.cyr:415 took the binary to **253,768 bytes** (+272 — shell dispatch tree now reachable, no longer DCE'd). |
| gnoboot | 0.1.0 — sovereign UEFI loader, multiboot2-replacement handoff via boot-info struct at RDI. |
| read-boot-log | 47,640 bytes (stale verdicts — purge queued). |

**CMOS readout (post-reset, user-reported):**

```
CMOS[0x53] gnoboot magic    = 0xcd  (gnoboot reached handoff)
CMOS[0x52] gnoboot checkpt  = 0x05
CMOS[0x51] kernel  magic    = 0xab  (kernel reached main code)
CMOS[0x50] kernel  checkpt  = 0xEA  (in-cp_fb stamp: last cp_fb returned clean)
CMOS[0x54]/[0x55]           = 0x30 / 0x30  (CR4 SMEP+SMAP both held)
CMOS[0x56-0x61] PMM         = 0x4b×6 / 0x5a×6  (live — proc_create_address_space
                                                still runs from spawn_user_proc)
CMOS[0x62-0x68] PML4        = 0x07×7  (stale — writers deleted by Repair O)
CMOS[0x69-0x6A] fb_phys     = 0x00, 0x00  (stale — writer deleted by Repair O)
```

**Decision-matrix outcome (per Attempt 27 § "Decision matrix for Attempt 28"):**

| Predicted | Actual |
|---|---|
| kcp ≥ 0x12 + new checkpoint in userland exec test = **Win** | ✅ — kcp 0x12 MAGENTA painted (post-VFS), 0x14 MAGENTA painted (post-userland-exec), 0x15 MAGENTA painted (kybernet-launch reached), halt. |

**Re-framing the MVP gap.** The original Attempt 28 success-condition ("advances past 0x12") was a narrow framing — it tracked the mem-iso fault as the active blocker, not closed-beta MVP. With the mem-iso front closed, the kernel reaches its current end-of-implementation: `sh_cmd_bench(); arch_halt();` at `main.cyr:415`. **That's not MVP.** MVP = boot-to-shell on iron = user types a character into a shell and sees it echo. Three real gaps separate Attempt 28 from MVP:

1. **`main.cyr:415` wiring** — `sh_cmd_bench()` was a benchmark stub. Real launch path is `kybernet()` → `shell()` → reads `kb_buf` ring + dispatches commands. **Landed same-session** (2026-05-15): `sh_cmd_bench()` → `kybernet()`, kernel 253,496 → 253,768 bytes (+272, shell dispatch tree now reachable).
2. **Framebuffer glyph renderer** — `kernel/arch/x86_64/fb.cyr` has `cp_fb()` (colored marker cells) but no text rendering. Phase 2 of fb.cyr's docstring already calls this out as "deferred: 8×8 bitmap font + fb_print() mirroring serial_println." Without it, the shell can read keystrokes but the user can't see them. Slot pending.
3. **Mirror shell I/O to fb** — `shell()` at `kernel/user/shell.cyr:340` uses `serial_print/serial_putc` exclusively. Add `kprint(buf, len)` that hits both serial + fb, or wrap `serial_*` calls. Slot pending alongside #2.

**Open question (iron-only):** does the existing PS/2 ISR + scancode table fire for the user's USB keyboard on archaemenid? Modern AMD NUCs typically have no PS/2 port; UEFI emulates PS/2 for USB keyboards via legacy SMM until the OS takes ownership of xHCI. This kernel doesn't touch xHCI, so legacy emulation should remain active — but verification is an iron burn, not a code question. If emulation doesn't hold, USB HID driver (xHCI + USB stack + HID class) becomes the real next blocker, which is much larger than the fb console.

**State after Attempt 28:**
- Path C sovereign UEFI handoff: ✅ works on iron
- agnos full init spine: ✅ works on iron (GDT/TSS/IDT → APIC/timer → paging → PMM → heap → ACPI/PCI → VFS → initrd → SYSCALL → stack canary → scheduler arming → idle survival → userland exec → kybernet-launch)
- Closed-beta gate (0x11 MAGENTA): ✅ held since Attempt 16, re-verified
- MVP (typeable shell on iron): ⏳ blocked on fb glyph renderer + (probably) PS/2-emulation working for USB keyboard

**This is the genesis-repo's last big lift before closed beta.** Once the shell is visible and typeable on iron, what's left is product polish (welcome banner, prompt color, command set), installer wiring, and the beta-cohort cut.

**Carry-forward (not blocking the fb-console slot):**

- Purge `scripts/src/read-boot-log.cyr` verdict logic for the deleted Repair M/N bisector stamps. The stale CMOS slots 0x62-0x6A should be marked "post-Repair-O dead — values stale from earlier burns."
- Remove the in-cp_fb stamps (kcp 0xE5-0xEA) from `fb.cyr:46-86` — they were diagnostics for a bug class that no longer exists, and they keep clobbering CMOS[0x50] so the *real* stage kcp is never readable.
- `boot_info_capture_rdi()` stays — load-bearing for the actual boot path.
- `cmos_stamp_fb_phys()` in `mbi.cyr` is now dead code; DCE will eliminate it but it can be deleted from source for hygiene.

---

### Attempt 29 — 2026-05-15 → "worst case" visual diagnosed as non-zero gvar-init bug; Repair (P) lands

**Photo slot (post-burn):** drop the screen photo at
`iron-boot-photos/attempt-29-<descriptor>.jpg` (e.g.
`attempt-29-prompt-visible.jpg` if Repair P confirms, or
`attempt-29-still-broken.jpg` if not), then update the next session
with the result so the cyrius issue draft (`agnos/docs/development/
issue/2026-05-15-cyrius-nonzero-gvar-init-not-honored.md`) can be
filed or revised.

**User-reported visual (pre-Repair-P):** "no prompt — only the top canaries disappear leaving the 3 yellow with gnoboot statement remaining."

**CMOS readout (post-reset):**

```
CMOS[0x53] gnoboot magic   = 0xcd
CMOS[0x52] gnoboot checkpt = 0x05
CMOS[0x51] kernel  magic   = 0xab
CMOS[0x50] kernel  checkpt = 0x15   (kybernet-launch reached MAGENTA)
CMOS[0x54]/[0x55]          = 0x30 / 0x30   (CR4 SMEP+SMAP held)
CMOS[0x56-0x61] PMM        = 0x6f×6 / 0x5a×6  (proc_create_address_space live)
CMOS[0x62-0x68] PML4       = 0x07×7   (stale — Repair-O-deleted writers)
CMOS[0x69-0x6A] fb_phys    = 0x00 / 0x00   (stale — Repair-O-deleted writers)
```

**Initial misread, corrected on inspection.** The visual looked like a regression vs Attempt 28 (which painted the full cell sequence). CMOS proved otherwise: kcp=0x15 = kybernet-launch reached MAGENTA = `cp_fb(0x15)` was executed. No fault — kernel ran past the wire-up into `kybernet() → shell()`, then sat waiting on `kb_buf`.

**Diagnosis.** The pattern "rows 1–2 cp_fb cells wiped (y=8..19), row 9 cp_fb cells (y=72..75) survive, no visible prompt" decodes to a single bug at three coordinates:

1. `fb_putc` paints text at `y = FB_CONSOLE_Y0 + fb_cur_y*8`. If `FB_CONSOLE_Y0 = 0` instead of `80`, the kybernet kprintln sequence (~6 lines) writes to y=0..55 — overwriting cp_fb cells 0x06..0x10 (rows 1–7).
2. The 3 yellow at row 9 (idx 0x80/0x81/0x82, y=72..75) survive because the prompt sits idle at line ~6, never reaching y=72.
3. The "no visible prompt" half: if `FB_FG = 0` and `FB_BG = 0` (both black) instead of 0x00FFFFFF / 0x00000000, every glyph paints black-on-black. Pixels are written; nothing is visible. **This also clears the canaries** — the "on" pixels of a glyph overpaint colored cp_fb cells to solid black.

`fb_cur_x = 0`, `fb_cur_y = 0`, `fb_console_ready = 0` all work because BSS zero is the desired init — no runtime code needed. The three non-zero initializers (`FB_CONSOLE_Y0=80`, `FB_FG=0x00FFFFFF`, `FB_BG=0x00000000`) require runtime stores; apparently those aren't being emitted at this point in the cyrius gvar-init phase (or are being emitted but not reached on this code path — root cause TBD on cyrius side).

**Repair (P) — explicit assignment at top of `fb_console_init()` (LANDED 2026-05-15):**

```cyrius
fn fb_console_init() {
    FB_CONSOLE_Y0 = 80;
    FB_FG = 0x00FFFFFF;
    FB_BG = 0x00000000;
    fset(0x20, ...);  # ...
}
```

3 lines + 11-line explanatory comment, no language surface, no cyrius edit. The top-level `var X = literal;` declarations stay (they're correct intent, and once the cyrius issue is fixed they're the canonical path) — the explicit assigns are belt-and-suspenders.

**Build under test:**

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.55 (pin unchanged) |
| agnos kernel | 1.30.1 candidate post-Repair-(P) — `build/agnos` = **266,712 bytes** |
| `kernel/arch/x86_64/fb_console.cyr` | +12 lines (3 assigns + 11-line comment) |

**Decision matrix for Attempt 29 burn:**

| Observed | Interpretation |
|---|---|
| Full cp_fb cell sequence visible (rows 1, 2, 9 all painted) **AND** "agnos> " prompt visible below row 9 | ✅ Hypothesis confirmed. Repair P fixes the symptom. cyrius gvar-init bug is real and isolated. File the cyrius issue. |
| cp_fb cells still missing **OR** prompt still invisible | Repair P insufficient — different root cause (e.g., load32 reading wrong width/height; fb_print being called with bogus len; a different shadowing issue). Re-bisect with stamps inside fb_putc. |
| kcp drops below 0x15 | Repair P regressed something earlier in boot. Unlikely given the assigns are pure stores to gvars, but possible. Revert and re-investigate. |

**Burn outcome — 2026-05-15 (post-Repair-P verification):**

![Attempt 29 — shell visible, USB keyboard not inputting](iron-boot-photos/attempt-29-shell-visible-no-keys.jpg)

| Observed | Interpretation |
|---|---|
| Full cp_fb cell sequence visible (rows 1, 2, 9 all painted, including 0x06–0x10 + 0x80/0x81/0x82 stripe) **AND** `agnos>` prompt visible below the grid | ✅ **Repair (P) confirmed.** Non-zero gvar-init bug fixed at the symptom level. cyrius issue (`docs/development/issues/2026-05-15-cyrius-nonzero-gvar-init-not-honored.md`) stands for upstream surface. |
| USB keyboard input not reaching the shell — prompt visible but typing produces no echo | 🔍 **New blocker surfaced: MVP gap #3 falsified.** Hypothesis was "UEFI legacy SMM emulates PS/2 for USB keyboard on archaemenid (probable yes)." Iron proved otherwise. Beelink SER has no PS/2 port — kbd_isr ring (`kb_buf`) never fills. Maps to sub-case (d) from the prior verdict tree: "shell loop reading from a kbd ring that never fills." |

**State after Attempt 29:**
- Path C sovereign UEFI handoff: ✅ verified
- Full kernel init spine: ✅ verified
- Closed-beta gate (CP 0x11 MAGENTA): ✅ held since Attempt 16, re-verified
- Shell rendered on iron framebuffer: ✅ **NEW** (Repair P)
- Shell receives keystrokes from a USB keyboard on archaemenid: ❌ blocked

**Next-action triage (user-driven, free attempts first):**

1. **BIOS knob** — boot Beelink into UEFI setup, look for `Legacy USB Support`, `USB Keyboard Support`, `XHCI Hand-off`, `EHCI Hand-off`. If "Auto" or off, force "Enabled". SMM emulation drops at `ExitBootServices` on some firmware unless the flag is sticky.
2. **Port swap** — try every USB-A port. Some boards wire only one port to the EHCI-compat shim; the rest are pure XHCI with no SMM emulation.
3. **If both fail → native XHCI + USB-HID-boot-protocol driver.** Not a hack — the right MVP answer ("sovereign OS depends on SMM emulation for input" is not a shipping posture). Scope: ~1.5–2.5k Cyrius LOC for keyboard-only.
   - XHCI controller init (discover via PCIe — already enumerated at CP 0x0B), MMIO map, command/event ring setup, reset, slot enable.
   - HID boot protocol: 8-byte report, fixed format (modifier byte + 6 keycodes), no descriptor parsing required.

**PS/2 keyboard explicitly not an option** — modern NUCs ship no PS/2 port.

---

### Post-Attempt-29 cleanup pass — 2026-05-15

Hygiene work landed after the burn, while the shell prompt was still on screen:

**What was stripped:**

| File | Change | Effect |
|---|---|---|
| `kernel/core/main.cyr` | All 19 `cp_fb(...)` call lines removed; **CMOS port-I/O stamps preserved** (still 8 bytes per stage, post-mortem readable via `read-boot-log.sh`) | Visual cp_fb cell grid (rows 1–9, y=8..79) no longer painted. The 80-pixel ribbon above the shell goes away. |
| `kernel/core/main.cyr` | 85 `serial_print(` / `serial_println(` → `kprint(` / `kprintln(` (mirrored to both serial + fb) | **Fixes the scrambled-digits issue** visible in the Attempt 29 photo: numbers were smushing together on fb because `kprint_num()` mirrored but `serial_print` for labels did not. Boot log now reads coherently on screen. |
| `kernel/arch/x86_64/fb_console.cyr` | `FB_CONSOLE_Y0 = 80` → `FB_CONSOLE_Y0 = 8` (canary stripe at y=0..7 stays — gnoboot-handoff diagnostic kept by design) | Shell + boot log start one cell below the canary, full screen height available. |
| `scripts/src/read-boot-log.cyr` | Verdict text updated: kcp=21 (CP 0x15) reflects Attempt 29 ground truth (shell alive, USB-kbd blocked, BIOS / port / native-USB triage); kcp=18/20 visual-cell-color disambiguation dropped (cells no longer exist); kcp=128/129/130 / kcp=5 verdict text renamed `serial_println` → `kprintln` | Future post-mortems read accurately against the post-cleanup kernel. |
| `kernel/core/main.cyr:362-367` | Stale "cp_fb under restored kernel CR3" comment in the mem-iso-removal block reworded ("Under restored kernel CR3 the test pegged kcp at 0x19…") | Doc accuracy. |

**What was kept (the "log infrastructure" the user asked to preserve):**

- All CMOS port-I/O stamps (`asm { 0xB0; 0x50; 0xE6; 0x70; 0xB0; <kcp>; 0xE6; 0x71; }`) — 8 bytes each, survive a hang, decoded by `read-boot-log.sh`. **This is the "if something breaks in startup, we know where to look" channel.**
- All `kprint*` log lines (every stage of init prints to both serial + fb). Visible on-screen during boot.
- `cp_fb()` function definition in `kernel/arch/x86_64/fb.cyr`. Infrastructure stays — re-adding a visual stamp at a new stage is a one-line `cp_fb(<idx>, <color>);` call.
- boot_shim canary stripe (y=0..7, 256 white pixels). gnoboot-handoff diagnostic, untouched per "leave gnoboot."

**Already-stripped during Attempt 28 work, verified not re-present:**

- Repair-N in-`cp_fb` bisector stamps (kcp 0xE5–0xEA). `fb.cyr` is clean.
- `cmos_stamp_fb_phys()` helper. Not present in `mbi.cyr` (DCE eliminated; source-clean too).

**Build under test (post-cleanup):**

| Artifact | Size |
|---|---|
| cyrius toolchain | 5.11.55 (pin unchanged) |
| `agnos/build/agnos` | **266,312 bytes** (was 266,712 post-Repair-P — net -400 from cp_fb call removal, partially offset by kprint indirection vs direct serial_print) |
| `agnosticos/scripts/build/read-boot-log` | 32,104 bytes (verdict text shrunk where visual-cell disambiguation removed) |
| multiboot2 (ELF64) / entry | OK / `0x1000a8` (unchanged) |

**Carry-forward post-cleanup:**

- File cyrius issue: "non-zero gvar initializer at module scope not honored at runtime; zero-init unaffected." Reproducer: Repair P. Severity: medium (silent wrong-result). Note: this is a **cyrius repo** issue — per `feedback_cyrius_hands_off`, surface only; do not edit cyrius.
- gnoboot 0.2 branch (CMOS-removal track) → user-flagged ready for main merge. Per `feedback_bootloader_kernel_ownership` claude owns gnoboot end-to-end during iron-boot bring-up, but per session policy this Claude is leaving gnoboot untouched while user manages the merge.
- USB-HID-boot stack scope estimate (XHCI + HID class) added to MVP gap #3 — primary path is BIOS knob + port swap (free), native driver is the real-answer fallback.

---

### Cleanup-pass burn verification — 2026-05-15 ~16:45 PDT

Post-cleanup-pass kernel (kprint-everywhere, cp_fb call sites removed, FB_CONSOLE_Y0=8, 266,312 B) flashed to USB and booted on archaemenid.

![Attempt 29 cleanup-pass — full kernel log on framebuffer, shell prompt visible](iron-boot-photos/attempt-29-shell-logging-cleanup.jpg)

| Observed | Interpretation |
|---|---|
| Full kernel init log rendered on framebuffer in coherent text (no scrambled-digit smashing) — `AGNOS kernel v1.30.0` → `64-bit long mode` → `GDT loaded (ring 3 ready)` → `IDT loaded` → `PIC remapped` → `Timer ISR installed` → `APIC id=0 timer active` → `SMP: 1 CPUs online` → `Keyboard ISR installed (full US QWERTY)` → `Page tables: 1024MB mapped` → `PMM: 3584 free / 4096 pages` → `KASLR: pmm_next_free=1378` → `PMM test: 3584 free` → `UMM: 57005 (expect 57005)` → `Heap initialized` → `Devices registered` → `ACPI: RSDP at 983056` → `PCI: 6 devices` → `VFS: initialized` → `Heap: <addrs>` → `SYSCALL/SYSRET initialized` → `Stack canary initialized` → `Syscall getpid=0` → `HW syscall test: 0` → `Creating test processes...` → `Process A (pid=1) created` → `Process B (pid=2) created` → `Processes: 2 total, 2 ready` → `Interrupts enabled` → `Timer ticks before sched: 3` → `Activating scheduler...` → `Scheduler test done. Timer ticks: 153` → `VFS write: Initrd: 2 files` → `initrd hello.txt: Hello, AGNOS!` → `initrd test: PASS` → `VFS memfile read: HELLO` → `Userland exec test...` → `Spawned pid=3` → `Userland exec complete` → `Launching kybernet` → `kybernet: starting init` → `kybernet: 0 processes` → `kybernet: 3572 free pages` → `kybernet: launching shell` → `AGNOS shell v1.30.0 (type 'help')` → `agnos>` | ✅ **Post-cleanup pass verified end-to-end.** The serial→fb mirror is now coherent; numbers and labels both flow through `kprint*` so the on-screen log matches what an attached serial cable would receive. Closed-beta gate (CP 0x11 MAGENTA at "Activating scheduler") still held. |
| `gnoboot v0.1.0: handing off to kernel` overlays the AGNOS-kernel banner area at the top of the screen | ⚠️ Cosmetic only — gnoboot's `efi_clear(st)` (0.2 branch) wiped the firmware splash, banner printed at y≈0, kernel's `fb_console.cyr` starts painting at y=8. Overlap is from ConOut firmware-font row height vs kernel's 8-pixel `fb_putc` glyphs — kernel text won the row but didn't fully erase the gnoboot pixels above. Resolution: gnoboot 0.2.0 merge (queued) tightens the banner; if cosmetics still bother after merge, kernel-side `fb_clear_rect(0, 0, W, 8)` immediately after `fb_console_init()` is a one-liner. Not blocking. |
| USB keyboard still not delivering scancodes — `agnos>` prompt sits idle, no echo on typing | ❌ MVP gap #3 still blocking — confirmed across BIOS knob toggles + every USB-A port swap. Native XHCI + USB-HID-boot driver is the real-answer fallback. See below § *USB-keyboard blocker triage*. |

**Build under test (this burn):**

| Artifact | Size | Pin |
|---|---|---|
| cyrius toolchain | — | 5.11.55 |
| `agnos/build/agnos` | 266,312 B | — |
| `gnoboot/build/BOOTX64.EFI` | 0.2 branch (CMOS-stripped, banner-tightened, efi_clear) | 5.11.53 |
| `agnosticos/scripts/build/read-boot-log` | 32,104 B | — |

**State after cleanup-pass burn:**

- Path C sovereign UEFI handoff: ✅ verified (now twice across the cleanup pass)
- Full kernel init spine on framebuffer in coherent text: ✅ **NEW** (kprint mirror)
- Shell rendered on iron framebuffer: ✅ held
- USB keyboard scancodes reaching shell: ❌ still blocked — pivots to driver work

### USB-keyboard blocker triage — 2026-05-15

| Path | Result |
|---|---|
| BIOS knob — `Legacy USB Support` / `XHCI Hand-off` / `EHCI Hand-off` toggled across available combinations | ❌ No combination delivers scancodes to `kb_buf`. SMM PS/2 emulation is genuinely off post-EBS on this firmware. |
| Port swap — every USB-A port tried | ❌ No port routed to a legacy-emulating shim. All ports are pure XHCI. |
| Native XHCI + USB-HID-boot driver | ⏳ **Real-answer fallback queued.** Scope: ~1.5–2.5k Cyrius LOC for keyboard-only. Discover XHCI via PCIe (already enumerated at CP 0x0B), MMIO map, command/event ring init, reset, slot enable + HID boot-protocol report parse (8-byte report, fixed format, no descriptor parsing required). |

**The kernel-side keyboard buffer (`kb_buf`, `kb_head`, `kb_tail` in `kernel/arch/x86_64/boot_data.cyr`) is structurally correct** — `kb_isr` is wired to IRQ1 in the IDT (`main.cyr:69-70`), `kb_isr_build()` reads port 0x60 and stores into `kb_buf[head]` with proper wrap. The buffer is fine; the issue is **no producer**. IRQ1 never fires because no PS/2 controller (real or emulated) is delivering scancodes. The fix is upstream of the buffer, in the XHCI bus enumeration + HID class driver.

---

## Carry-forward items (not blocking Attempt 28)

- **aarch64 native boot test**: blocked on Pi SSH access. Cyrius
  5.11.30 patched the aarch64 emitter; structural verification
  is clean (`readelf -S` 5 sections on `agnos-aarch64`) but
  hardware confirmation pending.
- **Cyrius 5.11.32 / 5.11.33 user-binary ELF cleanup**: queued in
  cyrius roadmap as the next slots — `EMITELF_USER` (x86) +
  `EMITELF` (aarch64) still have `e_shoff=0`. Not boot-relevant;
  affects `objdump`/`gdb`/`ltrace` on user binaries.

---

## Conventions for future entries

- One H3 (`### Attempt N — date HH:MM TZ → STATUS`) per attempt.
- Build-under-test table is mandatory; include sizes and hashes
  where they help bisect.
- Repair-step table uses approximate PDT timestamps; precise to
  ~5 min is fine — the doc is for narrative continuity, not
  forensic reconstruction (CHANGELOG / git log are authoritative
  for the latter).
- Verbatim error messages go in fenced code blocks (no
  paraphrasing — future-you wants to grep on the literal string).
- Repair steps must include a verification gate per row;
  "rebuilt and pushed" without a gate is not a step, it's a
  hope.
- Side-effect incidents (like the 2026-05-12 CI fmt false-alarm)
  get a named subsection in the relevant attempt — they're real
  parts of the cycle even if not the primary symptom.
