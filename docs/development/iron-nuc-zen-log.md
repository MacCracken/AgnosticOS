> **Status**: Active log for 1.30.10+ iron bring-up.
>
> **Prior history**: [`iron-nuc-zen-log-mvp.md`](iron-nuc-zen-log-mvp.md) — Attempts 1 – 68, frozen at the closed-beta MVP gate (agnos 1.30.9, 2026-05-18). Consult for any pre-MVP-era root-cause shape recurrence.
>
> **Last Updated**: 2026-05-19 (log open)

# Iron Boot Test Log — Post-MVP

Append-only running log of AGNOS iron-boot work **after the
closed-beta MVP gate hit** (Attempt 68, 2026-05-18). Same primary
target (NUC AMD archaemenid Beelink SER); same format conventions
as the MVP-era log.

The MVP gate (boot-to-shell with typeable keyboard on iron) is closed.
Work in this log advances **post-MVP** scope: framebuffer refresh
quality, networking, storage, eventually multi-host validation. The
v1.0 (public beta) gate adds full userland ABI + self-hosting on iron;
this log tracks the iron-side milestones along that path.

**Format**: each attempt gets one `### Attempt N — YYYY-MM-DD
HH:MM TZ → STATUS` block. Attempt numbering continues from the
MVP-era log (next is **Attempt 69**). Never rewrite past entries; if
a later attempt clarifies an earlier root-cause, add a note to the
later entry pointing back. Status is one of `FAIL` / `PASS` /
`PARTIAL` / `PENDING`.

---

## Standing context

| Item | Value |
|---|---|
| Primary target | **archaemenid** — Beelink SER, AMD Zen-class, x86_64 |
| Secondary target | Pi 4 / aarch64 (Pi SSH access blocked at MVP gate; carry-forward) |
| Build host | Same as target (archaemenid) — single-machine dev setup |
| Bootloader | [gnoboot](https://github.com/MacCracken/gnoboot) — sovereign UEFI app, Path C handoff |
| Boot-info struct | magic `0x41474E4F` ('AGNO'); RDI handoff; `fb_phys` at +0x48 |
| Install path | `agnosticos/scripts/install-usb.sh --update` writes a fresh kernel to USB |
| Diagnostic readback | `agnosticos/scripts/read-boot-log.sh` decodes CMOS slot 0x50–0x7F |
| Visual canary | framebuffer paint (cell grid retired post-1.30.1; text console authoritative) |
| **Display context** | **Arcade cabinet (Chewlex)** — bezel crops some edge pixels on photo captures. Right/left/top/bottom strips of the framebuffer are not visible in photos; "lower FB region noise" descriptions refer to the cabinet-visible lower band, not necessarily the literal `fb_height-1` rows. Edge-localized hypotheses (pitch padding C2, height-overshoot) cannot be ruled out from photos alone — fixes must be evaluated on whole-screen behavior. |
| **QEMU verification** | `scripts/qemu-fb-visual.sh` boots the full Path-C chain (gnoboot → kernel) in a visible window — bypasses cabinet cropping for whole-screen verification. Requires `qemu-ui-gtk` package or `DISPLAY_BACKEND=vnc` (VNC fallback, no package install needed). Same kernel binary as iron install — A/B before burning. |

---

## Open carry-forward from MVP era

Items flagged at Attempt 68 closeout, in priority order for post-MVP work:

### Framebuffer refresh quality (1.30.10 active scope)

Visible refresh is poor on archaemenid; pixel-pattern noise in the
lower FB region after bench scrolls (visible in
`iron-nuc-zen-photos/attempt-68-bench-three-tier-on-iron.jpg`).

Pending audit (no burn proposed; awaiting photo disambiguation):

- **C1 — Scroll perf**: `fb_scroll_up` does ~2M `load32+store32` pairs per scroll at 1080p. Bench output triggers many newlines → many full-screen redraws. Most likely "poor refresh" root cause. Fix: chunked block-copy per row. Single biggest win for 1.30.10.
- **C2 — Pitch-padding correctness**: if archaemenid GOP has `ppl > hres`, padding bytes between `width*4` and `pitch` are never touched (init clear and scroll inner loops bound at `width`, not pitch). Stale firmware paint leaks. Visual signature: right-edge stripes.
- **C3 — VGA-vs-HDMI handoff** (1.30.11 hardening): no kernel-side guard against firmware reprogramming the display during EBS→kernel-entry. Needs confirmation canary + measurement under actual cable types.
- **C4 — Obsolete gvar-init defensive workaround** (1.30.11): `fb_console.cyr:60–71` was a workaround for cyrius 5.7.19 gvar-init-order bug; fixed in cyrius 5.11.64. Now dead code worth cleanup.
- **FB BAR memtype**: verify PAT entry is WC, not UC. UC FB mapping makes scroll cripplingly slow and would compound C1.

Roadmap split: **1.30.10** = C1 + C2 (perf + correctness); **1.30.11** = C3 + C4 + BAR memtype (hardening). Then **1.30.12** = glyph-to-font extraction (below). Then 1.31.x = storage or networking.

### Glyph-to-font extraction (1.30.12 scope)

`fb_console.cyr` currently bakes 96 CGA 8x8 glyphs into the source via inline `fset(0x20, 0x...)` calls (96 × ~22 chars/line = ~2 KB of hex literals at the top of the init function). This is fine for getting to the MVP gate but doesn't scale:

- New fonts require source edits + rebuild — no opportunistic font swap.
- Tooling can't sanity-check glyph coverage (it's data hiding in code).
- No path to share the font format with userland renderers like `BannerManor`.

