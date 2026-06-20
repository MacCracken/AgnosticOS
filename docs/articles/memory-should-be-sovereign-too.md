# Memory Should Be Sovereign Too

## The install disk still runs C.

> AGNOS has replaced every load-bearing C dependency — kernel, compiler, shell, package manager, audio stack, cryptography, storage. One layer is still C: version control. smriti (sit) closes it.

---

## TL;DR

- AGNOS ships Cyrius kernel, Cyrius compiler, Cyrius shell, Cyrius package manager, and then shells out to `git`, which pulls in libgit2, zlib, and OpenSSL. That's the last C hole in the stack.
- **smriti** (sit, from स्मृति, *"that which is remembered"*) closes it. Three letters like git; same typing rhythm.
- Every layer it needs is already shipped: **sankoch** (LZ4/DEFLATE/zlib/gzip, beats C zlib 1.3.1 on compressible DEFLATE), **sigil** (hashing + trust verification), **patra** (B+ tree + WAL object store, v1.5.5), plus the Cyrius stdlib. sit is assembly, not invention.
- **Why not keep git**: the C dep chain invalidates the sovereignty argument AGNOS makes at every other layer. "Except git" is not a defensible carve-out.
- **Why not clone git**: reference don't mimic. Keep the object model (content-addressed DAG, distributed). Drop twenty years of backward-compat accretion: submodules, hooks-as-shell, `.gitattributes` cross-platform drama, LFS-bolt-on, porcelain-vs-plumbing schism.
- **Status**: sit is a scaffold with a handful of commits, all in git. Every sovereign tool is born inside its incumbent. The receipts article writes itself the day sit clones and hosts its own log.

---

## One Layer Left

Walk through an AGNOS install disk in 2026:

| Layer | Incumbent being replaced | Status |
|-------|---------------------------|--------|
| Kernel | Linux | Cyrius-native (`agnos` v1.26.1, 248 KB, 33 subsystems) |
| Compiler | LLVM / gcc | Cyrius self-hosts from a 29 KB seed (cc5 at v5.9.0) |
| Shell | bash / zsh | `agnoshi` v1.0.0 |
| Init | systemd | `kybernet` v1.0.1 (486 KB, 140 tests) |
| Package manager | apt / pacman / dnf | `ark` v0.8.0 (Cyrius) + `nous` v1.1.1 |
| Sandbox | bubblewrap / firejail | `kavach` v3.0.0 (500× faster on sandbox lifecycle) |
| Audit chain | syslog / systemd-journald | `libro` v2.0.5 |
| Audio codecs | libavcodec | `shravan` v2.3.2 |
| LLM gateway | OpenAI SDKs | `hoosh` v2.0.0 (15 providers) |
| Compression | zlib / liblz4 / libdeflate | `sankoch` (LZ4, DEFLATE, zlib, gzip — beats C zlib on compressible data) |
| Crypto / hashing | OpenSSL | `sigil` v2.9.4 |
| Structured storage | SQLite / BerkeleyDB | `patra` |
| **Version control** | **git + libgit2 + zlib + OpenSSL** | **still C** |

> Live versions for any row above: see [`development/state.md`](../development/state.md). The drift surface here is intentional — the Cyrius-native column is a moving target by design.

One row not like the others. Everything AGNOS commits is committed through a foreign C binary that depends on two other C libraries the rest of the OS has already replaced first-party.

That's the gap.

---

## Why Not Just Keep Git

The sovereignty argument AGNOS makes at every other layer applies here verbatim.

**The C dep chain is load-bearing.** `git` is roughly 200K lines of C across the core repo, plus zlib for pack-file compression, plus OpenSSL for SHA/signing, plus libcurl for HTTP transport. An AGNOS install that ships git on the disk also ships four C codebases and their transitive CVE surface — the same codebases AGNOS replaced first-party at every other layer.

