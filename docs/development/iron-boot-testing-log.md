> **Last Updated**: 2026-05-14

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

## Carry-forward items (not blocking Attempt 10)

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
