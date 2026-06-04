# ISO Stage-4-Only Plan — First Distributable AGNOS Image

> **Status**: Drafted 2026-04-27 · **Rebaselined 2026-06-01** (post-iron-boot, post-gnoboot pivot) | Approach: package the proven `install-usb.sh` boot media as a file artifact | Scope: x86_64 headless
> **Supersedes**: the original GRUB + Linux-`vmlinuz` + `pivot_root` + squashfs framing of this same document (now obsolete — see *What changed since the 2026-04-27 draft*)
> **Defers**: LFS-style cross-toolchain + chroot-from-source build (`iso-pipeline.md` Stages 1–2) to a later phase
>
> **NEXT AGENT — START HERE.** D1/D2 are resolved by what shipped on iron. The
> live decisions are now **N1–N3** (artifact format / rootfs writability /
> rootfs FS). Resolve those with Robert before writing `iso.cyr`.

---

## What changed since the 2026-04-27 draft

The original draft predates the entire iron-boot arc. It assumed a **Linux
live-CD shape**: GRUB loads a Linux `vmlinuz` + initramfs, initramfs mounts a
squashfs and `pivot_root`s into it, then execs kybernet. **None of that is how
AGNOS boots anymore.** What actually shipped and is iron-validated on
archaemenid (Zen) through the 1.40.x arc:

- **gnoboot** (sovereign UEFI PE32+ app) replaced GRUB entirely — the GRUB
  MB2-EFI W^X blocker killed that path. UEFI firmware loads
  `EFI/BOOT/BOOTX64.EFI`; gnoboot loads `/boot/agnos` via
  SimpleFileSystemProtocol and hands off through the sovereign boot-info
  struct (`RDI = &boot_info`, magic `0x41474E4F = 'AGNO'`).
- **agnos is the kernel**, direct — no Linux kernel anywhere in the chain. It
  drives real hardware (NVMe/AHCI/USB-MS storage, r8169 networking, ext2/4
  read+write+extents+jbd2, FAT/exFAT) on iron.
- **PID 1 comes from exec-from-disk**: the kernel mounts the ext4 `agnos-fs`
  partition at `/` and execs kybernet/agnoshi from it (1.40.x exec-from-disk
  + mount-namespace routing, iron-validated on the `14013_final*` burn).
- **The ESP `\boot\initramfs` is filled by gnoboot but not yet consumed.** As of
  **gnoboot v0.5.0** the bootloader loads `\boot\initramfs` (format-neutral path,
  optional) into an `EfiLoaderData` region and fills `initramfs_phys`/`size`
  (offsets 0x10/0x18) — previously **0 for MVP**. The remaining gap is kernel-side:
  `core/initrd.cyr` mounts a synthetic INDR image from a fixed `0x6000` and does
  **not** yet read the boot-info field. (This matters for N1 — a read-only live
  ISO needs the kernel wired to read `initramfs_phys` AND the initramfs **format**
  settled: gnoboot is format-neutral, the kernel's sovereign **INDR** is the
  AGNOS-native direction — *not* Linux `cpio.gz`.)

**The working boot media today** (`install-usb.sh`, iron-proven):

```
GPT  p1  256 MiB  FAT32 ESP (label AGNOSBOOT)  → EFI/BOOT/BOOTX64.EFI (gnoboot)
                                                  /boot/agnos (kernel)
                                                  /boot/initramfs (optional; gnoboot fills
                                                       boot_info, kernel not yet wired)
     p2   25 GiB  ext4 agnos-fs                 → rootfs the kernel mounts at /
     rest unallocated
```

**This plan's job is therefore much smaller than the original draft implied**:
produce that same layout as a distributable *file* (a `.img` or `.iso`),
not a Linux live-CD pipeline. `install-usb.sh` is effectively the reference
assembly already — `iso.cyr` is its file-artifact sibling.

---

## What this plan is

A focused first-cut path to a distributable AGNOS boot artifact, using **only
the binaries already built across the ecosystem**, assembled into the
gnoboot + agnos + ext4-rootfs layout that already boots on iron.

**Goal in one line**: produce `agnos-x86_64.{img,iso}` that boots in QEMU
(OVMF/UEFI) and reaches the agnoshi shell from already-built artifacts —
the same outcome `install-usb.sh` produces on a physical USB, but as a
shippable file.

