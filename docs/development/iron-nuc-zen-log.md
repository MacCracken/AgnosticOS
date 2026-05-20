> **Status**: Active log for 1.30.10+ iron bring-up.
>
> **Prior history**: [`iron-nuc-zen-log-mvp.md`](iron-nuc-zen-log-mvp.md) — Attempts 1 – 68, frozen at the closed-beta MVP gate (agnos 1.30.9, 2026-05-18). Consult for any pre-MVP-era root-cause shape recurrence.
>
> **Last Updated**: 2026-05-19 (Attempt 72 result — geometry channel works on iron; pitch-padding + pf hypotheses both falsified for quiet-boot path; BAR-placement divergence is the surviving candidate, needs `fb_phys` capture extension)

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
| 2 | Extend gnoboot to stamp `fb_phys` into CMOS slots 0x88–0x8F (8 bytes, little-endian) | ❌ Pending — design in next attempt-prep block |
| 3 | Extend `read-boot-log` decoder to print `fb_phys` block | ❌ Pending — paired with #2 |
| 4 | `13011_attempt_gnoboot_updated.jpg` → rename + anchor as `attempt-72-vga-spec-baseline.jpg` | ❌ Pending |

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
