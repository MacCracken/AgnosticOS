> **Last Updated**: 2026-05-13

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

### Attempt 5 — pending (Path A build)

Direction confirmed by the Diagnosis above. A bare v1.29.1-or-v1.29.2
retry on iron is no longer informative — the root cause is upstream of
any patch to the existing 32-bit shim. Attempt 5 will exercise the
new Path A build.

**Implementation scope** (each step independently verifiable; see
forthcoming plan doc for detail):

1. **Cyrius patch — new `EMITELF64_KERNEL`** in `src/backend/x86/fixup.cyr`
   (sibling of existing `EMITELF_KERNEL` at line 664; references the
   user-binary ELF64 emit at line 827 for size/layout patterns). Emits
   ELF64 header (64-byte) + PH64 (56-byte) + EM_X86_64 + multiboot2
   header (`0xE85250D6` + arch 0 + tags) + `MULTIBOOT_HEADER_TAG_ENTRY_ADDRESS_EFI64`.
   Non-trivial; ~200 lines. Likely lands as cyrius 5.11.32 (next free
   slot per the user-binary cleanup queue).
2. **agnos kernel shim rewrite** for long-mode entry. Expect
   `RAX = 0x36d76289` (multiboot2 magic), `RBX = MBI ptr`, paging on,
   GDT inherited from UEFI, 64-bit CS. Drop the 32-bit CR4 setup
   (UEFI already configured CR4); drop stack-setup-in-32-bit-mode logic;
   walk the MBI tags as 64-bit structures. Bump agnos to 1.30.0
   (kernel ABI change — ELF32→ELF64).
3. **scripts/install-usb.sh** — generated grub.cfg: `multiboot` → `multiboot2`,
   `module` → `module2`. Trivial.
4. **QEMU OVMF UEFI test** — boot under emulated UEFI (not `-kernel`,
   which uses Linux protocol). Exercises the same `grub_relocator64_efi_boot`
   path iron will use. If this passes, iron is a high-probability
   success.
5. **Iron Attempt 5** — full re-provision (not `--update`) with the
   Path A USB. NUC AMD.

---

## Carry-forward items (not blocking Attempt 5)

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
