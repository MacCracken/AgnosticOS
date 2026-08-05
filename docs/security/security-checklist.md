# Security Testing Checklist

**Last Updated**: 2026-08-05

> **How to read this file.** Every `- [ ]` box below is checkable **on AGNOS today** with a command or
> file you can actually run or open. Nothing here is aspirational. Controls that do not exist are not
> silently missing — they live in two no-tickbox sections at the bottom:
> **⛔ Not Applicable by Design** (AGNOS has no such subsystem and, per
> [`docs/development/roadmap.md`](../development/roadmap.md), never will) and
> **📋 Not Available Yet** (intended, unbuilt).
>
> ⚠️ **A checklist is the most dangerous fossil form**: an operator ticks a box and believes they are
> covered. The 2026-03 revision of this file carried tickboxes for Landlock, seccomp, namespace
> isolation, cgroup limits, capability checks, a permission system, PAM-shaped password policy, mTLS
> and ML-KEM key exchange. **None of those exist on AGNOS.** Worse, several of them produce
> *evidence-shaped emptiness* — an operator who greps for a seccomp filter and finds nothing reads
> "hardened" where the truth is "no mechanism". Those items were not left unchecked; they were moved
> below and labelled, because telling you *why the box is gone* is the deliverable.
>
> Marker convention matches root [`SECURITY.md`](../../SECURITY.md): 📋 intended / not built,
> ⚠️ caveat that changes what a green result means, ⛔ hard stop.

**Verified against**: agnos 1.56.40 (cycle open, not burned) · cyrius 6.5.7 · gnoboot 0.6.1 ·
ark 1.4.1 · sigil 3.12.2 · libro 2.8.4 · aegis 1.1.4 · phylax 1.2.4 · kavach 3.11.7 · takumi 1.1.1 ·
zugot 1.0.7 · bote 3.3.0 · daimon 2.0.0 · hoosh 2.6.0 · mela 1.0.1 · shakti 0.7.0 (pre-1.0).

---

## The one-paragraph posture this checklist tests against

> **AGNOS today is a single-owner, single-trust-domain OS.** Every process runs as uid 0 —
> `agnos/kernel/core/syscall.cyr:7190` is literally `if (num == 15) { return 0; } # getuid (root)`.
> There is no uid model, no per-process capability model, and no kernel-backed confinement. Its
> security value is a radically small, sovereign attack surface that structurally lacks whole classes
> of Linux vulnerability — **not** the enforcement of boundaries between processes, users, or code of
> differing trust. Test it as what it is. A finding of "process A read process B's shared memory" is
> **documented behaviour**, not a vulnerability (`agnos/kernel/core/syscall.cyr:7773-7786`).

⚠️ **Repo paths.** This document lives in `agnosticos`. Paths prefixed `agnos/`, `ark/`, `sigil/`,
`kavach/` etc. are **sibling repos** under `/home/macro/Repos/`, not files in this one. Unprefixed
paths are relative to this repo.

---

## Pre-Engagement

⚠️ AGNOS is a single-maintainer pre-Beta project. There is no security team, no external tester roster,
and no NDA process. The 2026-03 revision's third-party-engagement framing (NDA signed, emergency
contacts, legal authorization) described an organization that does not exist. What survives:

- [ ] Scope defined: which repos, which target (AGNOS kernel vs Linux host bootstrap — they are
      **different systems** and the distinction is the single most common source of false results)
- [ ] Target versions recorded from each repo's `VERSION` file, not from documentation
- [ ] Reporting channel confirmed against root [`SECURITY.md`](../../SECURITY.md)
- [ ] Test target is disposable (QEMU image or a re-flashable disk), never the working machine

## Information Gathering

- [ ] Syscall surface enumerated from source, not from docs — dispatch arms in
      `agnos/kernel/core/syscall.cyr` plus `#44 sched_yield`, which dispatches from
      `kernel/arch/x86_64/syscall_hw.cyr` instead and is **not** a hole
- [ ] Band map read at `agnos/kernel/core/syscall.cyr:29-58` (⚠️ the comment block is a map, not a
      guarantee — count the `if (num == N)` arms)
- [ ] Listening-port set enumerated **by starting daemons and looking**, not from a rule table —
      AGNOS has no packet filter to consult (see *Network Security*)
- [ ] Kernel binary type confirmed: `readelf -h agnos/build/agnos` — expect `Type: EXEC`
      ⚠️ (see *Kernel Security* → address randomization)
- [ ] Architecture read: [`docs/architecture.md`](../architecture.md) and root `SECURITY.md`,
      which are authoritative over any other doc in this tree

---

## Kernel Security

⚠️ **Renamed from "Kernel Module Security".** There are **no loadable kernel modules** — the AGNOS
kernel is a single Cyrius binary. The `kernel/modules/*/*.c` tree in this repo is Rust-era Linux LKM
source and is not part of AGNOS.

### Memory safety

⚠️ **Cyrius provides none of it.** Everything is `load8`/`load64`/`store64` over raw i64 addresses —
no bounds checking, no pointer types, no ownership, and **no automatic stack protector**. Every bound
in the kernel is a hand-written `if`. This section is therefore the highest-yield part of the whole
checklist, and it must be exercised by hand.

- [ ] Every new syscall handler validates its user pointers with `is_user_range(ptr, len)`
      (`kernel/core/syscall.cyr:280`) — **47** call sites in `syscall.cyr` today (a bare
      `grep -c` returns 49; two of those are the definition at `:280` and a comment at `:297`),
      plus 12 more elsewhere in `kernel/`.
      ⚠️ `is_user_ptr` (`:274`) is the scalar survivor and has **no caller in `syscall.cyr`** — its
      one live use kernel-wide is the SHSYS selftest's own ceiling probe
      (`kernel/core/main.cyr:3619`). A new *handler* use of it is a regression toward the 1.41.5
      finding class, because it cannot check a length
- [ ] Path arguments go through `sc_path_ok(ptr, len)` (`kernel/core/syscall.cyr:299`)
- [ ] Environment blobs go through `sc_env_blob_ok` (`kernel/core/syscall.cyr:311`) — the 16-entry
      cap is load-bearing, not stylistic
- [ ] Integer-overflow / wrap handling: `is_user_range` wrap check present in any new range validator
- [ ] Use-after-free / double-free: PMM refuses a double free (`kernel/core/pmm.cyr:591-592`)
- [ ] ⚠️ Heap contract audited by hand: `kfree_sized`'s `size` must map to the **same slab class** as
      its `kmalloc` (`kernel/core/heap.cyr:119-125`). A smaller class under-scrubs and leaks the tail
      into a later allocation. **This is an unenforced contract, not a check** — there are no
      redzones, no guard pages, and no double-free detection in the heap
