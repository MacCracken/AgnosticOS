# Iron Bring-Up — Process

> **Status**: Distilled 2026-05-15 from the NUC AMD Zen arc (Attempts 1–29). | **Scope**: generic process for bringing AGNOS up on a new hardware target. | **Companion**: [`iron-nuc-zen-log-mvp.md`](iron-nuc-zen-log-mvp.md) is the canonical example arc; the lessons here are extracted from it.

This doc is what you'd hand to a new agent (or a future-you) starting a bring-up on **different hardware**. It captures the *patterns* — diagnostic-channel ladder, decision gates, walls common to any UEFI x86_64 target — without re-litigating the specific bugs the nuc-zen walk found. For the chronological play-by-play of *one* target's bring-up, see [`iron-nuc-zen-log-mvp.md`](iron-nuc-zen-log-mvp.md) (Attempts 1–29, ~6500 lines).

---

## TL;DR

| | |
|---|---|
| **Use when** | starting bring-up on a target that doesn't already have an `iron-<target>-log.md` |
| **Don't use for** | one-off bugs on a target with an existing log (just append to that log) |
| **Outputs you produce** | `iron-<target>-log.md` (Attempts 1..N), `iron-<target>-photos/` |
| **Prior art** | [`uefi-boot-prior-art.md`](uefi-boot-prior-art.md) (industry comparison), [`path-c-sovereign-uefi.md`](path-c-sovereign-uefi.md) (current canonical handoff), [`path-a-elf64-multiboot2.md`](prior-art/path-a-elf64-multiboot2.md) (dead-end, prior art only) |

---

## Naming convention

Every new hardware target gets a `<arch>-<class>` prefix. The first arc that gave us this pattern was `iron-nuc-zen-*`. Future targets keep the same shape:

| Target class | Prefix |
|---|---|
| AMD Zen NUC (any model) | `iron-nuc-zen-` |
| Intel NUC (any silicon) | `iron-nuc-intel-` |
| Raspberry Pi 4/5 | `iron-rpi4-`, `iron-rpi5-` |
| Skytech build (Ryzen + dGPU) | `iron-skytech-` |
| Generic x86_64 desktop | `iron-x86-generic-` (only if no better class fits) |

**Per target**: one `iron-<target>-log.md` (the chronological attempt log) + one `iron-<target>-photos/` directory (USB-cam shots of the framebuffer, useful when the diagnostic channel of the day is "look at the screen and tell me what you see"). Don't reuse a log across targets — each target is its own arc.

---

## Phase 0 — Characterize the target before any iron attempt

Before you flash a USB stick, capture:

| Question | Why it matters |
|---|---|
| Is the dev box the same as the iron target? | Determines whether you have a second host to read serial. If single-machine (no second host), serial cable is structurally unavailable — your post-mortem signal must survive a triple-fault reset on the same hardware. CMOS scratch RAM is the canonical channel; see *Diagnostic channels*. |
| What CPU class? (Skylake / Zen / Coffee Lake / Cortex-A57 / …) | Determines which post-EBS state quirks you'll hit. AMD Zen has SMEP+SMAP, RDRAND, PDPE1GB. Older Intel may lack `-cpu max` features. ARM is a different boot world entirely. |
| What firmware? UEFI version? OVMF or vendor? | Vendor UEFI 2024+ is strict-W^X NX-marks `EfiLoaderData`, refuses self-patching `.text`, doesn't zero `AllocatePages` returns. OVMF defaults were looser until ~2024. Linux distros bypass these because they use `linuxefi`. AGNOS does not. |
| Does the BIOS expose a Legacy USB / XHCI Hand-off knob? | If yes, USB keyboard *might* still work via SMM PS/2 emulation post-EBS. If no, plan for a native XHCI + HID driver from day one. Verify the knob actually works rather than trusting the BIOS label. |
| Does `/dev/nvram` work on the live Linux you'd use to read CMOS? | Some BIOSes set a non-standard CMOS checksum that makes the Linux `nvram` driver refuse every read (`-EIO`). Diagnose this *before* attempting — if dead, port-IO directly via `iopl(3)` + `out 0x70` / `in 0x71` (see `agnosticos/scripts/src/read-boot-log.cyr`). |
| Which CMOS slots does the BIOS clobber on cold boot? | Cyrius `read-boot-log --dump` reads CMOS 0x0E–0x7F. Boot the live Linux fresh from cold POST several times; any slot that changes between boots is BIOS-managed. Put AGNOS signal slots in the *unchanged* region. On archaemenid that's 0x50–0x7F (the BIOS clobbers 0x42/0x43/0x44 every cold POST). |
| What's the USB device topology? Any PS/2 port at all? | If no PS/2 port, plan for the native XHCI + HID driver. If PS/2 is present, the existing `kernel/arch/x86_64/keyboard.cyr` PS/2 path may work without a USB stack. |

