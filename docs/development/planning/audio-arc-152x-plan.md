# AGNOS 1.52.x Audio Arc — VERIFIED Implementation Plan

> **Provenance:** synthesized 2026-07-03 from a 16-agent prior-art workflow (6 source-grounded
> maps — Intel HDA 1.0a spec, codec/ALC897 verbs, Linux `sound/pci/hda`, FreeBSD/minimal-OS,
> QEMU model, agnos-substrate reuse — → 9 adversarial verify passes → this synthesis). It
> **completes the adversarial-verify pass the [scoping doc](audio-arc-152x.md) never finished**
> and is the authoritative "how" the coder writes `kernel/core/hda.cyr` from; the scoping doc
> remains the "why/scope". **Corrections baked in vs the scoping doc:** SDnFMT `0x4011`→`0x0011`
> for 48k (0x4011 = 44.1kHz, correct only on the DOOM path); the front jack is **HP-Out(0x2)**
> not Line-Out; SDO0 = `0x80 + ISS*0x20` (compute from GCAP, not hardcoded); EAPD/COEF are the
> "enumerates-but-silent-on-iron" gate; the syscall band is **#64–#69** (symlink took #63).

# AGNOS 1.52.x Audio-Output Arc — Implementation Plan for `kernel/core/hda.cyr`

**Target:** Sovereign polled Intel HDA / Azalia output driver on archaemenid PCI `04:00.6 [1022:15e3]`, codec ALC897 (`0x10ec0897`), front headphone jack.
**Status:** greenfield — `kernel/core/hda.cyr` does not exist. VERSION at repo = `1.52.0` (B0 cut is open).
**Model:** polled / no-IRQ (r8169 IMR=0 posture); `INTCTL@0x20` stays 0 for the whole arc.

This plan folds in every REFUTED/UNCERTAIN correction from the adversarial pass. The two highest-value corrections are baked in globally:

- **SDnFMT for 48k/16/2ch is `0x0011`, NOT `0x4011`** (`0x4011` = 44.1 kHz base). CONFIRMED four times. Encode from named fields, never a magic literal.
- **Front jack on ALC897 is HP-Out (`0x2`), NOT Line-Out (`0x0`)** — the "pick Line-Out lowest-sequence" rule is REFUTED. Accept **both** HP-Out and Line-Out candidate pins and select by connectivity + location + a live `/proc/asound`-equivalent dump.

---

## 0. Global constants (define once, no magic literals)

```
# Controller register offsets (verified Linux hda_register.h + Intel spec 1.0a)
HDA_GCAP=0x00  HDA_VMIN=0x02  HDA_VMAJ=0x03  HDA_GCTL=0x08
HDA_WAKEEN=0x0C  HDA_STATESTS=0x0E  HDA_GSTS=0x10
HDA_INTCTL=0x20  HDA_INTSTS=0x24  HDA_WALLCLK=0x30
HDA_CORBLBASE=0x40 HDA_CORBUBASE=0x44 HDA_CORBWP=0x48 HDA_CORBRP=0x4A
HDA_CORBCTL=0x4C HDA_CORBSTS=0x4D HDA_CORBSIZE=0x4E
HDA_RIRBLBASE=0x50 HDA_RIRBUBASE=0x54 HDA_RIRBWP=0x58 HDA_RINTCNT=0x5A
HDA_RIRBCTL=0x5C HDA_RIRBSTS=0x5D HDA_RIRBSIZE=0x5E
HDA_IC=0x60 HDA_IR=0x64 HDA_IRS=0x68            # immediate-command path (B1 shortcut)
HDA_DPLBASE=0x70 HDA_DPUBASE=0x74              # DMA-position buffer (leave disabled)
HDA_SD_BASE=0x80  HDA_SD_STRIDE=0x20
# Stream-descriptor sub-offsets (add to per-stream base)
SD_CTL=0x00 SD_STS=0x03 SD_LPIB=0x04 SD_CBL=0x08 SD_LVI=0x0C
SD_FIFOW=0x0E SD_FIFOSIZE=0x10 SD_FMT=0x12 SD_BDPL=0x18 SD_BDPU=0x1C   # BDPU=0x1C (0x1B is an extract artifact)

# Bit fields
GCTL_CRST=0x1        # GCTL bit0
STATESTS_MASK=0x7FFF
CORBRP_RST=0x8000  RIRBWP_RST=0x8000
CORBCTL_RUN=0x2  RIRBCTL_DMAEN=0x2
SD_SRST=0x1  SD_RUN=0x2  SD_STREAM_TAG_SHIFT=20
IRS_ICB=0x1  IRS_IRV=0x2

# SDnFMT field encoders — CORRECTED (verdict CONFIRMED x4)
HDA_FMT_BASE_48K=0x0000     # bit14 CLEAR = 48kHz base
HDA_FMT_BASE_44K=0x4000     # bit14 SET = 44.1kHz base
HDA_FMT_BITS_16=0x0010      # (1<<4)
fn hda_fmt_chan(n) { return (n - 1) & 0xF; }       # channels-1
# 48k/16/2ch  = HDA_FMT_BASE_48K | HDA_FMT_BITS_16 | hda_fmt_chan(2) = 0x0011
# 44.1k/16/2ch = HDA_FMT_BASE_44K | HDA_FMT_BITS_16 | hda_fmt_chan(2) = 0x4011
# 48kHz depends on BASE=0 AND MULT(13:11)=0 AND DIV(10:8)=0 — all satisfied by 0x0011.

# Verbs (12-bit form: verb<<8 | data8 ; 4-bit form: verb<<16 | data16)
V_GET_PARAM=0xF00  V_GET_CFGDEF=0xF1C  V_GET_CONNLIST=0xF02  V_GET_CONNSEL=0xF01
V_GET_PINSENSE=0xF09  V_GET_PROC_COEF=0xC00
V_SET_STREAM_FMT=0x200  V_SET_AMP=0x300  V_SET_PROC_COEF=0x400  V_SET_COEF_IDX=0x500
V_SET_CONNSEL=0x701  V_SET_POWER=0x705  V_SET_STREAMID=0x706  V_SET_PINCTL=0x707
V_SET_EAPD=0x70C  V_SET_GPIO_DATA=0x715  V_SET_GPIO_MASK=0x716  V_SET_GPIO_DIR=0x717
# GET_PARAM sub-ids
P_VENDOR=0x00 P_NODECOUNT=0x04 P_FNTYPE=0x05 P_WCAP=0x09 P_PCM=0x0A P_PINCAP=0x0C
P_CONNLEN=0x0E P_AMP_OUT_CAP=0x12
# widget types (WCAP bits23:20), pin/amp bits
WID_DAC=0x0 WID_ADC=0x1 WID_MIX=0x2 WID_SEL=0x3 WID_PIN=0x4
PINCAP_OUT=0x10 PINCAP_EAPD=0x10000       # PINCAP_EAPD = bit16
PINCTL_OUT_EN=0x40 PINCTL_HP_EN=0x80
EAPD_ENABLE=0x02                          # SET_EAPD payload bit1 (bit0=BALANCED, bit2=LR_SWAP)
AMP_OUT_UNMUTE=0xB000                      # OUTPUT|LEFT|RIGHT, mute bit7=0, gain in [6:0]
```

