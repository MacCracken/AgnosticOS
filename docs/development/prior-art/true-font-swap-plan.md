# True-Font Swap Plan — replace hand-drawn 8×8 CGA with a real bitmap font

> **Status**: Drafted 2026-05-20 | Trigger: Iron Attempt 76 cleared three of four MVP bars under Quiet Boot on archaemenid (no lockup / live keyboard / live refresh) but left the fourth — **glyph legibility** — unsolved because scaling a primitive 8×8 hand-drawn bitmap bigger makes each pixel bigger, not each letter more readable.
> **Scope**: agnos `kernel/arch/x86_64/fb_console.cyr` — font data + render loop only. No new boot_info field, no gnoboot change, no Cyrius change.
> **Target version**: agnos 1.30.12 (one minor bump from 1.30.11 — visual quality is the only thing this cut moves).
> **Iron burn**: one. Decisive signal is "the shell prompt is legible on archaemenid Quiet Boot at 2560×1440."

---

## Problem

`fb_font[768]` in `fb_console.cyr` is 96 glyphs × 8 bytes each, hand-coded as CGA-style 8×8 bitmaps via `fset(ch, u64)` calls. The 8×8 grid is genuinely too coarse — even at scale=3 (the largest `fb_scale()` produces below 4K), letters like `e`, `a`, `s` read as featureless dot-clusters because the source bitmap doesn't have enough vertical pixels to distinguish them. The Attempt 76 photo confirms: pixels got bigger, letters did not.

Scaling further (scale=5/6/+) wastes screen area without improving legibility — the information just isn't in the source bitmap. The fix is to swap the source bitmap for a font with more vertical pixels per glyph.

## Constraints

- **Sovereign / GPL-compatible.** AGNOS is GPL-3.0-only. Font data needs to be either public domain or under a GPL-compatible permissive license (BSD / MIT / OFL with attribution).
- **Cyrius-source embedded.** No binary blob loaded at boot — the font is in-kernel data. Cyrius source convention is `fset(ch, ...)` calls populating `var fb_font[N]` at init time.
- **No new boot_info field.** gnoboot is at 0.4.1 with a stable Path-C ABI; this work doesn't touch the handoff.
- **No regressions.** VGA-spec path (Attempt 68 MVP gate at 1024×768) must keep working. Quiet Boot path (Attempt 76 functional gate at 2560×1440) must keep its three already-cleared bars.
- **Single iron burn.** Per `feedback_iron_burns_block_other_work` — every burn holds up the user's other archaemenid work; the visual swap is bundled into one cut, not split into a ladder.

## Font-source options

| Option | License | Sizes available | Bytes per glyph (ASCII 0x20-0x7F) | Notes |
|---|---|---|---|---|
| **A. VGA 8×16 BIOS font** | Public domain (IBM CGA/VGA ROM, in public use since 1981) | 8×16 only | 16 (96 × 16 = 1,536 B) | Linux `lib/fonts/font_8x16.c`, FreeBSD `share/syscons/fonts/cp437-8x16.fnt`; the canonical "PC text mode" font. Drop-in shape match with current `fset` interface — just longer per-glyph encoding. Sovereign choice. |
| **B. Spleen 16×32** | BSD-2-Clause (attribution) | 5×8, 8×16, 12×24, 16×32, 32×64 | 64 (96 × 64 = 6,144 B) | Modern bitmap; sharper than VGA ROM at high DPI. Multi-size means we could later use 8×16 for 1080p and 16×32 for 2K+ without re-rendering. Attribution + license header in source file. |
| **C. Terminus 16×32** | OFL-1.1 with reserved name "Terminus" | 12×24, 14×28, 16×32, etc. | 64 (96 × 64 = 6,144 B) | Long-running BSD/Linux console font; very legible at large sizes. OFL "reserved name" clause means we can use the font but can't redistribute a modified version under the same name. |
| **D. Cozette 6×13 / 13×26 at 2×** | MIT | 6×13 native | varies | Newer, designed for high-DPI terminal use. Non-power-of-2 width adds rendering complexity (no clean `bits >> (7 - col)` pattern). Skip for MVP. |

### Recommendation: **Option A — VGA 8×16**

Rationale (MVP-shaped):

- **Lowest-risk swap.** Same data shape (one byte per row, bit 7 = leftmost), same `fset`-style init pattern, same render loop — just double the row count (8 → 16) and double `fb_font` size (768 → 1,536). The existing `fb_scale()` adaptive scale stays.
- **Public domain.** No attribution, no license-header coupling, no upstream churn risk. Aligns with the sovereignty thread that already runs through gnoboot / Cyrius.
- **2× vertical resolution** is the cheapest legibility win. At archaemenid Quiet Boot 1440p with `fb_scale()` = 3, that's a 24×48 cell — readable text-shaped objects. At 1080p with scale=2, 16×32 — comfortably readable.
- **Familiar to every developer who's seen a PC text-mode console.** Default mental model match for "what does an OS shell look like."