**The maintainer set is external.** Junio Hamano is a great maintainer. "Not having an external critical-path maintainer for the VCS of your own sovereign OS" is a different kind of great. AGNOS made this argument about crates.io when registry squatters forced Cyrius into existence; the argument for VCS is identical.

**Release cadence doesn't compose.** AGNOS ships Cyrius patches on a variable cadence — often daily. When sankoch finds a DEFLATE edge case, the fix lands in a sankoch point release, and every AGNOS binary that depends on sankoch picks it up on its next build. git fixes land on git's cadence, under git's release governance, against a C codebase that AGNOS doesn't build. That's a coherence gap that compounds the longer AGNOS exists.

**The benchmarks exist at every other layer.** Every Cyrius-first-party replacement in the table above has a published receipts artifact against its C incumbent — compile time, binary size, memory, or operation latency. "Except git" is not a defensible carve-out.

---

## Why Not Clone Git

sit is **not** libgit2-in-Cyrius. That distinction is load-bearing.

Twenty years of git's development produced two different things entangled in one codebase:

**The object model — which we keep.** Content-addressed DAG. Blobs, trees, commits, tags. SHA-addressed integrity. Distributed, not centralized. This is the single best piece of VCS design in the last fifty years. It transfers cleanly and doesn't need reinventing.

**The surface — which we don't keep.** Twenty years of backward-compat accretion:

- **Porcelain vs plumbing.** git's CLI split into "things humans type" and "things scripts call" with overlapping-but-different semantics, because the human CLI accreted while the machine CLI stabilized. sit has one CLI; humans and scripts call the same invocations.
- **Submodules.** An accepted design failure — the community built git-subtree, git-subrepo, and an industry of monorepo tooling to avoid them. sit's answer is built in: workspaces as first-class, nested repos as explicit non-silent boundaries.
- **Hooks as shell scripts.** Shell-injection CVE surface, untyped, unsandboxed, cross-platform-incompatible. sit hooks are Cyrius source, kavach-sandboxed, kernel-enforced argv.
- **`.gitattributes` line-ending drama.** Twenty years of CRLF/LF / `text=auto` / works-on-macOS-not-Windows tickets. sit treats byte streams as byte streams; line-ending handling is an opt-in tool, not file metadata.
- **LFS as a bolt-on.** Large-binary support designed in, not bolted on as a third-party server protocol.
- **The 150-command surface.** `git stash create` vs `save` vs `push`; `git checkout` split into `switch` and `restore` in 2019 because the original verb did too many things. sit ships with the smaller verb set that hindsight earned.

Reference, don't mimic. The thesis that produced Cyrius applies verbatim: incumbents define the problem, not the solution.

---

## The Layers Are Already Live

sit is assembly, not invention. Every dep is in production against a C incumbent:

**sankoch — compression.** 1,881 lines of Cyrius, zero C, zero FFI. Beats C zlib 1.3.1 on compressible DEFLATE (L1: -9B, L6: -1B on representative corpus). Matches on zero-input. Only loses on incompressible random input (+40B — the least interesting case). 5,762 assertions green. LZ4, DEFLATE, zlib, gzip — full coverage. This is the pack-file layer.

**sigil — hashing and trust.** v2.9.1, first-party crypto boundary for all of AGNOS. libro (audit chain) already consumes it. This is the SHA / signing layer for objects and refs.

**patra — structured storage.** v1.5.5, Cyrius-native. B+ tree with WAL, transactional, 243 tests. This is the object-store and index layer — the replacement for git's `.git/objects/` plus pack-file index.

**Cyrius stdlib.** `syscalls`, `fs`, `alloc`, `string`, `vec`, `hashmap`, `fnptr`, `process`, `thread`, `keccak`, `ct`, `bigint`, `freelist`, `chrono`, `tagged`. Everything else sit reaches for is in the stdlib or a sibling crate, pinned by git-tag in `cyrius.cyml`.

Every line of code sit compiles is Cyrius, compiled by a Cyrius compiler that boots from a 29KB seed, running on a Cyrius kernel. The dep chain has no C in it.

