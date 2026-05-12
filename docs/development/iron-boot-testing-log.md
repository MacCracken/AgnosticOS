> **Last Updated**: 2026-05-12

# Iron Boot Test Log

Append-only running log of AGNOS **boot-to-shell-on-iron** test
attempts. The closed-beta MVP gate is boot-to-shell on real
hardware (Skytech Legacy 4 + Pi 4); this log tracks each
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
| Target hardware (primary) | Skytech Legacy 4 (x86_64) |
| Target hardware (secondary) | Raspberry Pi 4 (aarch64) |
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

### Attempt 2 — pending

**Awaiting**: project leader to reboot Skytech Legacy 4 with
patched USB, F-key boot menu → select USB → observe GRUB
behavior.

**Build under test** (what's currently on `/dev/sdb` per the
`install-usb.sh --update` output at 2026-05-12 ~15:30):

| Artifact | Version / Size |
|----------|----------------|
| cyrius toolchain | 5.11.29 |
| agnos kernel | 1.29.0 — `build/agnos` 250936 bytes, **5 section headers** |
| initramfs | `scripts/build/initramfs.cpio.gz` 295325 bytes (unchanged from Attempt 1) |

**Expected outcome (success):** GRUB menu appears (3-second
timeout, default = "AGNOS — Closed Beta MVP (boot to shell)"),
kernel banner `AGNOS kernel v1.29.0` prints over serial / VGA,
followed by 64-bit long-mode handoff, GDT/IDT/PIC/APIC init,
scheduler, PMM/VMM, ACPI/PCI, VFS, SYSCALL/SYSRET, eventually
reaching a shell (agnoshi).

**Failure modes worth distinguishing if it doesn't succeed:**

| Symptom | Diagnosis hint |
|---------|---------------|
| Same `grub_elf32_get_shnum` chain | USB content drift — verify with `cmp` against `/home/macro/Repos/agnos/build/agnos` |
| GRUB loads kernel but black screen / no banner | Boot-shim CR4 SMEP/SMAP issue (`-cpu max` exposes it in QEMU; real silicon since Haswell/Ryzen supports both — but check BIOS settings) |
| Banner prints but hangs early (pre-scheduler) | ACPI / PCI quirk on Skytech hardware — capture serial log; cross-ref against QEMU `-cpu max` trace |
| Banner prints, scheduler runs, but no shell | Likely kybernet or agnoshi-side issue, not boot chain — different failure class |

---

## Carry-forward items (not blocking Attempt 2)

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