Spleen 16×32 (Option B) is the right next step *if* VGA 8×16 turns out to still be too coarse at native HDMI resolution after the swap lands. Defer it to 1.31.x as a quality bump; don't bundle it into the MVP visibility burn.

## Scope of code change

All edits in `kernel/arch/x86_64/fb_console.cyr`. No other file should need to change for the font swap itself (version + banner update is separate per `feedback_no_unprompted_version_bumps`).

### 1. Storage

```cyrius
# Was: var fb_font[768];      # 96 glyphs × 8 bytes
var fb_font[1536];             # 96 glyphs × 16 bytes
```

### 2. `fset` — pack 16 bytes per glyph

The current `fset(ch, val: u64)` packs 8 bytes from one u64. For 16 rows we need 16 bytes, which doesn't fit in a single u64. Two options:

- **`fset16(ch, hi: u64, lo: u64)`** — two u64s, `hi` = rows 0-7, `lo` = rows 8-15. Each literal then reads top-to-bottom 16-row glyph as `0xR0...R7 0xR8...RF`.
- **`fset_row(ch, row, byte)`** — one byte per call, 16 calls per glyph. More mechanical, ~1,536 lines for the init table (vs ~96 with the dual-u64 form).

Recommendation: `fset16(ch, hi, lo)`. Same one-line-per-character init pattern, just two u64 literals per call.

### 3. Init table

96 lines, one per ASCII 0x20-0x7F. Source font data transcribed from the VGA ROM 8×16 dump. The data is identical across multiple sources (Linux, FreeBSD, original IBM ROM); pick any and verify the first 8 rows of `'A'` against a known reference (Linux `font_8x16.c` line for char 0x41 should match the high u64).

### 4. Render — 16 rows instead of 8

```cyrius
# fb_putc render loop, was:
for (var row = 0; row < 8; row = row + 1) { ... }
# Becomes:
for (var row = 0; row < 16; row = row + 1) {
    var bits = load8(glyph + row);
    # ... same inner loop ...
}
```

### 5. Cell geometry

```cyrius
# Was: cell_w = 8 * fb_scale()  -> square cell
# Becomes:
var cell_w = 8  * fb_scale();   # width  (font is 8 wide)
var cell_h = 16 * fb_scale();   # height (font is 16 tall)
```

This is the load-bearing change. Every place that currently uses `cell_w` for *both* horizontal and vertical extents must split: horizontal extents still use `cell_w` (= 8×scale), vertical extents use `cell_h` (= 16×scale).

Affected sites in `fb_console.cyr`:
- `fb_fill_cell` — inner loops bound by `cell_w` for x and `cell_h` for y.
- `fb_scroll_up` — scroll distance is `cell_h`, not `cell_w`. The `rows_to_copy` and bottom-clear loops use `cell_h`.
- `fb_putc` — `max_rows = (height - FB_CONSOLE_Y0) / cell_h`. Row advance after newline / wrap uses `cell_h`.
- Render block in `fb_putc` — outer loop 0..16 over rows, each row paints `s` lines of `s` pixels wide.

### 6. `fb_scale()` revisit

With a 16-tall source font, the legibility thresholds shift. Current thresholds were tuned for 8-tall glyphs:

| Display height | Current scale (8-tall) | Cell h | Proposed (16-tall) | Cell h |
|---|---|---|---|---|
| ≤900  (e.g., 1024×768)  | 1 | 8  | 1 | 16 |
| ≤1200 (e.g., 1920×1080) | 2 | 16 | 1 | 16 |
| ≤1800 (e.g., 2560×1440) | 3 | 24 | 2 | 32 |
| >1800 (e.g., 3840×2160) | 4 | 32 | 2 | 32 |

With a real 8×16 font, scale=1 is already legible at 1080p — no need for 2×. At 1440p, scale=2 gives 16×32 = comfortable. At 4K, scale=2 still works (32-px text on a 2160-px display = 1.5% of height, sit-back-distance readable).

Recommendation: drop `fb_scale` to a 2-tier function (`return 1 if h <= 1200, else 2`) — fewer rendering paths, no behavior beyond the visible thresholds.

### 7. Cleanup (bundled per `feedback_iron_burns_block_other_work`)

Since this is a single burn, fold these in the same cut:

