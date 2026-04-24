# Why GPU Belongs in the Stdlib

## The last FFI bridge.

> Every systems language treats the GPU as a third-party concern — pulled in through bindings to wgpu, ash, gfx-hal, or raw Vulkan/OpenGL headers. Cyrius folds mabda into the standard library. Same move AGNOS made for compression, crypto, and storage: if the subsystem is load-bearing, it's first-party.

---

## TL;DR

- Every other systems language defaults to *GPU-as-third-party*: Rust pulls wgpu, Zig pulls GLFW + manual Vulkan, Go pulls ebitengine, C++ pulls the Khronos stack. Cyrius's standard library owns mabda directly.
- **Why stdlib**: GPU is load-bearing for AGNOS — `soorat` (rendering), `kiran` (game engine), `ai-hwaccel` (capability enumeration), `joshua` (AI simulation), `cyrius-doom` (reference consumer). Load-bearing subsystems are stdlib concerns, not foreign deps.
- **Why not C hooks**: every FFI bridge is a C dep chain that AGNOS otherwise refuses — wgpu pulls Rust + LLVM + Vulkan loader + C driver surface. Binding to it reintroduces everything Cyrius exists to remove.
- **The honest caveat**: mabda currently *does* use wgpu via FFI — it's the one documented FFI exception in the Cyrius FFI policy. The article's point is that the exception is closing, not that it's already closed.
- **Why now**: the Cyrius stdlib at v5.6.x has the syscall surface, allocator model, and memory-layout guarantees needed to drive GPU hardware directly. The wgpu bridge was a viability bet; the native replacement is the execution of it.

---

## The Pattern Everywhere Else

How every mainstream systems language handles the GPU:

| Language | GPU access | Dep chain |
|----------|------------|-----------|
| Rust | wgpu crate | Rust + LLVM + naga + Vulkan loader + C driver |
| Zig | mach / manual Vulkan | C toolchain + Vulkan loader + driver |
| Go | ebitengine / gomobile | cgo + GL/Metal/DX bindings |
| C++ | Vulkan/OpenGL/DX headers | Platform SDK + driver |
| C | Same | Same |

Common shape: the GPU subsystem is **not** part of the language distribution. The language ships; the user pulls in the GPU layer as a foreign dep. On Rust this is idiomatic. On Zig this is considered a feature ("Zig is a C toolchain; bring your own"). On Go it requires cgo, which Go's culture actively discourages for other reasons.

The result is the same across all five: the GPU dep graph is someone else's problem. And "someone else" is almost always C.

Cyrius doesn't do that. mabda is a first-party subsystem, folded into the standard library, compiled by the same compiler that produces the kernel. There's no foreign ecosystem to depend on — or, currently, there's exactly one bridge and it's named, scheduled, and closing.

---

## Why That Pattern Is Wrong for a Sovereign OS

The argument against "GPU as third-party" has three parts:

**The dep chain re-infects the stack.** AGNOS removed C from the kernel, the shell, the package manager, the compression layer, the crypto layer, and the storage layer. Binding through wgpu reintroduces: the Rust toolchain (because wgpu is Rust), the Vulkan loader (C), the graphics driver surface (C, kernel-side), and the naga shader compiler (Rust). Four dep chains for one subsystem, every one of them already refused elsewhere in the stack.

**The abstraction is designed for a different problem.** wgpu, Vulkan, and the Khronos stack are designed to abstract over vendor-specific GPU driver interfaces *for an industry that ships heterogeneous driver stacks*. AGNOS doesn't. AGNOS has one kernel, one compiler, and a fixed target list. The cross-vendor abstraction pays for flexibility the OS doesn't need and can't take advantage of.

**The release cadence doesn't compose.** wgpu lands on wgpu's schedule under wgpu's governance. When AGNOS needs a GPU change — new capability, new target, security fix — the path goes through an external maintainer queue, a Rust version bump, a naga regeneration, and a wgpu release. Every other AGNOS subsystem fix lands in hours. The GPU layer shouldn't be the only exception.

These are the same three arguments the sit article makes about git, the sovereign-compiler article makes about LLVM, and the compression story makes about zlib. The pattern is consistent because the underlying logic is consistent: *if a subsystem is load-bearing, it's first-party; if it's first-party, it ships with the language, not bolted on.*

---

## Why Stdlib Is the Right Place

Not just "first-party in a sibling crate" — actually in the standard library, alongside `alloc`, `fs`, `string`, and `syscalls`.

**Because GPU is kernel-adjacent infrastructure.** Driving a modern GPU means talking to DRM/KMS, submitting command buffers through ioctls, managing memory regions that span user and kernel address spaces, and handling fences. That's the same surface the stdlib already owns for regular syscalls, file descriptors, and memory mapping. Putting mabda in stdlib lets it share the stdlib's syscall abstractions instead of reimplementing them.

