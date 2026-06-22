# Desktop Design Ideas — Generative Visual Language for aethersafha

> **Fermenting idea log**, not a spec. Capture design concepts that catch the eye
> *before* desktop work opens, let them ferment, iterate in place. Same treatment
> as the tools / games idea logs — capture, don't escalate, don't scaffold off it.
> When aethersafha's compositor window actually opens, this page is the brief we
> argue from; until then it accretes.
>
> Sibling axis to the ML planning docs ([generative-paradigms.md](generative-paradigms.md),
> [multimodal-substrate.md](multimodal-substrate.md)) — those map *generative ML*
> on the attn11 core; this maps *generative visuals* on the mabda/aethersafha
> surface. Same instinct (compute it, don't stream it), different surface.

| Field | Value |
|-------|-------|
| Status | **Fermenting** — idea capture, not scaffolded, no critical path |
| Surface | [aethersafha](https://github.com/MacCracken/aethersafha) (Wayland compositor — **Pending**) · [mabda](https://github.com/MacCracken/mabda) (GPU foundation — Ported) |
| Math substrate | [bsp](https://github.com/MacCracken/bsp) (geometry) · [abaco](https://github.com/MacCracken/abaco) / [hisab](https://github.com/MacCracken/hisab) (number theory / higher math) |
| Roadmap | Desktop stage of the maturity arc (demo→base→server→**desktop**→swallow) — post-server, post-summer-2026 |
| HW design | **Deferred** — only once OS + systems are in a great place; see *Hardware (parked)* below |
| Created | 2026-06-22 |

---

## The frame — concept survives the rewrite, substrate doesn't

The seed sources are JS/HTML/WebGL — Claude's web design examples
(<https://claude.ai/design#examples>): organic loaders, a global loader, shader
wallpapers. **The web implementation is the disposable part.** The durable part
is the *concept*, and the concepts that caught the eye share one trait worth
naming: they are **generative — computed per frame, not asset-streamed.** That is
the same instinct AGNOS already runs on the ML side (everything-is-i64, math over
assets). A sovereign desktop can express these *more* naturally than the web can,
because there's no browser engine in the way — a shader talks straight to the GPU
foundation layer, procedural motion is just math on bsp/abaco geometry.

So the rule for this page: **borrow the concept, drop the substrate.** Never port
the JS. Restate each idea as "what would mabda + aethersafha do natively to get
the same *effect*."

---

## Captured ideas

### 1. Organic loaders
- **What caught the eye**: procedural, fluid loading motion — not a sprite sheet, not a spinner GIF. Motion that looks grown rather than drawn.
- **Sovereign restatement**: per-frame procedural geometry/motion. Math on bsp + abaco/hisab; no asset pipeline. The loader *is* a small program, not a stored animation.
- **Open question**: shared motion primitives — does a "loader" reduce to a handful of parametric easing/field functions that the whole desktop draws from?

### 2. Global loader / system motion language
- **What caught the eye**: a single, unified "the system is working" state — coherent across the whole surface, not per-app reinvention.
- **Sovereign restatement**: this is a **compositor-level** concept, not an app concept. It belongs to aethersafha, not to any one program. A system-wide motion vocabulary the compositor owns and apps inherit — the inverse of every app shipping its own spinner.
- **Open question**: where's the boundary — what does the compositor own vs. what does an app get to override? (Parallels the identity/authorization "capability boundary" thinking — the compositor grants motion, apps consume it.)

### 3. Shader wallpapers
- **What caught the eye**: dynamic, GPU-driven wallpapers — living math, not a static JPEG.
- **Sovereign restatement**: literally just math on the GPU — a **mabda surface**. No JS runtime, no Electron, no asset. Arguably the cleanest fit of the three: a shader-as-wallpaper is exactly the kind of thing the everything-is-i64 stack should do cheaply.
- **Open question**: authoring/format — how is a wallpaper-shader expressed and shipped sovereignly (a Cyrius source? a compiled shader artifact via mabda)? Ties to whatever shader-authoring story mabda lands.

---

## Hardware (parked)

The HW-design itch (designing the box, not just the OS) is **explicitly deferred**
until OS + systems are in a great place — long enough out that reference points
will have turned over at least once. The lesson from watching Jetson / Olares-class
edge boxes is *not* the silicon:

- **Jetson** — worth half an eye as a **thermal / power-envelope and unified-memory** reference, not a design target. Don't design against today's edge-compute assumptions.
- **Olares** — a *software* reference (self-hosting control plane + app marketplace UX), relevant to the ark/nous/zugot/mela compare, not to HW.

**The hard gate — GPU before GPU box.** Acquiring HW unlocks nothing until
[mabda](https://github.com/MacCracken/mabda) can actually *drive* that generation
of silicon. Jetson Thor **is Blackwell** — so a Jetson without functional Blackwell
support in mabda is just an ARM CPU board; the GPU stays dark. And NVIDIA is the
worst case for a sovereign stack: modern parts gate command submission behind
**signed GSP firmware** — you can't bring the GPU up without NVIDIA's signed blob
in the path (the wall Nouveau keeps hitting on recent generations). So a Blackwell
target is not just a large mabda effort, it's a *sovereignty-compromised* one by
construction. **Implication to weigh later (vendor call, not baked in):** the first
sovereign-GPU target is probably **not** NVIDIA — AMD / Intel are far friendlier to
an open driver. Park the vendor decision until mabda's GPU-bring-up window actually
opens.

### Decided principles for later (ferment, not a plan)

Concrete "when the HW day comes" calls accrued in conversation — sharper than
"borrow Jetson's thermal envelope," worth not losing:

- **Local-offload port is non-negotiable.** On-device storage + a dumb, boring, well-documented offload port (USB-C dump) = "the output is yours." The sovereignty test for *any* capture/compute device: app-only / cloud-only / no-port = "you're the sensor." The affordance a vendor had room for and left out is the loudest signal of intent (cf. Meta's chunky frames with no dump port — room existed, omission was the choice).
- **Boot from soldered flash, run from NVMe — never removable flaky media.** SD-as-root is disqualifying for a reliable appliance (no wear leveling on cheap cards, power-loss FAT corruption, flaky connector — the #1 SBC field failure). Split: **flashable boot medium** (eMMC / onboard SPI-NAND) for gnoboot + kernel + boot root, reflashable *as a unit* (maps onto the existing `--update` ESP-only reflash discipline — working FS survives iteration); **NVMe secondary** for the live filesystem + data (real wear leveling, SMART, speed). Bonus: **NVMe is already in-kernel and iron-proven** on archaemenid, so the SBC route reopens no storage bring-up — only the flashable-boot half is new, and it rides the gnoboot/ESP pattern.
- **Memory architecture is a real design axis — know which one you're on.** **Unified/shared (UMA)** — APU/SBC/Apple-style — gives zero-copy across CPU/GPU(/NPU) + huge model capacity, but trades away *bandwidth*: LLM token-gen is memory-bandwidth-bound, so shared LPDDR = **medium throughput**, with all engines contending for one pool (Apple's current ceiling — great at "big model slowly," mediocre at "fast"). **Discrete** (desktop + dedicated VRAM) gives high bandwidth but pays a copy cost CPU↔GPU. AGNOS's plugged-in targets straddle both (NUC/SBC = UMA-ish; desktop = discrete), so **hoosh's dispatch logic has to know which regime it's on** — the right routing differs.

### Accelerator tiers — GPU vs tensor cores vs NPU

Where the compute classes sit, ordered by **sovereignty-friendliness** (the axis
that actually matters here, not raw TOPS):

| Class | What it is | Sovereignty | AGNOS fit |
|-------|-----------|-------------|-----------|
| **CPU** | general-purpose; attn11 already trains `f64` here, no accelerator needed | **most sovereign** — nothing borrowed | the reference tier; always works |
| **GPU** (programmable SIMT) | flexible throughput — training, flexible inference, *and* the shader/wallpaper visuals above | drivable on **open-driver vendors** (AMD/Intel); NVIDIA gated behind signed GSP firmware | **mabda's eventual target**; one surface serves both ML and the generative visuals |
| **Tensor cores** | fixed-function low-precision matmul units *inside* the GPU (NVIDIA term) | inherit the GPU's sovereignty — not separable | a GPU-backend detail, not its own tier |
| **NPU** | *separate* fixed-function block for low-watt sustained int8/int4 inference | **least sovereign** — closed vendor runtimes + proprietary model-compile toolchains, often *no* open path; same firmware wall as NVIDIA, sometimes worse | demand-gated, **post-GPU**, only on open-driver silicon |

**The NPU is a power-envelope solution, not a capability one — design around it = silly.**
It does *nothing* a GPU can't; it does a *subset* (low-precision inference) at far
lower watts. So it only earns its keep where power/thermal is the binding
constraint — laptops, phones, fanless battery edge boxes. The market confirms it:
**desktop CPUs mostly skip the NPU** (a desktop has a wall plug + room for a GPU, so
it's redundant). **All of AGNOS's current hardware-target lines are plugged-in**
(NUC, Intel, Pi-class, RISC-V), so the NPU is a **freebie-if-the-SoC-has-it, never a
design target**: if the chosen SoC carries one (an AMD APU does), use it
opportunistically to keep background inference off the GPU; otherwise spend zero
design decisions on it. It becomes a real consideration *only* if AGNOS ever pursues
a **battery/portable form factor** — not on any target line today.

**And it's the worst tier for sovereignty even then:** you generally feed an NPU a
vendor-compiler-produced blob through a closed SDK (Qualcomm QNN, Intel OpenVINO,
Rockchip RKNN toolkit, Hailo SDK, Coral/Edge-TPU TFLite). An NPU you can't drive
openly is a black box you hand a foreign-compiled model to — antithetical to
everything-is-i64. So the rule, if a battery form factor ever opens: **only on
silicon with an open driver path**, which today points at AMD XDNA (mainline
`amdxdna` driver) — but that's a laptop/APU-line bet, parked behind a form factor
that doesn't exist yet.

**Where to look (when this opens):**
- **AMD Ryzen AI / XDNA** — the friendliest NPU for openness: the `amdxdna` driver landed in **mainline Linux** and the MLIR-AIE / IRON toolchain is open-ish. And it's the **archaemenid lineage** (AMD APU), so it's the natural bet. *Leading candidate.*
- **Rockchip RK3588** — the SBC standard (integrated ~6-TOPS NPU, Orange Pi 5 / Radxa Rock 5). RKNN toolkit is closed; community RE exists. Relevant *because* it's the SBC route's default SoC.
- **Hailo-8 / -10** — discrete M.2 NPU; slots next to NVMe (Pi AI Kit uses Hailo-8). Closed SDK. Option if discrete-accelerator-over-M.2 is the shape.
- **NVDLA** — NVIDIA's Deep Learning Accelerator has **open RTL** (most open NPU *architecture*), worth watching as the reference even though real-silicon bring-up still needs vendor bits.
- **Coral / Edge TPU** — aging, TFLite-only, closed; note for completeness, not a target.

**Placement in the stack:** NPU is a *third inference-serving backend tier under
mabda → hoosh*, **not** a training path (CPU/GPU train; attn11 trains `f64` on CPU).
It comes online only after the sovereign GPU path exists and only on open-driver
silicon. Same shape as everything else tonight: own the driver or you're renting
the accelerator.

**Heterogeneous dispatch — adopt the Jetson model, sovereignly.** The right SoC
architecture treats the chip as a *pool of specialized engines* (CPU + GPU +
optional NPU/DLA) and routes each job to whichever runs it fastest/cheapest — what
Jetson (CPU/GPU/DLA) and Apple (CPU/GPU/ANE) both do. **In AGNOS that dispatcher is
hoosh's job** — the inference gateway is the natural owner of "big matmul → GPU,
low-watt int8 → NPU if present, fallback → CPU `f64`." The catch: Jetson's
"send-it-where-it's-fastest" magic works because NVIDIA owns and *closes* the whole
stack (TensorRT dispatches, CUDA drives every unit). The sovereign version means
**hoosh may only dispatch across engines it can drive openly** — so the tier table
above isn't trivia, it's *hoosh's legal dispatch-target list*. The dispatch
architecture is right and worth stealing wholesale; the sovereignty constraint is
"own the driver for every engine you route to."

**Durability lesson — don't design around abandonable fixed-function silicon.** The
discrete edge-TPU class (Coral / Edge TPU) is *aging out*, squeezed from both sides:
real TPUs went cloud-only (rent-don't-buy), integrated NPUs ate the edge niche, and
Coral was a CNN-era part that never made the transformer jump — Google deprioritized
it, no successor, supply dried. **A whole accelerator product line can evaporate.**
That's the risk of betting on exotic fixed-function silicon; the durable substrate
stays **CPU (always there) + GPU (open vendor)**, which don't get strategically
abandoned under you.

**The Apple lesson — "designed our own chip" ≠ sovereign, and ≠ sovereign *for you*.**
Apple is the most vertically integrated consumer tech company alive and is still
only *slightly* sovereign: it **licenses the Arm ISA** (doesn't own the instruction
set) and **fabs at TSMC** (owns no fabs — single point of dependency). Two
load-bearing rentals under the "our silicon" story. And the sovereignty it *did*
buy is **corporate, not user**: Apple Silicon reduced Apple's dependence on Intel
while making the Mac *more* locked to its owner (signed boot, soldered RAM, locked
firmware, no eGPU). "We designed our own chip" meant "we own you more tightly" — the
clawbox lesson at vendor scale. **Why this matters for AGNOS:** ISA sovereignty is
the one move Apple structurally *can't* make (its moat is Arm-ecosystem compat — it's
married to the rented ISA). AGNOS can — it's sovereign *from the compiler up* (you
can't rebuild macOS from a seed; you can rebuild AGNOS from the 29KB Cyrius seed).
That's the deep reason **RISC-V is a target line (1.6x)**: the open ISA Apple can't
touch, reachable only because sovereignty runs all the way to the source.

Zero cost to waiting here; real cost to designing against current-gen assumptions.
Revisit only when the desktop stage is solidly shipping **and** mabda has a real
GPU-bring-up path.

---

## See Also

- [generative-paradigms.md](generative-paradigms.md) / [multimodal-substrate.md](multimodal-substrate.md) — the *generative ML* axes on the attn11 core; this is the *generative visuals* sibling
- [`../state.md`](../state.md) — live ecosystem state (aethersafha port status lives here)
- [README.md](README.md) — planning folder index

---

*Idea log opened 2026-06-22 from a chat about "AI OS" products (Olares) and Claude
web design examples. Generative-visuals concepts noted for desktop-stage
experimentation; HW design parked. Capture-and-ferment — not on any critical path.*
