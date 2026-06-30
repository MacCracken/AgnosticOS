# agnos 1.52.x — Audio-output arc (HDA)

> **Status**: Scoped 2026-06-29 (multi-agent research, source-grounded — real `file:line` + live `lspci`/`/proc/asound` reads). **Caveat**: the synthesis/adversarial-verify pass of the research workflow failed (StructuredOutput retry cap); this doc is synthesized from the four completed, source-grounded **map** outputs — the milestone gates are author-synthesized, not independently verify-passed. The HDA map self-identified the risky parts (codec graph, BDL timing, WC/UC mapping), which is most of what a verify pass would surface. | **Slot**: agnos **1.52.x** (near-term AMD-line feature arc, user-chosen). | **Roadmap phase**: hardware/feature (audio).

## Why & where

Audio is **absent** from the agnos roadmap (greenfield — no `hda`/`sound` file in `kernel/core`). The user wants it "soon"; it slots as **1.52.x** on the AMD dev line because archaemenid has the controller and audio-output is self-contained (rides the proven PCI/DMA/IRQ machinery the NIC/NVMe/xHCI drivers established — no platform bring-up needed). Output-first; capture/mic, HDMI audio (`04:00.1`), the AMD ACP DSP (`04:00.5`), USB-audio-class, and MIDI are all **out of scope**.

## archaemenid hardware (verified live)

- **Controller**: `04:00.6` AMD Ryzen HD Audio `[1022:15e3]` — a **standard HDA/Azalia** controller (Intel HD Audio register spec, portable AMD/Intel; Linux binds it `HD-Audio Generic`). **Not** the ACP DSP (`04:00.5`) or HDMI audio (`04:00.1`).
- **Codec**: **Realtek ALC897** (`0x10ec0897`) — bog-standard HDA codec, enumerated over CORB/RIRB verbs; no AMD-proprietary quirks for basic stereo PCM.
- **Output**: the **front headphone jack** (user-confirmed) is the ALC897's line-out — the real on-iron "hear a tone" target. HDA codecs expose the front jack as a **separate pin widget** (often with jack-presence detect), so the codec-graph walk must route DAC → the *front-panel output pin*, not just the first pin found (QEMU's single-output codec quietly skips this — an iron-only concern).

## The four gates

### Gate 1 — kernel HDA/Azalia output driver (`kernel/core/hda.cyr`, single file)

Flat in `core/` like `nvme.cyr`/`ahci.cyr`/`r8169.cyr` (a `core/audio/` subdir is the deferred multi-file form, triggered by the `04:00.1` HDMI-audio function or a 2nd codec family — the `eth_drvrs`/`usb/` subdir precedent). Reuses the iron-proven PCI pattern verbatim: `pci_find_by_class(0x04,0x03,0x00)` → `pci_bar_64` → `pci_enable_bus_master_idx` → `vmm_remap_uc_2mb` (the `nvme_probe`/`r8169_probe` shape, `pci.cyr:376/391/96`); r8169's 8/16/32-bit MMIO accessors (`r8169.cyr:196-221`); `pmm_alloc()` DMA pages with 64-bit phys split lo/hi into descriptors (`r8169_init_rx/tx:472/528`); nvme's admin SQ/CQ doorbell-poll as the structural twin of HDA's CORB/RIRB (`nvme.cyr:387/423`). **Polled, no IRQ** (r8169 `IMR=0` precedent — serviced from the 100 Hz timer tick or inside a blocking `snd_write` window). The PCM sample ring is **WC-mapped** (`vmm_remap_wc_2mb`, the framebuffer path), the register BAR **UC** — keep them clear of the same 1 GB PDPT entry (the `pdpt_guard` cache-collision class).

**Six bites** (each a kernel patch minor):
- **B0 probe** — PCI class-probe, BAR map, GCAP read (`hda: found … OSS=N`). Read-only, lowest risk.
- **B1 reset + codec presence** — GCTL.CRST handshake + STATESTS (`hda: reset OK, codecs=0xNN`).
- **B2 CORB/RIRB + codec enum** — the verb command/response ring + widget-graph walk to a DAC + output Pin Complex. **The one genuinely-novel bite** (no block/net-driver analog); QEMU's trivial codec is necessary-not-sufficient — the ALC897 graph (mixer/selector hops, front-pin CONFIG_DEFAULT decode) is the iron-only part.
- **B3 stream + BDL DMA-arm** — BDL ring (≥2 entries, 128-byte aligned) + WC PCM ring, stream descriptor (SDnFMT `0x4011` = 48k/16/2ch), bind stream tag → DAC. Gate: SDnLPIB advances (DMA fetching).
- **B4 first tone** — fill the ring with a precomputed sine, loop. **Headline: first sound from sovereign agnos** — QEMU (`-audiodev wav` RMS assert) **and** archaemenid front jack.
- **B5 streamed PCM + refill** — double-buffer feed (refill the consumed BDL half as LPIB crosses midpoint). Gate: gap-free multi-second playback. Closes Gate 1.