**Substrate accessors:** clone `r8169_read8/16/32` + `write8/16/32` (`r8169.cyr:218-243`). Add a **readback-flush** on every UC MMIO store (load the reg back, like `nvme_mmio_write32` at `nvme.cyr:83-91`) to defeat posted-write reordering on the doorbell path.

---

## 1. Bite-by-bite plan (B0–B5)

### B0 — Probe (roadmap **1.52.0**)

**Sequence (verbatim reuse of the nvme/r8169 probe shape):**
1. `pci_find_by_class(0x04, 0x03, 0x00)` → idx (`pci.cyr:430`). Verify vendor:device `1022:15e3` to disambiguate from ACP DSP `04:00.5` / HDMI-audio `04:00.1`.
2. `var bar = pci_bar_64(idx, 0)` (`pci.cyr:445`) — HDA MMIO is always BAR0, 64-bit.
3. `pci_enable_bus_master_idx(idx)` (`pci.cyr:96`) — mandatory; CORB/RIRB/BDL are all bus-master DMA.
4. `vmm_remap_uc_2mb(bar)` (`vmm.cyr:66`) — register file is UC.
5. Read `GCAP@0x00` (16-bit). Decode `OSS=bits15:12`, `ISS=bits11:8`, `BSS=bits7:3`, `64OK=bit0`. Read `VMAJ@0x03`/`VMIN@0x02`.
6. Print `hda: found [1022:15e3] OSS=N ISS=M v1.0`.

**Success gate:** `OSS >= 1` and version reads 1.0. Read-only.
**Validation:** QEMU-PASS. QEMU `intel-hda` resets GCAP=`0x4401` → OSS=4/ISS=4. Assert `OSS>0`.

---

### B1 — Reset + codec presence (roadmap **1.52.1**)

**Sequence — CORRECTED per the settle-delay verdict (CONFIRMED):**
1. If `GCTL bit0 == 1` (already running), write `STATESTS = 0x7FFF` to clear stale bits. **Never** write STATESTS while in reset (LKML erratum).
2. **Enter reset:** `GCTL &= ~GCTL_CRST` (write 0). Poll `GCTL bit0` until it reads 0. (Bounded ~100 ms budget of spin-poll iterations, bail loudly on timeout.)
3. **Settle #1 (codec reset/PLL):** spin `>= 100 us` via `hda_udelay()` (see §4 GAP — rdtsc-calibrated spin, NOT a bare counting loop, NOT `usleep`).
4. **Exit reset:** `GCTL |= GCTL_CRST` (write 1). **Poll `GCTL bit0` until it reads back 1** — do not assume instantaneous.
5. **Settle #2 (codec discovery — CORRECTED):** spin **`>= 521 us` / 25 frames** (HDA 1.0a §4.3 Codec Discovery — this is the spec floor, distinct from and larger than the 100 us PLL settle). FreeBSD uses ~1000 us; **budget 1000 us** to absorb AMD-vs-QEMU variance.
6. **Read `STATESTS@0x0E` in a re-read loop** (not a single fixed spin) up to ~a few ms: nonzero = codec-present bitmask. Branch on value:
   - `0x00` → timing/no-presence (settle first suspect).
   - `0xFF` → controller read failed / link down (force `codec_mask=0`, different fault).
   - one bit set (expect `0x0001`, ALC897 at addr 0) → success.
7. Print `hda: reset OK, codecs=0xNN`. `INTCTL@0x20` stays 0.