---

## What sit Isn't

Scope discipline, because "sovereign git replacement" invites expectations that aren't the point:

- **Not a world competitor to git.** sit is AGNOS's VCS. Not a pitch deck for anyone else. If it's useful outside AGNOS, great; if it isn't, also great.
- **Not libgit2 translated to Cyrius.** A line-for-line port would inherit git's architectural debt and none of the "reference don't mimic" win.
- **Not a new object model.** Content-addressed DAG. Your mental model transfers.
- **Not a beat-git-on-day-one project.** git has twenty years of hardening on the hot paths. sit hits real workloads when it hits them; the receipts article names which paths cross over and which don't. Honest is the only interesting mode.

---

## smriti — What the Name Carries

**smriti** (स्मृति) — *"that which is remembered."* Sanskrit root. The shipping binary is `sit` — three letters like git, same typing rhythm. Phonetic echo of *symmetry* (version control as mirrored state across nodes). sit vs stand, park vs push — the verb wordplay holds.

Every other first-party AGNOS subsystem carries a name from the same naming tradition: *sankoch* (contraction/compression), *sigil* (mark of trust), *patra* (vessel/record), *libro* (book), *kavach* (armor), *shravan* (listener), *hoosh* (awareness), *agnoshi* (knower). sit fits.

---

## Where We Are

sit exists as a scaffold. `cyrius.cyml` with the four deps pinned at their shipping tags. `src/main.cyr` with a stub. A handful of commits — all in git.

Every sovereign tool is born inside its incumbent. Cyrius's first compiler was written in Python. AGNOS's first boot was from a Linux host. sit's first commit was made by git. The point isn't that the incumbent never touches the tool; the point is that the tool graduates out.

The milestone isn't "sit is written." The milestone is **sit clones and hosts its own history.** When that happens, the CSV history, benchmark numbers, and CVE-class comparisons land together and the receipts article writes itself.

Until then, this one states the refusal.

---

## Related

- [*Sovereign Compiler vs Brute Force*](sovereign-compiler-vs-brute-force.md) — the same refusal applied to the compiler layer
- [*Port Ledger Volume 1*](port-ledger-volume-1.md) — the pattern this article is volume `N+1` of
- [*Development Speed and How It Effects Documentation*](development-speed-and-documentation.md) — the coordination-doc problem that motivated handoff-as-code, which sit inherits
- [*The Price of Porting Early*](the-price-of-porting-early.md) — pinning against a moving compiler; applies in spades to sit depending on sankoch/sigil/patra mid-stride

---

## Since This Was Written

**Refreshed 2026-05-06.** Body table version columns are pinned to article date — current values live in [`development/state.md`](../development/state.md) and [`shared-crates.md`](../development/planning/shared-crates.md). Notable updates since the body was written:

- **Cyrius**: v5.6.17 → v5.9.0 (cut today). Three stdlib fold-ins shipped: sandhi (v5.7.0 service-boundary), vani (v5.8.0 audio I/O), niyama (v5.9.0 regex engines). The fold-in pattern, born during the post-write window, is now a documented decision framework — see [*What Justifies a Stdlib Foldin*](what-justifies-a-stdlib-foldin.md).
- **AGNOS kernel**: v1.22.0 → v1.26.1 (248 KB; CI-hygiene replaced a workaround with a real fix at v1.26.1).
- **sigil**: v2.9.1 → v2.9.4 (output-binary rename for ISO `--iso-check` compatibility).
- **sankoch**: v2.0.1 → v2.2.4 (continued layer additions).
- **sit itself**: still scaffold. The receipts article still writes itself the day sit clones and hosts its own log; that day still hasn't arrived. Per the article's own framing, this is fine — the milestone isn't "sit is written."

---

*AGNOS project — [agnosticos.org](https://agnosticos.org)*
*April 2026 (refreshed footer May 2026)*
