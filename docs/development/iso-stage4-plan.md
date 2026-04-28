# ISO Stage-4-Only Plan — First Bootable AGNOS Image

> **Status**: Drafted 2026-04-27 | Approach: live-image first | Scope: x86_64 headless
> **Supersedes**: the LFS-style "Phase 1" framing in `iso-pipeline.md`
> **Defers**: Stages 1–2 (cross-toolchain + chroot build of glibc/coreutils) to a later phase
>
> **NEXT AGENT — START HERE.** This is the next active work item after the
> 2026-04-27 boot-pipeline updates. Read this document, then resolve the
> "Open decisions" section with Robert before writing any code.

---

## What this plan is

A focused first-cut path to an actual bootable `.iso` artifact for AGNOS,
using **only the binaries already built across the ecosystem** (the 26-of-26
components currently READY per `boot --iso-check`). It deliberately **skips**
the LFS-style toolchain bootstrap and chroot-builds-from-source work that
the original `iso-pipeline.md` Phase 1 calls for.

**Goal in one line**: produce `agnos-x86_64.iso` that boots in QEMU and runs
kybernet as PID 1 from already-built artifacts.

**NOT a goal yet**: rebuilding AGNOS from source on a clean machine (that's
the eventual self-hosting story; deferred to a later phase).

---

## Why this cut first

The original `iso-pipeline.md` correctly sets the full Phase 1 as a Linux
From Scratch–style bootstrap: download GCC / glibc / binutils sources,
build a cross-toolchain, chroot, build the base system from zugot recipes
in dependency order. That's an **honest reproducible distro**, and we want
it eventually — but it's *months* of recipe-driven build work, not days.

The Stage-4-only cut is **live-image-first**: take what's already built,
package it into a bootable squashfs + GRUB ISO, prove it boots. This:

- Produces a real artifact in days, not weeks
- Demonstrates AGNOS booting on real hardware (the May 1 V1 headline)
- Validates the whole component chain end-to-end at runtime
- Defers the hard "rebuild from source" question to a later phase, when
  takumi is Cyrius-ported and zugot recipes are exercised at scale

**The trade-off**: the early ISO is *not* yet self-bootstrapping — it
carries pre-built binaries from the dev host. Most distros took years to
get to self-bootstrap; we don't need it on day one.

---

## Inputs (verified READY 2026-04-27 via `boot --iso-check`)

```
=== Summary ===
  Total:    26
  Ready:    26
  Missing:  0 required
PASS: All required ISO components present.
```

| Layer | Components |
|---|---|
| Boot Chain | kernel (agnos 1.26.1), kybernet 1.0.2, cyrius 5.7.21, ark 0.8.0, nous 1.1.1 |
| Security | sigil 2.9.4, kavach 3.0.0 |
| Agent Layer | daimon 1.1.4, hoosh 2.0.0, agnoshi 1.0.0, bote 2.5.1, t-ron 2.0.0 |
| Infrastructure | agnostik 1.0.0, agnosys 1.0.2, argonaut 1.5.0, libro 2.0.5, itihas 2.2.0, sankoch 2.1.0 |
| Recipes | zugot (build-order.txt) |
| Optional | shravan 2.3.2, hadara 1.0.0, avatara 2.3.0, ai-hwaccel 2.0.0, abaco 2.1.0, bsp 1.1.2, mabda 2.5.0 |
| Host Tools | qemu, grub-mkrescue, mksquashfs, xorriso 1.5.8 |

All artifact paths under `../../<repo>/build/<repo>` from `scripts/`.

---

## Open decisions — RESOLVE BEFORE CODING

These are not implementation details; they shape the plan. Each needs an
explicit answer from Robert before the next agent writes `iso.cyr`.

### D1. Kernel choice — what kernel does the ISO carry?

Three candidates:

