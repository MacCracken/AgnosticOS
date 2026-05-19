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
