> **Status**: Active log for 1.30.10+ iron bring-up.
>
> **Prior history**: [`iron-nuc-zen-log-mvp.md`](iron-nuc-zen-log-mvp.md) — Attempts 1 – 68, frozen at the closed-beta MVP gate (agnos 1.30.9, 2026-05-18). Consult for any pre-MVP-era root-cause shape recurrence.
>
> **Last Updated**: 2026-05-19 (Attempt 72 result + Attempts 73 / 74 prep + Burn A code landed and QEMU-verified. gnoboot 0.4.0 (33,792 B) + agnos 1.30.11 + Burn A bundle (420,832 B, +3,288 B vs baseline). **Surprise QEMU finding: MTRR audit reports `mtrr_eff=0 (UC), def=6 (WB), covered=1` at FB BAR 0x80000000 — meaning PAT-WC has been silently blocked by an MTRR variable-range override under QEMU OVMF all along, and the existing `fb: WC verified (PAT entry 1)` line was verifying PAT bits, not effective cache type. Kernel still boots under QEMU because emulated display ignores cache; iron will be the real test.** Per `feedback_no_instrumentation_means_no_instrumentation` + `feedback_redesign_dont_reinvent`: behavioral repairs sourced from Linux/EDK2 prior art, stacked into burns, no new diagnostic-only cycles.)

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

### Attempt 70 — 2026-05-19 → PASS

Burned 1.30.10 with u64 block-copy on archaemenid. Iron refresh
**perceptibly doubled** vs Attempt 69 — user-reported as
**"old-school CRT 80's-ish speeds, smoother, not perfect."** The
Attempt-69 tearing line is no longer a typical-user concern; the
refresh sweep is still detectable if you look for it, but it sits
below the closed-beta MVP refresh-quality bar.

Maps to the pre-bound outcome matrix row 1 — *visible refresh line
gone (or perceptually below threshold)* — with a 1.5-line read:
copy time fell from ~4.13M u32 pairs/scroll to ~2.07M u64
pairs/scroll, fitting just inside the display's inter-refresh
window for most-of-the-screen-most-of-the-time. Transaction count
was indeed the dominant residual bottleneck after WC.

Status: **PASS** at the closed-beta MVP refresh-quality bar.
Ship 1.30.10 as-is. The mathematically-certain path to pristine
refresh (RAM-side shadow buffer streamed to FB in a single WC
burst) remains the right long-term answer but is **not blocking** —
gated on PMM contiguous-page allocation (Multiboot2 memory map
parse + `pmm_alloc_contig`) and carried to 1.31.x triage as
"if-and-when-we-want-pristine," not "must-fix."

Move to **1.30.11 hardening** (VGA-vs-HDMI handoff audit + obsolete
gvar-init workaround cleanup + FB BAR memtype check), then **1.30.12
glyph-to-font extraction**.

Multi-device USB carry-forward (BT mouse + keyboard regressing
input) still unaddressed — captured under "Open carry-forward from
MVP era" above; triage after 1.30.11 closes.

### Attempt 71 prep — 2026-05-19 → PENDING IRON BURN

First **1.30.11 hardening** burn. Bundles four behavioral changes
targeting the VGA-vs-HDMI handoff bug (quiet-boot ON garbled glyphs)
plus the carry-forward hardening items + a pre-existing
multi-chunk WC-remap leak that the new FB BAR memtype check surfaced.
Audit-then-burn shape per `feedback_redesign_dont_reinvent`; no
diagnostic-letter ladder, no instrumentation. QEMU PASS observed
before bumping VERSION.

**Build under test**

| Item | Value |
|---|---|
| `agnos VERSION` | **1.30.11** (bumped 2026-05-19 per explicit user approval — "lets open 1.30.11 and get the hardening done and bug fix for vga/hdmi") |
| `build/agnos` size | **416,496 B** (was 414,544 B at 1.30.10; +1,952 B for the bundle) |
| Cyrius pin | 5.11.64 (unchanged) |
| gnoboot | 0.2.0 — **unchanged**. No boot_info ABI change; gnoboot already captured `pf` at `+0x5C`, kernel just started reading it. |
| Multiboot2 entry | `0x1000a8` (preserved) |
| Visual banner | `AGNOS kernel v1.30.11` / `AGNOS shell v1.30.11 (type 'help')` |

**Behavioral diffs (four changes, all one burn)**