**Success gate:** `codec_mask != 0` and `!= 0xFF`.
**Validation:** QEMU-PASS (QEMU sets STATESTS bit0). The settle-length correctness is **iron-only** (QEMU is fast; ALC897 on Zen is the real test — if STATESTS=0 on iron, this delay is the first suspect).

---

### B2 — Verb ring + widget-graph walk (roadmap **1.52.2** — *the iron-only heart, detailed in §2*)

Two-part scope, per the verdict that reframes B2:
- **Ring plumbing** = nvme-SQ/CQ-like (QEMU-verifiable, necessary-not-sufficient).
- **Graph walk + CONFIG_DEFAULT pin selection + ALC897 COEF/EAPD** = genuinely novel, **iron-gated**.

**Success gate (QEMU):** `GET_PARAM(0, VENDOR_ID)` round-trips `0x10EC0897` — proves the ring transport.
**Success gate (iron):** a real ALC897 front output pin is selected via live CONFIG_DEFAULT, its DAC resolved via connection-list walk, chain powered/unmuted/EAPD'd/COEF-initialized. **Path-found is NOT the audible gate** — that's B4.
**Validation:** QEMU proves ring round-trip only; QEMU's codec is a 3-node linear graph (AFG1→DAC2→PIN3, single LINE_OUT pin, no selector/mixer), so it validates transport but **nothing** about ALC897 pin routing.

---

### B3 — Stream + BDL arm (roadmap **1.52.3**)