**Because the allocator model matters.** GPU buffers are large, long-lived, and need specific alignment and memory-type constraints (device-local, host-visible, coherent). Cyrius's stdlib has a known allocator profile — bump, slab, arena — and mabda's allocation strategy composes with it. A sibling crate would have to ship its own allocator or paper over the mismatch.

**Because every downstream consumer is also first-party.** soorat, kiran, ai-hwaccel, joshua, cyrius-doom. None of them live outside AGNOS. None of them need mabda to be a separately-versioned crate with its own release cadence. Shipping mabda in stdlib collapses the version-pin matrix across five consumers at once.

**Because the alternative is lying about the architecture.** If mabda were a sibling crate, it would still be treated *as* stdlib by every consumer — pinned, never skipped, upgraded lockstep. That's what stdlib means. Moving it out of the stdlib would add release-cadence friction without changing the architectural reality.

---

## The FFI Exception

Worth naming directly, because any honest version of this article has to.

The [Cyrius FFI policy](https://github.com/MacCracken/cyrius) declares: *"No C — but FFI bridges permitted where native replacement isn't ready."* There is currently exactly one such bridge in-tree: **mabda → wgpu**.

This is an explicit, documented, scoped exception. The policy is not "sometimes it's OK" — it's *"name the exception, book its closure, measure the gap until it closes."* mabda's wgpu bridge is named in `cyrius.cyml`, scoped to mabda alone (it does not expand laterally), and closing: native-path work is the active arc, and when mabda's native GPU driver reaches parity for the consumer set, the wgpu line disappears from the manifest.

The title of this article is about where the GPU *belongs*. The subheader — *The last FFI bridge* — is about where it currently *sits*. Both claims are live simultaneously. That's the honest version.

---

## What mabda Is

Current shape, for the reader who wants a concrete anchor:

- **v2.5.0**, folded into Cyrius stdlib
- **Downstream consumers** (all first-party): `soorat` (rendering), `kiran` (game engine + ECS + scene hierarchy), `ai-hwaccel` (capability enumeration — 518 tests), `joshua` (AI simulation runtime), `cyrius-doom` (reference 3D consumer, 2.59ms/frame)
- **Backends today**: wgpu FFI bridge (the exception)
- **Backends in flight**: native Vulkan-direct path against DRM/KMS syscalls, sharing stdlib's allocator and syscall model
- **Shader pipeline today**: naga through wgpu
- **Shader pipeline in flight**: first-party SPIR-V emitter; reuses Cyrius's own codegen patterns where they apply

The shape of mabda is not going to change when wgpu comes out. The consumers don't have to rewrite. That's the load-bearing thing — *the interface is first-party; only the backend is bridged.*

---

## What mabda Isn't

- **Not a competitor to wgpu for the Rust ecosystem.** mabda targets AGNOS. If it's useful elsewhere, fine; if not, also fine.
- **Not a "port wgpu to Cyrius" project.** A line-for-line port would inherit wgpu's cross-vendor abstraction tax that AGNOS doesn't need. Reference don't mimic.
- **Not a new graphics paradigm.** Command buffers, pipelines, bind groups, shaders — the mental model transfers from any modern graphics API. The refusal is of the *dep chain*, not the *concepts*.
- **Not trying to beat wgpu on wgpu's hardened paths on day one.** wgpu has had years of vendor-specific debugging. mabda's native path will hit real workloads when it hits them; the receipts article names which paths cross over and which don't, honestly.

---

## Where We Are

mabda is folded into stdlib today, running through wgpu for the consumer set that needs it, with the native path in active development. The wgpu line in `cyrius.cyml` is documented, scoped, and closing.

The milestone isn't *"mabda is in stdlib"* — that's already true. The milestone is **the `wgpu` line disappears from the Cyrius manifest.** When that happens, the receipts article drops: per-consumer benchmarks against the wgpu baseline, driver-roundtrip latency, SPIR-V compile time, and memory-layout comparisons land together.

Until then, this one states the refusal and names the exception.

---

## Related

- [*Memory Should Be Sovereign Too*](memory-should-be-sovereign-too.md) — the sit / git-replacement counterpart. Same shape: last-layer refusal, receipts pre-committed to
- [*Sovereign Compiler vs Brute Force*](sovereign-compiler-vs-brute-force.md) — why Cyrius itself is first-party instead of riding LLVM; the argument template this article inherits
- [*Port Ledger Volume 1*](port-ledger-volume-1.md) — every port receipt in the same lineage (Rust → Cyrius, with numbers)
- [*The Price of Porting Early*](the-price-of-porting-early.md) — pinning against a moving compiler; mabda is simultaneously consumer and dependency of Cyrius's in-flight stdlib changes

---

*AGNOS project — [agnosticos.org](https://agnosticos.org)*
*April 2026*