**Hardest parts** (from the map): the codec widget-graph walk (B2), BDL/ring timing + refill cadence (mismatch = silent-or-garbage with no fault; oversize the ring early), the WC-vs-UC mapping discipline, and the QEMU-vs-iron codec divergence.

### Gate 2 — sovereign ring-3 audio syscall band `#63–#68`

`#63+` is the next free contiguous band (`#44` is the lone gap; net band ends `#57`; `#58-62` = lseek/flock/winsize/net_config/exec_redirect). Mirrors the **net band template** exactly (flat `if (num==K)` dispatch arm per verb, `is_user_range()` gating every ring-3 buffer, `a4=r10` via `ksyscall_a4_get()`, blocking calls in the proven `sleep_ms#41` sti-window `preempt_disable; sti; poll+arch_wait; cli; preempt_enable` — the `sock_connect#47` recipe; a small `snd_id 0..3` slot table auto-released on proc exit, the `flock_release_pid` precedent):

| # | Verb | Shape |
|---|---|---|
| 63 | `snd_open(card,device,dir)` | → `snd_id 0..3` / -1; binds an HDA output stream. Non-blocking. |
| 64 | `snd_config(snd_id,rate,fmt_packed)` | `fmt_packed=(channels<<16)|(bit_depth<<8)|alsa_fmt` (the `udp_send` packing precedent); collapses ALSA's 608-byte HW_PARAMS to one call. Default 48k/2ch/S16_LE. |
| 65 | `snd_write(snd_id,buf,frames)` | → frames / 0 (WOULD_BLOCK) / -1. **Blocking** (sti-window) by default; `a4` bit0 = NONBLOCK. `is_user_range(buf, frames*bpf)` before the window; auto-arm SDnCTL.RUN past prefill. |
| 66 | `snd_close(snd_id)` | stop + free ring + reclaim slot; idempotent; auto-on-exit. |
| 67 | `snd_drain(snd_id)` | block until queued periods DMA out (gapless finish), bounded deadline (the `icmp_echo` ~3s-bound precedent). |
| 68 | `snd_avail(snd_id)` | → free_frames; non-blocking writable-room poll (IF=0-safe, `sock_recv#49` shape) — the self-pacing hook for a real-time proof-app, and the seam for a later epoll-able `VFS_SND` fd (the 1.49 socket-as-VFS-fd pattern, deferred). |

**Re-freeze rule**: land the band in `kernel/core/syscall.cyr` header + `cyrius/lib/syscalls_x86_64_agnos.cyr` + the agnos userland-ABI doc in **one** change.

### Gate 3 — cyrius `vani` agnos backend (+ the hands-off cyrius peer)

The backend is **confined to `vani/src/alsa.cyr`** — the only module touching the kernel (`device`/`playback`/`capture`/`mixer` all bottom out in `audio_*`). Shape = per-function `#ifdef CYRIUS_TARGET_AGNOS` split mirroring `cyrius/lib/net.cyr` (43 such branches): the Linux ALSA machinery (608-byte `snd_pcm_hw_params`, `snd_xferi`, HW_REFINE bit-twiddling) becomes `#ifndef`-only; the agnos branch calls flat `sys_snd_*`. Seam set: `audio_open_playback`/`set_params_full`/`write`/`drain`/`close`.

**⚠ Two-sided — the cyrius half is HANDS-OFF (surface to user)**: cyrius needs a `SysNrAgnosAudio` band + `sys_snd_*` wrappers in `cyrius/lib/syscalls_x86_64_agnos.cyr` (the audio analog of the `#45-#61` net band + adapter). **The kernel arm + the cyrius peer must BOTH land** — vani can't call audio on agnos until cyrius exposes the numbers (exactly the `sys_symlink` two-sided gap; [[feedback_cyrius_hands_off]]).

### Gate 4 — proof-app: **cyrius-doom (it's already built + vani-wired)** — `vanitone` is just the bring-up smoke