- Delete the dead-code MTRR-install / audit functions (Out-of-scope item from 1.30.11 CHANGELOG). `fb_mtrr_install_wc`, `fb_audit_mtrr`, `fb_audit_pci_bar` and their helpers (`pci_cfg_addr`, `pci_cfg_read32`) lose their last call sites — full removal frees ~150 lines and ~5 KB binary.
- Update the file-header comment block referencing "8x8" glyphs.
- Update `kernel/version.cyr` banners to 1.30.12.

### 8. Out of scope for this cut

- **Color attributes / per-character colors.** White-on-black stays.
- **Unicode beyond ASCII 0x20-0x7F.** CP437 line-drawing chars stay future work.
- **Font fallback / multiple font slots.** One font, compiled in.
- **Cursor blink, soft cursor, hardware cursor.** No cursor visible work in this cut.
- **Shadow buffer.** Still 1.31.x triage.

## Verification

### QEMU smoke (before any iron burn)

`agnosticos/scripts/qemu-fb-smoke.sh` already exists from 1.30.11. Run twice:

```sh
QEMU_RES=1920x1080 ./scripts/qemu-fb-smoke.sh   # scale=1 path
QEMU_RES=2560x1440 ./scripts/qemu-fb-smoke.sh   # scale=2 path
```

Both must hit `EXPECT="AGNOS shell"` on ConOut. The headless smoke proves the *render loop* doesn't crash; it doesn't prove legibility (which needs a visual / iron). For legibility, capture a `qemu-fb-visual.sh` screenshot of each and eyeball.

### Iron burn protocol (single burn, archaemenid)

1. Build: `cd kernel && ../scripts/build.sh` — confirm `build/agnos` exists, multiboot2 ELF64 entry preserved at `0x1000a8`, size delta vs 422,048 B (1.30.11) is +1.5 KB ish (font data) minus ~5 KB (MTRR/audit dead-code removal) = roughly **-3.5 KB net**.
2. `sudo ./scripts/install-usb.sh --update /dev/sdX`.
3. **VGA-spec regression check first.** Boot archaemenid with BIOS toggled to VGA-spec + QuickBoot. Type a few characters. Expected: legible shell prompt, no regression vs Attempt 68. Photo to `iron-nuc-zen-photos/attempt-77-vga-baseline.jpg`.
4. **Quiet Boot decisive check.** Boot archaemenid with BIOS toggled to Quiet Boot ON. Wait for shell prompt to render. Expected: legible shell prompt (the whole point of the burn). Type something. Photo to `iron-nuc-zen-photos/attempt-77-quiet-boot-legible.jpg`.
5. Power off cleanly. Boot Linux. `sudo ./scripts/read-boot-log.sh` — CMOS extended-bank geometry stamps should match Attempt 71's `pf=1 w=2560 h=1440 pitch=10240` (geometry path unchanged, just sanity).

### Pre-bound decision tree

| Iron outcome | Diagnosis | Next move |
|---|---|---|
| VGA legible, Quiet Boot legible | **PASS.** 1.30.12 MVP-visual gate clear. | Close 1.30.x at .12. Triage 1.31.x scope. |
| VGA legible, Quiet Boot still illegible | Font swap correct but scale tier wrong for Quiet Boot 1440p | Bump `fb_scale()` threshold for ≤1800 from 2 to 3 (= 24×48 cell). One-line change, second burn. |
| VGA regressed (illegible / wrong size at 1024×768) | Scale tier wrong for low-res VGA path | Verify `fb_scale()` returns 1 for h ≤ 900; if it's returning something else, fix bug. |
| System lockup under Quiet Boot | Something in the cleanup bundle (Cleanup §7) broke it | `git bisect` — but the only behavioral cleanup is the dead-code deletion, which can't affect runtime by definition. Most likely an init-table typo in a glyph that loads into bad memory. Audit fset16 calls. |

## What this plan is NOT

- **Not a Spleen / Terminus / Cozette adoption plan.** That's a 1.31.x quality-bump conversation.
- **Not a Unicode plan.** ASCII 0x20-0x7F covers shell + login MOTD + commandress prompt; that's MVP. Unicode is post-MVP.
- **Not a font-loading plan.** No filesystem access, no font selection at runtime. Compiled-in only.
- **Not a refactor of the FB paint pipeline.** The pitch-aware WC-mapped u64 block-copy work from 1.30.10/11 stays as-is.

## Related

- `iron-nuc-zen-log.md` § Attempt 76 — what cleared the 3-of-4 bars and exposed the font-source issue.
- `feedback_display_density_before_speculation` — the memory that closed the wrong-layer arc (Attempts 71-74) and surfaced this work.
- `feedback_redesign_dont_reinvent` — VGA 8×16 = canonical reference impl; no first-principles glyph design.
- `feedback_iron_burns_block_other_work` — single burn, bundled cleanup.
- `path-c-sovereign-uefi.md` — the bootloader plan that's load-bearing for the FB this work paints into.