Capture all of this in the first section of the target's log. Don't skip — these answers explain why specific walls hit and the next agent won't have your live access to the box.

---

## Diagnostic channels — the ladder

Pick the highest-bandwidth channel your hardware supports, then layer down. Channels are listed in order of "more signal, more setup":

1. **Serial cable to a second host (UART or USB-TTL)**. The classic. Requires a second machine to read the wire. **Skip if dev box == iron target.**
2. **kprint mirror to framebuffer**. Every kernel-side `kprint*` call writes to *both* serial and the GOP framebuffer (paths captured by gnoboot into boot_info offset 0x48). Works pre-shell; produces a continuous boot log on screen.
3. **Visual canary at kernel entry**. ~26 bytes prepended to the kernel boot shim: paint a 256-pixel stripe at the top-left of the framebuffer if gnoboot captured `fb_phys` ≠ 0. Tells you "kernel reached instruction #1." **Ambiguous on its own** (no stripe could mean `fb_phys = 0` or `jmp rax` never landed) — pair with CMOS.
4. **CMOS persistent boot-log**. 8-byte raw-asm writes per checkpoint, survive triple-fault reset. Two slot pairs: one each for the bootloader (gnoboot) and the kernel. Each pair = (checkpoint counter, magic byte). Magic byte distinguishes "stage ran this boot" from "stale CMOS from earlier boot." Read post-mortem via `read-boot-log` Cyrius binary on the live Linux.
5. **MSI-X / interrupt-driven log to fb** (post-MVP). Phase-5 of the USB-HID arc, late xhci work. Lets in-kernel drivers log without polling.

**Rule**: the dev environment dictates the ladder. Don't recommend a channel that requires a second host on a single-machine setup. Three iron attempts were burned on this misread before the rule was internalized (see [`iron-nuc-zen-log-mvp.md`](iron-nuc-zen-log-mvp.md) Attempts 4–7 *Diagnosis 1*).

---

## Repair-letter pattern

When iron attempts start finding bugs faster than they're tagged, name each in-flight kernel fix with a single letter — **Repair (A)**, **Repair (B)**, … through **Repair (Z)** — and reference them across the attempt log + state.md + CHANGELOG. Convention:

- Letter resets per cycle (new minor → start at A again).
- Letter assigned at the moment a fix is *proposed*, not when it lands. A repair can stay (proposed) for multiple attempts if its premise depends on the previous burn's outcome.
- Each letter gets a one-paragraph problem + fix description in the attempt that adopts it. Cross-reference the LETTER, not the line numbers (line numbers rot; letters are stable).
- After a cycle closes, the per-letter entries fold into the CHANGELOG's `### Fixed` / `### Changed` sections under the cycle's release. Don't keep the letter scaffolding in the changelog — it's working notation, not release-history.

The nuc-zen arc used Repairs A–P across Attempts 9–29. Most were single-line edits; a few were architectural (Repair C: timer-ISR push-all-15-GPRs; Repair O: 303-line mem-iso block deletion). Letters O and P were the load-bearing ones for the cycle close.

---

## The premise-audit gate — "stop instrumenting, start grepping"

**Rule**: if a single bug has consumed **3+ diagnostic rounds** of stamp-and-bisect (CMOS stamps, visual stripes, fb-color cells) without resolving, STOP and `grep -r` the `docs/development/` tree for prior research on that specific code path.

The nuc-zen arc burned 9 iron attempts and 11 repair letters (F→N) chasing a bug inside a memory-isolation test block. Repair (O) — *deleting the block entirely* — landed when re-reading [`uefi-boot-prior-art.md`](uefi-boot-prior-art.md) confirmed the block was post-MVP work the prior research had already flagged as "not on the MVP boot path." The justification was sitting on disk the entire time.

**Patterns that trigger the gate:**
- A bisector ladder has more entries than the function it's bisecting has lines.
- Each new repair narrows the death window but doesn't change the death stage.
- You're considering instrumentation that doesn't follow from a hypothesis ("just add stamps everywhere and see what fires").
- The bug only manifests after a particular BIOS state transition (save-and-exit vs warm-reset). Probably racy state, probably not where you've been looking.

When the gate fires, do these in order:
1. `grep -r "<failing-function>" docs/development/` — does any prior research mention it?
2. `git log -p -- <failing-file>` — does the commit history flag a known-fragile path?
3. Re-read the failing code as if it were submitted by someone else — does the function actually belong on the MVP path?
4. If 1–3 yield nothing, *then* go back to instrumentation. But the answer is usually in 1.

---

## "MVP-to-X gap" re-audit pattern