**cyrius-doom IS the audio proof-app, and it already plays real DOOM sound.** Verified in `cyrius-doom/src/audio.cyr` (0.30.4): it loads the WAD `DS*` lumps (DMX format — 8-byte header + 8-bit unsigned PCM @ 11025 Hz: `DSSHOTGN`/`DSPISTOL`/`DSDOROPN`/…), caches them, and plays via **vani** (`audio_open_playback(0,0)` → `audio_set_params(dev,11025,1,8)` → `audio_write_bytes`). It is **Native Cyrius, already renders in-game on iron, and already makes real sound on Linux** (vani→ALSA) — zero Rust-port blocker. On agnos it is `#ifdef CYRIUS_TARGET_AGNOS → return 0`-disabled **only because vani has no agnos backend + no kernel audio** (audio.cyr:20-26) — *exactly* gates 1–3 of this arc.

So gate-4 is **not "build a proof-app"** — it's: land gates 1–3, then **remove the three `#ifdef CYRIUS_TARGET_AGNOS → return 0` guards** in cyrius-doom `audio_init`/`audio_preload`/`audio_play`, and DOOM's real shotgun comes out the archaemenid front jack. **Arc headline acceptance = "it runs DOOM *with sound*" on sovereign agnos** — the iconic demo, far stronger than a sine tone.

> **Format note (a real driver concern)**: DOOM's samples are **8-bit unsigned mono @ 11025 Hz**, but the ALC897/HDA native is 16-bit @ 48 kHz. `snd_config#64` must accept 11025/1/8 and the **kernel HDA driver must convert** (8→16-bit, 11025→48 kHz, mono→stereo) before the BDL DMA — OR cyrius-doom/vani up-converts before `snd_write`. Decide where the resample lives in B3/gate-2 (kernel-side convert is the cleaner consumer contract). QEMU's `hda-output` is more format-flexible than real codecs, so this is partly an iron-only concern.

> **`vanitone` keeps a smaller role** — the minimal bring-up smoke (open default PCM → `snd_write` a hand-rolled i16 sine → `snd_drain`, vani-only) for the QEMU `hda-smoke.sh` self-check at gates 1–2, *before* cyrius-doom's full WAD path is in play. DOOM is the arc-acceptance; vanitone is the unit test.
>
> **Surfaced finding (separate fix)**: CLAUDE.md / the role-map mark `naad` "Ported" — source contradicts (still Rust, 0 `.cyr`/53 `.rs`). Irrelevant to the cyrius-doom proof-app (DOOM has its own WAD-PCM path, no naad), but the naad port gates any *synth*-driven audio (tracker/m8c).

## Test ladder (QEMU self-checking → iron front jack)