**NOT a goal yet**: rebuilding AGNOS from source on a clean machine (the
self-hosting story; deferred). Persistent install onto target hardware (that's
**agnova**, the native installer — server-stage work, tracked separately).

---

## Base-OS manifest (what ships in the rootfs)

> **Decided 2026-06-01**: the first Stage-4 base ISO ships the **T0–T3 "base
> stage" profile** (minimal + CLI + self-extension + security). The **T4
> AI-native layer is deferred to a fast-follow profile** (it needs a bundled
> model + network and brings the most moving parts).

**Critical correction to the original 2026-04-27 "26 components" table:** AGNOS
binaries are **statically-linked sovereign** (D2). So **libraries do not ship as
rootfs files** — they are compiled *into* their consuming tools. The rootfs
manifest is the **tool binaries only**; libraries are build-time dependencies.
(Re-run `boot --iso-check` for a freshness snapshot, and verify each repo's
`VERSION` — the old "26/26 READY" capture predates agnos 1.30.5 → **1.41.1**,
gnoboot 0.2.0 → **0.4.3**, cyrius 5.11.55 → **6.0.24**.)

### On the ESP (firmware boot, not rootfs)

- **gnoboot** → `EFI/BOOT/BOOTX64.EFI`
- **agnos** (kernel) → `/boot/agnos`

### On the rootfs (ext4 `agnos-fs`) — T0–T3 tool binaries

| Tier | Projects (binary) | Role |
|---|---|---|
| **T0 — minimal bootable** | `kybernet` (PID 1) · `agnoshi`/`agnsh` (shell) · `kriya` (coreutils) · `commandress`/`cmdrs` (prompt) | boot → usable shell |
| **T1 — base CLI** | `owl` (cat) · `cyim` + `cyim-lsp` (editor) · `sit` (git) · `hapi` (dotfiles) · `iam` (sysinfo) · `chakshu`/`shu` (monitor) · `bannermanor`/`bnrmr` + `kii` (banner/MOTD) | working environment |
| **T2 — self-extension** | `ark` (package mgr) · `nous` (resolver; may be ark-internal — verify) | install/update more (maturity-arc "base stage" gate) |
| **T3 — security/system** | `aegis` (security daemon) · `shakti` (privesc) · `kavach` (sandbox) · `phylax` (threat detection) | system-service substrate |

### Deferred to the fast-follow AI profile (NOT in the first base ISO)

**T4 — AI-native layer**: `daimon` (agent orchestrator) · `hoosh` (LLM gateway)
· `bote` (MCP core) · `t-ron` (MCP security). Plus a bundled model. This is the
"AI-Native OS" differentiator; it ships once the base image is proven.

### Build-time libraries (statically linked — NOT rootfs files)

`agnostik`, `agnosys`, `argonaut`, `sigil`, `libro`, `itihas`, `sankoch`,
`mihi`, `darshana`, `abaco`, `hisab`, `mabda`, `bsp`. Needed to *build* the
tools above; they leave no separate artifact on the rootfs.

---

## Open decisions

### Resolved by what shipped on iron — no longer open

- **D1. Kernel choice → RESOLVED: agnos kernel, direct.** The original
  host-`vmlinuz` (D1a) and custom-Linux (D1c) options are dead; agnos drives
  real hardware on iron. gnoboot loads it; no Linux kernel in the chain.
- **D2. C runtime → RESOLVED: fully sovereign, no glibc.** AGNOS binaries are
  statically-linked Cyrius using Linux syscalls via `agnosys`; the ext4 rootfs
  needs no `/lib`, no libc. (Confirm with a spot `ldd` on the shipped binaries
  — expected "not a dynamic executable" across the board.)
- **D4. Where the new code lives → RESOLVED: new `scripts/src/iso.cyr`.**
  Separate entry point; clean separation from `boot.cyr` (the QEMU launcher).
  Two binaries (`build/boot` + `build/iso`).

### D3 (reframed) — the boot-to-PID1 contract

