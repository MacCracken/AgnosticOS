# ark v2 — Sovereignty Path

> **Status**: Roadmap | **Created**: 2026-06-29 (multi-agent research, source-grounded, adversarially verified) | **Scope**: cross-repo (ark · nous · takumi · zugot · agnos · gnoboot). This is the orchestration spine; per-repo bites filed 2026-06-29. **PROGRESS — ark's share of M0–M3 is ✅ DONE (ark 1.1.0/1.1.1, 2026-06-29)** — host de-apt seam + native-installer wiring + native backend/store + agnos-cross-build-compiles, 346 tests. **Still open**: M2's **nous** half (SOURCE_NATIVE resolver/index/lockfile — nous 1.2.7, not started), M3's **on-agnos runtime** proof (gated on the 1.50.x burn + the 1.51.x symlink syscall), and the server-stage **M4** (update mechanism) / **M5–M6** (takumi self-host) / zugot recipe portability. agnos kernel gaps = the **agnos 1.51.x** arc (waiting on 1.50.x burn-close to start).
>
> **Why this exists**: **agnova (the native installer) can't install anything *right* without a sovereign package manager beneath it.** On a box with no `apt`, `agnova install <x>` is meaningless unless the zugot→takumi→`.ark`→nous→ark chain resolves, fetches, verifies, and materializes natively. That puts sovereign ark on the **critical path** (`sovereign ark → agnova → server-stage exit`), not on a parallel "ecosystem" shelf. This doc roadmaps it.

## Thesis

**ark v2 "sovereignty" = AGNOS owns its package layer end-to-end with zero dependency on Debian `apt`/`dpkg`**: the chain `zugot(recipe) → takumi(build) → signed native .ark → nous(resolve over a native index) → ark(verify + materialize + register to PackageDb)` runs entirely on agnos, with `apt` demoted to an optional Debian-interop compat mode behind a config flag — **not deleted**.

It is **double-gated**:
- **Gate 1 — ark/nous/takumi de-apt + wiring work** (host-side, Linux): a `system_backend` seam, a `SOURCE_NATIVE` resolver, a native index/store, wiring resolved marketplace steps into the `.ark` installer, and replacing takumi's Linux build substrate.
- **Gate 2 — agnos exposing the surface**, which splits cleanly by maturity stage: the **INSTALL half** (FS-write + HTTPS-fetch of a *prebuilt* `.ark`) is base-reachable today (agnos 1.50.6); the **BUILD half** (takumi self-host "build agnos on agnos", needing nested-exec / build-step execution / confinement agnos deliberately lacks) is **server-stage**.

Per [[project_agnos_maturity_arc]]: *don't frame "ark end-to-end" as a base deliverable* — sovereign ark naturally lands ~**server**. The host-side refactor (M0–M2) is stage-neutral Linux dev work; the on-agnos install *proof* (M3) rides base surface; everything from the update mechanism onward is server.

## What exists today