Before adding a subsystem to close a gap to a milestone (shell, networking, audio, …), re-audit the existing kernel to confirm the gap is real. The nuc-zen arc identified an "MVP-to-typeable-shell gap" as three items: (1) fb glyph renderer, (2) serial → fb mirror, (3) USB keyboard input.

**Re-audit found items 1 and 2 were already implemented.** `fb_console.cyr` had shipped an 8×8 CGA font + `fb_putc`/`fb_print`/`fb_println` weeks earlier; `kprint.cyr` had been mirroring all output (serial + fb) since the post-Repair-P cleanup pass. Two of the three "needed subsystems" didn't need anything — only item 3 (USB keyboard) was a real gap.

Cost of skipping the re-audit: a day or two of "let's implement the fb glyph renderer" before discovering it was already there.

**Rule**: when planning a closing-the-gap-to-X arc, list every gap, then `grep -r` for each one to verify it's actually a gap. Save the implementation budget for the gaps that survive the audit.

---

## Per-attempt log entry format

Convention enforced across `iron-<target>-log.md`:

```markdown
### Attempt N — YYYY-MM-DD HH:MM TZ → STATUS

**Symptom** — one paragraph, verbatim observed behavior (no paraphrase
of error messages — readers grep on literal strings).

**Hypothesis** — one paragraph, what we think is happening. Cite the
prior attempt that informed this hypothesis.

**Build under test**

| Artifact | Size | Pin |
|---|---|---|
| `agnos/build/agnos` | N bytes | cyrius X.Y.Z |
| `gnoboot/build/BOOTX64.EFI` | N bytes | cyrius X.Y.Z |

**Verification gate** — what success / partial / failure look like.

**Outcome** — recorded post-burn. Photo reference where useful.

**Repairs proposed for Attempt N+1** — Repair (X), Repair (Y), one-line
each linking to the longer description below or in CHANGELOG.
```