Planned work:

- **Define a font-file format**. Probably CYML, possibly aligned with [`BannerManor`](https://github.com/MacCracken/bannermanor)'s M2 CYML font format (the user is working that arc in parallel — `bannermanor/docs/development/roadmap.md` § M2). If the schemas converge, kernel + userland render against one format. If they need to diverge (kernel doesn't want CYML parser dep), the kernel format is a tighter binary blob compiled in at build time.
- **Externalize the CGA 8x8 glyph table** from `fb_console.cyr` inline `fset` calls into a font-file shipped under `kernel/arch/x86_64/fonts/` (or wherever the convention lands).
- **Loader path**: at boot, kernel reads (or compiles in) the font blob and points the glyph table at it. Same `fb_putc` render code, different glyph source.
- **Bonus**: extending the table beyond ASCII 0x20–0x7F becomes a font-file edit, not a code change.

Scope dependency: lands **after** 1.30.11 hardening because the framebuffer geometry / scroll-perf work touches the same render code; doing both in flight at once = harder bisects. Lands **before** 1.31.x networking/storage because rendering quality is user-facing and should stabilize before adding scope.

### Multi-device USB / xHCI (post-MVP carry-forward — surfaced 2026-05-19)

Iron observation Attempt 69 post-burn: connecting a second USB device
(Bluetooth Mouse) while the keyboard is also attached causes the
keyboard input path to stop working properly. Single-device boot
(keyboard only) remains green at 1.30.10.

Current driver assumes one HID slot context (`agnos/kernel/arch/x86_64/usb/`).
Hypothesis space (not yet audited):

- Single Device Context allocated; second enumeration overwrites it
- Single Event Ring without per-interrupter routing; events from the
  second device get consumed by the keyboard's poll path
- Transfer ring conflated across slots
- Boot-protocol SET_PROTOCOL not re-issued for the second device, leaving it
  in Report Protocol mode (HID class default) — kbd interrupts may arrive
  formatted differently than the parser expects

**Prior-art reference** (per `feedback_redesign_dont_reinvent`):
Linux `drivers/usb/host/xhci-mem.c::xhci_alloc_virt_device` is the
canonical multi-slot allocator. Each device gets its own Device Context
Base Array entry, its own Input Context, its own Transfer Rings per
endpoint. Event Ring is shared but events carry Slot ID + Endpoint ID
for routing.

**Scope**: not in 1.30.10 (FB refresh quality). Triage after 1.30.11
hardening closes, before 1.31.x networking/storage opens. Capture as a
read-only audit first (compare AGNOS's slot allocation vs Linux's)
before any code change.

### aarch64 native boot test

Pi 4 / aarch64 boot test blocked on Pi SSH access. Cyrius 5.11.30
patched the aarch64 emitter; structural verification clean
(`readelf -S` 5 sections on `agnos-aarch64`) but hardware confirmation
pending. Tracker carries forward from MVP era.

### Cyrius user-binary ELF cleanup

Cyrius user-binary emitters (`EMITELF_USER` x86, `EMITELF` aarch64)
still produce `e_shoff=0`. Not boot-relevant; affects `objdump` /
`gdb` / `ltrace` on user binaries. Queued in cyrius roadmap for the
next user-binary touch.

---

## Attempts

### Attempt 69 prep — 2026-05-19 → PENDING IRON BURN

First post-MVP burn. Bundles three behavioral changes targeting the
1.30.10 framebuffer-refresh scope. Audit-then-burn shape per
`feedback_redesign_dont_reinvent`; no instrumentation.

**Build under test**

| Item | Value |
|---|---|
| `agnos VERSION` | **1.30.10** (bumped 2026-05-19 per explicit user approval — kernel banner reflects current work) |
| `build/agnos` size | **414,544 B** (was 413,216 B at Attempt 68; +1,328 B) |
| `build/agnos` sha256 | `958944305f29832fab4a6aca33ab507b2ca493471a28f887ac5eca472e64b674` |
| `build/agnos` mtime | 2026-05-19 13:45 |
| Cyrius pin | 5.11.64 (unchanged) |
| gnoboot | 0.2.0 — **unchanged**, no rebuild needed. Path-C handoff ABI stable. |
| Multiboot2 entry | `0x1000a8` (preserved) |
| Visual banner | `AGNOS kernel v1.30.10` / `AGNOS shell v1.30.10 (type 'help')` |

**Behavioral diffs (three changes, all in one burn)**

1. **WC framebuffer mapping** — kernel maps the entire GOP framebuffer region as Write-Combining instead of the default WB-cached.
   - `kernel/core/vmm.cyr` — new `vmm_remap_wc_2mb(phys)` (mirrors `vmm_remap_uc_2mb` structurally; flag `0x8B` = PWT=1, PCD=0, PAT=0 → PAT entry 1 = WC under firmware-default PAT MSR) + `vmm_remap_wc_range(phys, size)` loop helper
   - `kernel/core/main.cyr:8` — `vmm_remap_wc_range(fb_fb_phys(), fb_pitch() * fb_height())` runs immediately before `fb_console_init()`
   - **Why**: WB on framebuffer means CPU pixel writes batch through L1/L2 and reach the display controller on cache evictions — visible as the Attempt 68 pixel-pattern noise in the lower bench-output region. WC coalesces writes into burst transactions, eliminating cache-eviction timing artifacts. Canonical Linux/EDK2 framebuffer mapping.
   - **Prior art**: Linux `vesafb` / `efifb` request `ioremap_wc()` for the framebuffer BAR; same pattern.
   - **Falsifies**: if Attempt 69 still shows lower-region pixel-pattern noise after this remap, the artifact is **not** a WB-cache effect — re-audit toward C3 (VGA-vs-HDMI handoff) or unexpected MMIO timing.

2. **Pitch-aware init clear** — full-screen clear in `fb_console_init` walks `pitch / 4` u32s per row, not `width`.
   - `kernel/arch/x86_64/fb_console.cyr` (~line 70-90) — inner loop bound changed from `width_clr` to `stride_u32 = pitch_clr / 4`
   - **Why**: When firmware's `PixelsPerScanLine > HorizontalResolution`, padding columns between `width*4` and `pitch` carry stale UEFI/firmware paint forever. Cabinet bezel may hide this on archaemenid; QEMU at 1920×1080 verified the loop runs clean at iron extent.
   - **Falsifies**: if a right-edge stripe is visible in the next post-burn photo (and not hidden by cabinet), then ppl > hres on archaemenid AND this fix isn't covering it — investigate gnoboot's GOP capture (`fb_pitch = ppl * 4` assumption).

3. **Pitch-aware scroll clear** — `fb_scroll_up` body copy + bottom-row clear walk `pitch / 4`.
   - `kernel/arch/x86_64/fb_console.cyr` (~line 250-275) — both inner loops bound to `stride_u32`
   - **Why**: Same as #2 but in the scroll path. Padding columns stay coherent with the rest of the FB after every scroll.
   - **Combined-falsifies with #2**: if right-edge stripe is visible after init but disappears after first scroll, the init clear isn't hitting padding — investigate stride math.

**Pre-burn verification (done)**

| Gate | Status |
|---|---|
| Cyrius build clean | ✅ OK, no errors, 32 unreachable fns (DCE potential) |
| Build size sane (+1.3 KB for the diff) | ✅ 413,216 → 414,544 B |
| Multiboot2 ELF64 entry preserved | ✅ `0x1000a8` |
| QEMU Path-C smoke (serial verifies kernel reaches shell) | ✅ PASS — `EXPECT="AGNOS shell"` matched on ConOut |
| QEMU visual at 1920×1080 (std VGA + virtio-vga path) | ✅ Boots clean, scrolls clean, no regression vs default-res baseline |
| gnoboot rebuild needed? | ❌ No — Path-C ABI unchanged, gnoboot 0.2.0 OK |

**Pre-bound outcomes on iron**

| Outcome | Interpretation |
|---|---|
| Boot reaches shell, **no lower-region noise during bench scroll** | **WC remap was the fix.** WB-cache eviction timing was the root cause of Attempt 68's pixel-pattern noise. 1.30.10 ships, move to 1.30.11 hardening. |
| Boot reaches shell, **noise still visible during bench scroll** | WC mapping didn't fix it. Either: (a) the FB isn't actually getting WC on archaemenid (PAT MSR audit needed — verify the firmware PAT entries match expectations); (b) the noise is C3 (handoff race), not a cache effect; or (c) iron-only artifact we haven't modeled. Open re-audit; do NOT iterate by stacking letter-style repairs. |
| Boot reaches shell, **right-edge stripe visible** | ppl > hres on archaemenid; pitch-aware fix didn't fully take. Verify with photo + gnoboot GOP capture readback via CMOS or serial. (Cabinet bezel may hide; pull the bezel for the photo if so.) |
| Boot fails to reach shell (regression vs Attempt 68) | WC remap or pitch loop broke something. Specifics from FB paint state + CMOS post-mortem. Revert candidate: WC remap most likely (broader surface than pitch loops). |
| Boot succeeds, scrolls succeed, **type-test fails** | xHCI HID regression unrelated to fb changes. Diff vs Attempt 68 build — likely unrelated to this burn. |

**Burn protocol**

1. `cd ~/Repos/agnosticos && sudo ./scripts/install-usb.sh --update /dev/sdX` (where sdX is your USB device)
2. Reboot archaemenid, F-key boot menu, select USB
3. Watch boot log → shell prompt
4. Run a multi-line scroll to stress refresh: `help`, then `bench` if 3-tier bench is callable from shell
5. Type some characters; verify typeable shell still works
6. Photo the FB at scroll-pause + at shell-idle for the catalog
7. If clean: queue 1.30.10 version bump (only on your explicit go) + CHANGELOG entry; if noisy: do not iterate, file findings instead

**Photos for the catalog (post-burn)**

Per the catalog README, add entries under "Post-MVP era (Attempts 69+)":
- `attempt-69-wc-pitch-aware-fb-baseline.jpg` — first post-burn FB state at shell-idle
- `attempt-69-wc-pitch-aware-bench-scroll.jpg` — mid-scroll capture during bench output

### Attempt 69 — 2026-05-19 → PARTIAL

Burned 1.30.10 on archaemenid; boot reached typeable shell and refresh
was perceptibly improved, but only marginally. Lower-region pixel-pattern
noise from Attempt 68 is reduced under the WC mapping but the overall
scroll still feels heavy under bench output. WC mapping + pitch-aware
clears DID help (cache-eviction artifacts gone) but were not sufficient.

Additional finding flagged by user: **with a second USB device connected
(Bluetooth Mouse), the keyboard input path stops working properly.**
Single-device boot remains green. Multi-device xHCI behavior is unaudited;
the current driver assumes one HID slot context. Linux's
`drivers/usb/host/xhci-mem.c` (`xhci_alloc_virt_device`) is the
prior-art reference for multi-device slot allocation. **Not in
1.30.10 scope** — captured here as a post-MVP carry-forward to triage
once FB refresh stabilizes.

Status: **PARTIAL**. WC + pitch-aware fix landed but scroll perf
remains the dominant visual quality issue. Move to u64 block-copy
(Attempt 70 below) without another full-stack audit — the diff is
narrow and the WC mapping result already falsifies the "cache
eviction" hypothesis cleanly.

### Attempt 70 prep — 2026-05-19 → PRE-BURN GATES GREEN, PENDING USER BURN GO

**Build under test**

| Item | Value |
|---|---|
| `agnos VERSION` | 1.30.10 (unchanged — under-1.30.10 sub-iteration) |
| `build/agnos` size | **414,544 B** — identical to Attempt 69 floor (same instruction widths; u64 vs u32 MOV encodings are the same length on x86-64) |
| `build/agnos` sha256 | `d4e04c57973db90f7c8476abac99b91ba34fc8cce2c8cc6a0eadefac3469fa58` (was `958944305f29832fab4a6aca33ab507b2ca493471a28f887ac5eca472e64b674`) |
| `build/agnos` mtime | 2026-05-19 14:56 |
| Cyrius pin | 5.11.64 (unchanged; cycc 6.0.0 host emits an expected drift warning per the v6.0.0 cycle-open back-compat note in state.md) |
| gnoboot | 0.2.0 — unchanged |
| Multiboot2 ELF64 entry | `0x1000a8` ✅ preserved |

Targets the residual scroll-perf gap left by Attempt 69. Single-file,
single-purpose: switch `fb_scroll_up` body + bottom clear and
`fb_console_init` full clear from u32 to u64 granularity. Halves the
inner-loop count; on WC-mapped FB the write combiner fills 8-byte
bursts per cycle instead of 4-byte. No shadow buffer (PMM-cap
infrastructure blocker — see audit notes); no additional behavioral
changes.

**Why u64 and not a shadow buffer / rep movsb / hardware pan**

| Option | Status | Reason for / against |
|---|---|---|
| Pixel shadow buffer | ❌ Deferred to 1.31.x | PMM tops out at 16 MB / 14 MB free; 8.3 MB shadow consumes 60% of pages; PMM has no contiguous-page allocator. Needs Multiboot2 memory map parse + `pmm_alloc_contig` first. |
| `rep movsb` / ERMSB | Considered | Equivalent to u64 loop on modern Zen for FB→FB, more invasive to express in current Cyrius (would need an `asm` block). u64 is a one-line change; revisit if u64 isn't enough. |
| Hardware pan / GOP base offset | Considered | Needs GOP base-address rewrite + handoff ABI change. Much bigger surface; right answer long-term but not for 1.30.10. |
| Cell buffer (Linux fbcon shape) | Deferred to 1.30.12 | 64 KB cell tracking is the canonical text-console substrate, but it doesn't itself reduce scroll cost — it shines once we have font-extraction + dirty-rect tracking. Stack with glyph-to-font work. |

**Behavioral diffs (one change, one file)**

`kernel/arch/x86_64/fb_console.cyr` — three inner loops switch from
`store32`/`load32` per-u32 to `store64`/`load64` per-u64. Outer
row-iteration unchanged. Pre-loop computes `stride_u64 = pitch / 8`
instead of `stride_u32 = pitch / 4`.

1. **`fb_console_init` full clear (~lines 96-103)** — sweep zeros the
   whole framebuffer via u64 stores. Loop count: `(pitch/8) × height`
   = 960 × 1080 = ~1.04M store64 (was 1920 × 1080 = ~2.07M store32).
2. **`fb_scroll_up` body copy (~lines 276-282)** — top-down per-row
   `load64`/`store64`. Loop count per scroll: `(pitch/8) × (height-8)`
   = 960 × 1072 = ~1.03M u64-load+store pairs (was ~2.06M u32 pairs).
3. **`fb_scroll_up` bottom clear (~lines 284-289)** — 8-row zero
   sweep. Loop count: 8 × 960 = 7,680 store64 (was 15,360 store32).
   FB_BG is 0; packed u64 value is also 0 — no shift.

Total per-scroll IO transactions go from ~4.13M (u32 load+store pairs)
to ~2.07M (u64 load+store pairs). The READ side still pays
WC-mapped-FB read latency — if this doesn't perceptibly help, the
falsification is clean: shadow buffer / hardware pan is required.

**Pre-burn verification gates — RESULTS**

| Gate | Status |
|---|---|
| Cyrius build clean (`scripts/build.sh`) | ✅ OK — only the expected `cyrius.cyml pins 5.11.64 but cycc is 6.0.0` toolchain-drift warning per the v6.0.0 cycle-open back-compat note |
| Build size sane | ✅ 414,544 B (identical to floor — same MOV instruction widths) |
| SHA differs from floor | ✅ `d4e04c57…` vs floor `95894430…` (diff is in the binary) |
| Multiboot2 ELF64 entry preserved | ✅ `0x1000a8` |
| `pitch % 8 == 0` at archaemenid resolution | ✅ Iron pitch is 7680 at 1080p (8-aligned). QEMU 1920×1080 matches. Falsification: a future non-8-aligned pitch leaves 4-7 bytes/row dirty (right-edge stripe), same failure mode as the prior u32 path under non-4-aligned pitch. |
| gnoboot OVMF smoke (Path-C handoff line) | ✅ PASS — `gnoboot v0.2.0: handing off to kernel` observed on ConOut |
| Kernel reaches shell under QEMU (serial verification) | ✅ PASS — `EXPECT="AGNOS shell"` matched on ConOut. The kernel ran through both `fb_console_init`'s u64 full clear AND `fb_scroll_up`'s u64 body+bottom paths during boot without faulting on store64/load64 alignment or PAT/WC conflict. |
| `build/agnos` freshness (per `feedback_build_freshness_is_mine`) | ✅ mtime 2026-05-19 14:56; sha256 advanced |
| Visual scroll cleanliness at 1920×1080 (user-side eye-on-glass gate) | ⏳ Requires `scripts/qemu-fb-visual.sh` — user-driven (graphical session needed). Recommended A/B vs prior build before the iron burn. |

**Iron-specific symptom shape (Attempt 69 ground truth, 2026-05-19)**

User-reported iron symptom under bench scroll: **visible "refresh line" walks up the screen** in tick-up-tick-up cadence. This is the signature of scroll copy time being long enough that the display's vertical refresh catches partial-copy state — at 60 Hz the display redraws every ~16 ms, so any copy ≥ a few ms is visually traceable. **QEMU cannot reproduce this** — virtio-vga / std-vga have synchronized copy semantics that hide the iron GOP's racing behavior. QEMU visual gate is WONTFIX for this symptom; iron is the only ground truth for visible-line falsification.

**Pre-bound outcomes on iron**

| Outcome | Interpretation |
|---|---|
| Boot reaches shell, **visible refresh line gone** (or perceptually below threshold) | **u64 was the win.** Copy time halved enough to fit inside the inter-refresh window (or so close to it that the eye doesn't catch tearing). Transaction count was the residual bottleneck after WC. 1.30.10 final cut ready; move to 1.30.11 hardening. |
| Boot reaches shell, **visible refresh line still moving up, just slower / shorter** | u64 helped at the throughput level but copy time is still > display refresh period. Clean falsification of "transaction count dominates" — confirms the only mathematically-certain fix is single-burst write (RAM shadow → FB push, which the WC combiner streams in one continuous burst). **Tee up PMM extension + shadow buffer as 1.31.x** (per the audit in this entry — Multiboot2 memory-map parse + `pmm_alloc_contig`). Don't iterate further on per-cycle granularity. |
| Boot reaches shell, refresh line *unchanged* from Attempt 69 | u64 stores aren't actually achieving 2× throughput on iron — possibly write combiner is already saturated at u32, or PAT entry isn't WC despite the remap. Audit `vmm_remap_wc_*` actual effect (read MTRR/PAT state via MSR) before further FB work. |
| Boot reaches shell, **right-edge stripe appears** | Iron pitch not 8-aligned (unlikely at 1080p; QEMU 1920×1080 would surface it first). Fall back to u32 path for non-8-aligned pitches. |
| Boot fails to reach shell | u64 store/load on FB triggered a fault — alignment trap or PAT/MTRR conflict with WC region. Revert the whole diff. Inspect last-surviving paint state. |
| Boot succeeds, scrolls succeed, type test fails (no BT mouse connected) | Unrelated regression — diff is FB-only, shouldn't touch xHCI. Bisect vs 1.30.10 floor. |

**Burn protocol**

Same as Attempt 69 — `install-usb.sh --update`, F-key boot menu, run
multi-line scroll via `help` / `bench`, photo on scroll-pause + idle.
**No version bump** (per `feedback_no_unprompted_version_bumps`); land
under 1.30.10 unless user directs otherwise. CHANGELOG entry only on
explicit "roll the docs" instruction.

**Photos for the catalog (post-burn)**

- `attempt-70-u64-block-copy-baseline.jpg` — shell-idle reference
- `attempt-70-u64-block-copy-bench-scroll.jpg` — mid-bench scroll
- A/B diff vs `attempt-69-*.jpg` is the visual gate



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
- Side-effect incidents get a named subsection in the relevant
  attempt — they're real parts of the cycle even if not the
  primary symptom.
- **Per `feedback_iron_burns_block_other_work`**: no burn proposed
  without a written line-by-line audit FIRST. Burns hold up other
  work on archaemenid; every instrumentation/diagnostic proposal
  must come with an audit, never bundled as "for free."
- **Per `feedback_no_letter_codes_for_repairs`**: name fixes for
  what they DO (e.g., "EP0 MPS reconciliation"), not by letter.
  Historical letter codes in the MVP log stay as historical
  anchors; new fixes get descriptive names.
- **Per `feedback_redesign_dont_reinvent`**: solved-problem
  subsystems get PORTED from Linux/EDK2/FreeBSD reference impls
  then redesigned to Cyrius conventions. No first-principles
  diagnostic letters.