- **D1a — Host vmlinuz**: copy `/boot/vmlinuz-*` from the dev host into the
  ISO. Fastest path. Minor reproducibility concern (kernel comes from the
  build host's distro). *Pragmatic default for a first artifact.*
- **D1b — agnos kernel as multiboot**: AGNOS already boots in QEMU via
  multiboot1 (`make boot-test` works today). Use the agnos binary directly
  as the bootable kernel. **Clean sovereignty story** — but agnos is a
  sovereign kernel that doesn't yet drive the full hardware stack a Linux
  kernel does. May be too thin for "boots on real hardware that isn't QEMU."
- **D1c — Custom-built Linux kernel**: cross-build a stripped Linux kernel
  pinned to AGNOS's needs, package as `vmlinuz`. More work; better story
  than D1a; honest reproducibility.

**Recommended path**: D1a for the *very first artifact* (proves the pipeline),
then D1c for the May 1 V1 release (proves reproducibility), then D1b becomes
available as the kernel matures. **Robert's call.**

### D2. C runtime — do AGNOS binaries need glibc?

AGNOS binaries are Cyrius-compiled. They use Linux syscalls directly via
`agnosys`. Question: do any of them link against glibc / dynamic-link
anything from `/lib/`? Or are they fully statically linked sovereign
binaries that need *no* libc in the rootfs?

If fully sovereign — squashfs rootfs is just AGNOS binaries + minimal
`/etc` and `/usr` layout. Tiny image.

If glibc-dependent — rootfs needs glibc (either copied from the dev host's
`/lib/`, or pulled from a Linux distro base). Larger image, more
reproducibility caveats.

**Need to verify** by running `ldd build/<binary>` on each AGNOS-native
binary and checking for dynamic libraries.

### D3. Init / initramfs — what gets to PID 1?

kybernet is the design's PID 1 — but the ISO boot flow is:

1. GRUB loads kernel + initramfs
2. Kernel runs initramfs `/init` to mount the squashfs as `/`
3. `pivot_root` to the squashfs
4. Exec PID 1 (kybernet)

Two questions:
- What does `/init` in the initramfs look like? Minimal busybox + mount
  commands? Or a tiny custom shell-or-Cyrius binary that does the
  mount-and-pivot dance?
- Does kybernet handle the post-pivot init flow today, or does it need
  argonaut spinning up first?

**Need to read kybernet's startup expectations** before writing initramfs.

### D4. Where the new code lives — extend `boot.cyr` or new `iso.cyr`?

`scripts/src/boot.cyr` is currently a thin QEMU launcher + status reporter.
ISO assembly is a different concern (build pipeline, not runtime launcher).

- **D4a — extend `boot.cyr`** with `--iso` mode. Single binary, fewer
  files. Mixes concerns slightly.
- **D4b — new `scripts/src/iso.cyr`** as a separate entry point. Clean
  separation. Two binaries (`build/boot` + `build/iso`). The Makefile
  already advertises `make boot-iso` so wiring an `iso` binary into that
  target is natural.

**Recommended path**: D4b. Cleaner separation, easier to evolve the
ISO pipeline independently from the QEMU launcher.

---

## Pipeline stages (Stage 4 only — Stages 1–3 deferred)

Numbering matches the existing `iso-pipeline.md` so the relationship is
clear.

- **Stage 0 — Resolve Components**: ✅ DONE. `boot --iso-check` reports
  26-of-26 READY.
- **Stage 1 — Bootstrap Cross-Toolchain**: ❌ DEFERRED. Not needed for
  live-image cut.
- **Stage 2 — Build Base System in chroot**: ❌ DEFERRED. Not needed.
- **Stage 3 — Install AGNOS Components**: ✅ implicit (we use the
  already-built artifacts in place; no install step beyond copying into
  the rootfs layout).
- **Stage 4a — Assemble initramfs**: NEW. Pack a minimal initramfs that
  mounts the squashfs and execs into the squashfs `/sbin/init` (kybernet).
- **Stage 4b — Build squashfs rootfs**: NEW. Lay out `/usr/bin`,
  `/usr/lib/agnos`, `/etc`, `/var`, install AGNOS binaries, write
  `/etc/os-release` + `/etc/hostname` + service files.
- **Stage 4c — Assemble ISO**: NEW. Generate GRUB config (boot menu:
  AGNOS / AGNOS recovery), `grub-mkrescue` + `xorriso` to produce the
  bootable image, generate SHA256.
- **Stage 5 — Validate**: NEW. Boot the ISO in QEMU, scrape serial output
  for AGNOS banner, exit 0 on banner match.

---

## Files to create / modify

```
scripts/
├── src/
│   ├── boot.cyr           (existing — leave alone)
│   └── iso.cyr            (NEW — Stage 4 pipeline)
├── templates/             (NEW)
│   ├── grub.cfg.tmpl      (GRUB config template)
│   ├── init.tmpl          (initramfs /init script)
│   └── os-release.tmpl    (system identity)
├── tests/
│   ├── boot.tcyr          (existing)
│   └── iso.tcyr           (NEW — Stage 4 test cases)
└── cyrius.cyml            (add second [build] entry for iso.cyr if dual-binary)

config/                    (existing or NEW per repo state)
└── agnos/
    ├── services/          (kybernet → argonaut service files)
    ├── sysctl/            (kernel tunables)
    └── hostname           (default hostname)

docs/development/
├── iso-stage4-plan.md     (THIS DOCUMENT)
└── iso-pipeline.md        (existing — keep as long-term reference)
```

---

## Tasks for the next agent (sequenced)

1. **Resolve D1–D4 with Robert.** Don't code until decisions are made.
2. **Verify AGNOS binaries' dynamic-linkage state** (D2 follow-up).
   Run `ldd` on each AGNOS-native binary; document findings.
3. **Read `kybernet`'s startup contract** (D3 follow-up).
   Read `kybernet/CLAUDE.md` + relevant src to understand PID 1 expectations
   and whether it handles squashfs-pivot-root or needs an init wrapper.
4. **Draft `iso.cyr` skeleton** with stub functions for Stage 4a/4b/4c.
5. **Implement Stage 4a (initramfs)**: dependency-light first cut.
6. **Implement Stage 4b (squashfs rootfs)**: lay out the filesystem, copy
   binaries, write `/etc` files from templates.
7. **Implement Stage 4c (ISO assembly)**: GRUB config generation,
   grub-mkrescue invocation, SHA256.
8. **Wire `make boot-iso`** to invoke `./build/iso` (or the chosen entry
   point per D4).
9. **Implement Stage 5 (QEMU validation)**.
10. **CHANGELOG entry** in `agnosticos/CHANGELOG.md` under a new dated
    section. Bump VERSION.
11. **Update roadmap** Active Work table — mark Stage-4-only ISO ✅ DONE,
    pivot to Phase 2 (LFS bootstrap) as the next item.

---

## Scope discipline

**In scope** (Stage-4-only first cut):
- x86_64 only
- Headless minimal profile only
- QEMU boot validation only (real-hardware testing comes later)
- Already-built binaries from sibling repos
- GRUB + squashfs + initramfs assembly via host tools

**Out of scope** (deferred or separate work):
- LFS Stage 1 (cross-toolchain bootstrap) — Phase 2
- LFS Stage 2 (chroot recipe build of glibc/coreutils/bash) — Phase 2
- aarch64 / RISC-V multi-arch — Phase 4 (unblocked by Cyrius 5.0+;
  defer to later)
- Desktop profile (aethersafha / Mesa / PipeWire) — Phase 3
- Persistent storage / installable mode — separate work
- Self-bootstrapping (ISO can rebuild itself from source) — Phase 2 with
  takumi Cyrius port
- aegis / aethersafha Cyrius ports — pending repo work

---

## Relation to `iso-pipeline.md`

`iso-pipeline.md` is the **long-term reference document** describing all
stages and the eventual self-hosting endpoint. This document is the
**near-term execution plan** for the *first* deliverable. The two
documents are not in conflict; this one carves a smaller scope out of the
larger one and ships it first.

When Stage-4-only ISO is shipping, both documents should be updated:
- `iso-pipeline.md`: mark Stage 4 as **implemented** (Stage-4-only cut);
  reframe the LFS bootstrap as Phase 2.
- `iso-stage4-plan.md`: archive or mark as completed; subsequent phases
  get their own focused plan docs as needed.

---

## Timeline estimate

Days, not weeks — IF D1–D4 get clear answers up front. Indicative:

- D1–D4 resolution: 1 session with Robert
- iso.cyr skeleton + Stage 4a: 1 day
- Stage 4b (rootfs layout + binary copy): 1–2 days (most of the work)
- Stage 4c (ISO assembly): 1 day
- Stage 5 (QEMU validation): 0.5 day
- Polish / CHANGELOG / roadmap update: 0.5 day

**Total**: ~4–5 working days from decision-resolution to first booting
ISO artifact.

---

## Final note for the next agent

If the user pushes for "just start building it," the four open decisions
(D1–D4) need answers before any line of `iso.cyr` is written. Cyrius is
strict; manifest pins are real; pick wrong on D1 and the build pipeline
gets reshaped twice. Brief the user on the four questions, get answers,
then code.