Timestamps are approximate per [`feedback_iron_boot_log_precision`](https://github.com/MacCracken/agnosticos/blob/main/CLAUDE.md) — `~16:45 PDT` is fine; we're not doing forensics, we're keeping narrative continuity.

Photos go in `iron-<target>-photos/attempt-<N>-<descriptor>.jpg`. One descriptor word: `mvp-spine-alive`, `shell-visible-no-keys`, `boot-colors-racy`, etc.

---

## Walls common across UEFI x86_64 targets

These will hit *any* new x86_64 UEFI target. Plan for them up front; the nuc-zen arc paid the discovery cost.

| Wall | What | Mitigation |
|---|---|---|
| **GRUB MB2-EFI strict-W^X fault** | GRUB's `grub_relocator64_efi_boot` self-patches its `.text` via `movabs` to set register state. OVMF 2024+ / vendor UEFI 2024+ refuses these writes (`X64 Exception 0E #PF, ErrorCode 0x3 P=1 W=1`). | Use Path C (sovereign UEFI bootloader, gnoboot). GRUB-multiboot2-EFI is dead under modern firmware. Linux/FreeBSD/Windows all dropped this path by 2023; AGNOS follows. |
| **UEFI `AllocatePages` returns undefined contents** | UEFI 2.x §7.2: returned memory is undefined. QEMU OVMF happens to return zeroes; real firmware leaves POST scratch. Kernel `.bss` reads garbage on iron, triple-faults at first reference. | gnoboot zeroes the BSS gap (`store8(addr, 0)` loop over `[p_filesz, p_memsz)`) after the segment read. One-time cost: a byte loop. |
| **EfiLoaderData is NX-marked** | Strict-W^X firmware NX-marks LoaderData. `jmp` into one #PFs silently on iron (OVMF runs from LoaderData regardless). | gnoboot calls `AllocatePages` with `MemoryType = EfiLoaderCode` (1, not 2) for the kernel destination. |
| **Legacy SMM PS/2 emulation off** | Modern firmware doesn't emulate PS/2 over XHCI post-`ExitBootServices`. Keyboard input does not reach legacy port 0x60. | Native XHCI + USB-HID-boot driver shipped across agnos 1.30.0–1.30.5; MVP gate iron-cleared at Attempt 68 (2026-05-18, agnos 1.30.9). Historical scope: [`../archive/usb-hid-keyboard-driver-shipped.md`](../archive/usb-hid-keyboard-driver-shipped.md). |
| **`/dev/nvram` may be dead on live Linux** | Some BIOSes set a non-standard CMOS checksum; Linux nvram driver rejects every read with `-EIO`. | Read CMOS via `iopl(3)` + raw port-IO (`out 0x70 / in 0x71`). `read-boot-log` Cyrius binary does this; no kernel driver needed. |
| **BIOS clobbers some CMOS slots every cold POST** | Different BIOSes touch different slots — RTC at 0x00-0x0D, plus vendor-specific (archaemenid: 0x42-0x44). | `read-boot-log --dump` to identify the safe range. AGNOS currently uses 0x50-0x7F as the signal range. |
| **`AGNOS shell v…` banner overlays gnoboot banner on framebuffer** | Cosmetic only. gnoboot's `efi_clear` wipes the firmware splash but its banner prints with firmware-font row height (~14 px); kernel `fb_console` starts at y=8 with 8-pixel glyphs. Kernel "wins" the row but doesn't fully erase pixels above. | Either accept (it's cosmetic) or land a kernel-side `fb_clear_rect(0, 0, W, 8)` one-liner immediately after `fb_console_init()`. |

---

## Cyrius-side gotchas surfaced by iron work

When bringing up new hardware exposes a Cyrius bug, **surface it to the cyrius repo, don't fix in-place**. Per [`feedback_cyrius_hands_off`](https://github.com/MacCracken/agnosticos/blob/main/CLAUDE.md), cyrius is hands-off during kernel work; iron attempts often reveal cyrius issues that need their own cycle to address upstream.

Known cyrius bugs surfaced by iron work to date:
- **Non-zero gvar initializer at module scope not honored at runtime** (surfaced Attempt 29; workaround: explicit assignment at top of init() body before any other code).
- **Asm blocks referencing `[rbp-N]` are positional**. The convention is documented in `ring3.cyr:25` — *params at rbp-0x08, -0x10, -0x18; new locals start at rbp-0x20*. Multiple iron walls have been single-line asm-block-with-wrong-offset bugs.

When a kernel bug bottoms out at a cyrius behavior, file under `cyrius/docs/development/issues/YYYY-MM-DD-<issue>.md` (per `feedback_cyrius_hands_off`) and work around in the kernel; don't patch cyrius from within the iron-boot session.

---

## Cycle close — when is a target "validated"?

A target is **iron-validated** when:

1. Cold-boot lands at the AGNOS shell prompt on the target's display.
2. The full kernel init log renders coherently on the framebuffer (no scrambled digits, no missing labels).
3. CMOS reaches the highest kernel checkpoint that the build is designed to print before shell-launch.
4. The post-mortem `read-boot-log` reads cleanly (CMOS slots are stable).
5. The remaining gaps (keyboard input, network, etc.) are *named* — known blockers with a scoping doc and a roadmap, not unknown unknowns.

The cycle's CHANGELOG should fold all in-flight repair letters back into release-history form before tagging. Keep the per-target log open for future cycle work; don't "archive" — it's a living record of *this* hardware target.

---

## Prior art (consult before starting)

- [`uefi-boot-prior-art.md`](uefi-boot-prior-art.md) — how Linux, FreeBSD, OpenBSD, Windows, Limine boot under UEFI. AGNOS converged on the same architectural shape via Path C. Read first.
- [`path-c-sovereign-uefi.md`](path-c-sovereign-uefi.md) — the AGNOS sovereign UEFI handoff design (gnoboot → kernel via 80-byte boot-info struct in RDI). This is the current production path.
- [`path-a-elf64-multiboot2.md`](prior-art/path-a-elf64-multiboot2.md) — the abandoned approach (GRUB + multiboot2 + ELF64 + EFI64 entry tag). Useful as prior-art reference for *why* Path C exists; do not start a new bring-up here.
- [`iron-nuc-zen-log-mvp.md`](iron-nuc-zen-log-mvp.md) — the canonical example arc, Attempts 1–29. Read § *Diagnosis 1*, § *Diagnosis 2*, and § *Attempt 28 / MVP BOOT SPINE ALIVE ON IRON* for the highest-density lessons.

---

## Related

- [`../archive/usb-hid-keyboard-driver-shipped.md`](../archive/usb-hid-keyboard-driver-shipped.md) — the 5-phase scope for closing MVP gap #3 (USB keyboard input on modern UEFI firmware). Archived 2026-05-21 — shipped + MVP-gate iron-validated.
- [`feedback_iron_boot_log_precision`](https://github.com/MacCracken/agnosticos/blob/main/CLAUDE.md) — timestamps are approximate; don't pause work to ask for exact wall-clock.
- [`feedback_known_knowledge_first`](https://github.com/MacCracken/agnosticos/blob/main/CLAUDE.md) — the premise-audit gate codified.
- [`feedback_primary_target_focus`](https://github.com/MacCracken/agnosticos/blob/main/CLAUDE.md) — filter reviews to one target at a time during bring-up.
- [`project_single_machine_dev_setup`](https://github.com/MacCracken/agnosticos/blob/main/CLAUDE.md) — `archaemenid` IS the iron-boot target for the nuc-zen arc; informs the diagnostic-channel ladder.