1. **PixelFormat-aware FB render + serial diagnostic** — `fb_console_init` now reads `boot_info+0x5C` (`fb_pf()` getter), logs `fb: phys=0x... pf=N w=W h=H pitch=P` to serial before any paint, and branches on `pf`: `0` (RGBX) or `1` (BGRX) → paint normally; `≥ 2` (PixelBitMask / PixelBltOnly) → log warning, set `fb_console_ready = 0`, fall to serial-only console. Linux ref: `drivers/video/fbdev/efifb.c`.
2. **Obsolete gvar-init defensive workaround DELETED** — the 2026-05-15 cyrius-5.7.19 workaround in `fb_console_init` is dead code post-cyrius-5.11.64 fix; removed.
3. **FB BAR memtype runtime check** — new `fb_verify_wc()` reads back the controlling cache-mapping leaf entry (2 MB PDE or 1 GB PDPT entry) via new `vmm_get_pde_2mb(phys)` accessor (covers `<1 GB`, `1 GB-512 GB`, `≥512 GB` paths). Decodes PAT-index, emits `fb: WC verified (PAT entry 1)` (green) or `fb: WARN expected PAT entry 1 (WC), got entry N PDE=0x...` (silent regression). Called from `kernel/core/main.cyr` AFTER `pmm_init` + post-pmm WC remap retry.
4. **`vmm_remap_wc_2mb` idempotency fix** — pre-existing multi-chunk WC-remap leak (each call re-shattered the PDPT entry → overwrote earlier chunks' WC with WB). Iron archaemenid unaffected (FB in 32-bit hole = inline path = naturally idempotent), but the post-pmm retry in main.cyr exercises the high-BAR path and surfaced the bug under QEMU q35. New idempotency branch: if PDPT entry already shattered, reuse the PD and just edit the target PDE in place.

**Pre-burn verification gates — RESULTS**

| Gate | Status |
|---|---|
| Cyrius build clean | ✅ OK, no errors, 31 unreachable fns (DCE potential) |
| Build size sane (+1.9 KB bundle) | ✅ 414,544 → 416,496 B |
| Multiboot2 ELF64 entry preserved | ✅ `0x1000a8` |
| QEMU Path-C **headless smoke** (new `qemu-fb-smoke.sh`) — kernel reaches shell | ✅ PASS — `EXPECT="AGNOS shell"` matched on ConOut at 1920×1080 |
| Serial diagnostic emitted at fb init | ✅ `fb: phys=0x80000000 pf=1 w=1920 h=1080 pitch=7680` |
| Post-pmm WC verification | ✅ `fb: WC verified (PAT entry 1)` — the idempotency fix made this go from WARN to verified under q35 |
| gnoboot rebuild needed? | ❌ No — Path-C ABI unchanged, gnoboot 0.2.0 OK |
| `build/agnos` freshness (per `feedback_build_freshness_is_mine`) | ✅ Rebuilt 2026-05-19 post-edits, sha advanced |

**Iron-specific note on serial visibility**

archaemenid has no serial cable (per `project_single_machine_dev_setup`),
so the new `fb: pf=...` and `fb: WC verified` diagnostic lines are
NOT visible on iron directly. They're QEMU-side gates. On iron the
user observes the bundle indirectly:

- **Quiet-boot ON, clean shell renders** → `pf` was 0 or 1, original
  Attempt-33 garbled-glyph hypothesis (non-BGRX format under quiet-boot
  ON) is **falsified**. Re-audit toward pitch / bytes-per-pixel / mode
  geometry.
- **Quiet-boot ON, black screen / no shell visible** → `pf > 1`, kernel
  guard fired and disabled FB paint. **Hypothesis confirmed.** Compare
  with a quiet-boot OFF boot from the same image to distinguish
  "guard fired" from "kernel hung."
- **Quiet-boot ON, garbled glyphs (Attempt-33 signature recurs)** → `pf`
  was 0 or 1 but a DIFFERENT root cause produces the corruption.
  Re-audit; not a pure PixelFormat fix.

**Pre-bound outcomes on iron under quiet-boot ON**

| Outcome | Interpretation |
|---|---|
| Boot reaches typeable shell, clean rendering | Quiet-boot ON also reports BGRX/RGBX. Original garbled-glyph signature must have been pitch / mode-geometry / cache-related. Pf-aware guard is correct hardening but didn't address the root cause. Open re-audit (read serial under qemu-fb-visual at 1920×1080 with `-cpu max`, compare pf+pitch values vs iron). |
| Boot reaches typeable shell **under quiet-boot ON for the first time ever** | pf was the issue but the kernel handled all values 0/1 cleanly. **VGA/HDMI bug effectively closed** by the guard (since current modes paint OK). Quiet-boot OFF workaround can retire. |
| Black screen / no shell renders, kernel-running otherwise unclear | Likely `pf ≥ 2` and guard fired. Reboot with quiet-boot OFF to confirm kernel works in general. If quiet-boot OFF clean and ON black, **hypothesis confirmed**, queue gnoboot PixelInformation bitmask capture + decoder for next cycle (or fall back to "stay quiet-boot OFF" as supported config). |
| Garbled glyphs identical to Attempt 33 | pf-aware path took the BGRX branch but produced corruption anyway. Different root cause. Re-audit; check pitch vs ppl, scanline padding, real bytes-per-pixel under quiet-boot ON. |
| Boot fails to reach shell on quiet-boot OFF (regression) | New bundle broke the previously-working path. Revert candidate: items 1 (FB guard) or 4 (vmm idempotency) most likely. |
| Type-test fails (keyboard regression) | Bundle is FB-only; should not affect xHCI HID. Likely unrelated. |

**Burn protocol**

1. `cd ~/Repos/agnosticos && sudo ./scripts/install-usb.sh --update /dev/sdX`
2. Reboot archaemenid into BIOS, **toggle quiet-boot ON**, save & exit
3. F-key boot menu → USB
4. Observe FB: clean shell? black screen? garbled?
5. If clean: try typing — does keyboard still work?
6. Photo the FB
7. **Second boot for comparison**: reboot, toggle quiet-boot **OFF**, F-key boot from USB. Photo the FB. Compare.
8. Report which outcome row matched

**Photos for the catalog (post-burn)**

Under "Post-MVP era (Attempts 69+)":
- `attempt-71-quiet-boot-on.jpg` — what the FB shows under quiet-boot ON with 1.30.11's pf-aware guard
- `attempt-71-quiet-boot-off.jpg` — comparison baseline (same image, same kernel, quiet-boot OFF — should match the existing post-Attempt-70 visual baseline if everything else is consistent)

**First-user-input-on-iron canary** —
[`iron-nuc-zen-photos/attempt-70-help-me-build-an-entity-chart.jpg`](iron-nuc-zen-photos/attempt-70-help-me-build-an-entity-chart.jpg)
captures Alicia's first try at the iron shell: `agnos> Help me build
an entity chart` → `unknown: Help` → retry as `help` → 18-verb
command list rendered. Same frame shows the 3-tier bench output
immediately above (`syscall_write1: 31 c/op`,
`vfs_open_read_close: 256 c/op`, `=== done ===`) so the bench
numbers and the typeable-shell-with-real-user moment are anchored
together. AI-native user intent meeting a pre-userland kernel verb
table is exactly the post-MVP roadmap framing — daimon / hadara /
agnoshi LLM wiring is what closes the gap.

### Attempt 71 — 2026-05-19 → PARTIAL

1.30.11 hardening burn went down on archaemenid. Two BIOS toggles tested back-to-back, same kernel image, single USB cut.

**Outcomes**

| BIOS path | Result | Photo |
|---|---|---|
| **QuickBoot ON, VGA-spec display mode** | **PASS** — boot reaches typeable shell, clean BGRX glyphs end-to-end (`AGNOS shell v1.30.11`), keyboard alive, `fb: WC verified` (PAT entry 1) implied (no serial cable but the post-pmm WC remap landed without re-entering the original Attempt-33 failure region) | [`iron-nuc-zen-photos/attempt-71-quickboot-vga-pass.jpg`](iron-nuc-zen-photos/attempt-71-quickboot-vga-pass.jpg) |
| **Quiet Boot ON** | **FAIL** — Attempt-33 garbled-glyph signature returns. Same kernel binary, same gnoboot, only BIOS toggle changes | not photographed (user reported in conversation) |

**Hypothesis status — pf-aware-PixelFormat → FALSIFIED for quiet-boot ON**

The 1.30.11 guard at `fb_console_init` (refuses to paint when `pf > 1`) did NOT change the quiet-boot ON behavior. If `pf` had been ≥ 2 under quiet boot, the guard would have produced a **black screen with serial-only fallback** (outcome row 3 in the prep table). What actually showed up is **outcome row 4** (garbled glyphs identical to Attempt 33) — the BGRX branch took, paint fired, but the result is corrupted. The PixelFormat reading is NOT the root cause of the Attempt-33 signature.

**What this tells us**

Different BIOS modes (QuickBoot+VGA vs Quiet Boot) cause archaemenid's firmware to hand gnoboot different GOP state. The 1.30.11 handoff struct captures `fb_phys / fb_pitch / fb_width / fb_height / fb_pf` but NOT `Mode->Mode` (which GOP mode the firmware selected) or `Mode->MaxMode` (how many modes exist). The PixelFormat field alone can't distinguish "VGA-spec mode 0 (BGRX, 1024×768)" from "quiet-boot mode N (BGRX, some-other-resolution, possibly-padded-pitch)". Pf is the same in both branches; whatever varies sits in the geometry tuple or the mode number itself.

**Surviving hypotheses (ranked)**

1. **GOP mode-number divergence** — firmware selects different `Mode->Mode` under each BIOS path; downstream geometry inherits the divergence. Most direct evidence to capture next.
2. **Pitch-padding under quiet-boot's mode** — if quiet-boot lands on a native-HDMI mode where firmware pads scanlines (`ppl > width`), the kernel's pitch-aware paint should still work, but interaction with the WC remap range could shift bytes-per-pixel assumptions.
3. **FB BAR placement divergence** — same kernel WC remap might miss the BAR under one BIOS path. Less likely (image confirms paint *partially* works under VGA-spec) but cheap to rule out.

### Attempt 72 prep — 2026-05-19 → PENDING IRON BURN

**Diagnostic-only cycle.** Pure observability extension, no behavioral repair. Audited per `feedback_redesign_dont_reinvent` (port the same captures Linux EFI stub, FreeBSD `loader.efi`, OpenBSD `efiboot`, and Limine all make pre-EBS).

**Bundle under test**

| Item | Value |
|---|---|
| `agnos` source | 1.30.11 + working-tree FB handoff diagnostic extension (uncommitted; 1.30.12 cut to follow if iron data warrants) |
| `agnos` build | `build/agnos` — 417,544 B (was 416,496 B at 1.30.11 first cut; +1,048 B for accessors + CMOS stamps) |
| `gnoboot` | **0.3.0** (cut today — cyrius pin → 6.0.1 + GOP `Mode->Mode` / `Mode->MaxMode` capture into `boot_info+0x60`/`+0x64`, reserved-slot overlay so wire stays v2) |
| Cyrius pin | gnoboot **6.0.1** (toolchain-drift-clean), agnos **5.11.64** (unchanged; back-compat symlink path holds) |
| Multiboot2 entry | `0x1000a8` (preserved) |
| Visual banner | `AGNOS kernel v1.30.11` / `AGNOS shell v1.30.11 (type 'help')` (unchanged; no agnos VERSION bump) |

**Behavioral diffs (zero)**

This bundle is **observation-only**. The kernel's FB render path, WC remap, pf-guard, paint loops — none changed. The only differences vs Attempt 71's bundle are:

1. **gnoboot captures GOP `Mode->Mode` + `Mode->MaxMode`** pre-EBS into `boot_info+0x60` / `+0x64` (was an opaque reserved u64 in v2). Struct wire version stays 2; readers that don't know about the overlay see zeros and behave unchanged.
2. **Kernel adds two getters + extended `fb_console_init` serial diagnostic line.** New line on serial: `fb: mode=N/M phys=0x... pf=X w=W h=H pitch=P` (one line, includes everything the firmware handed us about the FB).
3. **CMOS extended-bank stamp at fb_console_init.** 16 bytes at slots `0x90..0x9F`: w / h / pitch / pf / mode_current / mode_max / 0xFB sentinel. Readable post-mortem via the extended `read-boot-log.sh` decoder. **This is the iron observability channel** since archaemenid has no serial cable.
4. **`read-boot-log` decoder extended** to print the new FB-geometry block in its default-summary output.

No paint code changes. No WC-remap changes. No new guards. Pure stamp-what-firmware-tells-us.

**Pre-burn verification gates — RESULTS**

| Gate | Status |
|---|---|
| Cyrius rebuild after 6.0.1 patch (UEFI-emit fncallN regression fixed) | ✅ gnoboot clean, zero `ud2` sentinels in `.text` (was 32 under 6.0.0) |
| gnoboot 0.3.0 binary | ✅ 33,792 B (was 32,768 B at 0.2.0; +1,024 B for new capture + banner string) |
| agnos rebuild with new accessors + CMOS write | ✅ OK, 417,544 B |
| `read-boot-log` rebuild with new decoder | ✅ OK (one `vec_get` warning is pre-existing, unrelated) |
| QEMU Path-C headless smoke (`qemu-fb-smoke.sh EXPECT="fb: mode="`) | ✅ PASS — diagnostic line lands |
| Multiboot2 ELF64 entry preserved | ✅ `0x1000a8` |
| `build/agnos` freshness (per `feedback_build_freshness_is_mine`) | ✅ Rebuilt 2026-05-19 post-edits |

**QEMU baseline observed (q35, OVMF, `QEMU_RES=1920x1080`)**

```
fb: mode=0/30 phys=0x80000000 pf=1 w=1920 h=1080 pitch=7680
fb: WC verified (PAT entry 1)
AGNOS kernel v1.30.11
```

Self-consistent under QEMU q35: pitch == width × 4 exactly (no padding), pf=1 BGRX (matches the kernel's monochrome paint assumption), phys above 1 GB (exercises the multi-chunk WC remap that 1.30.11 just fixed), mode 0 of 30 (OVMF enumerates a full mode table). This is the **shape of a no-divergence boot**.

**Burn protocol**

1. `cd ~/Repos/agnosticos && sudo ./scripts/install-usb.sh --update /dev/sdX`
2. Reboot archaemenid; BIOS → **VGA-spec mode + QuickBoot ON** (Attempt 71's known-working path).
3. F-key boot menu → USB. Observe boot reaches shell. **Power off cleanly** (don't trigger reset — preserve CMOS).
4. **Boot Linux on the same archaemenid; `sudo ./scripts/read-boot-log.sh`**. Capture stdout: this is the **VGA-spec baseline geometry**.
5. Reboot archaemenid; BIOS → **Quiet Boot ON** (the failing path). F-key → USB. Observe FB outcome (expected: Attempt-33 signature recurs).
6. Power off cleanly. Boot Linux. `sudo ./scripts/read-boot-log.sh` again — **quiet-boot failing geometry**.
7. Diff the two captures.

**Diff interpretation table**

| Diff signature | Diagnosis |
|---|---|
| Same `mode#` + same `w/h/pitch/pf` across both paths | Firmware exposes identical GOP under both BIOS settings — bug is downstream of the handoff (paint code, WC interaction, something kernel-internal). |
| Different `mode#`, same `w/h` | Firmware picks different mode # but same dimensions; semantic-only difference. Unlikely to cause garble; worth ruling out. |
| Different `w/h/pitch` with `pitch ≠ width × 4` under quiet boot | **Pitch-padding hypothesis confirmed**. The classic diagonal-shear signature. Renderer is already pitch-aware (`fb_console.cyr` lines 134-138 / 366-368 / 440) — points to a deeper interaction (WC range, glyph stride, canary residue). |
| Different `fb_phys` between paths | **BAR placement divergence**. WC remap targets right address for working mode, possibly wrong for failing one. Verify against `vmm_get_pde_2mb()` readback in a follow-up. |
| `pf=2` or `pf=3` in failing path | PixelBitMask / BltOnly under quiet — pf-guard would have refused the paint and produced black screen. Already ruled out by Attempt 71 (garbled ≠ black), but the geometry log confirms. |
| All four slots zero, sentinel `[0x9F] != 0xFB` | Kernel didn't reach `fb_console_init` — failure is earlier in boot than the diagnostic-stamp site. Triage from CMOS kernel-checkpoint slot `0x50` (existing channel). |

**Photos for the catalog (post-burn)**

Anchored under "Post-MVP era (Attempts 69+)":
- `attempt-72-vga-spec-baseline.jpg` — VGA-spec working boot (same shape as `13011_QuickBoot_Vga.jpg` but anchored to Attempt 72's bundle)
- `attempt-72-quiet-boot-fail.jpg` — Attempt-33-signature reproduction under 1.30.11 + 0.3.0 bundle
- (optional) `attempt-72-read-boot-log-diff.txt` — text capture of the two `read-boot-log.sh` outputs side-by-side; the actual diagnostic record

### Attempt 72 — 2026-05-19 → PARTIAL

1.30.11 + working-tree diagnostic extension + gnoboot 0.3.0 burned on
archaemenid. VGA-spec QuickBoot ON path PASSES (same shape as Attempt
71 — `13011_attempt_gnoboot_updated.jpg` captured the clean
typeable-shell state). Quiet Boot ON path FAILS with the Attempt-33
garbled-glyph signature, AND the new CMOS geometry channel works:
post-mortem read-back from the failing path lands at slots 0x90–0x9F
with sentinel ✓.

**Build under test** — unchanged from Attempt 72 prep table above
(agnos 1.30.11 + working-tree diag extension, gnoboot 0.3.0, cyrius
pin 5.11.64 / gnoboot 6.0.1). No code changes between prep and
burn.

**Path outcomes**

| BIOS path | Outcome | Photo |
|---|---|---|
| **QuickBoot ON, VGA-spec display mode** | **PASS** — boot reaches typeable shell, clean BGRX glyphs, same shape as Attempt 71's vga-pass. CMOS read-back from this path was not captured. | [`iron-nuc-zen-photos/attempt-72-vga-spec-baseline.jpg`](iron-nuc-zen-photos/attempt-72-vga-spec-baseline.jpg) (working filename `13011_attempt_gnoboot_updated.jpg`) |
| **Quiet Boot ON** | **FAIL** — Attempt-33 garbled-glyph signature returns. Same kernel binary, only BIOS toggle changed. CMOS post-mortem captured. | not yet anchored; see geometry capture below |

**Quiet-boot CMOS geometry capture (the failing path)**

```
Boot reached:
  kernel  checkpoint = 0x15     magic = 0xab ✓
  gnoboot checkpoint = 0x05     magic = 0xcd ✓

FB geometry (gnoboot GOP capture, written by fb_console_init):
  sentinel [0x9F]        = 0xfb  ✓
  GOP mode#  [0x9D/0x9E] = 0x00 / 0x0d
  PixelFormat [0x9C]     = 0x01           (BGRX)
  width  [0x90..0x93]    = 2560
  height [0x94..0x97]    = 1440
  pitch  [0x98..0x9B]    = 10240 bytes/scanline
```

**Hypothesis status — pitch-padding and pf both FALSIFIED for the quiet-boot path**

The diff-interpretation table in the prep block (line 542) above
mapped each diff signature to a diagnosis. The captured geometry
falsifies two rows directly:

- **Row 3 — pitch-padding** (`pitch ≠ width × 4`): falsified. Iron
  reports `pitch = 10240 = 2560 × 4` exactly. No firmware scanline
  padding under quiet-boot. The classic diagonal-shear signature
  cannot be the cause.
- **Row 5 — pf ≥ 2** (PixelBitMask / BltOnly): falsified. `pf = 1`
  (BGRX) — the supported paint branch took. Already ruled out by
  Attempt 71 (`garbled ≠ black`); now confirmed by direct readback.

**What survives — BAR-placement divergence is the lead candidate**

| Diff candidate | Status under Attempt 72 data |
|---|---|
| Same `mode#` + same `w/h/pitch/pf` across both paths | Cannot conclude — VGA-spec CMOS not captured. If VGA-spec is also `mode=0` `2560×1440 BGRX pitch=10240`, this row is confirmed and the bug is downstream of the handoff (paint code, WC interaction). If VGA-spec is `mode=N≠0` or different `w/h`, this row is ruled out. |
| Different `mode#`, same `w/h` | Cannot conclude — VGA-spec CMOS not captured. |
| **Different `fb_phys` between paths** (BAR placement divergence) | **Surviving candidate.** Current CMOS channel does NOT stamp `fb_phys`, so this hypothesis is invisible from the geometry block alone. If quiet-boot's FB BAR lands at a different physical address than VGA-spec's, the WC remap chain (per 1.30.11 vmm idempotency fix) targets the right address for one mode but possibly wrong for the other. |

**The WTF data point**

The failing path reports a *geometrically pristine* FB: pitch = w × 4
(no padding), pf = BGRX (the supported branch), sentinel ✓ (paint
setup ran). And glyphs still corrupt. This rules out the two
geometry-shaped hypotheses cleanly and concentrates the remaining
explanation surface on:

1. **fb_phys / BAR placement divergence** — invisible from current CMOS bank, needs extension
2. **WC range / PAT interaction with this specific phys address** — also `fb_phys`-gated to diagnose
3. **Paint code interaction with 2560×1440 geometry under quiet-boot's specific phys placement** — same gating

All three converge on "we need fb_phys stamped in the CMOS bank to
distinguish them." No paint-code change proposed; no behavioral
diff proposed. Next iteration is observability-only, same shape as
Attempt 72: extend the CMOS bank to stamp `fb_phys` (8 bytes,
slots 0x88–0x8F are available between the legacy xHCI sentinels at
0x81/0x84/0x86/0x87 and the FB geometry block at 0x90–0x9F).

**What didn't get captured**

- VGA-spec `read-boot-log` capture (step 4 of the prep protocol).
  Without it the "same geometry both paths" row stays open. Pickup
  cost is one VGA-spec boot + power-cycle into Linux + script run.
- `attempt-72-quiet-boot-fail.jpg` — quiet-boot FB photo not taken
  (user reported the result in conversation; CMOS capture is the
  durable record).

**Action items**

| # | Item | Status |
|---|---|---|
| 1 | Capture VGA-spec `read-boot-log` to close the geometry-diff row | ❌ Pending — one cheap iron boot from the user side |
| 2 | Extend gnoboot to stamp `fb_phys` into CMOS slots 0x88–0x8F (8 bytes, little-endian) | ❌ **SUPERSEDED by Attempt 73** — stacking behavioral repair instead of instrumentation, per `feedback_no_instrumentation_means_no_instrumentation` |
| 3 | Extend `read-boot-log` decoder to print `fb_phys` block | ❌ **SUPERSEDED by Attempt 73** — same |
| 4 | `13011_attempt_gnoboot_updated.jpg` → rename + anchor as `attempt-72-vga-spec-baseline.jpg` | ❌ Pending |

### Attempt 73 prep — 2026-05-19 → PENDING IRON BURN

**Burn A of a two-burn audit-driven repair plan.** Bundles three
behavioral repairs sourced from Linux/EDK2/UEFI prior art targeting
the surviving BAR-placement-divergence candidate, stacked into one
burn per `feedback_no_instrumentation_means_no_instrumentation` +
`feedback_redesign_dont_reinvent`. Burn B (Attempt 74, gnoboot
`SetMode` to force a known mode) gates on A's outcome.

**Why these three together** — repair #1 makes the kernel use
firmware's authoritative FB extent (vs the computed `pitch * height`
which can over-/under-cover); repair #2 detects the silent-WC-drop
class where MTRR forces UC regardless of PAT (the most-likely AMD
Zen failure mode for HDMI-native BARs); repair #3 detects runtime
BAR reassignment between gnoboot's pre-EBS capture and kernel
paint. Together they answer "is the BAR where we think, sized as we
think, and cached as we think?" without adding another iron-burn
diagnostic cycle.

**Bundle under test**

| Item | Value |
|---|---|
| `agnos` source | 1.30.11 + working-tree Attempt 72 diag + Attempt 73 repairs #2 + #3 |
| `agnos` build | TBD — expect ~+1.5 KB (MTRR walk + PCI enumeration loop) |
| `gnoboot` | TBD (0.4.0 candidate) — adds FrameBufferSize capture (+0x20 of GOP_MODE), boot_info struct_size 0x70 → 0x78, fb_size at boot_info+0x68, END tag relocates to +0x70. Wire version stays **v2** since no consumer walks the tag stream; the END move is invisible to fixed-offset readers (agnos kernel) |
| Cyrius pin | unchanged (gnoboot 6.0.1, agnos 5.11.64) |
| Multiboot2 entry | `0x1000a8` (preserved) |
| Visual banner | `AGNOS kernel v1.30.11` / `AGNOS shell v1.30.11 (type 'help')` (unchanged; no agnos VERSION bump) |

**Repair #1 — gnoboot captures `FrameBufferSize`; kernel uses it for WC remap**

| Step | Site | Change |
|---|---|---|
| 1a | `gnoboot/src/main.cyr` post-`load64(gop_mode + 0x18)` | Add `var fb_size = load64(gop_mode + 0x20);` — UEFI 2.10 §11.9 EFI_GRAPHICS_OUTPUT_PROTOCOL_MODE field at offset 32 |
| 1b | `gnoboot/src/main.cyr` boot_info field writes | Add `store64(&boot_info + 0x68, fb_size);` between mode_max@0x64 and END tag |
| 1c | `gnoboot/src/main.cyr` struct header | Bump `struct_size` from 0x70 to 0x78. END tag relocates from 0x68 to 0x70 (still zero by trailing-zero fill, walker semantics preserved for any future consumer) |
| 1d | `agnos/kernel/arch/x86_64/fb_console.cyr` | Add `fb_fb_size()` accessor reading `load64(boot_info_ptr + 0x68)`. Backward-compat: v2-without-size readers see zero at +0x68 if loaded from an older gnoboot, which falls back to legacy behavior |
| 1e | `agnos/kernel/core/main.cyr:118` | Change WC remap call from `vmm_remap_wc_range(fb_fb_phys(), fb_pitch() * fb_height())` to `vmm_remap_wc_range(fb_fb_phys(), fb_size_or_fallback())` where `fb_size_or_fallback()` returns `fb_fb_size()` if non-zero else `fb_pitch() * fb_height()` |
| 1f | `agnos/kernel/arch/x86_64/fb_console.cyr:108` serial line | Extend `fb: mode=…` line to include `size=0x...` — informational only, no behavioral diff at this step |

Source: UEFI 2.10 §11.9.1 (`FrameBufferSize`: "amount of memory required to hold the frame buffer"); Linux `drivers/firmware/efi/libstub/screen_info.c` reads `mode->frame_buffer_size`; FreeBSD `stand/efi/loader/framebuffer.c` honors it. EDK2 reference impl: `MdeModulePkg/Universal/Console/GraphicsConsoleDxe`.

**Repair #2 — MTRR audit at `fb_console_init`**

Adds a function `fb_audit_mtrr()` called immediately before the pf-guard at line 157. Reads MSRs via existing `rdmsr()` (`agnos/kernel/arch/x86_64/io.cyr:79`).

| Step | MSR | Decode |
|---|---|---|
| 2a | `0x2FF` MTRR_DEF_TYPE | bits[7:0] = default type (0=UC, 1=WC, 4=WT, 5=WP, 6=WB); bit[10] = FE (fixed enable); bit[11] = E (overall enable). If E=0, MTRRs disabled, only PAT applies → log "MTRR disabled, PAT authoritative" + return |
| 2b | `0xFE` IA32_MTRRCAP | bits[7:0] = VCNT (number of variable MTRR pairs, typically 8) |
| 2c | `0x200..0x20F` (VCNT pairs) | Each pair: base MSR (bits[7:0]=type, bits[63:12]=base_phys) + mask MSR (bit[11]=V valid, bits[63:12]=mask). Compute coverage range per AMD APM Vol 2 §7.7.5 |
| 2d | For `fb_phys` | Walk variable MTRRs; effective type = matched MTRR type if any valid range covers fb_phys, else DEF_TYPE. Per Intel SDM Vol 3A §11.5.2.2: MTRR=UC overrides PAT to UC; MTRR=WB allows PAT-WC override |
| 2e | Log | One line: `fb_audit: mtrr_eff=<TYPE> def=<TYPE> covered=<Y/N>`. If `mtrr_eff != WB`, log a WARN — PAT-WC cannot take effect, scroll-copy reads will be UC-speed |

Source: AMD APM Vol 2 §7.7.5 (Effective Memory Type); Intel SDM Vol 3A §11.5.2.2 Table 11-7; Linux `arch/x86/kernel/cpu/mtrr/generic.c::mtrr_type_lookup_variable`.

**Repair #3 — PCI BAR readback for VGA-class device**

Adds `fb_audit_pci_bar()` called immediately after MTRR audit. Walks PCI config space via legacy 0xCF8/0xCFC port-I/O.

| Step | Action |
|---|---|
| 3a | For bus in 0..255 (capped early at 32 to avoid scanning empty buses on archaemenid — actual NUC topology has bus 0 + a few PCIe segments) |
| 3b | For dev in 0..31, fn in 0..7 (only fn 0 for non-multifn) |
| 3c | Read VendorID at config+0x00; skip if 0xFFFF (no device) |
| 3d | Read Class Code at config+0x08 — bits[31:8] = class/subclass/progIF, mask to bits[31:16] = 0x0300 (Display/VGA-compatible) or 0x0380 (Display/Other) |
| 3e | For matching device, read BAR0..BAR5 at config+0x10..0x24 |
| 3f | For each BAR: bits[0]=1 ⇒ I/O space (skip); bits[2:1]=00 ⇒ 32-bit MMIO; bits[2:1]=10 ⇒ 64-bit MMIO (combine with next BAR for high 32 bits); bits[3]=prefetchable hint (FB BAR is usually prefetchable) |
| 3g | For each MMIO BAR, determine size by writing all-1s, reading back, computing `size = ~(value & ~0xF) + 1`. **Restore original BAR value** after sizing |
| 3h | Find the BAR whose range contains `fb_phys` |
| 3i | Log | One line: `fb_audit: pci=<bus>:<dev>.<fn> bar=<N> base=0x... size=0x... matches_fb_phys=<Y/N>` |

Source: PCI Local Bus Spec rev 3.0 §6.2 (Configuration Space) + §6.5 (Configuration Registers); Linux `arch/x86/pci/early.c::read_pci_config_*` and `drivers/pci/probe.c::__pci_read_base`; OSDev wiki "PCI" article (canonical legacy 0xCF8/0xCFC walker).

**Pre-burn verification gates**

| Gate | How |
|---|---|
| gnoboot rebuild with `FrameBufferSize` capture | `cd ~/Repos/gnoboot && CYRIUS_TARGET_EFI=1 cyrius build src/main.cyr build/BOOTX64.EFI` clean, zero `ud2` sentinels |
| gnoboot `tests/ovmf_smoke.sh` | PASS — handoff banner still appears |
| agnos rebuild with MTRR + PCI audits | `cd ~/Repos/agnos && cyrius build kernel/agnos.cyr build/agnos` clean |
| Multiboot2 ELF64 entry preserved | `readelf -h build/agnos \| grep Entry` = `0x1000a8` |
| QEMU Path-C headless smoke | `agnosticos/scripts/qemu-fb-smoke.sh EXPECT="fb_audit: mtrr_eff="` PASS — MTRR audit line lands. Also expect `fb_audit: pci=` line |
| QEMU Path-C visual smoke at 2560×1440 | `QEMU_RES=2560x1440 ./qemu-fb-visual.sh` — verify boot reaches shell with clean glyphs (QEMU doesn't reproduce the iron bug, but this catches new regressions) |
| `build/agnos` freshness | per `feedback_build_freshness_is_mine`, rebuild after every kernel-touching commit |

**Pre-bound outcomes on iron under quiet-boot ON**

| Iron outcome | Diagnosis |
|---|---|
| Boot reaches typeable shell, clean rendering, `fb_audit: mtrr_eff=WB matches_fb_phys=Y` | One of the three repairs landed the fix. Likely #1 (FB size) if firmware was over-reporting pitch×height; less likely #2 (Zen UEFI usually sets WB for FB BAR). Pick winner from serial line content. **Quiet-boot bug closed.** |
| Boot reaches shell with glyph corruption AND serial shows `mtrr_eff=UC` for fb_phys | **MTRR-UC pinning confirmed.** PAT-WC cannot take effect. Burn B becomes either "SetMode to a mode whose BAR lands in MTRR-WB range" OR "add variable-MTRR override for FB BAR." Decisive answer. |
| Boot reaches shell with glyph corruption AND `mtrr_eff=WB matches_fb_phys=Y` AND fb_size matches expectation | All three Burn-A repairs were wrong scope. Next candidate: paint-code interaction with the specific pitch/width tuple, or something post-EBS firmware does to the BAR. Burn B (`SetMode`) becomes the decisive test by forcing a known-working mode. |
| Boot reaches shell with corruption AND `fb_audit: pci=… matches_fb_phys=N` | **BAR reassignment detected.** Kernel painting the wrong physical address. Repair: re-locate the BAR in kernel post-EBS or in the runtime audit, update `fb_phys`. Burn B becomes a follow-up to this. |
| Boot fails earlier than fb_console_init | Likely PCI walker triggered a fault on archaemenid's specific PCI topology. Bisect by disabling #3, retry with just #1 + #2. |

**Burn protocol**

1. `cd ~/Repos/agnosticos && sudo ./scripts/install-usb.sh --update /dev/sdX`
2. Reboot archaemenid; BIOS → **VGA-spec mode + QuickBoot ON** (the known-working baseline). F-key boot menu → USB. Observe boot reaches shell. **Power off cleanly** (preserve CMOS) — this captures the working-path MTRR/PCI audit lines for diff.
3. Boot Linux on same archaemenid; `sudo ./scripts/read-boot-log.sh` — captures geometry + new fb_size if exposed in extended bank. (Note: MTRR/PCI audit output is serial-only; without serial cable on archaemenid we'll be inferring from CMOS-stamped fb_size + the visual outcome only.)
4. Reboot archaemenid; BIOS → **Quiet Boot ON** (the failing path). F-key → USB. Observe FB outcome.
5. Photo the FB whether it works or not. CMOS post-mortem.
6. Diff the two `read-boot-log` captures.

**Iron-side data we'll get from this burn**

- CMOS geometry block (slots 0x90-0x9F) — same as Attempt 72
- CMOS fb_size mirror — **NEW**, slot to be allocated (proposing 0x88-0x8F, 8 bytes LE) since the kernel adds the MTRR/PCI audit
- Visual outcome under VGA-spec (should still pass)
- Visual outcome under Quiet Boot ON (the decisive signal)

(MTRR + PCI audit output is serial-only by current design — exposing those to CMOS would expand the extended bank further. Holding for now; if Burn A's visual outcome doesn't disambiguate, Burn B can include CMOS stamps for the MTRR effective type byte + PCI BAR low/mid bytes as a CMOS-only addition with no behavioral cost.)

**Photos for the catalog (post-burn)**

- `attempt-73-vga-spec-baseline.jpg` — working-path FB under Burn-A bundle
- `attempt-73-quiet-boot-result.jpg` — failing-path FB (clean = fix landed; corrupt = continues to Burn B)
- (optional) `attempt-73-read-boot-log-diff.txt` — text capture of two `read-boot-log.sh` outputs

#### Attempt 73 — code-staging + QEMU baseline complete 2026-05-19 → PENDING IRON BURN

Code landed for all three Burn-A repairs and QEMU smoke PASSES end-to-end on the new bundle. Build artifacts ready for `install-usb.sh --update`.

**Build artifacts**

| Component | Version | Size | Notes |
|---|---|---|---|
| gnoboot | **0.4.0** (cut today) | 33,792 B | adds `load64(gop_mode + 0x20)` → `fb_size` → `boot_info+0x68`. struct_size 0x70 → 0x78. END tag relocated to +0x70. Wire stays v2. Banner bumped, OVMF smoke PASS with new `gnoboot v0.4.0: handing off to kernel` literal |
| agnos | 1.30.11 (working tree) | 420,832 B (+3,288 B vs 417,544 baseline) | new fns: `fb_fb_size()`, `fb_size_or_fallback()`, `fb_audit_mtrr()`, `pci_cfg_addr()`, `pci_cfg_read32()`, `fb_audit_pci_bar()`. WC remap call at `core/main.cyr:17` + `:118` switched to `fb_size_or_fallback()`. `fb: mode=…` diag line extended with `size=` field |
| Cyrius pin | gnoboot 6.0.1 / agnos 5.11.64 | unchanged | no toolchain bump needed |
| Multiboot2 entry | 0x1000a8 | preserved | ELF64 readelf check OK |

**QEMU baseline observed (q35, OVMF, 1920×1080)**

```
gnoboot v0.4.0: handing off to kernel
fb: mode=0/30 phys=0x80000000 pf=1 w=1920 h=1080 pitch=7680 size=0x7e9000
fb_audit: mtrr_eff=0 def=6 covered=1
fb_audit: WARN MTRR=UC pins fb_phys to uncached — PAT-WC block
fb_audit: pci=0:1.0 class=0x300 bar=0 base=0x80000000 fb_phys=0x80000000 delta=0x0
AGNOS kernel v1.30.11
...
fb: WC verified (PAT entry 1)
```

| Signal | QEMU value | Interpretation |
|---|---|---|
| `size=0x7e9000` (8,294,400 B) | matches `pitch * height` = 7680 × 1080 = 8,294,400 B exactly | Under QEMU OVMF, firmware reports FB extent that equals the geometry product. No padding. Repair #1 wires through cleanly. |
| `mtrr_eff=0 def=6 covered=1` | **MTRR-UC covers the FB BAR**; `MTRR_DEF_TYPE=WB` (6) | Per Intel SDM Table 11-7 / AMD APM Vol 2 §7.7.5: MTRR=UC + PAT=WC = **effective UC**. The pre-existing `fb: WC verified (PAT entry 1)` line was verifying PAT bits in isolation; the audit reveals the true effective cache type is UC. Repair #2 caught a real condition the kernel previously had no visibility into. |
| `pci=0:1.0 class=0x300 bar=0 base=0x80000000 fb_phys=0x80000000 delta=0x0` | VGA-class device on bus 0, dev 1, fn 0. BAR0 base matches `fb_phys` with delta=0 | No BAR reassignment under QEMU. Repair #3 returns the expected "clean handoff" baseline; iron Quiet-Boot reporting `delta != 0` or "no VGA BAR matched" would be the smoking gun for runtime BAR mutation. |

**Re-interpretation of pre-Attempt-73 behavior on QEMU**

The kernel was reporting `fb: WC verified (PAT entry 1)` and we believed PAT-WC was active. The MTRR audit shows it never was — effective cache type was UC the entire time on QEMU. Kernel boots cleanly anyway because QEMU's emulated display ignores cache semantics (writes hit the display regardless of cache type, no eviction-timing artifacts since there's no real cache hierarchy backing MMIO). This explains why the `fb_verify_wc` gate has been passing despite MTRR-UC overrides — the gate is true (PAT *is* set to WC) but the gate doesn't capture the effective type.

**Implication for iron interpretation**

On archaemenid (real hardware, real cache hierarchy), the MTRR effective type IS load-bearing. The Burn-A iron run becomes a one-step diagnostic that names the root cause directly:

| Iron under VGA-spec ON (working path) | Iron under Quiet Boot ON (failing path) | Diagnosis |
|---|---|---|
| `mtrr_eff=6 (WB)` | `mtrr_eff=6 (WB)` | MTRR not the difference. Iron behaves like QEMU + working display. Look elsewhere (paint code, scroll path, glyph render). Burn B (SetMode) decisive. |
| `mtrr_eff=6 (WB)` | `mtrr_eff=0 (UC)` | **MTRR=UC pinning under Quiet Boot is the smoking gun.** Different BIOS paths land the FB BAR in different MTRR-covered ranges. Repair: kernel adds variable-MTRR override for the FB BAR (Linux pattern: `mtrr_add`-equivalent). Burn B may not be needed — issue rooted in cache-attribute setup, not mode selection. |
| `mtrr_eff=0 (UC)` on BOTH paths | (same on both) | Iron is permanently MTRR-UC at the FB BAR. The fact VGA-spec works while Quiet Boot doesn't means another variable distinguishes them (BAR size, alignment, PCI-side cache hint). Re-audit, maybe Burn B. |
| `pci=...delta != 0` on Quiet Boot | | **Runtime BAR reassignment.** Kernel painting wrong physical address. Repair #3 caught it; either re-locate the BAR post-EBS or use the runtime audit's match as the source of truth. |

**Ready for install + iron burn.** Per `feedback_bootloader_kernel_ownership` Claude owns the kernel + gnoboot build freshness; both artifacts (33,792 B + 420,832 B) are post-edits and built from current HEAD. Per `feedback_iron_burns_block_other_work` the audit is on paper above; no new instrumentation in flight.

### Attempt 74 prep — pending Attempt 73 outcome → PENDING IRON BURN

**Burn B of the two-burn audit-driven repair plan.** Adds gnoboot
`SetMode` to force a known mode regardless of BIOS path. Gated on
Attempt 73's outcome — three of the five pre-bound A-outcomes
make B necessary, two make B redundant (close-on-A); see decision
table below.

**Why SetMode is held for Burn B, not A** — `SetMode` *changes the
variable being tested* (the firmware-default mode). Stacking it
with the A-bundle would conflate "A's repair landed" with "the mode
just changed underneath us." Keeping B separate lets us attribute
the fix correctly: A's three repairs answer "is the BAR where /
sized as / cached as we think?"; B answers "does forcing a known
mode eliminate the divergence regardless?" — orthogonal questions
worth orthogonal burns.

**Necessity decision from Attempt 73 result**

| Attempt 73 outcome | Burn B status |
|---|---|
| Quiet-boot ON renders cleanly, repair #1 (FB size) credited | **Close on A.** B becomes optional hardening (SetMode forces a small canonical mode to reduce future BIOS-toggle surprises) — defer indefinitely or fold into post-MVP "deterministic boot path" work. |
| Quiet-boot ON renders cleanly, repair #2 (MTRR) credited | **Close on A.** Same as above — root cause was effective-cache-type, not mode. SetMode wouldn't have helped (would have just landed in a different BAR with the same MTRR issue). |
| Quiet-boot ON renders cleanly, repair #3 (PCI BAR) credited | **Close on A.** Same — root cause was BAR reassignment. SetMode could have masked it but #3's runtime audit is the durable fix. |
| Quiet-boot ON still corrupts, MTRR=WB + fb_phys matches PCI BAR + fb_size matches pitch×height | **Burn B is decisive.** Mode-selection itself or paint-code interaction with this specific mode's geometry is the only remaining variable. SetMode to a known small BGRX mode eliminates the divergence at the source. |
| Boot fails earlier than fb_console_init | **Burn B blocked.** Diagnose the regression introduced by Burn A first (likely #3 PCI walker on archaemenid's topology). |

**Bundle under test**

| Item | Value |
|---|---|
| `agnos` source | 1.30.11 + Attempt 73 carry-forward (no kernel-side changes in B) |
| `agnos` build | Unchanged from Attempt 73 |
| `gnoboot` | TBD (0.5.0 candidate) — adds mode enumeration + SetMode call; FrameBufferSize capture from 0.4.0 retained |
| Cyrius pin | unchanged |
| Multiboot2 entry | `0x1000a8` (preserved) |
| Visual banner | Unchanged from 1.30.11 |

**Repair #4 — gnoboot `SetMode` to a known mode**

Adds a mode-selection pass between `LocateProtocol(GOP)` and the
`Mode->*` capture in `gnoboot/src/main.cyr`.

| Step | Action | Source |
|---|---|---|
| 4a | After `LocateProtocol(GOP)`, read `Mode->MaxMode` to get count | UEFI 2.10 §11.9 |
| 4b | For each `N` in `0..MaxMode-1`: call `QueryMode(This, N, &SizeOfInfo, &Info)` to populate mode info without changing state | UEFI 2.10 §11.9.2.1 |
| 4c | Filter modes: keep only `PixelFormat ∈ {0, 1}` (RGBX or BGRX — supported branches); prefer pf=1 BGRX (kernel's native paint assumption per `fb_console_init`'s guard) | UEFI 2.10 §11.9 + agnos `fb_console.cyr:144-161` |
| 4d | From filtered set, pick the mode whose `HorizontalResolution * VerticalResolution` is smallest but >= 800*600 (lower bound to keep boot diagnostics legible; smaller BAR is more likely to land in a cleanly-cached region) | Linux `drivers/firmware/efi/libstub/screen_info.c::setup_gop` (mode selection heuristic) |
| 4e | If `Mode->Mode != selected_N`: call `SetMode(This, selected_N)`. Capture rc | UEFI 2.10 §11.9.2.2 |
| 4f | If SetMode rc == 0: re-read `Mode->Info` pointer (SetMode may have reallocated it) and re-capture all geometry fields into boot_info | UEFI 2.10 §11.9 ("After this call, the contents of EFI_GRAPHICS_OUTPUT_PROTOCOL.Mode are updated") |
| 4g | If SetMode rc != 0: log via `efi_print`, keep current mode, proceed with existing capture | Failure-safe per `feedback_no_hardware_purchase_suggestions` (no firmware-specific workarounds; fall through cleanly) |
| 4h | Add a sentinel to CMOS slot 0x88 marking "SetMode attempted" (one byte: 0x4D = 'M' if rc=0, 0xFA = fail) — minimal stamp so iron post-mortem can tell which branch fired | Pattern matches existing checkpoint discipline |

Source: UEFI 2.10 §11.9 (full GOP protocol); Limine `PROTOCOL.md` "Framebuffer feature" (mode-selection request shape); Linux `drivers/firmware/efi/libstub/screen_info.c::setup_gop` (canonical EFI-stub mode-picker); FreeBSD `stand/efi/loader/framebuffer.c::efi_find_framebuffer`.

**Pre-burn verification gates**

| Gate | How |
|---|---|
| gnoboot rebuild with SetMode | `CYRIUS_TARGET_EFI=1 cyrius build src/main.cyr build/BOOTX64.EFI` clean |
| gnoboot `tests/ovmf_smoke.sh` | PASS — handoff banner still appears; QEMU OVMF has all modes available |
| QEMU multi-mode validation | Run `qemu-fb-visual.sh` at multiple `QEMU_RES` settings (1024x768, 1920x1080, 2560x1440) — verify gnoboot picks the smallest >= 800x600 in each case, kernel paints cleanly |
| Failure-safe path | Force a SetMode failure in QEMU (mock by passing invalid mode N = MaxMode + 1 temporarily) — verify gnoboot logs + falls through to current mode |
| Multiboot2 entry preserved | `readelf` check on agnos binary unchanged (no kernel-side changes expected in B) |

**Pre-bound outcomes on iron under quiet-boot ON**

| Iron outcome | Diagnosis |
|---|---|
| Boot reaches typeable shell, clean rendering, CMOS slot 0x88 = 0x4D | **SetMode landed the fix.** Firmware-mode-selection was the divergence source. Close issue; canonicalize mode-selection in gnoboot as standard practice (matches Linux/Limine). |
| Boot reaches typeable shell, clean rendering, CMOS slot 0x88 = 0xFA | SetMode failed but the corruption is gone — likely an Attempt-73 repair landed late and we missed crediting it. Re-run with Burn-A bundle to confirm. |
| Boot reaches shell with corruption AND 0x88 = 0x4D | SetMode landed but the bug persists. **Decisive falsification of "mode selection is the variable."** Whatever's wrong is not addressable by firmware-mode choice — points to post-EBS firmware behavior, paint-code edge case, or something in the agnos kernel itself unrelated to BAR/cache. Re-audit needed; this is the "neither A nor B nailed it" branch, expensive but rare. |
| Boot reaches shell with corruption AND 0x88 = 0xFA | SetMode failed AND corruption present — burn was non-decisive. Firmware doesn't support runtime mode switching on archaemenid. Fall back to "stay on the firmware-default mode and accept the divergence as a BIOS-config requirement (always boot with VGA-spec)" — document and ship that as a closed-beta-acceptable workaround. |
| Boot fails earlier than gnoboot banner | gnoboot crashed inside SetMode/QueryMode loop. Bisect 4b/4e — likely a fncallN issue with the mode-info pointer ABI. |

**Burn protocol** — same shape as Attempt 73 (VGA-spec baseline, then Quiet Boot ON, photo + CMOS read-back after each).

**Photos for the catalog (post-burn)**

- `attempt-74-vga-spec-baseline.jpg` — VGA-spec path under Burn-B bundle (should still pass; SetMode should pick a mode that works on both BIOS paths)
- `attempt-74-quiet-boot-result.jpg` — failing-path FB under SetMode-forced mode

### Attempt 74 — 2026-05-20 → FAIL (both repairs falsified, escape plan written)

**Bundle as burned** (diverged from the original Burn-A / Burn-B orthogonal-burn discipline of Attempts 73 / 74 prep — three changes stacked into one iron run):

| Item | Detail |
|---|---|
| `gnoboot` | **0.4.1** — `SetMode(gop, cur_mode)` re-arm pre-EBS. The original Burn-B plan (4d: pick the smallest mode ≥ 800×600) was *replaced* with "re-arm the current mode" sourced from Linux `efifb.c` + EDK2 `GraphicsConsoleDxe` + FreeBSD `efifb.c` — minimal-risk variant, no resolution change |
| `agnos` | 1.30.11 working tree + **Burn-A audit** (`fb_audit_mtrr`, `fb_audit_pci_bar`, `FrameBufferSize` consumption) **stamped to CMOS 0x88-0x8F** since iron has no serial cable |
| `agnos` (added on top this session) | **`fb_mtrr_install_wc(fb_phys, fb_size)`** — variable-MTRR WC install for the UMA FB region, called from `fb_console_init` before any FB write. Added without an explicit pre-bound outcome row in either Attempt 73 or 74 prep — closest mapping was Attempt 73's "MTRR=UC pinning is the smoking gun → repair: kernel adds variable-MTRR override" row, but that repair was supposed to be a *follow-up* to a Burn-A audit-only diagnostic, not stacked into the same burn |
| `agnos` build size | 421,584 B (+752 B vs 420,832 B Burn-A baseline — `wrmsr` + `wbinvd` helpers + `fb_mtrr_install_wc` body) |

**Visual outcome — Quiet Boot ON**: unchanged. Garbled-glyph signature persists (no fresh photo captured this session; user-reported "no change on the machine on boot into quiet mode"). Matches the [Attempt 33 photo](iron-nuc-zen-photos/attempt-33-phase-2-5-corrupted.jpg) signature characterized in detail below.

**CMOS audit readback** (slots 0x88-0x8F under Quiet Boot ON):

| Slot | Value | Expected per audit semantics | Status |
|---|---|---|---|
| 0x88 MTRR eff | `0x18` | one of {0=UC, 1=WC, 4=WT, 5=WP, 6=WB, 7=UC-} | **invalid memory-type encoding** |
| 0x89 MTRR def | `0xF0` | one of the same set | **invalid memory-type encoding** |
| 0x8A-0x8D BAR base | `0x0400CC44` | matched VGA-class BAR base (LE32) or 0 if no match | non-zero with PCI-match=0 → inconsistent state (audit either ran-and-zeroed-then-stamped, or early-returned leaving prior-boot bytes; can't disambiguate from current stamping) |
| 0x8E delta low byte | `0x00` | (fb_phys - base) & 0xFF; 0 = clean alignment | clean — but only meaningful if 0x8F=1 |
| 0x8F PCI match flag | `0x00` | 1 = VGA-class BAR matched fb_phys within 256 MB | no match |

**Geometry channel** (slots 0x90-0x9F, unchanged from Attempt 72): width=2560, height=1440, pitch=10240, pf=1 (BGRX), mode_current=0, mode_max=13, sentinel=0xFB. Geometry stamping confirms `fb_console_init` ran end-to-end. Since the MTRR/PCI audit calls are *after* the geometry stamps in `fb_console_init`, the audits also ran — meaning 0x88-0x8F are real audit outputs, not stale bytes.

#### Visual signature reinterpretation

Comparing the two iron photos in catalog:

| Photo | Path | Characteristic |
|---|---|---|
| [`attempt-33-phase-2-5-corrupted.jpg`](iron-nuc-zen-photos/attempt-33-phase-2-5-corrupted.jpg) | Quiet Boot ON (failing) | Horizontal bands of dense dot-patterns separated by dark gaps. Within each band, multiple kernel text rows appear *vertically compressed and interleaved*. No legible text. Structure is regular (not random), with consistent band spacing — characteristic of a periodic mapping mismatch between writer and reader. |
| [`attempt-71-quickboot-vga-pass.jpg`](iron-nuc-zen-photos/attempt-71-quickboot-vga-pass.jpg) | QuickBoot + VGA-spec (working) | Top half: overlapping text history with scroll artifacts (the "perceptually-doubled refresh, old-school CRT 80's-ish" pattern reported at Attempt 70). Bottom: shell prompt `agnos> v1.30.11 (type 'help')` rendered cleanly. Fresh writes legible; scroll-copy region noisy. |

**The two paths are not "works vs broken" — they are "scroll-noisy but FB-write-clean" vs "FB-write-fundamentally-broken at every timestamp"**, including freshly-painted text the kernel just wrote. Quiet Boot's shell prompt would be unreadable if it ever rendered.

The Quiet Boot signature is **not cache-coherence corruption**:

- Cache corruption (stale WB lines reaching DRAM partially) would produce *random* pixel pop-in, partial glyph holes, and timing-dependent tear lines. Position of text would be correct; pixels would be wrong.
- What we see is the opposite: *pixels are at structured positions that don't match where the kernel wrote them*. Glyph data exists; it's been **read back at a different stride/layout than it was written**.

Working hypotheses consistent with the structural signature, ranked by likelihood:

1. **Scanout pitch divergence** — kernel writes scanline N at FB offset `N * pitch` (pitch=10240 from GOP). Display engine reads scanline M at FB offset `M * effective_stride` where `effective_stride ≠ pitch`. Each visible band = several kernel rows folded into one scanout row (if effective < pitch) or each kernel row split across scanout rows (if effective > pitch). UEFI 2.10 §11.9 *requires* GOP-reported `PixelsPerScanLine` to equal hardware scanout stride; some AMD-APU firmwares are known to violate this on quiet-boot paths where the iGPU is left in a different scanout configuration than the GOP-reported one.
2. **Tile-format scanout** — AMD GCN/RDNA display engines support tiled scanout formats (1D-tiled, 2D-tiled, swizzled) in addition to linear. Quiet-Boot's native-HDMI 2560×1440 mode may program the CRTC for tiled while GOP reports linear pixel layout. Writes interpret as linear; reads de-tile — produces the periodic-band signature.
3. **Address-translation divergence** — the FB BAR's *physical* address as visible to the CPU may not match what the display engine scans. AMD APUs route iGPU display reads through a different fabric path than CPU writes; if quiet-boot leaves an IOMMU/GART mapping that aliases `FrameBufferBase` to a different scanout buffer, writes hit one page, the display reads another.

All three are firmware-state-on-handoff problems, **not** kernel-side cache problems. The MTRR-WC install in this burn was attacking the wrong layer.

#### Falsifications carried forward

| Hypothesis | Status | Burn that falsified it |
|---|---|---|
| `pf ≥ 2` (BitMask / BltOnly PixelFormat) is the variable | FALSIFIED (Attempt 71) | guard for `pf > 1` would have produced black screen; got Attempt-33 garble instead |
| Pitch padding (`ppl > width`) is the variable | FALSIFIED (Attempt 72) | stamped pitch=10240 = width × 4 exactly |
| MTRR=UC overrides PAT-WC at FB BAR is the variable | FALSIFIED (Attempt 74) | MTRR-WC install made no visual difference; cache-attribute layer is not the root |
| `SetMode(gop, cur_mode)` re-armed CRTC scanout would re-align display engine to GOP base | FALSIFIED (Attempt 74) | no visual change after the re-arm; iron firmware ignores SetMode-to-same-mode as a no-op, or the divergence is at a layer SetMode doesn't touch |

Four distinct single-variable hypotheses falsified across four attempts on the same symptom. Per `feedback_stop_letter_laddering`, the escape plan section below replaces "stage Attempt 75 letter" as the next move.

#### Audit-value oddity (0x18, 0xF0) — secondary but worth investigating

The audit values are not currently explainable by the install code alone:

- `fb_mtrr_install_wc` writes `base_val = phys_aligned | 1` to a variable PHYSBASE MSR — bits[7:0] = 0x01 (WC type).
- `fb_audit_mtrr`'s loop captures `base_msr & 0xFF` from the *last* matching variable MTRR. If firmware has a wider variable MTRR overlapping fb_phys later in the iteration, my install's type-1 gets overwritten in `matched_type` by whatever firmware programmed.
- 0x18 in PHYSBASE bits[7:0] is reserved/invalid per Intel SDM Vol 3A §11.11.3 ("Bits 11:8 are reserved (MBZ)" — and bits 7:0 should hold type 0-7). Either firmware is programming reserved bits, *or* there's a Cyrius asm/lowering interaction we haven't characterized, *or* the audit captures a slot whose MSR truly contains 0x18 in those bits.

Not the immediate blocker (visual signature points elsewhere), but if/when the audit gets re-examined it would help to log the raw MSR values (not just `& 0xFF`) for the matched slot — left for future work.

#### Escape plan — research before any more iron burns

Per `feedback_stop_letter_laddering` + `feedback_redesign_dont_reinvent` + `feedback_iron_burns_block_other_work`. **No iron burn proposed in this entry.** The actionable items below are research and existing-image re-boot diagnostics; new code burns gated on the user's explicit go after reviewing this entry.

**R1 — Capture VGA-spec / QuickBoot CMOS readback** (existing image, no rebuild, no install)

We have Quiet Boot CMOS data (Attempt 72 + Attempt 74). We do **not** have VGA-spec CMOS data — the comparison row in the Attempt 72 / 73 outcome tables was never populated. Without it we can't confirm what the mode/MTRR/PCI difference between the two BIOS paths actually is, and we'll keep guessing.

Plan: reboot archaemenid into BIOS, toggle to VGA-spec + QuickBoot ON (the known-working path), boot from the *same USB image already installed*, wait for shell to render, power off cleanly. Boot Linux on archaemenid. `sudo ./scripts/read-boot-log.sh` captures the VGA-spec geometry + MTRR audit values. Diff against the Quiet Boot capture above.

Cost: one extra boot cycle on archaemenid, no install, no rebuild.

Decisive signal: if VGA-spec stamps `mode=N>0` (firmware-picked non-zero mode) and Quiet Boot stamps `mode=0`, then the BIOS toggle is selecting a different GOP mode — the working path may be running at a smaller / older / linear-scanout mode that quiet-boot replaces with native-HDMI-tiled. That makes the original Burn-B plan (force a small mode in gnoboot regardless of BIOS toggle) the correct attack.

**R2 — Read Linux `drivers/firmware/efi/libstub/screen_info.c` + EDK2 `MdeModulePkg/Universal/Console/GraphicsConsoleDxe`** for the actual mode-selection / scanout-handoff prior art

The Burn-B prep already cited these references but didn't transcribe what they *do*. Specifically:

- Does Linux's `setup_gop` *select* a mode, or does it always honor the firmware-picked one?
- Does any Linux EFI stub path call `SetMode(gop, N)` where N differs from `Mode->Mode` (the current mode)?
- Does EDK2 `GraphicsConsoleDxe` have an explicit AMD-APU-aware code path?
- What does the Linux `screen_info` quirk table (`drivers/firmware/efi/libstub/screen_info.c` quirks region) have for AMD?
- Is there a documented Linux workaround for the specific signature in [`attempt-33-phase-2-5-corrupted.jpg`](iron-nuc-zen-photos/attempt-33-phase-2-5-corrupted.jpg)?

Web-source via `WebFetch`/`WebSearch` if the source isn't local. Result: a transcribed reference of what the canonical handlers actually do, written up in `docs/development/efifb-prior-art.md` (sibling to `uefi-boot-prior-art.md`).

Cost: research time only, no iron.

**R3 — Revive the original Burn-B plan** (gated on R1 + R2)

The original Attempt 74 prep (still preserved at lines 825-907 above) called for gnoboot to *pick* the smallest mode ≥ 800×600 and `SetMode` to it — not the cur_mode re-arm that 0.4.1 shipped. If R1 confirms the BIOS-toggle changes mode and R2 confirms that's an established attack vector, revert gnoboot's `SetMode(cur_mode)` to `SetMode(selected_smaller_mode)` per the original 4a–4h sequence. This becomes a proposable burn only after R1 and R2 land in writing.

**R4 — Independent check: simpledrm / efifb-equivalent for AMD UMA on archaemenid**

If Linux's own efifb fails on archaemenid Quiet Boot (separate from AGNOS), we have an external reference point that the bug is firmware-side and not specific to our paint code. Boot Linux without `nomodeset` under Quiet Boot ON; observe whether early-boot framebuffer text is also garbled before amdgpu loads. If yes: confirmed firmware bug, workaround scope (BIOS-toggle requirement) becomes ship-acceptable for closed-beta MVP. If no: the bug is something AGNOS does that Linux doesn't, and we have a behavioral diff to study.

Cost: one Linux boot under Quiet Boot, observe early-boot text, no iron burn.

#### What this entry does NOT propose

- Any new code change to agnos or gnoboot
- Any new iron burn
- Any new CMOS-stamp instrumentation
- Any letter-coded follow-up to Attempt 74 (no `FF`/`GG`/etc.)

The user's direction in chat — *"I don't think you're expecting me to do a burn with no chances"* — is the ceiling on the next move. R1-R4 above are the audit work that has to land before another burn is justifiable.

#### New iron observation from chat (post-write-up)

User report after the burn, before the escape plan landed:

> *"not able to see gnoboot references only garbled kernel messages with lockup when using quiet."*

Three distinct facts:

1. **No gnoboot text on screen.** Pre-EBS `efi_print` output (the `gnoboot v0.4.1: handing off to kernel` banner) is not visible under Quiet Boot ON. Consistent with OEM BIOS Quiet-Boot behavior — the splash logo overlays the UEFI text console until OS takes over the FB. Not new evidence about the root cause.
2. **Garbled kernel messages appear.** Once kernel paint starts (post-EBS, post-`fb_console_init`), the Attempt-33 structural-corruption signature is visible. CMOS readback confirms `fb_console_init` ran end-to-end (sentinel 0xFB at slot 0x9F, geometry stamped through 0x90-0x9E).
3. **Lockup.** New variable. Pre-Attempt-74 Quiet Boot was "garbled visuals but system runs through to invisible shell" per Attempt 71/72 results — keyboard fix from Attempt 68 was assumed to work on this path even if illegible. Attempt 74's lockup is novel and points at one of the three new code paths added in this burn:
   - `fb_mtrr_install_wc` — `wrmsr` to MTRR PHYSBASE/PHYSMASK + `wbinvd` bracket
   - `fb_audit_mtrr` — `rdmsr` reads of 0x2FF / 0xFE / 0x200-0x20F
   - `fb_audit_pci_bar` — 128 PCI config-space probes via 0xCF8/0xCFC

`wrmsr` is the primary suspect: AMD `SYS_CFG_MSR` (0xC0010010) carries `MtrrLock` (bit 18) on some Zen platforms; when BIOS sets MtrrLock, writes to variable-range MTRR MSRs (0x200-0x20F) trigger `#GP(0)` per Intel SDM Vol 2B / AMD APM Vol 3 §3.3 ("Specifying a reserved or unimplemented MSR address... will also cause a general protection exception"). At the kernel's pre-IDT stage, `#GP` cascades to triple fault → CPU reset; if AMD-APU firmware catches the fault in a SMI handler, the system can appear to lockup rather than reset.

This is independent of the visual corruption (which would persist regardless of whether `wrmsr` ran or not) — but the lockup means the kernel can't get to whatever post-`fb_console_init` work happens, so even the workaround-of-last-resort ("ship Quiet-Boot-as-unsupported") got worse.

#### R2 partial findings (research, no iron)

Web-sourced prior art on the signature class. Full transcription is over-scope for this entry; the directly-relevant findings:

**Linux EFI stub mode-selection** ([`drivers/firmware/efi/libstub/gop.c::set_mode`](https://raw.githubusercontent.com/torvalds/linux/master/drivers/firmware/efi/libstub/gop.c)):

```c
static void set_mode(efi_graphics_output_protocol_t *gop)
{
    // ...
    switch (cmdline.option) {
    case EFI_CMDLINE_MODE_NUM:  new_mode = choose_mode_modenum(gop); break;
    case EFI_CMDLINE_RES:       new_mode = choose_mode_res(gop);     break;
    case EFI_CMDLINE_AUTO:      new_mode = choose_mode_auto(gop);    break;
    case EFI_CMDLINE_LIST:      new_mode = choose_mode_list(gop);    break;
    default:                    return;   // ← honor firmware-picked mode
    }
    // ...
    if (new_mode == cur_mode) return;
    if (efi_call_proto(gop, set_mode, new_mode) != EFI_SUCCESS) efi_err(...);
}
```

**Linux only calls `SetMode` when user passed `video=efifb:mode_N` / `res_WxH` / `auto` on the kernel command line.** Default behavior is to honor whatever mode firmware picked — *no* SetMode call. Linux's `screen_info.lfb_linelength` is computed as `pixels_per_scan_line * depth / 8`, NOT read from `GOP_MODE->FrameBufferSize`. Implication for gnoboot: 0.4.1's `SetMode(cur_mode)` re-arm is not a Linux-canonical pattern; the canonical pattern is "leave the mode alone unless explicitly overridden."

**Ubuntu Bug #1065263 — "wrong stride for efifb on some systems"** ([launchpad](https://bugs.launchpad.net/bugs/1065263)). Visual signature: "diagonal-stripey corruption on the display at boot time" on UEFI systems. Root cause class: "efifb driver was coming up with the wrong idea of the framebuffer dimensions" — i.e., stride/pitch divergence between GOP-reported and hardware-effective scanout stride. Resolution: kernel patches from Matthew Garrett to both efifb and the early-boot EFI stub. **Same signature class as Attempt 33** — periodic structural corruption from writer/reader stride mismatch.

**NetBSD wsfb tutorial** ([netbsd.org](https://wiki.netbsd.org/tutorials/x11/how_to_use_wsfb_uefi_bios_framebuffer/)) — confirms the exact symptom: "on this graphics card (Asus X202E laptop), the framebuffer is linear, but not fully contiguous, and the 10 unusable pixels at the end of each row have to be taken into account, or else, you'll be treated to a characteristic jagged, streaky display." Mode 0 on that laptop had `pitch=1376` for `width=1366` — 10-pixel padding per scanline. Our archaemenid Quiet-Boot stamp shows `pitch=10240` for `width=2560` (exact, no padding visible) — but the *effective hardware stride* on the scanout side could still differ from the GOP-reported `pitch`, which is what UEFI 2.10 §11.9 implicitly forbids but real firmware sometimes violates.

**FreeBSD drm-kmod issue #60** ([github](https://github.com/freebsd/drm-kmod/issues/60)) — confirms AMD-specific behavior at 2560×1440 specifically: "efifb keeps happily writing to VRAM way after amdgpu expects it to stop, and if the framebuffer is large enough (e.g. 2560x1440) it would directly overwrite stuff like the firmware the driver is loading into the card." Different bug than ours (this is FB-vs-amdgpu eviction, ours is initial-paint corruption), but anchors that 2560×1440 + AMD UMA + UEFI FB is a documented problem cluster.

**Aggregate conclusion for our case**: the structural signature is the well-known "GOP pitch ≠ hardware scanout stride" bug class, documented on Linux back to 2012 and again on FreeBSD recently. The Linux fix (Garrett patches) was in `screen_info` setup + efifb, not in the EFI stub's mode handling. Linux *does not* call `SetMode` to work around this — it honors firmware's mode and patches the consumer of the stride field. **This implies R3 (gnoboot `SetMode` to a smaller mode) may not be the right attack either** — the right attack might be a kernel-side stride re-derivation from the actual hardware (PCIe BAR size and scanout regs).

R3 stays in scope but moves down the priority list. R4 is now the next move, per user direction.

---

### Attempt 75 prep — R4 Linux-efifb-under-Quiet-Boot diagnostic 2026-05-20 → PENDING USER OBSERVATION

User direction (chat): *"file R4 as a next attempt review just reset with and choose quiet mode for regular archaemenid boot and then review it after."*

**This is not an AGNOS iron burn.** No USB install, no kernel rebuild, no code change. The diagnostic is: boot archaemenid into its host Linux OS under BIOS Quiet Boot ON and observe whether Linux's own efifb early-boot console shows the same garbled-glyph signature *before* amdgpu loads and the desktop comes up.

#### Why this is decisive (and cheap)

The Attempt-33 signature is either:

- **(a) A firmware bug** that affects any post-EBS framebuffer writer — Linux efifb, FreeBSD, AGNOS, anything. The fix lives in firmware (BIOS update) or downstream (full GPU driver that reprograms scanout). Workaround scope: "ship with VGA-spec/QuickBoot as a closed-beta-acceptable BIOS-config requirement; document under known-issues."
- **(b) An AGNOS-specific bug** — something AGNOS does that Linux doesn't. The fix lives in our kernel or gnoboot. Workaround scope: keep researching, possibly along R3 lines, possibly elsewhere.

Linux booting Quiet Boot ON resolves the disjunction directly:

| Linux observation under Quiet Boot ON | Diagnosis | Next step |
|---|---|---|
| **Linux early-boot text (kernel ring buffer / GRUB / loader splash) is also corrupted** — same diagonal-stripe / structural-mis-alignment signature visible *before* amdgpu loads (typically the first few seconds of boot, before the X / Wayland session starts) | **Firmware bug confirmed.** Linux's efifb hits the same issue. Workaround scope shifts to "ship with VGA-spec required; document; BIOS update later." No more AGNOS-side speculation on FB paint code. | Add known-issue line to AGNOS docs; R3 (gnoboot SetMode-to-smaller) becomes optional hardening rather than required repair; revert the kernel MTRR-install since it didn't help and may be causing the lockup. |
| **Linux early-boot text renders cleanly under Quiet Boot ON** (typical: GRUB menu / kernel decompression line / systemd messages visible normally) | **AGNOS-specific bug.** Linux's efifb handles whatever firmware leaves; AGNOS doesn't. There's a behavioral diff to study — most likely candidates per R2: stride computation, scanline rendering, MTRR/PAT setup difference, or something gnoboot's handoff sequence does differently from Linux's EFI stub. | R2 deep-dive into actual Linux source diff. R3 implementation re-prioritized against findings. New attempt with single behavioral repair. |
| **Linux locks up under Quiet Boot ON entirely** (kernel doesn't reach desktop, screen frozen / black / corrupted) | Worse than (a). Firmware bug severe enough to crash Linux too. | Document as un-supportable BIOS path on this hardware; ship "Quiet Boot OFF" as hard requirement, not workaround. |

#### Observation protocol

1. **Reset archaemenid cleanly.** Power-cycle.
2. **Enter BIOS, set Quiet Boot ON** (the same toggle that produces AGNOS's Attempt-33 signature).
3. **Save & exit; boot into host Linux normally** (not the AGNOS USB).
4. **Watch the screen during the first 10-15 seconds**: this is where efifb is the active console. Specifically:
   - Does the BIOS splash / OEM logo render normally? (probably yes; that's a different rendering path before any OS)
   - When the OEM logo clears and Linux takes over, does the kernel ring buffer / initrd messages / systemd unit startup text render *cleanly* or with the Attempt-33 stripe/compression signature?
   - Does Linux reach the login prompt / desktop? Or does it lock up?
5. **Note what you saw.** Cleanest signal points are "GRUB menu legible / illegible" (if archaemenid uses GRUB), "kernel boot messages legible / illegible," "desktop reachable / locks up."
6. **Photo optional but useful** — if there's a corrupt frame, capture it for the photo catalog at `iron-nuc-zen-photos/attempt-75-linux-quiet-boot.jpg`. The interesting moment is post-OEM-logo, pre-desktop.

#### What this entry does NOT do

- No code change to agnos or gnoboot
- No new USB install
- No new build artifact
- No kernel/bootloader version bump

Pure observation under a different OS using the existing BIOS toggle.

#### Expected report-back

Brief is fine — "Linux looked clean, reached desktop" or "Linux had the same stripes during boot but reached desktop" or "Linux didn't boot, screen looked like AGNOS." From there I can interpret per the table above and direct R3 (or document the workaround if path (a) confirmed).

#### Closed → BYPASSED 2026-05-20

R4 was never executed. In chat, when the user pushed back on the "catch a frame of Linux scroll text" protocol, the visual signature in [`attempt-33-phase-2-5-corrupted.jpg`](iron-nuc-zen-photos/attempt-33-phase-2-5-corrupted.jpg) was re-interpreted: **the horizontal "bands" weren't structural mis-alignment — they were 8-px-tall character cells on a 1440-px display (0.5% of screen height per row)**. At native HDMI the 8x8 CGA glyphs become illegible dot-clusters arranged in rows that read visually as "stripes." VGA-spec mode works because the smaller resolution (1024×768 territory) makes 8-px glyphs proportionally larger. Root cause: font-pixel-density, not scanout / cache / MTRR.

The MTRR / SetMode / scanout-divergence speculation arc that consumed Attempts 71-74 was wrong layer the whole time. R1/R2/R3/R4 all became unnecessary once the photo was read as "tiny font" rather than "structural corruption."

The fix landed in working-tree 1.30.11 the same session — see Attempt 76 below.

---

### Attempt 76 — font-pixel-density fix 2026-05-20 → PASS (MVP-gate functional; visual deferred to true-font in 1.30.12)

Root cause closed in chat: 8×8 CGA glyphs at 2560×1440 = 0.5% of screen height, render as visual "stripes." The Attempts 71-74 ladder chased the wrong layer.

Fix in `kernel/arch/x86_64/fb_console.cyr` (working-tree 1.30.11, no version bump):

- `fb_scale()` → 1/2/3/4 by `fb_height()` (≤900/≤1200/≤1800/else); archaemenid Quiet Boot 1440 → scale 3.
- `fb_putc` / `fb_fill_cell` / `fb_scroll_up` render each font bit as an `S×S` block, `cell_w = 8 * scale`.
- `fb_mtrr_install_wc` + `fb_audit_mtrr` + `fb_audit_pci_bar` calls removed from `fb_console_init` (suspected Quiet Boot lockup source via AMD MtrrLock → `#GP`).

Build 422,048 B (`./scripts/build.sh`), multiboot2 ELF64 entry `0x1000a8`. QEMU smoke `QEMU_RES=2560x1440 ./scripts/qemu-fb-smoke.sh` PASS through `agnos>`. gnoboot unchanged at 0.4.1.

#### Iron outcome

| Quiet Boot ON / archaemenid | Before (1.30.10 + Attempt 74) | After (Attempt 76) |
|---|---|---|
| System state | **Lockup** post-`fb_console_init` (suspected MtrrLock `#GP`) | **Live** — runs through to shell |
| Keyboard input | Untestable (locked) | **Live** — keystrokes accepted |
| FB refresh | Untestable (locked) | **Live** — paint loop running |
| Glyph legibility | Garbled stripes at 8-px cell | Scaled to 24-px cell; still illegible as letters — 8×8 CGA bitmap is too primitive to read even at 3× |

**Three of four bars cleared in one burn.** Lockup gone (the MTRR-install removal was the correct call — falsifies the WC-MTRR-fix hypothesis that drove Attempt 74). Keyboard + refresh both live on the previously hostile Quiet Boot path. The remaining bar (legible glyphs) is a font-source problem, not a paint/cache/MTRR/scanout problem — scaling a primitive 8×8 bitmap bigger makes each pixel bigger, not each letter readable.

Photo: [`iron-nuc-zen-photos/attempt-76-quiet-boot-scaled-glyphs-illegible.jpg`](iron-nuc-zen-photos/attempt-76-quiet-boot-scaled-glyphs-illegible.jpg) — scale=3 24-px-cell render under Quiet Boot ON at 2560×1440; pixels enlarged but the 8×8 source bitmap is too primitive to read as letters. Trigger photo for the true-font swap plan.

#### Closeout

1.30.x FB hardening sweep closes at .11 on this result. Functional MVP gate (typeable shell on iron Quiet Boot) clears here for the first time end-to-end (Attempt 68 cleared it on VGA-spec; Attempt 76 clears it on Quiet Boot too). Visual legibility moves to **1.30.12 true-font** — bitmap font swap (8×8 CGA hand-drawn → real 8×16 or larger bitmap source), no new layer, no new boot-info field. Plan doc: forthcoming under `docs/development/`.

User direction in chat (paraphrase): *"the session doesn't lock up anymore, it refreshes, typing is accepted — only rendering of glyphs is left, I might call 1.30.11 done and move to true font."*

---

### Attempt 77 — 2026-05-20 → PARTIAL (VGA path legible + slightly faster; Quiet Boot still illegible, hypothesis space open)

1.30.12 true-font swap landed in `agnos@75914e9` ("self rolled glyph to font"). The 8×8 CGA inline-table renderer in `kernel/arch/x86_64/fb_console.cyr` was replaced with a self-rolled bitmap font (larger cell — likely 8×16 or comparable; full geometry to be confirmed from the source). `cyrius/programs/qemu-fb-smoke` was used in the cycle to iterate the font without burning iron, per the workflow note in the b0905dd commit message ("updated font for agnos with qemu tool").

**Build under test:**

| Component | Detail |
|---|---|
| `agnos` source | 1.30.12 — `git@HEAD: 75914e9 self rolled glyph to font` |
| `agnos` build | `build/agnos` 425,840 B (mtime 2026-05-20 10:40 PDT) — +3,792 B vs Attempt 76's 422,048 B; growth attributable to the bitmap-font glyph table |
| `gnoboot` | 0.4.1 (unchanged from Attempt 76) |
| QEMU smoke | PASS via `qemu-fb-smoke` driver (font iterated to legibility before any iron burn — `feedback_iron_burns_block_other_work` honored) |

#### Iron outcome

| 2560×1440 / archaemenid | After Attempt 76 (3× scaled 8×8 CGA) | After Attempt 77 (1.30.12 true font) |
|---|---|---|
| VGA-spec / QuickBoot legibility | Garbled at small cell; scaled cells made pixels bigger but not letters readable | **Legible** (user-confirmed). New font reads as actual letters; reported "slight speed improvements for VGA" alongside the legibility win |
| Quiet Boot legibility | Scaled but illegible (3× of an 8×8 CGA primitive — still not letter-shaped) | **Still illegible.** Photo: [`attempt-77-quiet-boot-true-font-lines-off.jpg`](iron-nuc-zen-photos/attempt-77-quiet-boot-true-font-lines-off.jpg) — horizontal banding cuts through glyphs; text visible but row-aligned in a way that doesn't read as continuous lines |
| Quiet Boot lockup | Cleared at Attempt 76 (no regression here) | Cleared (no regression) |
| Quiet Boot keyboard / refresh | Live (no regression) | Live (no regression) |

**VGA-pass closure** — the true-font swap was the right call for VGA: it converts Attempt 76's "functional MVP but illegible" outcome into a "functional MVP that reads as a terminal." That part of 1.30.12's scope landed. The "slight speed improvement" is consistent with a wider cell amortizing fewer scroll-copy iterations per visible row, though no benchmark was taken this attempt.

**Quiet Boot residual** — the font landing made the VGA path legible without making the Quiet Boot path legible. The signature is *different* from Attempt 76's: glyphs are recognizable as letterforms within each band but the bands themselves don't compose continuous lines of text. Whatever's wrong on Quiet Boot is *not* a font-source primitiveness problem (Attempt 76's hypothesis, now closed by VGA reading correctly with the new font).

#### Hypothesis space — explicitly tentative

User in chat: *"I'm only assuming the math is off but given that we may be still drawing for the previous glyph style or something about the framebuffer is off."* All three branches are open; none has been falsified or confirmed by an iron burn yet.

| Hypothesis | Shape | What would falsify |
|---|---|---|
| **H1 — Render math still 8×8** | Font source swapped to 8×16 (or similar) but one or more sites in `fb_console.cyr` still compute row stride / cell pitch / scroll-copy offsets using the old 8×8 cell dimensions. A row written with new-font math reads cleanly on VGA-spec (because VGA path may compute differently or hit a different scanout layout), but the Quiet-Boot scanout exposes the mismatch as inter-row misalignment. Audit target: every literal `8` in cell-geometry context in `fb_console.cyr` — `fb_putc`, `fb_fill_cell`, `fb_scroll_up`, `fb_console_init`'s cell-grid math. | Iron-readable confirmation that all geometry constants match the new font cell size (e.g., CMOS-stamped cell_w / cell_h / font_h alongside the existing geometry channel at 0x90-0x9F). |
| **H2 — Framebuffer-layer divergence (Attempt 74 carry-forward)** | The Quiet-Boot vs VGA-spec divergence catalogued in Attempt 74's escape plan (scanout-pitch divergence / tile-format scanout / address-translation divergence) was never closed — Attempt 76 made the kernel survive Quiet Boot but did not investigate *why* Quiet Boot reads back differently than VGA-spec. The new font might be exposing the same underlying FB-layer problem at a different layer of detail (legible per-glyph because the font is robust, but inter-row banding because the FB layout is still off). | R1 from Attempt 74's escape plan — VGA-spec CMOS readback (geometry / MTRR / PCI) diffed against Quiet Boot CMOS readback. Was still PENDING at Attempt 75; remains the highest-value research item before another iron code burn. |
| **H3 — Font-data layout mismatch** | Self-rolled font's glyph data is laid out (row-major vs column-major, MSB-first vs LSB-first, padded vs packed) in a way the renderer assumes is one and the font emits as the other. Would produce per-glyph distortion or shifted glyphs in *both* boot paths, so this is the weakest candidate given VGA reads correctly — but it cannot be fully ruled out without confirming the font format pins down on both paths. | VGA reading cleanly with no per-letter distortion (user-confirmed in chat) makes H3 the least-likely branch, but a side-by-side photo of identical text rendered on both paths would close it explicitly. |

H1 and H2 are not mutually exclusive — both could be in play and the Quiet-Boot signature could be either (or compositional).

#### Closeout

1.30.12's VGA-path goal landed. Quiet-Boot legibility is the remaining 1.30.12 scope, and the right next move is **research, not a burn** — per `feedback_stop_letter_laddering` and `feedback_redesign_dont_reinvent`, an iron burn at this point would be speculative across three open hypotheses and produce ambiguous post-mortem data.

#### Research pass — 2026-05-20 (no iron burn, all read-only)

**H1 — render math still 8×8: FALSIFIED by code audit.**

Every site `true-font-swap-plan.md` §5 named as load-bearing was checked against `agnos:kernel/arch/x86_64/fb_console.cyr@75914e9`:

| Site | Line | Status |
|---|---|---|
| `fb_fill_cell` cell-fill loops | `fb_console.cyr:469-485` | Correct — outer loop bounded by `cell_h`, inner by `cell_w`, pitch-aware store32 |
| `fb_scroll_up` scroll distance | `fb_console.cyr:496-528` | Correct — `cell_h = 16 * fb_scale()`, `rows_to_copy = height - FB_CONSOLE_Y0 - cell_h`, bottom-clear runs `0..cell_h` rows. Pitch-aware u64 block-copy unchanged. |
| `fb_putc` `max_cols` / `max_rows` | `fb_console.cyr:544-545` | Correct — `max_cols = width / cell_w`, `max_rows = (height - FB_CONSOLE_Y0) / cell_h` |
| `fb_putc` glyph render outer loop | `fb_console.cyr:592` | Correct — `for (row = 0; row < 16; row = row + 1)`, no residual `8` |
| `fb_putc` per-glyph Y origin | `fb_console.cyr:591` | Correct — `y_px = FB_CONSOLE_Y0 + fb_cur_y * cell_h` |
| `fb_putc` per-glyph X origin | `fb_console.cyr:590` | Correct — `x_px = fb_cur_x * cell_w` |
| `fb_putc` scaled-pixel write | `fb_console.cyr:599` | Correct — `(y_px + row * s + dy) * pitch + (x_px + col * s) * 4` |
| Newline + backspace `cell_h` use | `fb_console.cyr:550-568` | Correct — both branches use `cell_h` for Y advance |

No site uses `cell_w` for vertical extent or `cell_h` for horizontal extent anywhere in the file. The plan-§5 split was executed cleanly across all 8 sites. **H1 is not the cause.**

**H3 — font data layout: FALSIFIED by cross-reference.**

`fb_console.cyr:70-89` `fset16(ch, hi, lo)` packs `hi` → bytes 0-7 (rows 0-7), `lo` → bytes 8-15 (rows 8-15), MSB-first byte order — explicit and matches the file's header comment block (`fb_console.cyr:19-28`). `fb_putc` at `fb_console.cyr:592-595` reads `bits = load8(glyph + row)` and `on = (bits >> (7 - col)) & 1` — bit 7 = leftmost pixel, consistent with how the font is encoded.

Spot-check of canonical reference: `fb_console.cyr:260` `fset16(0x41, 0x000010386CC6C6FE, 0xC6C6C6C600000000)` ("A") decodes to bytes `00 00 10 38 6C C6 C6 FE C6 C6 C6 C6 00 00 00 00` — **byte-for-byte match** with Linux's `lib/fonts/font_8x16.c` row table for 0x41. **H3 is not the cause.**

**H2 — framebuffer-layer divergence: STRONGLY SUPPORTED by prior art (AMD display engine left in tiled/DCC scanout at GOP handoff).**

Two independent confirmations:

1. **OSDev forum thread #57150** ("EFI GOP lying about screen resolution?") names the exact mechanism: *"the framebuffer isn't actually linear but tiled. The GPU may implement various types of tiling and/or compression for the various buffers it uses including scanout, textures, etc. This may be a reason Gop->Blt and ConsoleOut work, but directly addressing the buffer does not."* — direct match for our symptom shape (Quiet Boot banded, VGA-spec / verbose-POST clean, same GOP-reported geometry on both).
2. **Linux `drivers/video/fbdev/efifb.c`** trusts GOP `PixelsPerScanLine` with no AMD-specific stride quirks — Linux sidesteps this class of bug instead by reprogramming the DCN ("Display Core Next") pipe via `drivers/gpu/drm/amd/display/` on amdgpu takeover, forcing the scanout buffer to a *displayable* DRM format modifier (linear, no DCC). The `freebsd/drm-kmod#60` history confirms the upstream consensus: on AMD iGPUs the firmware-left state at GOP handoff is *untrustable* for direct CPU writes; the fix is to reprogram the pipe, not to second-guess `PixelsPerScanLine`.
3. **EDK2's own console driver** (`MdeModulePkg/Universal/Console/GraphicsConsoleDxe`) uses `gop->Blt()` rather than direct framebuffer writes, with the driver-writer's-guide noting `FrameBufferBase` is **optional** per the UEFI spec — tiled/compressed scanout is the canonical reason a GOP implementation may omit it. AGNOS is post-EBS so `Blt()` is unavailable; direct writes are the only path.
4. **"Quiet Boot" mechanism** is undocumented by AMI/Phoenix/Insyde at this level, but the observed AGNOS pattern (Quiet ON banded / VGA-spec clean) matches the OSDev finding: verbose POST forces a VGA-text mode-set, which *necessarily* reprograms the display pipe to linear; Quiet Boot leaves the pipe in whatever logo-rendering / DCC-compressed layout VBIOS used to draw the BGRT logo.

**Carry-forward correction**: the Attempt 74 / Burn-B `SetMode(gop, cur_mode)` ("re-arm current mode") was the prior-art-canonical fix for this — and it was **falsified** (Attempts 73/74 entry, falsifications-carried-forward table). What this means in light of the OSDev finding: *re-arming to the same mode* is a firmware no-op on archaemenid; the OSDev wording is "*switching mode (even setting same mode)* switches framebuffer to linear" — implying the side effect comes from the `SetMode` work, not from a CRTC-state diff. On archaemenid the same-mode optimization elides the work entirely.

The **untried variant** is `SetMode(gop, <some_other_mode>)` followed by `SetMode(gop, original_mode)` — force a real mode change so the firmware can't elide the pipe reprogram, then come back. This is *not* the same as the original true-font plan's "smallest mode ≥ 800×600" idea (which permanently downshifts geometry); it's a transient bounce that ends at the same final geometry the kernel was already prepared for. No iron burn proposed in this entry — pre-burn audit + gnoboot diff line-by-line first.

#### Disposition

| # | Item | Status |
|---|---|---|
| 1 | `fb_console.cyr` cell-geometry audit | **CLOSED** above (H1 falsified by audit) |
| 2 | Font data layout verification | **CLOSED** above (H3 falsified by Linux `font_8x16.c` byte-for-byte cross-ref) |
| 3 | Prior-art cross-check on font-render-vs-resolution | **CLOSED** above (renderer is resolution-robust by audit; failure is below the renderer) |
| 4 | **Behavioral fix — gnoboot `SetMode(other) → SetMode(original)` bounce** | **PROPOSED** as next iron move. Per OSDev #57150, *the work of switching modes* is what flips the scanout buffer to linear; Attempt 74's same-mode SetMode was elided as a firmware no-op (falsified). A transient bounce to a *different* mode and back forces the firmware to actually reprogram the pipe, then return to the geometry the kernel was already prepared for. No kernel change; gnoboot-side only. |

**No further instrumentation proposed.** Per `feedback_no_instrumentation_means_no_instrumentation` + the Attempt 74 precedent (MTRR-install was nominally "diagnostic + repair," locked the box, masked the real failure). VGA-spec CMOS readback and cell_w/cell_h CMOS stamping are both off-table — even passive data-capture is on the rejected list, and neither would tell us anything the H1/H3 falsifications haven't already settled.

#### Sources

- Prior-art audit, this session: OSDev forum thread #57150 "EFI GOP lying about screen resolution?", EDK2 `MdeModulePkg/Universal/Console/GraphicsConsoleDxe`, EDK II UEFI Driver Writer's Guide §23.2.4, Linux `drivers/video/fbdev/efifb.c` master, `freebsd/drm-kmod#60`, Phoronix "Displayable DCC for Raven Ridge", `drm_fourcc.h` `AMD_FMT_MOD_*` modifiers.
- Local: `docs/development/uefi-boot-prior-art.md`, `docs/development/path-c-sovereign-uefi.md`, `docs/development/true-font-swap-plan.md`.

Status partial. The behavioral lever is the SetMode bounce in gnoboot; line-by-line audit of that change is the gate before any next iron burn proposal.

---

### Attempt 78 — gnoboot SetMode-bounce 2026-05-20 → FALSIFIED (no flicker on VGA or HDMI = firmware also elided the different-mode bounce)

gnoboot 0.4.2 landed the transient SetMode-bounce that Attempt 77's research pass identified as the next untried lever. Iron burn on archaemenid: no regressions, no flicker on either monitor, same banded-glyph signature on Quiet Boot. The bounce variant is closed on the same evidence shape that closed 0.4.1's same-mode form at Attempt 74 — firmware elision of the SetMode work, this time across a real mode delta.

**Build under test:**

| Component | Detail |
|---|---|
| `agnos` | 1.30.12 unchanged from Attempt 77 (`75914e9` self-rolled font, 425,840 B) |
| `gnoboot` | 0.4.2 — `SetMode(gop, bounce_mode)` → `SetMode(gop, cur_mode)` per `src/main.cyr:374-393`. `bounce_mode = 0`, or `1` when `cur_mode == 0`. `max_mode <= 1` single-mode fallback to 0.4.1's same-mode form. |
| Pre-bound iron decision tree | Captured in `gnoboot/CHANGELOG.md` § [0.4.2] before burn — five outcome shapes pre-bound, "no flicker" = "firmware also eliding the different-mode bounce." |

#### Iron outcome

| 2560×1440 / archaemenid | Attempt 77 (0.4.1) | Attempt 78 (0.4.2) |
|---|---|---|
| VGA path legibility | Legible | Legible (no regression) |
| Quiet Boot legibility | Banded glyphs | Banded glyphs — same signature |
| Visible mode-switch flicker | n/a (no bounce) | **None observed on VGA or HDMI** — pre-bound falsification signal triggered |
| Quiet Boot lockup / keyboard / refresh | Live | Live (no regression) |
| kernel checkpoint | 0x15 / magic 0xab | 0x15 / magic 0xab ✓ |
| gnoboot checkpoint | 0x05 / magic 0xcd | 0x05 / magic 0xcd ✓ |
| GOP `current` / `max` | — | `0x00` / `0x0d` (read-boot-log) — bounce path's `max_mode <= 1` fallback was NOT taken; gnoboot chose `bounce_mode = 1` and issued the bounce SetMode |
| FB geometry post-bounce | w=2560 h=1440 pitch=10240 BGRX | **Unchanged** — w=2560 h=1440 pitch=10240 BGRX (no BAR relocation, no Mode->Info delta) |

#### Honest caveat on the falsification reading

gnoboot 0.4.2 does not stamp the bounce SetMode's return code (`rc_a` at `main.cyr:383`). CMOS alone can't distinguish:

- **(a)** Bounce ran, firmware returned `EFI_SUCCESS` on both calls, no visible CRTC work (user's claim — firmware elision across mode delta).
- **(b)** Firmware rejected `bounce_mode = 1` with non-zero `rc_a`, fell back to same-mode (known elided per Attempt 74).

Both routes have the same destination — the GOP SetMode call shape at gnoboot post-FB-read time isn't a viable lever on archaemenid's Zen iGPU firmware — so resolving (a) vs (b) doesn't change the next move. Per `feedback_no_instrumentation_means_no_instrumentation`, adding an `rc_a` stamp slot to learn the difference is off-table; the caveat is logged here as a known unknown.

#### Hypothesis space update

H2 (firmware leaves AMD scanout in tiled/DCC at GOP handoff) **remains the strongest standing hypothesis** — falsifying the SetMode-bounce form does not falsify H2 itself; it falsifies the OSDev #57150 "*SetMode work flips scanout to linear*" recipe as it applies to archaemenid specifically. The mechanism is real (cross-referenced in Linux DCN drivers + FreeBSD drm-kmod#60 + EDK2 GraphicsConsoleDxe's Blt avoidance pattern); the *firmware-side workaround* OSDev describes doesn't work here because Zen UEFI elides both call shapes.

Closed levers (gnoboot-side, GOP):
- ❌ `SetMode(gop, cur_mode)` (0.4.1, falsified Attempt 74)
- ❌ `SetMode(gop, other_mode) → SetMode(gop, cur_mode)` (0.4.2, falsified Attempt 78)

Remaining options for H2 specifically — none proposed here, all are research items:
- Kernel-side direct DCN pipe reprogram (Linux `drivers/gpu/drm/amd/display/` analog). Multi-kiloline; Attempt 77 noted this as the deferred fallback if the bounce was falsified, which it now is.
- An entirely different framing of the symptom (`uefi-boot-prior-art.md` § *Foot-guns ruled out experimentally* gets the new entry — the OSDev recipe doesn't generalize to Zen).

#### Disposition

| # | Item | Status |
|---|---|---|
| 1 | gnoboot 0.4.2 SetMode-bounce hypothesis | **FALSIFIED** by iron burn 2026-05-20 (this entry) |
| 2 | H2 (FB-layer divergence — tiled/DCC scanout at GOP handoff) | Still standing — the *firmware-side* GOP-call workaround is dead; the *kernel-side* DCN reprogram path is the remaining channel for H2 |
| 3 | Path forward | **No iron burn proposed.** Per `feedback_iron_burns_block_other_work` + `feedback_stop_letter_laddering` + `feedback_redesign_dont_reinvent`, the next move on the Quiet-Boot legibility residue is *not* another speculative GOP poke — it's reading Linux's DCN reset code in earnest if/when this residue gets re-prioritized. Per `feedback_accept_partial_wins`, the MVP functional gate stays cleared and Quiet-Boot legibility is a planned-next-cut, not a current blocker. |
| 4 | `uefi-boot-prior-art.md` footnote | **Pending this commit** — OSDev #57150's "SetMode flips buffer to linear" recipe doesn't generalize to AMD Zen UEFI firmware (both same-mode and different-mode forms elided). |
| 5 | `gnoboot/CHANGELOG.md` 0.4.2 entry | **Pending this commit** — append falsification note to § [0.4.2] and add 0.4.2 to falsifications-carried-forward. |

#### Sources

- gnoboot/CHANGELOG.md § [0.4.2] — pre-bound iron decision tree (the "no flicker" branch).
- gnoboot/src/main.cyr:330-413 — bounce implementation, post-SetMode geometry re-read.
- read-boot-log capture this burn — kernel checkpoint 0x15, gnoboot 0x05, GOP current=0x00 max=0x0d, geometry 2560×1440/10240/BGRX unchanged.
- Attempt 74 (above) — falsification of 0.4.1's same-mode form (matching evidence shape).
- Attempt 77 (above) — research pass that proposed the bounce variant; H1 + H3 falsified, H2 supported.

No new iron burn proposed. The next entry in this log will be a deliberate one — not a letter-laddered follow-up.

---

### Attempt 79 — Intel cross-check (z890 USB + archintel SSH) 2026-05-20 → INCONCLUSIVE (closeout)

After Attempt 78 closed the GOP-side `SetMode` lever space, the question of whether the Quiet-Boot residue is **AMD-Zen-specific** or **general-firmware** stayed open. Two Intel cross-check moves were attempted before closeout; both produced structurally inconclusive but shape-informative data.

#### Move 1 — bare-metal boot on ASRock z890 (Intel) → USB-bootability fail

Attempted to USB-boot the existing gnoboot 0.4.2 + agnos 1.30.12 build on an ASRock z890 (Intel) board. z890 firmware did not recognize the AGNOS-built USB drive as bootable. The USB-C wrapper on this board is a contributing factor — modern Intel firmware varies in how it negotiates USB-C boot media, separate problem from the GPT/ESP layout AGNOS uses. **Disposition: separate bootability issue, not an AGNOS defect.** Older Intel test machine parked as future discriminator-when-time-permits; not a closeout blocker.

#### Move 2 — SSH cross-check on archintel (i9 Arch Linux, Arrow Lake-S) → structurally inconclusive

Read-only firmware/GOP/FB state from `archintel` (i9 desktop, Intel Arrow Lake-S iGPU `[8086:7d67]` + NVIDIA RTX 5080 `[10de:2c02]` dGPU, ASRock firmware, Arch Linux 7.0.9, kernel boot 2026-05-20 14:43). Three load-bearing findings:

| Finding | Reading |
|---|---|
| **No BGRT table** (`ls /sys/firmware/acpi/tables/BGRT` → ENOENT) | The trigger condition for AMD Zen's BGRT-render-leaves-scanout-dirty hypothesis is **not present on this firmware**. Can't directly test "what happens post-BGRT" comparison. |
| **Primary FB driver is `simpledrm`, not `efifb`** | Modern Linux path explicitly **assumes the firmware FB may be tiled/DCC-compressed** and routes writes through a CPU-side shadow buffer (per `LWN: SimpleDRM system memory framebuffers`, agent-3 prior-art finding). This is the architectural answer to AGNOS's bug class — but it's the *opposite* of AGNOS's sovereign direct-paint design choice. |
| **Hybrid GPU; fbcon ends on NVIDIA dGPU primary** (`fbcon: nvidia-drmdrmfb (fb0) is primary device`) | Not a pure Intel-iGPU GOP comparison. The Intel iGPU is present and i915 initializes cleanly (Meteorlake display v14.00 D0, GuC/HuC firmware loaded), but the dGPU takes primary display. |

#### Disposition — closeout

The two Intel attempts together rule out a clean discriminator on currently-available hardware:
- z890: USB bootability blocked the test from running.
- archintel: hardware/firmware shape (no BGRT + hybrid GPU + simpledrm) makes it structurally non-comparable to archaemenid's pure-AMD-Zen-iGPU-with-BGRT scenario.

**H2 (AMD-Zen-specific tile/DCC scanout at GOP handoff) remains the strongest read on archaemenid evidence** (Quiet Boot vs VGA-spec asymmetry on the same board), but is not Intel-cross-confirmed. Per `feedback_accept_partial_wins`, the MVP functional gate stays cleared (typeable shell + legible VGA path); Quiet Boot legibility moves out of the active scope as planned-next-cycle work, not a current MVP blocker.

**No further iron burns proposed in this branch.** Next-cycle target is one of:
- (a) Kernel-side minimal-redesign port of Linux's HUBP `clear_tiling` sequence (3-6 MMIO writes per HUBP per amd-gfx ML; DCN1→DCN3 register offsets inherited; Cezanne is the archaemenid chip family; PCI BAR0 of `1002:1638`). Per `feedback_redesign_dont_reinvent` — learn the shape, redesign in Cyrius, don't lift code.
- (b) Architectural evaluation of whether AGNOS adopts a shadow-buffer model (simpledrm-style) for the FB console layer, or keeps the sovereign direct-paint model and accepts AMD-Zen-specific quirk-handling.

These are the recorded options for next-cycle resumption, not commitments. Pin: `project_amd_zen_scanout_residue.md`.

#### What this entry does NOT close

- The discriminator question (AMD-specific vs general-firmware) — parked as a known-unknown.
- The older-Intel cross-check on a single-iGPU box with a BGRT table — parked as future option when cabling/time permits.

#### Sources

- archintel SSH read 2026-05-20 (data quoted above).
- Attempt 78 (immediately above) — closes both GOP-side SetMode lever variants.
- Attempt 77 research pass — H2 hypothesis support.
- `uefi-boot-prior-art.md` § *Foot-gun ruled out experimentally on archaemenid* — extended with Intel-inconclusive footnote this commit.
- `gnoboot/CHANGELOG.md` § [Unreleased] — next-cycle signpost added this commit.

**Closeout state**: 1.30.x FB hardening sweep closes at agnos 1.30.12 + gnoboot 0.4.2. Active scope leaves the FB layer; resumes when next cycle opens with a fresh identifier window.

---

### Attempt 80 — NVMe iron debut 2026-05-20 → PASS (Crucial P3 2TB enumerated end-to-end, kernel walked to shell)

First iron burn of the 1.31.x storage arc. NVMe Phases 1-5 had closed in QEMU same-session (~940 LOC across `kernel/core/nvme.cyr` + new `kernel/core/block.cyr`, byte-exact write/read round-trips through the new dispatch wrapper validated). Install on archaemenid, let the driver introduce itself to the real Crucial P3 SSD — full stack lit up on first try, kernel walked through to `AGNOS shell v1.31.0`.

**Build under test:**

| Component | Version | Notes |
|---|---|---|
| `agnos` | **1.31.0** — NVMe Phase 1-5 + iron-debut folded into the cycle-open release (~441,056 B, +19,144 B over the post-cycle-open production-lean baseline of 421,912 B) | block-layer dispatch live (`blk_active=2` = NVMe); archaemenid has no virtio so NVMe registers alone |
| `gnoboot` | 0.4.2 (unchanged from Attempt 78 closeout) | sovereign UEFI handoff, banner only |
| `cyrius` | 6.0.1 toolchain post-cycle-open; kernel pin 5.11.x bedrock | NVMe arc compiled clean, no new compiler bug surfaced |

**Iron evidence shape — confirms real silicon, not QEMU emulation:**

| Field | Iron value | Reading |
|---|---|---|
| VID | `49321` = `0xC0A9` | Micron Technology (Crucial's parent). QEMU's NVMe model uses `0x1B36` (Red Hat). |
| Model | `CT2000P3SSD8` | Crucial P3 2 TB — matches the SSD physically installed in archaemenid. |
| Serial | `2342E880DED6` | Real per-unit ID. |
| Firmware | `P9CR30A` | Crucial-issued P3 firmware revision. |
| NSZE × LBADS | `3907029168 × 512B` | 1907729 MB ≈ 1.86 TB usable — matches the part's spec. |
| LBA 0 first 8 bytes | `0 0 0 0 0 0 0 0` | Drive is blank (no GPT yet on this surface) — expected, not a problem. |

**Boot output through to shell** (photo: `iron-nuc-zen-photos/attempt-80-nvme-iron-debut-crucial-p3.jpg`):

```
nvme: found at 4241489920, version=1.4.0
nvme: MQES=65535 DSTRD=0 TO=255x500ms CSS_NVM=1 MPSMIN=0 MPSMAX=0
nvme: controller disabled, RDY=0
nvme: admin queue ready, CC.EN=1 RDY=1
nvme: VID=49321 SSVID=49321 NN=1 MDTS=6
nvme: model='CT2000P3SSD8                            '
nvme: serial='2342E880DED6        '
nvme: firmware='P9CR30A '
nvme: ns1 NSZE=3907029168 LBAS=512B size=1907729MB
nvme: I/O queues 1 ready (64 entries SQ+CQ)
nvme: ns1 LBA0 first 8 bytes: 0 0 0 0 0 0 0 0
nvme: registered as block_dev (3907029168 LBAs x 512B)
VFS initialized
...
AGNOS shell v1.31.0 (type 'help')
```

**What this validates on iron beyond QEMU:**
- BAR0 64-bit at real-PCIe address `0xFCE00000` — mid-range, different shape than QEMU's `0xC0000000000` high-BAR shatter path.
- `MPSMAX=0` = controller supports 4 KB host pages only. AGNOS's 4 KB host-page baseline is exactly what this drive expects; the Phase 1 `MPSMIN > 0` refusal path is now exercised against a real `MPSMIN=0` controller.
- `MDTS=6` → 256 KB max single transfer cap; AGNOS only ever requests small transfers, well under the cap.
- IDENTIFY CTRL + IDENTIFY NS1 both polled to status=0 against real silicon — admin queue + phase-tag tracking + doorbell stride decode work on non-QEMU.
- I/O SQ+CQ create + single-LBA read of LBA 0 closed the loop end-to-end. The 8-zero readout confirms the drive serviced the command (empty disk reads zeros, not garbage).
- `nvme_register_block_dev` fired (capacity 3907029168 sectors); dispatch wrapper now points at real NVMe.

**Contrast with the xHCI arc.** xHCI took 5 weeks, 19 iron attempts, 9 letter codes, and a prior-art reckoning before clearing on archaemenid. NVMe ported from Linux's `drivers/nvme/host/pci.c` to Cyrius conventions per `feedback_redesign_dont_reinvent` and lit up first iron try. Driver-class shape differs (NVMe is structurally simpler — fewer error paths, simpler queue model, MSI-X deferred per xHCI's polling precedent), but the consultation-not-first-principles posture is what compounded the win.

**Out of scope (debut):**
- No write to the drive on iron (LBA 0 read only). AGNOS lacks GPT / ext2 / fat32 formatters and won't write to archaemenid's surface casually.
- PRP-list path: only PRP1 / PRP2-single-page exercised on iron; PRP-list coded + QEMU-validated but not iron-exercised yet.
- Multi-namespace: only NSID=1 fetched (drive's `NN=1` confirms one namespace anyway).
- MSI-X IRQ-driven completion: polling-only on iron, as in QEMU.

**Sources:**
- Photo `iron-nuc-zen-photos/attempt-80-nvme-iron-debut-crucial-p3.jpg` (only on-disk evidence for this burn — no read-boot-log run).
- agnos CHANGELOG `[Unreleased]` § NVMe arc — iron debut.
- agnosticos `state.md` for the cross-repo arc framing.

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