- [ ] Regression coverage actually runs:
      `cd agnos && sh scripts/smoke/syscall-harden-smoke.sh`
      ⛔ This selftest shipped in 1.41.5 and **nothing ran it for ~15 minor versions** — it had even
      stopped compiling. The runner landed 2026-08-05. It is the only coverage epoll / timerfd /
      signalfd have. A selftest nothing runs is a comment, not coverage
- [ ] Ingress clamp non-regression:
      `cd agnos && HARDENING_SELFTEST=1 sh scripts/build.sh && sh scripts/smoke/hardening-smoke.sh`
      (gates on `hardening: ip-clamp PASS`). ⚠️ **This smoke does not self-build** — run it against a
      plain production kernel and it exits at `hardening-smoke.sh:65` with
      *"kernel was not built with HARDENING_SELFTEST=1"*. (The syscall-harden, blk-write and
      blk-ring3 smokes DO self-build; fault-kill and ring3 do not — hence the explicit builds below)

### Ring-3 / ring-0 boundary

This is the strongest control AGNOS has, and it is genuine.

- [ ] Per-process address space: each proc gets its own PML4/PDPT/PD
      (`agnos/kernel/core/proc.cyr:563-671`). Two ring-3 processes cannot see each other's private
      memory through the MMU
- [ ] Kernel pages carry U/S=0: kernel identity PDEs are `0x83`
      (`kernel/arch/x86_64/paging.cyr:7`, `kernel/core/proc.cyr:610`); user pages are `0x87`
      (`kernel/core/proc.cyr:1007`)
- [ ] SMEP + SMAP enabled when CPUID advertises them — the CR4 block at
      `kernel/arch/x86_64/boot_shim.cyr:281-295`. ⚠️ Silently skipped on a CPU without the bits, and
      ⚠️ **SMAP is open for the whole duration of every syscall** (`stac` before / `clac` after the
      handler call, `kernel/arch/x86_64/syscall_hw.cyr:505-515`), not per-copy as Linux does it
- [ ] W^X on user memory — ⚠️ **verify which half is actually live.** `proc_map_page_nx`
      (`kernel/core/proc.cyr:1021-1046`) stamps bit 63, and the high mmap arena's
      `proc_map_page_hi` does the same (`proc.cyr:1444`). What is genuinely NX today:
      **the user stack** (`kernel/core/elf.cyr:156,358`) and **all `sys_mmap` anonymous memory**
      (both arenas). ⛔ **Segment W^X is NOT live.** The non-`PF_X` → NX arm exists
      (`elf.cyr:126,319`) but never fires for a real binary: the kernel's own note at
      `elf.cyr:314-317` says *"cyrius/cyrld currently emits ONE RWE PT_LOAD per binary
      (code+data+bss together), so this segment IS PF_X → executable (no change) … The STACK NX
      below is the live W^X win for now."* Every AGNOS binary's data and BSS therefore share an
      **executable** 2 MB page with its code. Do not tick this as segment W^X
- [ ] ⚠️ **EFER.NXE is inherited from UEFI firmware on the shipping boot path, not set by AGNOS.**
      The gnoboot shim never touches EFER (`kernel/arch/x86_64/boot_shim.cyr:150-303`); only the dead
      ELF32/multiboot1 path does (`:98-100`). On firmware that leaves NXE clear, **every W^X mapping
      becomes a reserved-bit #PF**, and no boot-time assertion checks for it. The comment at
      `proc.cyr:1025` claiming NXE is set at boot is wrong for the shipping path
- [ ] Ring 3 cannot issue port I/O: IOPL 0 (`kernel/arch/x86_64/ring3.cyr:181-184`) and the TSS
      IOPB offset equals the TSS limit, so there is **no I/O permission bitmap**
      (`kernel/arch/x86_64/gdt.cyr:82`)
- [ ] GPRs are zeroed before every ring-3 entry so no kernel register content leaks
      (`kernel/arch/x86_64/ring3.cyr:200-209`)