- **`.ark` v1 format — DONE.** A 5-section little-endian binary (16 B header magic `0x89 'A' 'R' 'K'`, TOML manifest, file table, content blob, optional Ed25519 sig over SHA-256; DEFLATE level-6). **Produced** by takumi `ark_write` (`takumi/src/ark_format.cyr`), **consumed/verified** by ark `ark_pkg_read` (`ark/src/ark_package.cyr`) — the two match field-for-field (ark's reader written against takumi ADR 0001 + bayan 2.3.1). The package container is not the gap.
- **ark v1.0.0 / nous 1.2.7 / takumi 1.0.0 / zugot 1.0.5** — all Cyrius-native, all on Debian-host today.
- **The sovereign install primitives exist but aren't wired end-to-end**: `ark_pkg_install` (`ark_package.cyr:564`) installs a local `.ark`; `ark install ./x.ark` and `name@version --marketplace` reach it. But a **resolved** plan's `STEP_MARKETPLACE_INSTALL` **dead-ends** — `exec.cyr:177-179` fails loud ("uses the native .ark installer, pending").

### The real chain gaps (research-confirmed)
1. **recipe→build→install not wired inside ark** — ark installs a `.ark` only from a local path or a mela download; no path runs zugot-recipe → takumi-build → install.
2. **apt is still the system leg** — `nous/src/sysdb.cyr` shells `apt-cache`/`dpkg-query`; `ark/src/exec.cyr` `step_to_argv` lowers system steps to `apt-get` (hard-coded, lines 60-89).
3. **no native repo: no build-cache / local artifact store / index protocol** — takumi writes `.ark`s to a dir; nothing indexes them into something nous/ark can resolve against.
4. **whole stack is Linux-host-bound** — every runtime primitive (takumi `/bin/sh -c` + fork/exec, the sandbox) is a Linux call, unproven on agnos.
5. **shallow version selection, no lockfile** — nous takes each recipe's single fixed version; no constraint solving on recipe deps; lockfile is unbuilt.
6. **mela registry is a stub in nous** — `registry.cyr` scans a local dir; `registry_install_package` returns `Ok(0)`. Resolver (nous) and downloader (ark→mela) use two different marketplace views.
7. **no on-agnos end-to-end validation** — tested only on Linux (ark 292 + nous 271 + takumi roundtrip).

## The apt leg: KEEP behind a seam, don't delete

The sovereign cutover is a **default-mode flip, not a removal** — verified:
- **It's already dead on agnos by construction.** `nous/src/sysdb.cyr:8` gates the entire system leg on `which_exists("apt-cache") && which_exists("dpkg-query")`; agnos has neither → `sd_apt==0`, nothing tags `SOURCE_SYSTEM`, the `apt-get` argv branches are unreachable. **Sovereignty on agnos requires zero code excision.**
- **Deleting it breaks dev/CI + Debian interop for no sovereignty gain** — ark/nous/takumi are built and tested *on Debian* where apt is the real system source.
- **ark's own [ADR 0002] (accepted; native deferred to v2)** designs apt as one of three selectable `system_backend` modes (`apt | apt-agnos | native`): "native demotes apt to optional… behind a capability flag." The cutover is flipping the default `STRAT`/`SOURCE` from `SYSTEM_FIRST` to native.
- **The one real gap**: there's **no seam yet** — apt argv is hard-coded in `step_to_argv`, the apt assumption is implicit in nous `sysdb`, and `ArkConfig` has no `system_backend` field. So: **add the seam, wrap apt behind it, make `SOURCE_NATIVE` the default on agnos, keep apt for Debian.**

> Open question: is the middle `apt-agnos` tier (apt fronted by an agnos syscall shim) ever built, or do we skip straight to `apt | native`? It only matters if AGNOS wants Debian-*package* interop before native — if not, `apt-agnos` is dead weight.

## Milestones

Stage legend: **host** = Linux-side ark/nous work (advances no agnos kernel stage) · **base** = rides base agnos surface · **server** = needs server-stage agnos surface. Gates corrected by the adversarial verify pass.

| # | Title | Stage | Key gates | Acceptance |
|---|---|---|---|---|
| **M0 ✅** | **`system_backend` seam** (de-apt refactor, no behavior change) | host | — (pure Linux refactor) | **DONE — ark 1.1.0.** `ArkConfig.system_backend` (apt/apt-agnos/native) + `apt_wrapper`, threaded through `exec.cyr step_to_argv`; apt mode byte-identical, full suite green, native selectable. |
| **M1 ✅** | **Wire resolved marketplace/community steps → native `.ark` installer** | host | M0 | **DONE — ark 1.1.0.** `exec_plan` routes marketplace/community steps to ark's installer (no more fail-loud); source-aware rollback; resolve-"latest" via mela's manifest. `test_native_apply`: a plan installs from local `.ark` via `--apply`, rollback-able, no apt. |
| **M2 ✅ (ark) / ⏳ (nous)** | **`SOURCE_NATIVE` resolver + signed native index + local artifact store** | host | M0, M1, **takumi produces a real `.ark` into the store** (producer gate) | **ark's share DONE — 1.1.0** (`BACKEND_NATIVE` installs from ark's local `.ark` store into the authoritative `PackageDb`, never shells `dpkg-query`; default flips native on agnos). **⏳ nous half PENDING** — no `SOURCE_NATIVE` resolver / signed index / lockfile in nous 1.2.7 yet; ark is the wired-and-ready *consumer*, the resolver lands when nous ships it (the filed nous bite). |
| **M3 ✅ code / ⏳ on-agnos runtime** | **On-agnos fetch+install of a *prebuilt* sovereign `.ark`** | **base** (install-half) | M1; agnos FS-write ✅, HTTPS-fetch ✅; **⚠ agnos symlink-create syscall — the 1.51.x(a) two-sided gap** | **ark code DONE — 1.1.0** (`src/portable.cyr` `#ifdef` shims replace the Linux raw syscall literals; the **agnos cross-build now compiles** — was failing on undefined `sys_symlink`; host byte-identical, 337 tests). **⏳ on-agnos RUNTIME validation DEFERRED** (compiling ≠ working): needs the agnos burn to *run* it, and a **symlink-bearing `.ark` is rejected on agnos until the 1.51.x symlink syscall lands**. This is the convergence point: 1.50.x burn-closes → 1.51.x(a) symlink (agnos + cyrius peer) → ark M3 on-agnos proof → agnova's install minimum. |
| **M4** | **AGNOS-side update mechanism** (system-image / native-package update) | server | M3; **boot-slot or in-place-swap primitive — ABSENT in gnoboot/agnos** (owed); crash-safe FS ✅ | Installing a new `.ark` of a base-system component and atomically switching to it across a reboot succeeds, with verified rollback. *(The maturity arc names this as base's "AGNOS-side update mechanism" — but it's owed work, not present surface.)* |
| **M5** | **Sovereign build-step executor on agnos** (replace takumi's Linux substrate) | server | M3; **nested-exec** (execwait#37 refuses recursive exec → must drive `spawn_path#43` + poll-`waitpid#4`); **argv/env caps** (127 B path+argv, 1024 B/16-entry env — too small for build invocations); **build confinement** (capability-bounded or explicit no-op-warn) | `takumi build --execute` runs a non-trivial recipe into a DESTDIR fake-root and emits a valid signed `.ark` — **no `/bin/sh`, no fork, no namespace/Landlock** — verified by ark installing that agnos-built `.ark`. **The longest pole.** |
| **M6** | **Self-host: build agnos on agnos** (server flagship / public-beta technical milestone) | server | M2, M4, M5; takumi build-execution surface; server-stage maturity | A booted agnos rebuilds a meaningful slice of its own base system from zugot recipes via takumi, indexes the `.ark`s natively, resolves with nous, installs with ark — entirely apt-free, QEMU + iron. |
| **M7** | **Server-side / accept()-gated package services** (native repo / resolver daemon) | server (off critical path) | M6; **cyrius server-socket peer — ✅ ALREADY RESOLVED** (cyrius 6.2.22; descent 1.1.3 accepts on agnos) | *Only if* a network-facing native repo or resolver daemon is in scope. The earlier "blocked on cyrius peer fail-loud" framing was **wrong** — the peer landed; this is not externally blocked. |

## Critical path & sequencing

```
M0 (seam) → M1 (wire installer) → M2 (native resolver+store) ── host-side de-apt spine
                                        │
                                        ├─ M3 (on-agnos install of prebuilt .ark) ── BASE surface; what agnova needs
                                        │        │
                                        │        └─ M4 (update mechanism) ── owed boot-slot primitive
                                        │
                                        └─ M5 (build executor) → M6 (self-host "build agnos on agnos") ── SERVER flagship
                                                                      │
                                                                      └─ M7 (accept-gated services, off-path)
```

- **M0 strictly gates M1/M2** — nothing native is selectable until the seam exists; it's ADR 0002's "cheap now, expensive to retrofit" refactor, so it goes first.
- **The base→server inflection is between M3/M4 and M5.** M0–M3 (+ the design of M4) are reachable on present agnos surface; **M5 (build executor) is the genuine server gate and the longest pole** — it replaces takumi's entire Linux process/sandbox substrate.
- **Parallelism**: M1 + early M2 scaffolding (defining `SOURCE_NATIVE` + index format) run concurrent with M0's nous threading; M3's host-syscall-literal triage runs parallel to M2; M4's boot-slot primitive can be *designed* in parallel.
- **agnova's minimum is M3** — install a prebuilt, signed `.ark` on agnos. The full sovereign loop (M6) is the server flagship.

## New agnos-surface asks surfaced by this path

**Filed as the agnos `1.51.x` arc** (2026-06-29, "Sovereign-package-manager kernel surface" — agnos roadmap slotted table), sequenced by which ark milestone each unblocks. The verify pass turned up these concrete kernel gaps (surface-don't-drive on the cyrius bits, per [[feedback_cyrius_hands_off]]):

1. **symlink-create syscall** — agnos syscall map is 0-61 with `#30 unlink / #31 rename / #32 link (hardlink) / #33 stat`; **no symlink**, and the cyrius agnos peer has `sys_link` but no `sys_symlink`. `ark_pkg_install` pass-2 (`ark_package.cyr:629-642`) calls `sys_symlink` unconditionally for every `ARK_FT_SYMLINK` (real `.ark`s carry `.so → .so.N` symlinks). **Blocks M3** unless scoped to symlink-free fixtures. *(base/server)*
2. **nested/recursive exec from a spawned proc** — `execwait#37` refuses re-entry (`syscall.cyr:1271-1277`, `pcpu_ew37_busy_get()!=0 → -1`, "out of scope until the multithreading arc"); `spawn_path#43` is the only child-exec path but returns immediately (no in-process step pipelining → poll-`waitpid#4` loop). takumi (a spawned ELF) must exec N build children. **Blocks M5.** *(server)*
3. **argv/env length caps** — `#37`/`#43` cap path+argv at 127 B and env at 1024 B / 16 entries; build invocations are long. **Blocks M5/M6.** *(server)*
4. **atomic system-update / boot-slot primitive** — absent in gnoboot (its "slots" are boot_info struct fields) and agnos (`reboot#13` is a stub that just `arch_halt()`s). **Blocks M4.** *(server)*
5. **build confinement** — takumi's sandbox needs fork×4 / `unshare(CLONE_NEWUSER|NEWNET)` / Landlock / `/proc/*/uid_map` / `setsid` — agnos has none. Resolve as an **agnos-native capability-bounded sandbox** (matches the capability-per-action posture) or an explicit no-op-with-warning at server bring-up. Ties to Phase 20's "Native sandbox-confinement primitives." *(server)*

## Open questions

1. **M4 update model**: A/B dual-slot image-swap (gnoboot selects on next boot — needs new gnoboot slot logic) vs ark-driven in-place re-materialize of base files from verified `.ark` with transactional rollback. Does it need a new agnos syscall (no kexec/image-swap today)?
2. **M5 build confinement on agnos**: real capability-bounded sandbox vs explicit no-op-warn? takumi's `--require-sandbox` is fail-closed today — what does fail-closed *mean* on agnos?
3. **Recipe portability**: zugot's `base/` recipes assume a Debian `/bin/sh` multi-step model + `*-linux-amd64` GitHub-release assets. For M6, port recipes to a structured step model the native executor runs, or stand up a sovereign step interpreter? The `marketplace/MacCracken/*` set (builds via `cyrius build`) is the natural first proving ground.
4. **mela unification**: nous's registry is a stub while ark talks to mela directly — does M2's native index subsume the mela path on agnos, or coexist?
5. **`apt-agnos` middle tier**: build it, or skip straight to `apt | native`?

## References

- ark: `src/{types,exec,engine,ark_package,recipe,marketplace}.cyr`, `docs/adr/0002-*` (the `system_backend` model), `docs/development/roadmap.md` (1.0.1 wiring items).
- nous: `src/{sysdb,resolver,strategy,registry,types}.cyr` (strategy default = `MARKETPLACE_FIRST`; `SYSTEM_FIRST` is injected by ark, not nous).
- takumi: `src/{build,sandbox,ark_format}.cyr` (the Linux `/bin/sh` + fork/exec substrate to replace).
- zugot: `base/` recipes + `build-order.txt` (225-pkg topo).
- agnos: `kernel/core/syscall.cyr` (the surface + the gaps above), `docs/development/state.md` (server-socket peer resolved; descent accepts).
- Memory: [[project_agnos_maturity_arc]] (sovereign ark ≈ server; don't call it base), [[feedback_cyrius_hands_off]] (cyrius peer is resolved — don't edit cyrius), [[feedback_qemu_test_agnos_userland]] (M3/M6 need real on-agnos runs, not just compiles).
