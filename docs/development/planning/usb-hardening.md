# USB Hardening — Beta-Phase Defensive Stack

> **Status**: Planning — Design Phase | **Last Updated**: 2026-05-23
>
> **Scope**: Cross-cutting subsystem covering USB enumeration trust, class-policy enforcement, IOMMU isolation, behavioral sandboxing, and audit-chain integration. Spans **xhci** (kernel/core/xhci_*.cyr), **aegis** (security daemon), **kavach** (sandbox), **libro** (audit chain), **phylax** (threat detection), **agnostik** (shared types), and **agnosys** (kernel interface).
>
> **Phase**: NOT MVP. MVP (closed beta) target is boot-to-shell with typeable keyboard on iron — a single bootup-time USB keyboard enumeration is in scope; deny-by-default policy is not. This doc is **public-beta scope** (post-1.32.x networking arc, post-1.33.x WRITE, in the maturity arc's **base → server** transition per [[project_agnos_maturity_arc]]).
>
> **Companion docs**: [`agnostic-integration.md`](agnostic-integration.md), [`identity-and-authorization-model.md`](identity-and-authorization-model.md), [`first-party-standards.md`](first-party-standards.md) (release-gate audit pattern). Architectural alignment: [[project_agnos_auth_posture]] (recognition + authorization > authentication) and [[project_agnos_empire_defense_layers]] (four-layer parallel-infrastructure model).

---

## Why this matters

USB is a **trust-the-device protocol**. On enumeration, the host asks the device what it is via descriptors (device → configuration → interface → endpoint), and historically the host believes the answer. Every consumer OS today still defaults to "if it says it's a keyboard, it's a keyboard, and keyboards are trusted input." This is the long-running, underappreciated attack surface that BadUSB (Nohl + Lell, 2014), Stuxnet, the Rubber Ducky, and Equation Group's Cottonmouth implants all exploit.

The attack surface is not one bug — it's a **category of architectural defaults** that grew when "USB is just a peripheral bus" was the operating assumption. Every consumer OS has retrofitted security layers (USBGuard, IOMMU integration, descriptor validation hardening) on top of permissive defaults to preserve compatibility. AGNOS is greenfield. **The architectural opportunity is to ship with deny-by-default, capability-based USB policy as the natural shape of the stack** — not as a daemon the user installs after the fact.

### Threat model — explicit

| Vector | Description | Prior art |
|---|---|---|
| **BadUSB** | Device claims to be a different class than its physical form. Mass-storage stick presents as keyboard, types attack commands. | Karsten Nohl + Jakob Lell, Black Hat 2014. Commercialized as Hak5 Rubber Ducky. |
| **Composite-device abuse** | Single device exposes multiple class interfaces — one the user expects, one the attack surface. The user plugs in a "USB stick"; the device exposes mass-storage AND HID simultaneously. | Standard BadUSB variant. |
| **Malformed-descriptor RCE** | Descriptor bytes that don't match what the parsing code expects — length fields exceeding buffer, endpoint counts past spec max, interface association pointing nowhere. Corrupts the kernel driver before any policy decision runs. | Andy Nguyen's syzkaller-driven Linux USB driver bug class — dozens of memory corruption vulns triggered by malformed descriptors during enumeration. |
| **DMA attack from controller** | The xHCI controller does DMA. Without IOMMU configuration, a malicious or compromised controller can read or write arbitrary system memory. | Thunderclap (NDSS 2019) — practical DMA attacks against Thunderbolt/USB-C devices on systems with weak IOMMU. |
| **Stuxnet-class propagation** | Mass-storage autorun / open-on-mount infection vector. | Stuxnet, 2010+. |

---

## Five-stage defensive layer

Each stage has its own defensive opportunity and a corresponding AGNOS subsystem. Stages run in order during enumeration; a device that fails any stage is rejected.

### Stage 1 — Pre-descriptor validation

**Where**: `kernel/core/xhci_*.cyr` enumeration path. Before any class-driver dispatch.

Structural sanity checks on descriptor bytes themselves, before parsing what they mean:
- Length fields match the actual byte count received from the device.
- Endpoint counts ≤ USB spec maxima per class.
- Interface association descriptors point to interfaces that exist.
- Class/subclass/protocol combinations are legal per USB-IF certification.
- bcdUSB / bcdDevice are plausible (not 0x0000, not 0xFFFF, not future versions).

**Defensive opportunity**: Most BadUSB attacks ship with descriptor anomalies that wouldn't pass USB-IF certification. Linux accepts these "for compatibility." **AGNOS does not have that constraint.** Reject before the class driver is even chosen.

**Output**: device passes → stage 2. Device fails → libro audit entry (`usb.reject.malformed-descriptor`) + UI notification (per [[project_agnos_auth_posture]] "recognition over interrogation" — the user sees what happened, no password prompt).

### Stage 2 — Class-policy enforcement

**Where**: kernel-side class dispatcher (TBD subsystem — currently bundled into xhci, splits naturally into a `usb_class_dispatch.cyr` at this phase).

Once the device's claimed class is known, apply policy before loading the class driver:
- **HID-after-boot deny by default** — keyboards plugged in at boot are accepted; HID class arriving after `kybernet` is up requires explicit approval. Eliminates ~90% of the casual BadUSB surface in one rule.
- **Composite-device suspicion** — devices exposing HID + mass-storage / HID + network are suspicious-by-default. Curated allowlist for legitimate cases (gaming peripherals).
- **Class-availability gating** — mass-storage and ethernet classes require user-side opt-in policy before any device of that class is accepted. (System-level setting, not per-device prompt.)
- **Boot-time vs run-time policy split** — different policy applies during the boot window vs after init completes. Most legitimate USB attachment happens at boot; security tightens after.

**Defensive opportunity**: This is the layer where most defensive USB implementations live — and where most operating systems do nothing.

### Stage 3 — Per-device authorization

**Where**: **`aegis`** (security daemon) — in-kernel, NOT userspace.

USBGuard's pattern (notification + click-to-allow) is the right shape. **The wrong shape is USBGuard's deployment**: it runs in userspace and depends on the kernel notifying it of new devices, which creates a race condition where a device can attack before the policy daemon evaluates it. In AGNOS, the policy engine must be **in-kernel and synchronous with enumeration** — the enumeration path blocks until policy decides.

Policy shape:
- Trusted device IDs (vid:pid + serial) auto-approved.
- New devices prompt via the kernel UI surface.
- Certain classes (HID specifically) require explicit approval if they appear after boot.
- Mass-storage gets mounted read-only by default (see stage 4).

**Defensive opportunity**: Removing the userspace-daemon race condition is a genuine architectural improvement over Linux's deployment of USBGuard. This is the layer where `aegis`'s synchronous-with-enumeration position pays off.

### Stage 4 — Behavioral sandboxing

**Where**: **`kavach`** (sandbox) + **`phylax`** (threat detection). Per-device behavioral envelope enforced at the driver level.

Even an authorized device shouldn't be able to behave maliciously:
- **Rate limiting** — a keyboard shouldn't send 1000 keystrokes/sec; a mass-storage device shouldn't enumerate new interfaces post-attachment.
- **Capability-envelope enforcement** — a printer shouldn't claim HID capabilities mid-session.
- **Per-device behavioral signature** — `phylax` watches for the class of attacks where a device behaves normally during enumeration to get approved, then behaves maliciously once it's in.
- **Read-only mass storage by default** — when mass storage is attached, mount read-only unless the user explicitly mounts RW. Eliminates "USB stick infects system on autorun" class.

**Defensive opportunity**: This is the surface that catches devices which pass stages 1-3 by mimicking benign behavior during enumeration. The `phylax` integration makes per-device behavior part of the system-wide threat-detection picture, not a USB-only audit silo.

### Stage 5 — IOMMU DMA isolation

**Where**: `kernel/core/iommu.cyr` (new at this phase) consuming AMD-Vi / Intel VT-d. **AMD-Vi is already initializing on archaemenid before xHCI** (visible in `dmesg` post-1.30.x). The substrate is ready.

USB controllers do DMA. Without IOMMU configuration, a malicious or compromised USB controller can read/write arbitrary system memory bypassing every other defensive layer. With IOMMU:
- Each USB controller gets a minimal DMA window — only the memory regions it actually needs for its rings and transfer buffers.
- Equivalent to Linux's `iommu.strict=1`, but the AGNOS default rather than an opt-in.
- Defends against the Thunderclap (NDSS 2019) attack class — practical DMA attacks against Thunderbolt/USB-C devices that succeed only because IOMMU configuration is permissive by default.

**Defensive opportunity**: Linux only enabled strict IOMMU mode by default for Thunderbolt in 2019, and for general USB later. AGNOS can do this on day one. Genuine differentiator for sovereign deployments — DMA attacks are invisible to every other defensive layer.

---

## AGNOS-specific architectural posture

### In-kernel policy, not userspace daemon

USBGuard's enumeration race exists because the kernel notifies userspace asynchronously and the device can act before the daemon evaluates it. In AGNOS, `aegis`'s policy hook runs **synchronously inside the xHCI enumeration path** — enumeration blocks at the stage-3 gate until aegis returns approval. No race window.

### Capability-based device access at kernel level

The pattern is familiar from application security (input validation, schema enforcement, capability-based access, behavioral monitoring) but **almost never applied at the kernel driver layer.** The reasons are mostly historical inertia + compatibility cost. Neither constrains AGNOS.

Prior art: seL4 has had capability-based device access for years; KeyKOS had it in the 1980s. **What's new in AGNOS is combining capability-based kernel hardening with a modern driver stack that supports real consumer hardware.** Each piece exists somewhere; the integration doesn't exist anywhere consumer-deployable.

### Audit-chain integration is mandatory

Every USB connect / disconnect / descriptor-mismatch / policy decision goes through **`libro`** (cryptographic audit chain). Forensically, "what was plugged in and when" is one of the highest-signal pieces of evidence in incident response, and most operating systems make it surprisingly hard to reconstruct after the fact. AGNOS makes it trivial: query libro for `usb.*` event class, get the full chain with cryptographic proof of completeness.

### Boot-time vs run-time policy distinction

The architectural insight is that **most legitimate USB attachment happens at boot** — keyboard plugged in, mouse plugged in, occasionally mass storage. After init completes, the population of "things that get plugged in to a running system" is dominated by attacker-attached devices in any meaningful threat scenario. So the policy can be: permissive at boot (within stage-1 + stage-5 envelope), strict after `kybernet` reaches steady state. Single rule eliminates most casual BadUSB attempts.

---

## Repo touch points

| Repo / file | What it owns | What this plan adds |
|---|---|---|
| `agnos/kernel/core/xhci_*.cyr` | xHCI controller + enumeration | Stage-1 validation hook; stage-3 gate (blocks for `aegis` reply) |
| `agnos/kernel/core/iommu.cyr` (new) | AMD-Vi / Intel VT-d consumer | Per-controller DMA window allocation; iommu.strict-equivalent default |
| `agnos/kernel/core/usb_class_dispatch.cyr` (new) | USB class-routing logic, split from xhci.cyr | Stage-2 policy gate |
| **aegis** | Security daemon | In-kernel sync policy engine; per-device authorization; trusted-device-ID database |
| **kavach** | Sandbox / capability enforcement | Stage-4 behavioral envelopes per device class |
| **phylax** | Threat detection | Stage-4 behavioral anomaly detection; cross-system signal correlation |
| **libro** | Cryptographic audit chain | `usb.*` event class — every connect/disconnect/policy-decision/descriptor-mismatch |
| **agnostik** | Shared types | USB descriptor types, class enum, policy verdict enum |
| **agnosys** | Kernel interface | Syscalls for `aegis` to read/write policy from userspace |
| **agnoshi** | AI shell | `aegis` policy CLI / UI surface; new-device prompts |

---

## Phasing within the beta arc

The order matters because each stage builds on the previous. Approximate sequencing (subject to roadmap revision):

1. **Stage 1 (pre-descriptor validation)** — lands first; pure defensive code in `xhci_*.cyr`, no new subsystem dependencies. Can ship with public-beta cut.
2. **Stage 5 (IOMMU DMA isolation)** — lands next; AMD-Vi substrate already up on archaemenid, just needs the per-controller DMA window allocator. Independent of stages 2-4.
3. **Stage 2 (class-policy enforcement)** — requires the boot-vs-runtime split + class-availability config surface. Cross-cuts shell.
4. **Stage 3 (per-device authorization)** — requires `aegis` in-kernel policy engine. Biggest single bite.
5. **Stage 4 (behavioral sandboxing)** — most architecturally ambitious; requires `kavach` + `phylax` integration. Last-landed, gates on stages 1-3 being live in production.

Stages 1 + 5 are the high-leverage early cuts — they harden the substrate without requiring the full `aegis`/`kavach`/`phylax` machinery.

---

## Where AGNOS lands in the security landscape

The combination of:
- **Audit-grade compliance machinery at the application layer** (the SecureYeoman / RBAC / SAML / DLP / audit-chain story),
- **Capability-based hardening at the kernel layer** (this doc + the empire-defense layers in [[project_agnos_empire_defense_layers]]),
- **Self-hosted sovereign deployment model** (no per-host cloud dependency, single-machine path well-established via archaemenid),

...is a position no other project occupies. Each piece exists somewhere — seL4 has kernel capabilities, USBGuard has device policy, enterprise compliance suites have audit chains — but the **integration** is unique to AGNOS.

USB hardening specifically is a place where the gap between "industry default" and "what's actually possible if you start clean" is enormous. The cost of doing it right is bounded (the architectural sketch above fits in roughly four named bites); the cost of NOT doing it is paid forever in every subsequent compatibility-preservation decision.

---

## Cross-references

- **Memories**: [[project_agnos_auth_posture]], [[project_agnos_empire_defense_layers]], [[project_agnos_maturity_arc]], [[project_hardware_catalog]]
- **Existing security docs**: `docs/security/security-guide.md`, `docs/security/penetration-testing.md`, `docs/security/cis-benchmarks.md`
- **Adjacent planning**: [`agent-injection-defense.md`](agent-injection-defense.md) (LLM-layer attack surface; same defense-in-depth posture, different layer)
- **Prior art / external references**: Karsten Nohl + Jakob Lell BadUSB (Black Hat 2014); Andy Nguyen / syzkaller Linux USB driver bug class; Thunderclap NDSS 2019; Stuxnet (2010); seL4 + KeyKOS capability-based device access; USBGuard (Linux daemon, deployment-model reference)