- [ ] SFMASK clears IF|TF|DF|AC on syscall entry (`kernel/arch/x86_64/syscall_hw.cyr:217-229`)
- [ ] Ring-3 fault kills the process, not the machine — the box survives:
      `cd agnos && FAULT_SELFTEST=1 EXT2_WRITE_SELFTEST=1 ./scripts/build.sh && sh scripts/smoke/fault-kill-smoke.sh`
      (gates on `run: exit 142` and `fault: SURVIVED back in kernel`).
      ⚠️ All 256 vectors get a stub (`idt.cyr:27`), but only {0 #DE, 6 #UD, 13 #GP, 14 #PF} are on
      the **kill** path (`idt.cyr:482-537`, gated on CPL3). **Every other vector — #DB, #BP, #NM,
      #DF, #MF, #AC, #XM — still paints the canary and halts the box even from ring 3**, and so does
      any CPL0 fault. Vector 0 proved that class cost a machine before 1.56.18
- [ ] Ring-3 scheduling / preemption holds: `cd agnos && RING3_SELFTEST=1 ./scripts/build.sh && sh scripts/smoke/ring3-smoke.sh`

### Irreversible-operation gates

⚠️ These are **anti-accident gates, not authorization**. The kernel says so itself
(`kernel/core/syscall.cyr:6802-6807`): the arm call is "the exact seam where an aegis/shakti
installer-capability check lands **when agnos grows per-proc caps**." Any ring-3 process can arm them
today by calling with a constant published in the source. Test that the gate holds, and understand
what holding means.

- [ ] Raw block write refuses until armed, and the armed round-trip is correct:
      `cd agnos && sh scripts/smoke/blk-write-smoke.sh`
      ⛔ **`run: exit 83` or `exit 84` means THE GATE IS BROKEN** — an unarmed raw write succeeded.
      Gate source: `kernel/core/syscall.cyr:6834-6845` (`blk_open_sys`)
- [ ] Raw block **read** is ungated by design — confirm you understand this before reporting it:
      `kernel/core/syscall.cyr:6790-6798`, Phase-1 "non-destructive". Non-destructive is not
      non-disclosing; any process can read the whole disk
      (`cd agnos && sh scripts/smoke/blk-ring3-smoke.sh`)
- [ ] Kernel-side modeset sits behind an arm-once on-disk latch — confirm `/.modeset-armed` is absent
      on a system that should not be modesetting (`agnos/kernel/core/modeset_latch.cyr:97`)
- [ ] `shm_free #74` is owner-gated; a non-owner gets −1 (`kernel/core/syscall.cyr:7787-7799`).
      ⚠️ `shm_write #72` / `shm_read #73` are **cross-owner permitted and only counted**
      (`syscall.cyr:7773-7786`). The compositor reads a client's buffer every frame, so this is
      current design, not a defect. ⛔ **The counter is not operator-readable**: `shm_xown_warns`
      (`syscall.cyr:860`) is a kernel global with no syscall, no boot print and no ring-3 path — its
      only reader is the in-kernel SHSYS selftest (`kernel/core/main.cyr:3700-3702`). Verify this
      behaviour by reading the source, not by querying a running system

### Address randomization

- [ ] ⛔ Confirm for yourself that **no address randomization is active in a shipped AGNOS**:
      `readelf -h agnos/build/agnos` reports `Type: EXEC`. gnoboot only slides an `ET_DYN` image
      (`gnoboot/src/main.cyr:429,441`); an ET_EXEC kernel takes the fixed-load arm at `:463-467`
- [ ] ⚠️ The PIE mechanism exists and is testable, but is **opt-in and built by nothing** —
      `CYRIUS_PIE` appears in no CI job, no `scripts/build.sh` default, and no ISO pipeline. To
      exercise it: `cd agnos && CYRIUS_PIE=1 ./scripts/build.sh && sh scripts/smoke/kaslr-smoke.sh`
      (the smoke hard-errors on a non-PIE build — `scripts/smoke/kaslr-smoke.sh:29`)
- [ ] ⛔ The **allocator** half of KASLR is dead code. `pmm_next_free` is RDRAND-seeded
      (`kernel/core/pmm.cyr:533-535`) but **no allocation decision consumes it.** ⚠️ A grep returns
      five hits, not one — expect them: `pmm.cyr:596` and `:713` only *maintain* the hint on free
      (`if (page < pmm_next_free) …`), and the sole consumer of the value is the boot diagnostic
      print at `kernel/core/main.cyr:380-381`. `pmm_alloc` never reads it. The bottom-up first-fit that
      consumed it was removed at 1.41.12 (`pmm.cyr:541-553`). **The boot log still prints a
      `KASLR:` line for a mechanism that does nothing.** Do not read that line as a control

### The S1–S13 set — do not restate the summary

⚠️ `agnos/docs/development/security-hardening.md:234-255` marks S1–S13 "13 of 13 Done", **closed at
v1.28.0** — 28 minor versions before the 1.56.40 this file was verified against. (That header line is
the only version stamp the section carries; do not attribute it to any other release.) Several
entries have since been silently invalidated by later code. Re-derive before citing:

- [ ] S7 KASLR — ⛔ **inert, both halves** (above). Do not restate "KASLR data-only"
- [ ] S8 KPTI — ⛔ **collapsed, and it is not a Meltdown mitigation.** `kernel/core/proc.cyr:652-660`
      and `kernel/arch/x86_64/syscall_hw.cyr:89-90` both say so: kernel == user == running CR3, the
      CR3 switches are same-value no-ops. Architectural protection (U/S=0) holds; speculative
      side-channel protection does not exist
- [ ] S9 IBRS — ✅ real but **CPUID-gated**: leaf 7 subleaf 0 EDX bit 26
      (`kernel/arch/x86_64/syscall_hw.cyr:249-260`). If the CPU does not advertise it, the MSR writes
      are **not emitted at all** and there is no warning. No retpoline anywhere
- [ ] S10 VT-d IOMMU — ⛔ **not active on the primary iron target.** `iommu_init()` runs only when an
      Intel DMAR table is present (`kernel/core/main.cyr:544-551`), and on AMD the kernel
      **deliberately disables AMD-Vi every boot** — `amd_iommu_disable()` at `kernel/core/main.cyr:478`
      writes the AMD-Vi Control Register to 0, "passthrough for everyone". archaemenid is AMD Renoir.
      On the iron AGNOS actually runs on, **DMA is entirely unrestricted**
- [ ] S13 stack canaries — ⚠️ **four hand-placed guards, not `-fstack-protector`.**
      `var canary = stack_canary_secret` appears in exactly four functions:
      `kernel/core/elf.cyr:20`, `kernel/core/elf.cyr:209`, `kernel/core/syscall.cyr:6938`,
      `kernel/core/net_tcp.cyr:710`. The secret is a **global**
      (`kernel/core/syscall.cyr:4`), not `gs:0x28`, so any kernel-memory disclosure reads it
- [ ] S1 / S2 / S6 — re-verified real: U/S separation (`paging.cyr:7`), per-CPU TSS + RSP0
      (`gdt.cyr:72-116`), **user** stack guard pages (`elf.cyr:158,362`).
      ⚠️ S6 does **not** cover kernel stacks — per-proc RSP0 stacks are 64 KB slots packed
      contiguously with no unmapped page between them (`kernel/core/proc.cyr:283`). A kernel-stack
      overflow walks into the neighbour's stack with no fault and no canary

---

## Boot Chain

⛔ **gnoboot performs no cryptographic verification of anything.** The entire kernel-integrity check
is the ELF magic, twice.

- [ ] Read the whole verification path yourself — it is ~90 lines:
      `gnoboot/src/main.cyr:405-494`. Magic at `:409`, `PT_LOAD` at `:419`, magic re-checked at the
      load address at `:479-482`. There is no hash and no signature
- [ ] Confirm sigil is not in the boot path: `gnoboot/cyrius.cyml` `[deps]` is
      `stdlib = ["fnptr"]` — one stdlib helper, nothing else. Whatever signing capability sigil has,
      **no boot-path code calls it**
- [ ] ⚠️ Confirm the toolchain pin lag: `gnoboot/cyrius.cyml` pins `cyrius = "6.2.44"` against a
      toolchain at 6.5.7 — on the one component with no exception handling and nothing between it
      and the firmware
- [ ] Understand the exposure: anyone who can write `\boot\agnos` on the ESP owns the machine, and
      the ESP is a FAT partition
- [ ] Exec-time validation read and understood — `agnos/kernel/core/elf.cyr:19-176`: ELF magic,
      class=2, `e_entry >= 0x400000`, phdr-table bounds, and a pre-pass over every PT_LOAD **before**
      any allocation (`:56-72`, the 1.41.6 fix). ⛔ **No hash, no signature, no sigil reference
      anywhere in the loader.** Verification happens at **install**, in ark — never at exec

---

## Supply Chain & Package Integrity

⛔ **There is no vulnerability-tracking mechanism for AGNOS first-party dependencies. None,
anywhere** — no advisory DB, no CVE feed, no OSV/NVD client, no scanner, no known-bad-version list, in
cyrius/cbt, ark, nous, takumi, zugot or mela. ⚠️ `cyrius audit` is a **quality** sweep
(fmt / lint / docs / tests / bench, per `cyrius --help`), **not** a vulnerability audit. Do not let the
name mislead you. What genuinely exists is integrity and pinning, and it is worth checking:

- [ ] Declared dep tags actually exist upstream:
      `python3 scripts/check-dep-tags.py <repo-dir>` (in this repo). Exit 0 = every declared tag
      exists; network failures are reported as unknown, never as OK
- [ ] ⚠️ `path = "../X"` overrides audited. **A path override disables the tag as a test** — the
      commit-pin check is intentionally bypassed (`cyrius/cbt/deps.cyr:1277-1282`). ark, phylax,
      aegis, bote, mela, kavach, libro and t-ron override **every** dep this way, so a dev box with
      sibling checkouts compiles a different program than CI does. CI is the first honest build of
      the declared graph
- [ ] Commit pins hold: `cyrius deps` refuses on HEAD ≠ locked commit (force-pushed/repointed tag) or
      a dirty cache worktree (`cyrius/cbt/deps.cyr:1396-1441`)
- [ ] ⚠️ `cyrius deps --verify` run **against a committed lockfile you did not just regenerate**.
      As ordered in every ecosystem CI (`cyrius deps` then `cyrius deps --verify`) the file-hash half
      is tautological — verify compares the lock against the files it was just written from
      (`cyrius/cbt/deps.cyr:118-120`). The commit-pin half is unaffected
- [ ] `cyrius vet <src>` and `cyrius deny <src>` run — include-path policy and traversal/absolute-path
      denial. ⚠️ This is the *entire* audit-tooling surface; `cyrius/programs/cyaudit.cyr` has no
      version awareness and no advisory feed
- [ ] zugot recipe sources are hash-pinned: 548 of 564 `.cyml` recipes carry a `sha256`; the 16
      without are all `local = true` with no upstream source. The parser **fails closed** — a remote
      source with no hash returns 0 (`takumi/src/parse.cyr:203-217`)
- [ ] takumi verifies **before** extracting: `fetch_source` → `verify_source_hash` → `extract_archive`
      (`takumi/src/cli.cyr:274-289`), and `verify_source_hash` returns fail on any expected hash that
      is not exactly 64 hex chars (`takumi/src/source.cyr:200-219`)
- [ ] zugot's dated CVE audit cadence is being kept — one immutable report per pass at
      `zugot/docs/audit/YYYY-MM-DD.md` (`zugot/docs/adr/0005-audit-cadence.md`). ⚠️ This covers
      **zugot's upstream pins only**. First-party Cyrius code has no advisory process
- [ ] Toolchain releases are signed end-to-end — `cyrius/programs/cyrsign.cyr` (detached Ed25519 over
      `SHA256SUMS`), and `cyrius/.github/workflows/release.yml` refuses to publish unsigned.
      ⚠️ **No other repo in the ecosystem signs its releases**, and a first install is explicit TOFU

### Package install verification (ark)

Every check below is in `ark_pkg_read` (`ark/src/ark_package.cyr:231-388`), called from
`ark_pkg_install_inner` (`:602`) **before any file is written**.

- [ ] `ark verify [package]` runs clean (real subcommand — `ark/src/cli.cyr:144`)
- [ ] SHA-256 root hash over the verified prefix (`ark/src/ark_package.cyr:252-259`)
- [ ] Per-file SHA-256 against the index (`:349-375`).
      ⚠️ Skipped for an entry whose hash field is absent
- [ ] Zip-slip guard rejects the **whole package** before writing a single file
      (`ark/src/ark_package.cyr:628-637`)
- [ ] Symlink entries fail closed on a target without symlink support, i.e. agnos (`:638-644`)
- [ ] ⛔ **`require_signed` defaults to 0** — `ark/src/types.cyr:342` (`store64(p + 96, 0)`). Unsigned
      `.ark` files install; signed-by-anyone `.ark` files install. The Ed25519 check at
      `ark_package.cyr:266-272` only runs when the package's own `ARK_FLAG_SIGNED` bit is set, and the
      trust gate at `:610-617` only runs when policy demands it. **Confirm which mode your system is
      in before recording a green here**
- [ ] Trust anchor populated: `/etc/agnos/ark/trusted_keys`
      (`ark/src/types.cyr:24`) — a newline-delimited hex Ed25519 pubkey file.
      ⚠️ A signature without a trust anchor proves nothing about publisher identity
      (`ark/docs/audit/2026-06-18-pre-v1-audit.md:76-91`)
- [ ] ⚠️ `require_signed` / `trust_keys` are **not settable from a config file** — no such key is
      parsed by `load_config_from` (`ark/src/cli.cyr`). The policy is code-only today

---

## Network Security

📋 **AGNOS has no firewall.** No netfilter, no nftables, no packet-filter hook anywhere in the kernel.
Inbound reachability is decided entirely by *what you run*. "Unnecessary services disabled" is not a
check you can perform against a rule table — it is a check you perform against a process list.

- [ ] Listening set enumerated against the daemons you actually started. ⛔ **Do not write "nothing
      else listens"** — that was a false claim already caught once, and no count belongs here either.
      Derive it: `command grep -rln 'INADDR_ANY' /home/macro/Repos/*/src/` returns 16 files across 16
      repos today. ⚠️ **A hit is not proof of a default bind** — hoosh and kavach appear only because
      their source says they do *not* use it, and `sandhi` / `sit` are server *libraries*. Confirm
      each candidate's actual bind call before listing it
- [ ] daimon: ⛔ binds **`0.0.0.0:8090` with no authentication whatsoever**
      (`daimon/src/server.cyr:183,222` both pass `INADDR_ANY()`; port 8090 at
      `daimon/src/config.cyr:11`). A `"127.0.0.1"` listen_addr default is stored at
      `daimon/src/config.cyr:10` and its accessor `config_listen_addr` (`:17`) is **never called
      anywhere in `daimon/src/`** — the default is dead code. No `Authorization` / `Bearer` / token handling exists in
      `daimon/src/` at all. If daimon is running, treat the box as fully exposed on that port
- [ ] hoosh 8088: binds `127.0.0.1` by default (`hoosh/src/main.cyr:77,83` — `_http_bind =
      0x0100007F`, and the source records that this was once hardcoded to `INADDR_ANY`) but ⛔ **auth
      fails open** — `hoosh/src/lib/auth.cyr:6` returns 1 when the token vector is empty, and the
      startup default is an empty vector (`hoosh/src/main.cyr:1024`). ⚠️ The off-loopback warning at
      `hoosh/src/main.cyr:377-378` fires **only** when bound off 127.0.0.1, so a loopback deployment
      is silently unauthenticated. Confirm tokens are configured or accept that it is open
- [ ] bote: ⚠️ `bote` with no args is **stdio, not a listener** (`bote/src/main.cyr:168`). A port opens
      only on an explicit subcommand — 8390 http (`main.cyr:146`), 8391 bridge (`:158`), 8392
      streamable (`main_streamable.cyr:62`, separate binary), 8393 ws (`main_ws.cyr:50`, separate
      binary). All four bind `INADDR_LOOPBACK()`. ⚠️ `bote unix` is an AF_UNIX transport — a Linux
      path only
- [ ] bote auth is opt-in via one env var: `BOTE_BEARER_TOKENS=tok-a,tok-b`
      (`bote/src/main_common.cyr:97-105`). ⛔ **Unset ⇒ no validator is installed ⇒ every request
      passes.** When set, the comparison is constant-time (`bote/src/auth.cyr:97-117`)
- [ ] ⚠️ `bote bridge` sets `allowed_origins = ["*"]` — a CORS wildcard (`bote/src/main.cyr:159-161`)
- [ ] agora 2323: binds `INADDR_ANY` (`agora/src/main.cyr:36`), sigil Ed25519 challenge/response,
      anon-read / auth-post by default. ⚠️ This is a **telnet** service and it is part of the system
- [ ] kavach credential proxy: ⛔ **serves secrets over plain HTTP with no authentication** —
      `GET /v1/secret/<name>` returns the raw secret; the only gates are a per-instance name allowlist
      and a loopback bind (`kavach/src/credential_http.cyr:8-31,82`). On AGNOS, where every process is
      uid 0 with no confinement, **"loopback-only" is not an isolation boundary** — every process on
      the box is a peer
- [ ] Kernel network band understood: 13 fixed-shape numbers (#45–#57) over one kernel TCP/UDP stack,
      8-slot conn table. ⛔ **Never write "AGNOS has no sockets"** —
      `sock_connect#47 / sock_send#48 / sock_recv#49 / sock_close#50 / sock_listen#56 / sock_accept#57`
      exist and work. The true and durable claim is: **no generic BSD socket family, no `socket()`
      over arbitrary domains, no `splice`, no `AF_ALG`** — which is the CVE-2026-31431 structural
      immunity argument, and it survives intact
- [ ] ⛔ Conn ownership: **there is none.** `sock_send#48` / `sock_recv#49` / `sock_close#50` and
      `udp_recv#53` / `udp_unbind#54` bounds-check the id and nothing else
      (`agnos/kernel/core/syscall.cyr:8681-8737,8779-8815`). Any process can send on, drain, or tear
      down any connection. Do not report this as a finding; it is documented behaviour
- [ ] TLS is a **ring-3** concern (Cyrius stdlib `tls_native` over sigil), not a kernel one. There is
      no TLS in the AGNOS network path

---

## Agent Runtime Security

⛔ **Nothing in the agent path is confined.** kavach's Landlock / seccomp / namespace / cgroup backends
are **Linux-target only**; on AGNOS every one is `#ifdef CYRIUS_TARGET_AGNOS`-gated to fail closed —
`_spawn_enter_rootfs` returns −1 (`kavach/src/confine.cyr:116-118`), `confine_child` **exits**
(`:208-216`), `spawn_namespaces_available` returns 0 (`:304-308`), `spawn_seccomp_available` returns 0
(`:346-350`), `confine_capture` returns −1 (`:397-402`). kavach's own comment names the failure mode it
is avoiding: *"a sandbox that is silently not a sandbox, which is the worst failure mode this file
has."* What you can check is that it keeps failing **loudly**:

- [ ] kavach reports honestly on AGNOS: every confinement primitive returns a structured
      `err_not_supported` or a negative, **never `Ok(0)`**. A silent success here is a critical
      regression — re-read the five sites above after any kavach bump
- [ ] ⚠️ `backend_sy_agnos` is **inverted from its name** and must not be cited as agnos sandboxing —
      it shells out to `docker` / `podman` to run the agnos image as a container **on a Linux host**
      (`kavach/src/backend_sy_agnos.cyr:1-16`). The Linux host's seccomp/cgroups do the confining.
      agnos has no docker
- [ ] Process isolation that **is** real: per-process CR3 (`agnos/kernel/core/proc.cyr:563-671`) and
      per-process fd tables (`agnos/kernel/core/vfs.cyr:149-179`). ⚠️ **The fd-table split degrades
      to a SHARED table, silently.** `proc_fd_base[pid] == 0` falls back to the global `vfs_table`
      (`vfs.cyr:156`), and the source names three triggers (`vfs.cyr:146-147`): pre-init, kthreads,
      **and a kmalloc-failed inherit** — `vfs_fd_inherit` returns early at `:178` leaving the child
      on the global table with no error to the caller. Under memory pressure this is an isolation
      loss with no signal
- [ ] Signal/reap authorization holds: `proc_may_signal` permits init, self, or a direct child only
      (`agnos/kernel/core/proc.cyr:927-938`); `proc_may_reap` gates `waitpid`
- [ ] Audio slot and file-lock ownership hold: the slot is stamped with the opener's pid
      (`agnos/kernel/core/syscall.cyr:8992`) and re-checked on every subsequent audio call
      (`:9002, :9014, :9058, :9076, :9094`); `flock #59` holder check (`:8920-8926`)
- [ ] ⛔ Resource exhaustion accepted as known-open: `sys_mmap` has **no per-process page budget**
      (`agnos/kernel/core/proc.cyr:1655,1661`). One process can `mmap` all machine RAM. Tracked as
      the fairest-called genuine confinement gap in
      `agnos/docs/development/security-hardening.md:267-269`

## LLM Gateway Security

- [ ] hoosh bind address and auth-token state confirmed (see *Network Security*)
- [ ] ⚠️ Model backend understood: hoosh's default router points at `http://localhost:11434`
      (Ollama) — `hoosh/src/main.cyr:1031`. Plain HTTP to a local process
- [ ] Weight-file provenance: `tula` is the one place a model artifact can be integrity-anchored — a
      typed manifest plus an Ed25519 sigil-signed header. ⚠️ **Nothing in the agent path is required
      to use it**, and `anukūlana` imports foreign GPT-2 safetensors with no signature requirement
- [ ] ⚠️ Prompt-injection detection: t-ron ships a six-check detector over a Unicode-normalized string
      (`t-ron/src/safety.cyr:470-491`, zero-width stripping at `:339-370`). ⛔ **It is not wired into
      anything.** `bote/cyrius.cyml` has no `[deps.tron]`, daimon has no `[deps.tron]`, and no
      `tron_*` symbol appears in either `src/` tree. The dependency runs the other way — t-ron
      declares `[deps.bote]`

## MCP Server Security

- [ ] Bearer auth state confirmed per transport (see *Network Security*) — this is the **only** gate
      bote has
- [ ] ⛔ Tool-invocation authorization: **there is none.** t-ron's gate is real code with no caller —
      its deny-code enum (`t-ron/src/gate.cyr:14-21`) names what it *would* refuse:
      `DENY_UNAUTHORIZED` / `DENY_RATE_LIMITED` / `DENY_INJECTION_DETECTED` / `DENY_TOOL_DISABLED` /
      `DENY_ANOMALY_DETECTED` / `DENY_PARAMETER_TOO_LARGE`. Verify by grepping `bote/src/` and
      `daimon/src/` for `tron_` and both manifests for `[deps.tron]`; the correct result today is
      **zero hits in all four**
- [ ] ⚠️ `bote/src/sandbox.cyr` ships an abstract `SandboxRunner` seam and a **noop adapter**. Its
      header names kavach as the canonical choice; bote wires nothing
- [ ] daimon's five libro MCP tools reachable and honest —
      `libro_query` / `libro_verify` / `libro_export` / `libro_proof` / `libro_retention`
      (`daimon/src/mcp_builtin.cyr:25-62`, dispatched at `:56-62`)

## Desktop Environment Security

⛔ **aethersafha is NOT Wayland.** That path is dead; the compositor speaks the sovereign **setu**
protocol with bhumi/mehman backends. ⚠️ `grep -ri wayland aethersafha/src/` does return hits — expect
them and do not read any of them as a Wayland server: `MOZ_ENABLE_WAYLAND` / `GDK_BACKEND` /
`QT_QPA_PLATFORM` env vars set for **guest Linux browsers** on the swallow path
(`apps.cyr:620,624,628,632,712-713`), a `PLG_CAP_WAYLAND_SURFACE` plugin-capability bit
(`plugin_host.cyr:69`), and two historical XWayland-parity comments (`main.cyr:7`,
`foreign.cyr:2`). **No Wayland protocol is implemented or served**, so budgeting time for Wayland
protocol fuzzing tests nothing.
⚠️ aethersafha is **0.12.1 — pre-1.0** and moving fast; scope it as a moving target.

- [ ] setu protocol message handling reviewed (`setu/src/`) — the actual client/compositor seam
- [ ] Input handling and buffer bounds reviewed by hand (see *Memory safety* — the language gives you
      nothing)
- [ ] ⚠️ Window/surface isolation understood as **shm-mediated and cross-owner-permitted**: the
      compositor reads a client's pixel buffer every frame via `shm_read #73`, which is why #72/#73
      are warn-only (`agnos/kernel/core/syscall.cyr:7773-7786`)

---

## Cryptography (sigil)

- [ ] Signing algorithms confirmed from source, not from claims: Ed25519, and **ML-DSA-65 only** for
      post-quantum signing (`sigil/src/mldsa_params.cyr:10` — *"Only ML-DSA-65 (NIST security
      category 3) is parameterised here"*), default-on since 3.7.6 (`sigil/src/lib.cyr:146-168`)
- [ ] ⚠️ "Default-on" means **compiled in, not in use.** ML-DSA appears in exactly two consumers —
      `libro/src/signing.cyr` (which offers Ed25519 / ML-DSA-65 / hybrid) and `t-ron/src/main.cyr`.
      **ark, takumi, nous, mela, bote, daimon, kavach and the agnos kernel contain no ML-DSA
      reference at all. Every signature in the supply chain today is Ed25519**
- [ ] ⛔ **There is no post-quantum key exchange.** A repo-wide grep for `ml_kem` / `mlkem` / `kyber`
      over `sigil/src/` returns **zero**, as does `sphincs` / `slh_dsa`. `sigil/src/x25519.cyr` is
      X25519 alone — no hybrid. Do not test for, or claim, harvest-now-decrypt-later protection
- [ ] Key rotation surface verified against `sigil/src/` before recording anything about it

## Audit Chain (libro)

- [ ] Chain integrity verifies: `chain_verify` (`libro/src/chain.cyr:253`), reachable to an operator
      through daimon's `libro_verify` MCP tool. ⚠️ `libro/src/main.cyr` is a **test harness**, not a
      CLI — there is no `libro verify` command
- [ ] Writers confirmed: daimon — `daimon_audit_event` (`daimon/src/audit.cyr:41`) and
      `daimon_audit_agent` (`:46-48`, `chain_append_with_agent`) are the lifecycle writers;
      `:31` is only the genesis "MCP host initialized" entry, so do not cite it as agent coverage.
      argonaut — `argonaut/src/audit.cyr` + `audit_ext.cyr`, with a chain-integrity verify on
      **replay** (`audit_ext.cyr:113`, rationale at `:109-112`) that refuses a tampered store.
      ⚠️ **ark declares no `[deps.libro]`** despite libro's README naming it a consumer — package
      installs are not on the chain
- [ ] ⚠️ Tamper model stated precisely: the chain makes tampering **detectable, not preventable**.
      `libro/src/file_store.cyr` is append-only JSONL guarded by `flock`; on AGNOS every process is
      uid 0 with no MAC, so any process can truncate or rewrite it. Detection requires an
      out-of-band copy of the head hash
- [ ] ⚠️ Out-of-band anchoring is **opt-in and unwired by default** — `libro/src/anchoring.cyr`,
      `timestamping.cyr`, `tpm_anchor.cyr` (the last behind `-D LIBRO_TPM`). Per-entry Ed25519
      signing is likewise opt-in
- [ ] ⛔ **Transparency log: does not exist under any name.** A grep for `transparency` over
      `sigil/src/` and `libro/src/` returns zero. Earlier revisions of this checklist asked you to
      verify its entries

## Scanning & Quarantine (aegis, phylax)

- [ ] ⛔ **aegis is not a daemon.** `aegis/src/main.cyr` is 28 lines: set log level, print
      `"aegis ready"`, return. No loop, no socket, no hook. Do not record "aegis daemon running and
      enforcing policies"
- [ ] ⛔ **aegis has zero consumers.** No repo declares `[deps.aegis]` — including daimon and
      argonaut, which its README names. Confirm before assuming anything calls it
- [ ] ⚠️ aegis "scanning" is **metadata-only**: file exists? size 0? world-writable mode bit?
      size > 500 MB? That is the complete list (`aegis/src/lib.cyr:966-1024` agent — exists /
      size 0 / world-writable; `:1035-1085` package — exists / size 0 / >500 MB). No content
      inspection, no signature check, no pattern matching. ⚠️ **Do not assume the world-writable
      test even reads the right field on AGNOS**: `_aegis_stat_modesize` (`:939-951`) calls
      `sys_fstat` at Linux `struct stat` offsets, while agnos's `stat#33` is a sovereign 48-byte
      layout with mode at offset 0 (`agnos/kernel/core/ext2.cyr:236` — agnos *does* populate the
      real ext2 `i_mode`, it just is not at Linux's offset). aegis has no proven agnos build
- [ ] ⚠️ aegis "auto-quarantine" pushes an entry onto an **in-memory** map when an event is
      CRITICAL/HIGH and config allows (`aegis/src/lib.cyr:445-483`; the map is lazy-initialized at
      `:463` and read back via `aegis_quarantine(d)` at `:407`). It does not kill, isolate or
      terminate anything, and it does not survive a restart
- [ ] ⚠️ `aegis/src/firewall.cyr` **renders** an nftables ruleset and states in its own header that
      the consumer is responsible for applying it. **Nothing applies it**, and AGNOS has no nftables
- [ ] phylax one-shot scan runs: `phylax scan <path>` (`phylax/src/cli.cyr:1210`) — real YARA engine,
      entropy + chi-squared, PE/ELF parsing, string extraction, SARIF output
- [ ] `phylax rules list` lists loaded rules (`phylax/src/cli.cyr:1283`). ⚠️ The bare verb is **not**
      a command — `phylax rules` with no sub-verb prints
      `Usage: phylax rules <list|validate|fetch>` and exits 1 (`cli.cyr:1284-1287`). Built-ins load
      via `yara_engine_load_builtin_rules` (`phylax/src/yara.cyr:1667`) — **count them yourself**, do
      not restate a number from a doc
- [ ] ⛔ `phylax watch` is unavailable on AGNOS and fails closed with a clear message (no inotify) —
      `phylax/src/cli.cyr:427-433`. `phylax daemon` listens on **AF_UNIX**
      (`phylax/src/cli.cyr:956-977`), which AGNOS does not have, so it cannot run there at all
- [ ] ⚠️ phylax has **zero consumers** — no `[deps.phylax]` in any manifest. It is a standalone CLI

## Marketplace (Mela) Security

- [ ] Package signature verification on install — real, and it is ark's
      (`ark/src/ark_package.cyr:602-617`). ⚠️ The marketplace path is the one place that **forces**
      `require_signed` on (`ark/src/marketplace.cyr:58`); the default path does not
- [ ] ⛔ **Sandbox profiles are generated and then applied by nothing.**
      `mela/src/flutter_agpkg.cyr:233-254` builds a `SandboxProfile` with `landlock_paths` /
      `seccomp_mode` / `network` and emits `sandbox.json`. On AGNOS there is no mechanism that can
      consume it. This is the subtlest trap in the file: an auditor finds real code producing a real
      sandbox descriptor and ticks the box. **The descriptor is inert**
- [ ] Publisher keyring anchoring understood — `ark_trust_from_keyring`
      (`ark/src/ark_package.cyr:433`)

## Data Protection

- [ ] ⚠️ Encryption at rest is **installer-side only**: agnova offers a LUKS root option, but the
      AGNOS kernel **cannot read an encrypted volume**, so it applies to host-staged installs. TPM
      sealing is unbuilt — agnova has no `--tpm` flag
- [ ] Encryption in transit: ring-3 only, via the Cyrius stdlib's `tls_native` over sigil. ⚠️ Not one
      of the ecosystem's listening services listed above serves TLS
- [ ] Audit-log content reviewed for secrets before export (`libro_export`) — the chain is not
      redacted
- [ ] ⚠️ PII / user attribution: audit records **cannot carry a meaningful user identity.** There is
      no uid model; any `"user"` field is supplied by the writer, not established by the system

## Incident Response

⚠️ Root [`SECURITY.md`](../../SECURITY.md) states it flatly: **there is no incident-response tooling
yet.** No dashboard, no alerting, no intrusion-detection service, no forensic-capture command. phylax
provides detection *rules*; libro provides forensic *records*. Neither is an operational IR
capability, and an incident is the worst moment to discover that. What a responder can actually do:

- [ ] Stop the agent through daimon (which owns agent lifecycle). 📋 There is no isolate verb —
      containment today is "stop the process", not "restrict it in place"
- [ ] Copy the libro chain files **before anything else**; the chain is hash-linked and signed, so a
      tampered record is detectable — but only against a head hash you already hold
- [ ] Power the machine down cleanly (ACPI S5) or arm nothing further. 📋 There is no lockdown switch
- [ ] ⚠️ Note for the report: **any process can power off or reboot the box** from any pid with a
      published magic pair (`agnos/kernel/core/power.cyr:343-351`). `power_sys` says why in source:
      *"`getuid` is hardcoded 0 and there is no uid model, so a uid check would be a gate that is
      always open"* (`power.cyr:338-342`)

## Post-Testing

- [ ] All findings documented with a **live path + line** for each claim
- [ ] Each finding classified against the posture paragraph at the top — documented-behaviour items
      (cross-owner shm, unowned conns, ungated `blk_read`, unbudgeted `mmap`) are **not**
      vulnerabilities on AGNOS today and must not be filed as such
- [ ] Reproduction steps provided as a runnable smoke or a syscall sequence
- [ ] Risk ratings assigned per the CVSS bands below
- [ ] ⚠️ Any doc updated as a result carries the source path it was verified against. A security doc
      describing a control that does not exist is **worse than no document**

---

## ⛔ Not Applicable by Design

These are not unchecked items. AGNOS has no such subsystem, and per
[`docs/development/roadmap.md`](../development/roadmap.md) confinement "when it lands, is
**capability-scoped and native** — never Landlock, seccomp or `unshare` ABI emulation." Testing for
them produces **evidence-shaped emptiness**: an empty result reads as "hardened" when it means "no
mechanism exists." Each line says what replaced it, or that nothing did.

| Removed item | Why it is not applicable | What is there instead |
|---|---|---|
| Landlock enforcement · seccomp filters · syscall allowlist · namespace isolation · cgroup limits | Linux LSM/namespace primitives. kavach implements them for **Linux targets** and fails closed on AGNOS (`kavach/src/confine.cyr:116,208,304,346,397`) | Nothing yet — see *📋 Not Available Yet* |
| uid/gid separation · "root is the only UID 0 account" · SUID audit · `getcap` · `id` / `whoami` | ⛔ **Inverted, not absent.** `getuid` returns 0 for every process (`agnos/kernel/core/syscall.cyr:7190`). `find / -perm -4000` finding nothing means "no uid model", not "no SUID risk" | Single-owner posture; sigil keys are identity where identity is needed |
| PAM · password policy · password storage · password reset · brute-force lockout · session tokens/timeout/fixation | No accounts, no login, no sessions. `aegis/src/pam.cyr` and shakti's PAM path are **Linux-host-only** | agora has real per-user sigil Ed25519 challenge/response (`agora/src/main.cyr`) — scope any auth test **to agora by name** |
| Horizontal / vertical privilege escalation · permission escalation · permission revocation | There are no privilege levels to move between and no permission system to revoke from. ⚠️ shakti is pre-1.0 (0.7.0), authenticates against a userland policy file, and **has no kernel seam behind it** | The syscall-boundary arm gates (block-write, modeset latch) — anti-accident, not authorization |
| chroot · mount options · `/etc/fstab` · sysctl hardening · `/proc/self/{ns,cgroup,status}` | None of these exist. `mount#11` and `umount#24` are no-op stubs (`agnos/kernel/core/syscall.cyr:7193,7191`) | — |
| systemd · auditd · rsyslog · `systemctl` | PID 1 is **kybernet** (with argonaut as its library) | sakshi for logging; libro for the audit chain |
| `cargo audit` · `cargo-deny` · `cargo outdated` · `Cargo.toml` pinning · RustSec advisory DB · crates.io ecosystem rules | ⛔ **The toolchain is not Rust.** No cargo, no crates.io, no `Cargo.toml` anywhere in the repo. The monolith was dismantled 2026-04-01 | The real chain: `cyrius.cyml` + `cyrius deps` → zugot recipes → nous → takumi → ark. See *Supply Chain & Package Integrity* |
| Loadable kernel module security | The AGNOS kernel is a **single Cyrius binary** — no module loader, no eBPF | *Kernel Security* above |
| mTLS · client certs · local CA · cert rotation | No mTLS implementation exists in sigil, daimon, hoosh or bote. `sigil/src/certpin.cyr` provides SPKI pinning primitives, not an mTLS stack | — |
| ML-KEM / Kyber key exchange · SPHINCS+ · PQC algorithm negotiation · downgrade-attack prevention | ⛔ Zero occurrences in `sigil/src/`. There is no handshake to negotiate or downgrade | ML-DSA-65 **signing** only (`sigil/src/mldsa_params.cyr:10`) |
| Wayland protocol security | aethersafha speaks **setu**, not Wayland | setu protocol review, above |
| Firewall rules · network segmentation · TCP wrappers · protocol-family disable (DCCP/SCTP/RDS/TIPC) | No packet filter, and **no protocol-family selector at all** — which is the structural immunity, not a config gap | Enumerate the daemons you started |
| `ptrace` · `LD_PRELOAD` / dynamic linker · `fork` · io_uring · `AF_UNIX` · inotify · docker | Not implemented. `#96` is reserved for `fork` and is **not built** | — |

## 📋 Not Available Yet

Intended, designed, **not built**. Nothing below is a tickable box; each is a roadmap item with the
evidence that it is unbuilt.

- 📋 **Per-process / per-agent capabilities.** Not in the kernel, not in daimon, not behind any config
  schema. `grep -i capabilit daimon/src/` returns **zero hits**; `AgentHandle`
  (`daimon/src/agent.cyr:27-40`) has no capability field. The kernel names the seam three separate
  times as future work (`agnos/kernel/core/syscall.cyr:6804`, `power.cyr:338`, `proc.cyr:929-931`)
- 📋 **Native confinement.** Capability-scoped and sovereign when it lands — explicitly not a Linux
  ABI emulation
- 📋 **Signature verification at exec.** The ELF loader checks magic, class and bounds and nothing
  else (`agnos/kernel/core/elf.cyr:19-176`). Verification is an **install-time** property of ark
- 📋 **Secure Boot / measured boot.** Post-v1.0 in `gnoboot/docs/development/roadmap.md:202-210,236-240`.
  The pieces that exist are gnoboot itself and `cyrius sign-efi`; **no enrolment flow chains them**
- 📋 **Human-approval / kill-switch surface.** Earlier revisions of the security guide showed
  `security.request_permission(...)` and `security.emergency_kill_switch()`. **That `security.*`
  namespace does not exist in any language.** ⚠️ **But do not record a clean grep here** — a
  near-namesake pair ships in Cyrius today: `sec_ui_request_permission`
  (`aethersafha/src/security_ui.cyr:515`) and `sec_ui_emergency_kill_switch` (`:648`). ⛔ **Both are
  inert UI state.** The "kill switch" sets an `emergency` flag, sets `human_override`, un-approves
  pending override entries in a vec and prints a line — it kills no process and revokes no grant
  (there are no grants: no capability model exists). Both have **zero callers outside
  `security_ui.cyr`**. This is the same trap as mela's sandbox profiles: real code, real name,
  nothing behind it
- 📋 **Agent injection defense (L1–L6).** `docs/development/planning/agent-injection-defense.md` is a
  good design spine and is **entirely un-actioned** — cite it as a roadmap, never as a control
- 📋 **Vulnerability tracking for first-party code.** zugot's dated CVE cadence covers upstream pins
  only
- 📋 **Incident-response tooling.** No IDS service, no alerting, no dashboard, no forensic capture
- 📋 **Meltdown mitigation.** KPTI is collapsed; there is no retpoline
- 📋 **A shipped PIE kernel.** The mechanism exists and was boot-validated; no build path invokes it
- 📋 **SMP re-judgement.** `agnos/docs/development/security-hardening.md:274-275`: *"**SMP**
  invalidates invariant (1). Every finding in this document judged 'not a race' must be re-judged when
  APs are scheduled."* APs are being scheduled. Two SMP-hole issues are open under
  `agnos/docs/development/issues/` dated 2026-08-02 and 2026-08-03

---

## Vulnerability Severity Criteria

### Critical (CVSS 9.0-10.0)
- Remote code execution
- Complete system compromise
- Data exfiltration

### High (CVSS 7.0-8.9)
- Privilege escalation
- Sensitive data access
- Service disruption

### Medium (CVSS 4.0-6.9)
- Limited privilege escalation
- Limited data access
- Temporary service impact

### Low (CVSS 0.1-3.9)
- Information disclosure
- Minor configuration issue
- Minimal impact

⚠️ **Calibrate against the posture, not against Linux.** "Privilege escalation" presumes privilege
levels; AGNOS has one. A finding that a process reached uid 0 is not a finding — it started there. Rate
against what an attacker *gains*: reaching ring 0 from ring 3, escaping the per-process address space,
or persisting across a reboot are the real Critical/High shapes on this system.