- **QEMU `hda-smoke.sh`** (model on `whirl-smoke.sh`'s q35+OVMF+nvme+xhci-kbd scaffold): `-device intel-hda -device hda-output,audiodev=snd0 -audiodev wav,id=snd0,path=out.wav` → drive agnsh via `sendkey` to run `vanitone` → python-inspect `out.wav` RMS ≠ 0. **Fully self-checking, no human** — proves B0–B4 plumbing (controller, CORB/RIRB verbs, stream DMA, first-tone-as-WAV).
- **iron (archaemenid)**: real ALC897 codec enumeration + front-panel pin routing + audible tone through wired headphones. The **true gate for B2/B4** — QEMU's trivial codec can't prove real-codec enumeration ([[feedback_qemu_test_agnos_userland]]).

## Milestones (1.52.x)

| Minor | Deliverable | Acceptance |
|---|---|---|
| **1.52.0** | HDA B0+B1 — probe + reset + codec presence | QEMU: `hda: found … codecs=0xNN` |
| **1.52.1** | HDA B2 — CORB/RIRB + codec-enum (DAC + output pin) | QEMU verb round-trip; **iron**: ALC897 front-pin path found |
| **1.52.2** | HDA B3+B4 — stream/BDL DMA + **first tone** | QEMU wav-RMS ≠ 0 **+ audible tone on archaemenid front jack** (headline) |
| **1.52.3** | HDA B5 — streamed PCM + refill | gap-free multi-second playback (QEMU + iron) |
| **1.52.4** | audio syscall band `#63-68` (Gate 2) | ring-3 `snd_*` ABI; `hda-smoke` drives it from ring 3 |
| **1.52.5** | vani agnos backend (`alsa.cyr` `#ifdef`) **+ cyrius `sys_snd_*` peer (hands-off)** | `vani` `audio_*` works on agnos (both halves landed) |
| **1.52.6** | **cyrius-doom audio un-gated (Gate 4)** — remove the `#ifdef CYRIUS_TARGET_AGNOS→return 0` guards in `audio_init`/`audio_preload`/`audio_play` | **DOOM's real `DSSHOTGN`/`DSPISTOL` WAD samples through the archaemenid front jack — "it runs DOOM *with sound*"** (vanitone is the earlier bring-up smoke) |

## Coordination & ownership (cross-agent — the part you sequence)

The arc spans **four surfaces owned by different agents**. This is the map for coordinating them — what's parallel, what's a hand-off, and the two decisions only you can route.

| Gate | Deliverable | Owner | Blocked on |
|---|---|---|---|
| 1 | HDA driver `kernel/core/hda.cyr` (6 bites) | **kernel agent** | nothing — QEMU-testable standalone, start anytime |
| 2 | audio syscall band `#63-68` | **kernel agent** | gate 1 (a driver to back the verbs) |
| 3a | cyrius `sys_snd_*` peer (`syscalls_x86_64_agnos.cyr`) | **cyrius — HANDS-OFF, you drive** | gate-2 numbers settled |
| 3b | vani agnos backend (`vani/src/alsa.cyr` `#ifdef`) | **vani touch** (whoever picks it up) | gate 2 + 3a |
| 4 | cyrius-doom un-gate (delete 3 `#ifdef` guards) | **cyrius-doom agent** | gates 1–3 |

**The decoupled track (happening now):** the cyrius-doom agent's current audio work is the **host (Linux) sound path** — WAD `DS*` load → vani → ALSA. It is **NOT blocked on the kernel arc** (it uses vani's existing Linux backend), and it's the proof-app *readiness*: once it's solid on the host, the agnos side is just deleting the three guards after gates 1–3 land. So this runs **in parallel** with the kernel agent's gate-1/2 work — they don't wait on each other until the final un-gate.

**Two coordination decisions only you can route:**
1. **The `#63-68` ABI freeze is the pivot.** Nothing on the cyrius/vani side (3a/3b) can bind until the kernel agent settles the syscall numbers + signatures — and **3a is hands-off cyrius, so YOU drive it** once the kernel agent publishes the band. Sequence: kernel agent freezes `#63-68` → you commission the cyrius `sys_snd_*` peer → vani backend → un-gate. Don't let the kernel agent and the cyrius peer drift on numbering (the `sys_symlink` two-sided lesson).
2. **Where the 8-bit/11025 → 16-bit/48k resample lives** — kernel-side (driver converts, clean consumer contract) vs cyrius-doom/vani-side (up-convert before `snd_write`). This is a **kernel-agent ↔ cyrius-doom-agent decision**; pick it before gate 2's `snd_config` semantics are frozen so both build to the same contract.

**Convergence point:** gates 1+2+3a+3b all green → the cyrius-doom agent removes the guards → DOOM's real shotgun on the archaemenid front jack. Everything before that is parallelizable across the three agents.

## Open / caveats

- **Verify pass incomplete** — synthesized from source-grounded maps, not adversarially cross-checked (see Status). Recommend a quick adversarial read of B2 (codec graph) + the `#63-68` ABI before implementation.
- **IRQ escalation** — ships polled; if iron shows underrun crackle, the fallback is a real BCIS→IDT vector (heavier under the cooperative-iron model). Mitigate by oversizing the ring first.
- **naad/dhvani Rust port** — prerequisite for the tracker proof-app + synth audio; NOT for `vanitone`. Separate work.

## References

- agnos: `kernel/core/{pci,r8169,nvme,vmm,pmm,syscall}.cyr` (the driver + ABI patterns), `scripts/whirl-smoke.sh` (the QEMU harness template).
- cyrius: `lib/syscalls_x86_64_agnos.cyr` (the ring-3 number map + the hands-off `sys_snd_*` peer), `lib/net.cyr` (the `#ifdef CYRIUS_TARGET_AGNOS` pattern).
- vani: `src/{alsa,format,device,playback}.cyr` (the ALSA backend the agnos peer mirrors).
- agnosticos: shared-crates audio-proof-apps row; memory [[feedback_qemu_test_agnos_userland]], [[feedback_cyrius_hands_off]], [[project_kernel_driver_family_subdirs]].