No `pivot_root`, no Linux initramfs flow. The contract is: gnoboot → agnos →
kernel mounts `agnos-fs` at `/` → exec PID 1 from disk. The open sub-question
is narrow: **confirm the exact on-disk PID-1 source** (kybernet path on the
ext4 rootfs, and whether argonaut must spin up first) by reading kybernet's
startup contract before laying out the rootfs. The optional `\boot\initramfs`
(gnoboot fills the boot-info field as of v0.5.0, but the kernel doesn't read it
yet) can be **omitted from the artifact** unless N1 chooses the read-only-ISO
path below.

### New decisions — RESOLVE BEFORE CODING

- **N1. Artifact format — writable `.img` vs bootable `.iso`?**
  - **N1a — raw `.img`** (recommended first cut): a GPT disk image that is a
    byte-for-byte mirror of what `install-usb.sh` writes (ESP + writable ext4
    rootfs). `qemu-img` + loopback assembly; `dd` to a USB to physically boot.
    **Trivial** — it's `install-usb.sh` targeting a file instead of `/dev/sdX`.
    Writable rootfs, no new kernel features needed.
  - **N1b — bootable `.iso`** (optical/El-Torito + EFI System Partition image):
    the classic "live CD." But optical media is **read-only**, so the ext4
    rootfs can't be written in place. That forces *either* a read-only root
    mount (kernel must mount ext4 `ro` and tolerate it — verify) *or* the
    **RAM-rootfs path**: gnoboot loads the initramfs into memory and fills
    `initramfs_phys`, kernel runs root from RAM. **That gnoboot feature is not
    built yet** (it's `0 for MVP`) — so N1b has a real upstream dependency that
    N1a does not.
- **N2. Rootfs writability — writable or read-only?** Ties to N1. N1a gives
  writable for free. A live-ISO wants read-only base (+ optional tmpfs/overlay
  for `/var`, `/etc` — overlay support is itself a kernel question).
- **N3. Rootfs filesystem — ext4 or squashfs?** The current media uses **ext4**
  (kernel reads+writes it, iron-proven). The original draft assumed squashfs —
  but the kernel has **no squashfs read support** (deferred, `roadmap.md`
  row 23). So ext4 is the only proven option today; squashfs would be a new
  kernel-side port. Recommend **ext4** for the first cut.

**Recommended path**: **N1a (.img) + N2 writable + N3 ext4** for the first
artifact — it's the proven media as a file, needs zero new kernel/gnoboot work,
and ships in days. The read-only live `.iso` (N1b) becomes a clean follow-on
once gnoboot grows initramfs-load (or the kernel grows ro-root + overlay).

---

## Pipeline stages (Stage 4 only)

Numbering matches `iso-pipeline.md`. Stages 1–3 deferred / implicit as before.

- **Stage 0 — Resolve components**: re-run `boot --iso-check` for a fresh
  readiness snapshot.
- **Stage 4a — Build the ext4 rootfs image**: lay out `/usr/bin`, `/etc`,
  `/var`; install the agnos-native binaries (kybernet, agnoshi, + chosen
  profile); write `/etc/os-release`, `/etc/hostname`, kybernet/argonaut service
  files; `mkfs.ext4` into a sized image file. (Mirrors `install-usb.sh`'s
  agnos-fs seeding, but into a file.)
- **Stage 4b — Build the ESP image**: FAT32 image with
  `EFI/BOOT/BOOTX64.EFI` (gnoboot) + `/boot/agnos` (kernel). No GRUB config —
  gnoboot reads `/boot/agnos` directly. (Drop the initramfs unless N1b.)
- **Stage 4c — Assemble the artifact**: GPT-combine the ESP + ext4 images into
  `agnos-x86_64.img` (N1a) — or build an El-Torito UEFI `.iso` carrying the ESP
  image (N1b). Emit SHA256.
- **Stage 5 — Validate**: boot the artifact in QEMU under OVMF/UEFI; scrape
  the framebuffer/serial smoke harness (`qemu-fb-smoke.sh`) for the agnoshi
  banner; exit 0 on match.

---

## Files to create / modify

```
scripts/
├── src/
│   ├── boot.cyr           (existing — QEMU launcher; leave alone)
│   ├── install.cyr        (existing — STALE: header still says "GRUB snippet";
│   │                        update or supersede — its initramfs build is now
│   │                        vestigial for the default path)
│   └── iso.cyr            (NEW — Stage 4: rootfs + ESP + artifact assembly)
├── templates/             (NEW)
│   ├── os-release.tmpl    (system identity)
│   └── hostname.tmpl
├── tests/
│   └── iso.tcyr           (NEW — Stage 4/5 test cases)
└── cyrius.cyml            (add a second [build] entry for iso.cyr)

config/agnos/              (NEW or per-repo — service files, hostname)

docs/development/
├── iso-stage4-plan.md     (THIS DOCUMENT)
└── iso-pipeline.md        (long-term reference — update Stage 4 to gnoboot model)
```

Note: much of Stage 4a/4b duplicates logic already in `install-usb.sh`
(partition layout, mkfs, file placement). Consider whether `iso.cyr` and
`install-usb.sh` should share a single source of truth for the media layout so
they can't drift.

---

## Tasks for the next agent (sequenced)

1. **Resolve N1–N3 with Robert** (D1/D2/D4 already settled above). Don't code
   until the artifact-format decisions are made.
2. **Re-run `boot --iso-check`**; refresh the component inventory.
3. **Spot-`ldd` the shipped binaries** to confirm the D2 sovereign assumption.
4. **Read kybernet's startup contract** (D3 follow-up) — exact PID-1 path on
   the rootfs; whether argonaut must precede it.
5. **Draft `iso.cyr` skeleton** with stub functions for Stage 4a/4b/4c.
6. **Implement Stage 4a (ext4 rootfs image)** — the bulk of the work.
7. **Implement Stage 4b (ESP image)** — gnoboot + kernel; no GRUB.
8. **Implement Stage 4c (artifact assembly)** — `.img` (N1a) or `.iso` (N1b).
9. **Implement Stage 5 (QEMU/OVMF validation)** via `qemu-fb-smoke.sh`.
10. **Wire `make boot-iso`** to `./build/iso`.
11. **CHANGELOG + VERSION** bump (per the no-unprompted-bump rule: on Robert's
    go); **update roadmap** (mark Stage-4 ISO done; ISO becomes a shipping
    distribution path) and `iso-pipeline.md` (Stage 4 → gnoboot model).

---

## Scope discipline

**In scope** (Stage-4-only first cut): x86_64 only · headless profile only ·
QEMU/OVMF validation · already-built binaries · gnoboot + agnos + ext4 layout ·
`.img` artifact (N1a default).

**Out of scope** (deferred / separate work): LFS cross-toolchain + chroot build
(Phase 2) · self-bootstrapping ISO (Phase 2 w/ takumi port) · read-only live
`.iso` w/ RAM-rootfs (blocked on gnoboot initramfs-load) · squashfs rootfs
(blocked on kernel squashfs read, roadmap row 23) · persistent install onto
hardware (**agnova**, server stage) · aarch64/RISC-V multi-arch (Phase 4) ·
desktop profile (aethersafha — Phase 3).

---

## Relation to `iso-pipeline.md`

`iso-pipeline.md` is the long-term reference (all stages → eventual
self-hosting). This is the near-term execution plan for the *first* artifact.
When the Stage-4 `.img` ships, update both: `iso-pipeline.md` Stage 4 → the
gnoboot model (not GRUB); this doc → mark the `.img` cut complete and split the
read-only `.iso` follow-on into its own plan when gnoboot grows initramfs-load.

---

## Timeline estimate

Days, not weeks — and shorter than the original estimate because `install-usb.sh`
already proves the assembly and N1a is "the same thing, to a file."

- N1–N3 resolution: 1 session with Robert
- iso.cyr skeleton + Stage 4b (ESP, small): 0.5 day
- Stage 4a (ext4 rootfs layout + binaries): 1–2 days (most of the work)
- Stage 4c (.img assembly): 0.5 day
- Stage 5 (QEMU/OVMF validation): 0.5 day
- Polish / CHANGELOG / roadmap: 0.5 day

**Total**: ~3–4 working days from decision-resolution to a booting `.img`.

---

## Final note for the next agent

D1/D2 are settled by iron — do not reopen "what kernel / does it need glibc."
The live fork is N1 (`.img` vs `.iso`), and it carries a real dependency: the
read-only `.iso` path needs gnoboot to load the initramfs (a feature still at
`0 for MVP`). Default to the writable `.img` first cut; it needs no new
upstream work and mirrors the media that already boots on hardware.