**Sequence — CORRECTED per the output-stream-index and SDnFMT verdicts:**
1. **Compute output stream descriptor base — do NOT hardcode 0x80.** Read `GCAP`, extract `ISS`. `sd_base = HDA_SD_BASE + ISS * HDA_SD_STRIDE`. (ISS=4 → `0x100`; the maps' "0x160" literal is REFUTED — 0x160 only holds if ISS=7.) Assert `OSS>=1` first. `0x80` is SDI0 (input) — writing there drives a capture stream = silence.
2. **Allocate DMA memory (cache-attribute discipline — see §7):**
   - BDL: `pmm_alloc()`, 128-byte aligned (page-align satisfies), **WB/coherent** (`vmm_map ...,0x83`, PAT0). ≥2 entries, each 16 bytes `{addr_lo u32, addr_hi u32, len u32, flags u32(bit0=IOC)}`.
   - PCM ring: `pmm_alloc_2mb()` (`pmm.cyr:611`) then `vmm_remap_wc_2mb()` (`vmm.cyr:143`). **Placed >1 GB in phys away from the UC BAR** (see §7).
3. **Stream reset:** `SD_CTL bit0 (SRST)=1`, poll until reads 1; clear bit0, poll until reads 0.
4. Program (order per Linux `setup_controller`): `SD_CTL` stream tag `(tag<<20)`; `SD_CBL = total bytes`; **`SD_FMT = 0x0011`** (or `0x4011` for the 44.1k DOOM path — see §5); `SD_LVI = nentries-1`; `SD_BDPL/SD_BDPU = bdl_phys lo/hi`.
5. Poll `SD_FIFOSIZE@+0x10` nonzero = **format-accepted** sanity check.
6. **Bind codec side (same tag + same format word):** `SET_STREAM_FMT(0x200)` on the DAC = **identical** `0x0011`; `SET_STREAMID(0x706)` on the DAC = `(tag<<4)|channel` (tag=1 → `0x10`). The controller `SD_FMT` and the DAC format **must match or the stream faults**.
7. `SD_CTL |= SD_RUN`.

**Success gate:** `SD_LPIB@+0x04` **advances** (DMA fetching).
**Validation:** QEMU-PASS (QEMU `intel_hda_xfer` DMA-reads the BDL, advances LPIB). Poll `SD_LPIB` directly — do **not** rely on the DPLBASE writeback (QEMU only writes it back if `DPLBASE bit0` set; leave it disabled).

---

### B4 — First tone (roadmap **1.52.3**, same minor as B3; jack is iron-only)

**Sequence:**
1. Precompute an i16 sine at the chosen native rate into the WC ring. **Mind the Cyrius var-array unit trap** (`[[cyrius-var-array-u64-units]]`): a module-global `var sine[N]` = N×u64 (8N bytes = 4N i16 samples); function-local `var buf[N]` = N bytes. Preferred: `store16` directly into the pmm-allocated phys ring (r8169 pattern) to avoid the two-convention mix.
2. BDL loops the ring; `SD_RUN` already set from B3.

**Success gate (QEMU):** `-audiodev wav` sink → close after ~1 s → python-read `out.wav` → assert RMS>0. Note this proves controller+ring+stream-DMA, **not** pitch correctness (QEMU silently resamples, so a wrong-base 0x4011 still passes RMS — this is exactly why the SDnFMT correction is done pre-code).
**Success gate (iron):** audible tone out the archaemenid front jack — **the true B2+B4 gate**.
**Harness:** clone `whirl-smoke.sh` (q35+OVMF+nvme+xhci-kbd) + `-device intel-hda -device hda-output,audiodev=snd0 -audiodev wav,id=snd0,path=out.wav,out.frequency=48000,out.channels=2,out.format=s16`.

---

### B5 — Streamed PCM + refill (roadmap **1.52.3**/**1.52.4** boundary)

**Sequence:**
1. Keep `SD_RUN` set. Poll `SD_LPIB` (or `SD_STS bit2 BCIS`, W1C) from the 100 Hz timer tick **or** inside a blocking `snd_write#66` sti-window.
2. When LPIB crosses the BDL midpoint, refill the consumed half from the ring-3 buffer. Keep `SD_LVI` wrap correct.
3. **Oversize the ring first** (≥64 ms; at 48k/16/2 = 192 KB/s, one 10 ms tick needs ≥2 KB — size to tens of ms so a missed tick never underruns).

**Success gate:** gap-free multi-second playback.
**Validation:** QEMU validates refill cadence timing; iron validates it under real ALC897 FIFO latency.

---

## 2. B2 in full detail — the ALC897 widget-graph walk (iron-only heart)

### 2a. Verb ring setup (nvme SQ/CQ twin, with the divergence flagged)

`pmm_alloc()` a CORB page + a RIRB page (or share: RIRB at CORB+2048, Linux idiom). Zero both. **These rings are WB/coherent, NOT WC, NOT in the PCM region** (verdict UNCERTAIN reduced the fence claim but CONFIRMED the placement).

**CORB program (exact order, from `snd_hdac_bus_init_cmd_io`):**
1. `CORBLBASE@0x40 = low32(corb_phys)`; `CORBUBASE@0x44 = high32`.
2. `CORBSIZE@0x4E = 0x02` (256 entries).
3. `CORBWP@0x48 = 0`.
4. **CORBRP two-step reset (no nvme analog):** write `CORBRP@0x4A = 0x8000`, poll bit15 until **set**, write `0`, poll bit15 until **clear**. Bound each poll (1000 iters), warn-and-proceed on timeout (matches Linux). *This is the single most-likely-under-implemented step; skipping the poll-set/poll-clear drops the first verbs silently.*
5. `CORBCTL@0x4C = CORBCTL_RUN`.

**RIRB program:**
1. `RIRBLBASE@0x50 / RIRBUBASE@0x54`.
2. `RIRBSIZE@0x5E = 0x02`.
3. `RIRBWP@0x58 = 0x8000` (single self-clearing write).
4. `RINTCNT@0x5A = 1`.
5. `RIRBCTL@0x5C = RIRBCTL_DMAEN` (bit1 only; **bit0 IRQ stays 0**).

**Divergence from nvme (verdict-flagged):** RIRB has **NO phase/ownership bit**. Track a software `rirb_rp`; detect a new response by `RIRBWP@0x58 != rirb_rp` (with manual wrap), NOT the nvme phase-tag test. Zero the RIRB on init so a stale entry can't be misread. Check `RIRBSTS bit2 (overrun)`; keep the ring drained every verb.

**Optional B1-simplifier:** the **Immediate Command path** (`IC@0x60` / `IR@0x64` / `IRS@0x68`) does a single-verb round-trip with no ring DMA — write verb to IC, set `IRS bit0 (ICB)`, poll until clear + `IRS bit1 (IRV)`, read IR. This sidesteps the CORBRP-reset handshake **and** the WC/UC question for the command channel entirely. **Recommended for B1 VENDOR_ID presence; use CORB/RIRB for the B2 graph walk** (the fuller path the arc needs anyway). This is a de-risking option, not a required substitution.

### 2b. Verb encoding + send/recv

Command dword = `(codec_addr<<28) | (nid<<20) | verb_field`, where `verb_field` is `(verb12<<8)|data8` for 12-bit verbs or `(verb4<<16)|data16` for 4-bit verbs (`SET_STREAM_FMT 0x2`, `SET_AMP 0x3`). **The single cmd path must support both frame shapes** or `SET_STREAM_FORMAT`/`SET_AMP` silently malform.

Send: store at `CORB[++wp]`, write `CORBWP@0x48 = wp` (doorbell = nvme SQ tail). Poll `RIRBWP` != `rirb_rp`; read the 8-byte RIRB entry (dword0 = response, dword1 = resp-ex: codec addr + solicited bit); advance `rirb_rp`. **Bound every verb poll with a deadline** (the ~3 s icmp precedent) and return error rather than hang.

### 2c. Widget-graph walk

1. **Root:** `GET_PARAM(0x00, P_VENDOR)` → assert `0x10EC0897`. `GET_PARAM(0x00, P_NODECOUNT)` → FG node list (start=bits23:16, count=bits7:0).
2. **AFG:** for each FG node, `GET_PARAM(fg, P_FNTYPE)`; `== 0x01` = Audio Function Group. `GET_PARAM(afg, P_NODECOUNT)` → widget start NID + count (ALC897: ~30 widgets from ~0x02).
3. **Enumerate:** per widget, `GET_PARAM(nid, P_WCAP)`; type `= (cap>>20)&0xF`. Latch `OUT_AMP_PRESENT=bit2`, `CONN_LIST=bit8`, `STEREO=bit0`. Classify into DAC / PIN / MIX / SEL sets.

### 2d. Pin selection — CONFIG_DEFAULT (CORRECTED — the REFUTED rule)

For each OUT-capable PIN (`GET_PARAM(nid, P_PINCAP)` has `PINCAP_OUT=bit4`), `GET_CFGDEF(0xF1C)` and decode (FreeBSD-header-confirmed masks):
```
default_device = (cfg>>20)&0xF      # 0x0=Line-Out, 0x1=Speaker, 0x2=HP-Out
port_conn      = (cfg>>30)&0x3      # 0=Jack, 1=NONE, 2=Fixed, 3=Both
location       = (cfg>>24)&0x3F     # geometry+general-location (Front vs Rear)
association    = (cfg>>4)&0xF
sequence       =  cfg&0xF
```
**Selection rule (REFUTED "Line-Out lowest-sequence" replaced):**
- **Accept BOTH `default_device==HP-Out(0x2)` AND `default_device==Line-Out(0x0)` as candidate analog output pins.** On a real ALC897 the front headphone jack is almost always **HP-Out (0x2)**, and the nominal line-out pin `0x14` is frequently **retasked to Speaker** by board firmware.
- **Reject `port_conn == 1 (NONE)`** — phantom/unpopulated pins advertise output device types but have no connector.
- **Prefer `location == Front`** and a pin carrying **jack-detect** (`GET_PINSENSE 0xF09`, presence bit31).
- **Do NOT tie-break on Sequence for headphone-vs-line** — Sequence only orders channels within one Association.
- **Do NOT hardcode NID 0x14 or 0x1b.** Keep them only as a sanity-check log line.

**Iron pre-flight (mandatory before freezing B2 routing):** capture a live per-pin `GET_CFGDEF` dump on archaemenid (the `/proc/asound/card*/codec#*` equivalent) and hard-verify which node is the front jack and whether it decodes HP-Out or Line-Out. Log every pin's raw `config_default` during bring-up. **Also fix `docs/development/planning/audio-arc-152x.md:13`** which asserts the front jack "is the ALC897's line-out" — that premise is REFUTED.

### 2e. Trace DAC feeding the chosen pin

`GET_PARAM(pin, P_CONNLEN)`: `length=cap&0x7F`, `long_form=cap&0x80`. Loop `GET_CONNLIST(0xF02)` at index steps of 4 (short: 4×u8) or 2 (long: 2×u16); **expand any high-bit-set entry as a range** from the previous NID. Follow the pin's selected input (`GET_CONNSEL 0xF01`) through Mixer/Selector hops until a widget of type DAC(0). On a Selector, `SET_CONNSEL(0x701, index)` to point it at the chosen input. Record chain `[pin, ...hops..., dac]`. Verify the terminal is type DAC.

### 2f. ALC897 output-enable sequence (the quirks)

In order:
1. **Mandatory Realtek COEF init** (verdict: real + correctly specified; sufficiency board-contingent). On NID `0x20`, clear bit5 of COEF index 0x7: `SET_COEF_IDX(0x500) payload 0x07` → `GET_PROC_COEF(0xC00)` → val → `SET_COEF_IDX(0x500) 0x07` → `SET_PROC_COEF(0x400) (val & ~(1<<5))`. This puts EAPD under verb control; omitting it is a known no-output cause on ALC892/897.
2. **Power up chain:** `SET_POWER(0x705, 0x00)` (D0) on AFG, DAC, any mixer/selector, PIN.
3. **Pin control:** `SET_PINCTL(0x707)` = `PINCTL_OUT_EN(0x40)` alone for line-out, `0xC0` (`|HP_EN`) for a headphone-capable jack. ALC897 front jack is HP-drive capable → use `0xC0`.
4. **EAPD (conditional — verdict CONFIRMED):** only if the pin's `P_PINCAP` has `PINCAP_EAPD (bit16)`, issue `SET_EAPD(0x70C, 0x02)` (bit1). Candidate pins `{0x0f,0x10,0x14,0x15,0x17}`. **QEMU has no EAPD**, so this is an iron-only silent-failure gate.
5. **GPIO fallback (verdict UNCERTAIN — add the path, gate it):** EAPD-only is the *likely* case on a desktop AMD board but is **board-contingent, not codec-guaranteed**. If EAPD-only yields silence on iron, the board gates the amp behind a codec GPIO. Provide a fallback: read AFG GPIO-count cap, then `SET_GPIO_MASK(0x716)` / `SET_GPIO_DIR(0x717)` / `SET_GPIO_DATA(0x715)` driving GPIO0/GPIO1 high. Try it **only** if EAPD-only is silent. Do not hardcode "no GPIO ever."
6. **Unmute + gain:** `SET_AMP(0x3xxxx)` on DAC out-amp and PIN out-amp (each if `OUT_AMP_PRESENT`). Payload `AMP_OUT_UNMUTE=0xB000 | gain`. **Do NOT ship gain index 0** — on some amps index 0 is the floor (silent). Read `P_AMP_OUT_CAP(0x12)` num-steps and set gain to ~75% in bits[6:0], mute bit7=0. Unmute the chosen mixer input amp too: `0x7000 | (idx<<8)`.

After 2f the analog path is live; arming `SD_RUN` (B3) produces audible output.

---

## 3. #64–#69 ring-3 syscall band (roadmap **1.52.4**)

Next-free is **#64** (confirmed: highest used in `syscall.cyr` is `symlink#63`, contiguous through 63). Clone the net band. **Land the kernel header AND the `cyrius/lib/syscalls_x86_64_agnos.cyr` peer in ONE change** (the `sys_symlink` two-sided lesson, `syscall.cyr:1187`) — but the cyrius peer is **HANDS-OFF**: surface the needed `sys_snd_*` stub addition to the user, do not edit `cyrius/` without per-edit permission.

| # | name | class | template | gating |
|---|------|-------|----------|--------|
| 64 | `snd_open` | non-blocking | allocate an `snd_id` 0..3 slot; bind to the output stream. Auto-released on proc-exit (the `flock_release_pid` precedent, `syscall.cyr:367`). | validate args; no user buffer |
| 65 | `snd_config` | non-blocking | set rate/bits/channels on the slot. **Accept ONLY native rates (44100/48000), 16-bit, stereo** (see §5). Reject others with `-EINVAL`. | scalar args |
| 66 | `snd_write` | **blocking** | copy PCM from ring-3 into the WC ring; block until space. Uses the **`sock_connect#47` sti-window verbatim** (`syscall.cyr:1864-1868`): `is_user_range(buf, frames*bpf)` gate FIRST (`syscall.cyr:1883`), then `preempt_disable; asm{sti}; <poll SD_LPIB / refill>; asm{cli}; preempt_enable`. | `is_user_range(buf,len)` **before** the sti-window |
| 67 | `snd_close` | non-blocking | stop stream (optionally), release the `snd_id` slot. | slot-id bounds |
| 68 | `snd_drain` | **blocking** | block until the ring plays out (LPIB reaches write head). Same sti-window shape as #66. | no user buffer |
| 69 | `snd_avail` | **non-blocking** | return free frames in the ring. **`sock_recv#49` shape** (`syscall.cyr:1893-1917`), IF=0-safe, no sti. `a4` NONBLOCK flag via `ksyscall_a4_get()` (`syscall.cyr:1953`). | slot-id bounds |

**sti-window discipline:** blocking calls (#66, #68) must gate `is_user_range` **before** opening the sti window (never touch a user pointer with IF=1 unvalidated); non-blocking calls (#69) stay IF=0-safe with no sti. `snd_id` 0..3 slot table auto-releases on proc-exit.

---

## 4. agnos substrate reuse table + GAPs

| HDA need | agnos primitive @ file:line | notes |
|----------|-----------------------------|-------|
| PCI discovery by class | `pci_find_by_class(0x04,0x03,0x00)` `pci.cyr:430` | same call nvme_probe uses |
| BAR0 (64-bit MMIO) | `pci_bar_64(idx,0)` `pci.cyr:445` | HDA MMIO always BAR0 |
| bus-master enable | `pci_enable_bus_master_idx(idx)` `pci.cyr:96` | mandatory; silent without |
| UC register mapping | `vmm_remap_uc_2mb(bar)` `vmm.cyr:66` | nvme/r8169 precedent |
| WC PCM ring mapping | `vmm_remap_wc_2mb(phys)` `vmm.cyr:143` | HDA is the **2nd** WC caller (framebuffer 1st) |
| WB/coherent CORB/RIRB/BDL | `vmm_map(...,0x83)` (PAT0) | as nvme rings |
| MMIO 8/16/32 accessors | clone `r8169_read/write8/16/32` `r8169.cyr:218-243` | HDA needs all 3 widths |
| posted-write ordering | readback-flush `nvme_mmio_write32` `nvme.cyr:83-91` | flush after doorbell store |
| WB-write ordering (batched) | mfence `asm{0x0F;0xAE;0xF0}` `virtio_blk.cyr:453` | only between two WB writes the device observes |
| ring doorbell / poll shape | `nvme_admin_submit/poll` `nvme.cyr:387/423` | RIRB diverges: no phase bit |
| DMA page alloc | `pmm_alloc()` `pmm.cyr:539` | 4 KB, 128-byte-aligned satisfied |
| contiguous 2 MB PCM ring | `pmm_alloc_2mb()` `pmm.cyr:611` | gap-free ring |
| 64-bit phys lo/hi desc split | `r8169.cyr:641-646` | CORB/RIRB/BDL base writes |
| blocking sti-window | `sock_connect#47` `syscall.cyr:1864-1868` | `snd_write#66`/`snd_drain#68` |
| non-blocking syscall | `sock_recv#49` `syscall.cyr:1893-1917` | `snd_avail#69` |
| user-range gate | `is_user_range` `syscall.cyr:222` | before sti-window |
| a4/NONBLOCK flag | `ksyscall_a4_get()` `syscall.cyr:1953` | r10 |
| slot auto-release on exit | `flock_release_pid` `syscall.cyr:367` | snd_id 0..3 |
| probe call-site shape | `main.cyr:489/557` (r8169/nvme) | `if (hda_probe()==1){...}` |

**GAP 1 — µs codec-settle delay.** No `usleep/udelay/mdelay` primitive exists. Build `hda_udelay(us)` as an **rdtsc-calibrated spin** (the xhci_port idiom: `var t0=rdtsc(); while ((rdtsc()-t0) < cycles) {}`, calibrated to ~3 GHz Zen TSC) OR a bounded non-posted-MMIO-read count (r8169 reset drain, `r8169.cyr:370`, ~0.5-1 µs/read). **Not** a bare counting loop (Zen speed varies). Used for both reset settles and the STATESTS re-read loop.

**GAP 2 — WC DMA-ring helper.** WC mapping is today a manual `vmm_remap_wc_2mb` call with no ring-lifecycle helper. The PCM ring needs WC + the pdpt-placement discipline (§7). Factor a small `hda_alloc_wc_ring(bytes)` that allocs 2 MB contiguous, remaps WC, and asserts the PWT-still-set post-condition — but this is a convenience wrapper, not a missing kernel capability.

---

## 5. Resample decision — lives in the PRODUCER, not the kernel

**Decision: the kernel HDA driver does ZERO resampling. `snd_config#65` accepts native rates only (44100 / 48000), 16-bit, stereo.**

Rationale (verdict CONFIRMED against shipped code): `cyrius-doom/src/audio.cyr` **already** up-converts host-side in `audio_tick` (11025-mono-U8 → 44100-stereo-S16, 4× integer upsample), and its on-metal comment states real HDA codecs reject S8/mono/11025 outright — the analog jack takes only S16_LE/stereo/44100. A kernel-side 8→16 / mono→stereo / 11025→48k converter would be **redundant work on the wrong side of the ABI** and would put a per-sample CPU convert inside the polled tick. Producers (vani / cyrius-doom) up-convert before `snd_write`.

**Native-rate choice:** the driver supports **both** 44100 (`SD_FMT=0x4011`) and 48000 (`SD_FMT=0x0011`).
- **44100 is the DOOM path** — `44100/11025 = 4` exactly (integer upsample, no drift/filter). This is the one place `0x4011` is *correct* (genuine 44.1 kHz).
- **48000 is the generic vanitone sine path** — `0x0011`.

Both are ALC897-native (44.1/48/96/192 advertised). `11025` is *format-register-legal* via DIV=/4 (`0x4311`) but **unadvertised in AC_PAR_PCM** and unreliable on real silicon — treat as a curiosity, never a path.

---

## 6. Gate 3 (vani agnos backend) and Gate 4 (DOOM with sound)

### Gate 3 — cyrius `vani` agnos backend (two-sided)

The cyrius `vani` audio library gets an agnos backend that calls `snd_open#64 → snd_config#65 → snd_write#66 → snd_drain#68 → snd_close#67`. **The cyrius `sys_snd_*` syscall peer is HANDS-OFF** (`cyrius/` requires per-edit user permission). This gate is two-sided: the kernel band (§3) is ours; the cyrius `vani`/`sys_snd_*` side is surfaced to the user as a required peer addition, landed by them. Vani is the producer that up-converts to native rate before `snd_write` (§5). Gate-3 acceptance: `vanitone` proof-app emits a sine through the full band on QEMU (wav RMS>0) and archaemenid (audible).

### Gate 4 — un-gate cyrius-doom's sound

`cyrius-doom` currently carries three `#ifdef CYRIUS_TARGET_AGNOS → return 0` guards that stub audio out on agnos (`src/audio.cyr:118` + `src/audio.cyr:270` + `src/sound.cyr:39`). Gate 4 removes/rewires them so DOOM initializes its audio path (which already produces 44100-stereo-S16 in `audio_tick`) and routes it through the vani agnos backend → the band → the ALC897 front jack. **The `--agnos` build must be updated to consume the sound drivers** (not just un-guarded — actually wired to vani's agnos backend).

**★ cyrius-doom is the FIRST thing to test once audio works** (user directive 2026-07-03), and it has a dedicated fast path: **`cyrius-doom --audio-test`** (`src/main.cyr:240`) plays **6 SFX + an L/R stereo-pan sweep (~8 s) WITHOUT launching the full game** — the tightest end-to-end audio-path check (WAD `DS*` PCM → vani → `snd_*` band → HDA → front jack). Use `--audio-test` as the first Gate-4 validation, *then* full `cyrius-doom` for the headline.

**Acceptance = the arc headline: DOOM runs with sound on iron.** Validated only on archaemenid (QEMU proves the transport; front-jack routing + EAPD/COEF/GPIO are iron-only).

---

## 7. Top risks + how the plan de-risks them

**Risk 1 — SDnFMT base-rate bug (CONFIRMED ×4, high).** `0x4011` is 44.1 kHz, not 48 kHz; a 48 kHz stream plays ~8.1% flat (44100/48000, −1.47 semitones). **QEMU's wav-RMS smoke MASKS it** (energy is rate-invariant; QEMU silently resamples). *De-risk:* encode from named fields (`HDA_FMT_BASE_48K|HDA_FMT_BITS_16|hda_fmt_chan(2)`), never a literal; write the identical word to both `SD_FMT` and the DAC `SET_STREAM_FORMAT` (mismatch faults the stream); the 44.1 k `0x4011` is used *only* on the deliberate DOOM 44100 path.

**Risk 2 — front-pin identity (REFUTED, high, iron-only).** The "Line-Out lowest-sequence" rule lands on the wrong connector: ALC897 front jack is HP-Out(0x2), pin 0x14 often retasked to Speaker. Silent jack, no fault, QEMU passes. *De-risk:* accept HP-Out AND Line-Out candidates, reject `port_conn==NONE`, prefer Front location + jack-detect, resolve DAC via real connection-list walk, and **capture a live archaemenid CONFIG_DEFAULT dump before freezing routing**. Fix the plan-doc line 13 premise.

**Risk 3 — EAPD/COEF/GPIO amp gating (CONFIRMED EAPD conditional; GPIO UNCERTAIN; high, iron-only).** Missing EAPD or COEF = enumerates fine, dead silence. GPIO gating is board-contingent. *De-risk:* mandatory NID-0x20 COEF-index-0x7 bit5-clear; EAPD gated on `PINCAP_EAPD` bit16; a GPIO fallback path present but tried only if EAPD-only is silent on iron. All invisible to QEMU (no EAPD/amp model).

**Risk 4 — WC/UC cache collision (CONFIRMED placement; fence claim UNCERTAIN; high, iron-only, QEMU-invisible).** *De-risk (placement):* CORB/RIRB/BDL = WB/coherent, only the PCM ring = WC; keep the WC ring and UC BAR in **different 1 GB PDPT entries** (allocate WC-ring phys >1 GB from the BAR). The real agnos-specific hazard is **2 MB-page memory-type aliasing** — a later WB `vmm_map` on a 2 MB PDE clobbers a sibling chunk an earlier remap set WC/UC; assert PWT-still-set on the WC ring PDE after the UC BAR map. *De-risk (ordering — corrected):* **DROP the blanket "mfence between verb write and CORBWP doorbell."** On x86 with CORB mapped WB and CORBWP mapped UC, the two stores are already architecturally ordered (matching agnos's fence-free nvme doorbell). Apply the two-rule doctrine instead: mfence **only** between two WB writes the device observes (virtio_blk pattern); a **readback-flush** (not a fence) to push the posted MMIO doorbell (nvme/r8169 `rtl_pci_commit` pattern).

**Risk 5 — output-stream-index (CONFIRMED formula, "0x160" literal REFUTED, high).** `0x80` is SDI0 (input); arming it drives a capture stream = silence. `0x160` only holds if ISS=7. *De-risk:* compute `sd_base = 0x80 + ISS*0x20` from a live GCAP read (ISS=4→0x100 typical); assert `OSS>=1`; print OSS/ISS in the B0 line.

**Risk 6 — codec settle timing (CONFIRMED, med, iron-only).** Under-budgeting the post-CRST wait → STATESTS=0. *De-risk:* budget the **521 µs / 25-frame** §4.3 floor (use ~1000 µs), distinct from the 100 µs PLL settle; poll GCTL readback before waiting; read STATESTS in a **re-read loop**, and branch `0x00` (timing) vs `0xFF` (link down).

**Risk 7 — RIRB no phase bit (CONFIRMED divergence, med).** nvme phase-tag poll doesn't transfer. *De-risk:* shadow `rirb_rp` + `RIRBWP` compare with manual wrap; zero RIRB on init; handle `RIRBSTS` overrun; keep drained every verb.

**Risk 8 — B2 QEMU false-confidence (CONFIRMED, med).** QEMU's 3-node single-LINE_OUT codec proves ring transport, nothing about ALC897 routing. *De-risk:* write the graph walk **generically** (never hardcode NID2/NID3 or 0x14/0x1b); B2's graph-walk acceptance is **iron-gated**, QEMU only gates verb round-trip.

---

## 8. Roadmap milestone breakdown (drops into the 1.52.x row)

| Minor | Bite(s) | Acceptance gate | Validation surface |
|-------|---------|-----------------|--------------------|
| **1.52.0** | B0 probe | `hda: found [1022:15e3] OSS=N ISS=M v1.0`, OSS≥1 | QEMU-PASS |
| **1.52.1** | B1 reset+presence | `hda: reset OK, codecs=0xNN` (≠0, ≠0xFF) | QEMU-PASS; settle-length iron-only |
| **1.52.2** | B2 verb ring + graph walk | QEMU: VENDOR_ID `0x10EC0897` round-trips (ring). **Iron: ALC897 front pin selected via live CFGDEF + DAC resolved + COEF/EAPD/(GPIO) chain up** | ring = QEMU; **graph walk = iron-gated** |
| **1.52.3** | B3 stream/BDL arm + B4 first tone + B5 refill | QEMU: SD_LPIB advances + wav RMS>0; gap-free multi-sec. **Iron: audible tone on archaemenid front jack** | plumbing = QEMU; **audible = iron** |
| **1.52.4** | #64–#69 syscall band | ring-3 `snd_open/config/write/close/drain/avail` land; blocking sti-window + is_user_range verified; cyrius `sys_snd_*` peer (HANDS-OFF, user-landed) | QEMU + iron |
| **1.52.5** | Gate 3 — vani agnos backend + vanitone | `vanitone` sine through full band: QEMU wav RMS>0 + archaemenid audible | QEMU + iron |
| **1.52.6** | Gate 4 — un-gate cyrius-doom 3 guards | **DOOM runs with sound on archaemenid** (arc headline) | **iron** (front-jack routing iron-only) |

*Note: B3/B4/B5 share 1.52.3 as low-effort plumbing bites gated together on the same QEMU+iron pass; the syscall band, vani, and DOOM each earn their own minor as larger, separately-verifiable items. The plan-doc's stale "1.52.4 audio syscall band #63-68" row must be reconciled to **#64-#69** (#63 = symlink) before freeze.*

---

**Reference anchors for the coder:** `kernel/core/hda.cyr` (to create), substrate at `pci.cyr:96/430/445`, `vmm.cyr:66/143`, `nvme.cyr:83-91/387/423`, `r8169.cyr:218-243/370/641`, `pmm.cyr:539/611`, `syscall.cyr:222/367/1187/1864-1868/1893-1917/1953`, `main.cyr:489/557`. Producer: `cyrius-doom/src/audio.cyr:15-31,401-463`. Plan-doc to correct: `docs/development/planning/audio-arc-152x.md:13` (front-jack-is-line-out premise) and the `#63-68`→`#64-69` band row.
