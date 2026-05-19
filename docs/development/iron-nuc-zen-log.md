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

_(No attempts yet — log opens 2026-05-19, post-MVP scope. First entry will be Attempt 69 once a 1.30.10 burn is proposed.)_

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
