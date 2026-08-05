# Security Guide

**Last Updated**: 2026-08-05 (rewritten for the Cyrius/agnos era against agnos 1.56.40 · cyrius 6.5.7 · gnoboot 0.6.1)

This guide documents the security architecture of AGNOS **as it exists in source today**, not as it is intended to exist. It replaces a 2026-03 revision that described a Landlock/seccomp/namespace sandbox model, a per-agent permission system, a human-approval flow, an emergency kill switch, mutual TLS and post-quantum key exchange — **none of which were ever built**, and several of which AGNOS has permanently ruled out.

> **The one rule this document is written under**: a security document that describes a control which does not exist is worse than no document, because it tells an operator they are protected when they are not. Every ✅ item below was read in source at the cited `path:line`. Where a control is absent, this page says so loudly rather than omitting it.

### Status markers

| Marker | Meaning |
|---|---|
| ✅ | **Shipped and verified** — read in source at the cited path:line |
| 🐧 | **Linux-target only** — the code exists but compiles out on AGNOS |
| 📋 | **Intended** — designed or on the roadmap; not a mechanism that runs |
| ⛔ | **Absent** — does not exist in any form. Named here so nobody assumes it |

> **Notable structural-immunity entry**: the AGNOS-native kernel is **structurally immune** to **CVE-2026-31431** (Linux LPE in `algif_aead`/AF_ALG via `splice()`). The sovereign syscall table has **no generic BSD socket family, no `socket()` over arbitrary domains, no `splice`, no AF_ALG** — the bug class is unreachable. ⚠️ Never phrase this as "AGNOS has no sockets": AGNOS ships a curated network band (`sock_connect`#47 / `sock_send`#48 / `sock_recv`#49 / `sock_close`#50 / `sock_listen`#56 / `sock_accept`#57, handlers at `agnos/kernel/core/syscall.cyr:8636-8876`). Those take a slot-indexed `conn_id` and **no address-family argument**, so there is no family to select. The immunity is anchored on the *shape* of the surface, not its size — the table has grown repeatedly and the property holds. This is the canonical **absence-by-design** pattern; see [SECURITY.md](../../SECURITY.md).

## Security Architecture

### Defense in Depth

AGNOS layers security **natively**. ⚠️ No layer below is a Linux mechanism, and none will be: per [`docs/development/roadmap.md`](../development/roadmap.md), confinement "when it lands, is **capability-scoped and native** — never Landlock, seccomp or `unshare` ABI emulation." Layers that are not built are marked, not dressed in a borrowed name.

```
┌──────────────────────────────────────────────────────────────┐
│ Layer 6: Agent / Application                                 │
│   ⛔ per-agent capabilities · ⛔ human-approval gate           │
│   📋 t-ron MCP gate (built, wired into nothing)               │
├──────────────────────────────────────────────────────────────┤
│ Layer 5: Service                                             │
│   ⚠️  daimon 8090 binds 0.0.0.0 with no auth                  │
│   ⚠️  hoosh 8088 auth fails OPEN when no tokens configured    │
├──────────────────────────────────────────────────────────────┤
│ Layer 4: Install-time trust                                  │
│   ✅ ark: SHA-256 root hash + per-file hashes                 │
│   ⚠️  Ed25519 signature only when the package carries one;    │
│       require_signed defaults to 0                           │
├──────────────────────────────────────────────────────────────┤
│ Layer 3: Process isolation                                   │
│   ✅ per-process CR3 · ✅ ring-3 separation · ✅ W^X/NX        │
│   ⛔ no uid · ⛔ no capabilities · ⛔ no confinement            │
├──────────────────────────────────────────────────────────────┤
│ Layer 2: Kernel ingress                                      │
│   ✅ user-range validation on every pointer argument          │
│   ✅ SFMASK entry sanitization · ✅ SMEP/SMAP · ✅ IOPL 0      │
│   ⚠️  no LSM framework and no loadable modules — by design    │
├──────────────────────────────────────────────────────────────┤
│ Layer 1: Boot / hardware                                     │
│   ⛔ gnoboot verifies nothing but ELF magic                   │
│   ⛔ no Secure Boot enrolment · ⛔ no TPM measured boot        │
│   ⚠️  AMD-Vi IOMMU deliberately DISABLED on the iron target   │
└──────────────────────────────────────────────────────────────┘
```

### The one-sentence honest model

> **AGNOS runs one owner's trusted software on one machine.** Its security value is a radically small, sovereign attack surface that structurally lacks whole classes of Linux vulnerability — **not** the enforcement of boundaries between processes, users, or code of differing trust, none of which the kernel implements today.

That is a coherent posture for a single-owner pre-Beta founder-dogfood system. It is **not** a multi-user posture and must never be described as one.

## Threat Model

### Assets

1. **User Data** — files, keys, personal information
2. **System Integrity** — the kernel image, the ESP, the installed package set
3. **Agent Operations** — AI agent tasks and decisions
4. **Communication** — network traffic, IPC, shared-memory surfaces
5. **Resources** — CPU, GPU, memory, storage

### Threat Actors

1. **Malicious or compromised agents** — the primary concern for an agent-hosting OS
2. **External attackers** — network-reachable services (see the listening-services table below)
3. **Supply chain** — a compromised dependency, recipe source, or `.ark` package
4. **Physical / firmware** — anyone who can write the ESP owns the machine (see §12)

⚠️ **"Insider threats — malicious users or processes" is not a meaningful actor on AGNOS today.** There are no users, and every process is already fully privileged. It returns as an actor the day a uid or capability model lands.

### Attack Vectors

⚠️ This table previously listed "Sandboxing, seccomp, namespaces" and "no root for agents" as mitigations. **A mitigation column that names a control which does not exist is worse than an empty one.** It now says what actually stands in the way — often nothing.

| Vector | Risk | What actually stands in the way today |
|--------|------|----------------------------------------|
| Agent escapes its intended scope | **High** | ⛔ **Nothing.** There is no sandbox, no capability set, and no uid. A process is limited only by the syscalls that exist |
| Privilege escalation | **N/A — nothing to escalate to** | ⛔ Every process is already uid 0 (`getuid` returns 0 unconditionally, `agnos/kernel/core/syscall.cyr:7190`) |
| Kernel compromise via a bad user pointer | **High** | ✅ `is_user_range()` bounds every pointer argument (48 call sites in `syscall.cyr`); ✅ SFMASK entry sanitization; ✅ SMEP/SMAP. ⚠️ The kernel is memory-unsafe by construction and hand-audited |
| Cross-process data theft (private memory) | Low | ✅ Per-process CR3 — the strongest control AGNOS has |
| Cross-process data theft (shared memory) | **High** | ⛔ `shm_write`#72 / `shm_read`#73 are **cross-owner permitted**, warn-counted only (`syscall.cyr:7772-7786`). Only `shm_free`#74 is owner-gated |
| Connection hijack / teardown | **High** | ⛔ The 8-slot TCP conn table has **no owner field**; `sock_send`/`sock_recv`/`sock_close` bounds-check `conn_id` and nothing else |
| Disk disclosure / destruction | **High / Medium** | ⛔ `blk_read`#77 is ungated by design. ⚠️ `blk_write`#78 requires a one-time arm with a constant published in the source — anti-accident, **not** anti-adversary |
| Memory-exhaustion DoS | **High** | ⛔ `sys_mmap` has **no per-process page budget** (`proc.cyr:1651-1661`); one process can take all machine RAM |
| Shellcode on heap or stack | Low | ✅ W^X — every non-executable segment, every user stack and all `mmap` memory is mapped NX |
| DMA from a malicious PCI device | **High on AMD iron** | ⚠️ AMD-Vi is **deliberately disabled every boot** (`main.cyr:478`). VT-d runs only when an Intel DMAR table is present |
| Tampering with the kernel image | **High** | ⛔ **Nothing verifies it, ever** — not at boot, not at exec. The ESP is a FAT partition |
| Prompt injection into an agent | **High** | 📋 t-ron ships a six-pattern injection detector (`t-ron/src/safety.cyr:470-491`) that **nothing calls** — neither bote nor daimon declares `[deps.tron]` |
| Supply-chain compromise of a dependency | Medium | ⚠️ TOFU commit-pinning against `cyrius.lock`, **tagged deps only** — the entire check sits behind `if (dep_tag != 0)` (`cyrius/cbt/deps.cyr:1396`), and the source states that a `git` dep with no `tag` is *"intentionally float[ing] (track a branch HEAD) so they are not pinned"* (`:1394-1395`). ✅ `.ark` hash + optional signature at install. ⛔ **No advisory database of any kind** — see [vulnerability-management.md](vulnerability-management.md) |

## Security Features

### 1. Process isolation — ✅ shipped

The strongest control AGNOS has, and it is genuine.

- **Per-process address space.** `proc_create_address_space` builds a fresh PML4/PDPT/PD per process (`agnos/kernel/core/proc.cyr:553`). Two ring-3 processes cannot see each other's private memory through the MMU.
- **Ring-3 separation.** CS=0x23 / SS=0x1B at DPL 3 (`agnos/kernel/arch/x86_64/ring3.cyr:166,186`). Kernel identity PDEs carry `0x83` — present + writable + 2 MB, **U/S clear** (`proc.cyr:610`); user pages carry `0x87` with U/S set (`proc.cyr:1007`). Ring 3 cannot reach a kernel page.
- **SMEP + SMAP**, CPUID-gated, enabled on the shipping gnoboot boot path (`agnos/kernel/arch/x86_64/boot_shim.cyr:281-295`). Ring 0 cannot execute a user page.
- **No port I/O from ring 3.** The TSS is written with IOPB offset = TSS limit — i.e. **no I/O permission bitmap** (`agnos/kernel/arch/x86_64/gdt.cyr:81`) — and ring 3 runs at IOPL 0. Any `in`/`out` takes #GP.
- **Ring-3 faults kill the process, not the box**, for vectors {0 #DE, 6 #UD, 13 #GP, 14 #PF} (`agnos/kernel/arch/x86_64/idt.cyr:498`).
- **GPR zeroing before every ring-3 entry** so no kernel register content leaks to a fresh program (`ring3.cyr:200-209`).

⚠️ **The per-process CR3 is a deliberate superset of the kernel map.** All kernel entries are mirrored into it as U/S=0. Ring 3 still cannot touch them, but a *kernel* dereference of a bad user pointer reads real kernel or MMIO memory — it does not fault harmlessly. That is why the validators in §3 are load-bearing.

⚠️ **KPTI is collapsed.** Since 1.40.3 the "user" CR3 stashed per process **is** the full kernel CR3 (`proc.cyr:648-671`; `syscall_hw.cyr:89-90` states the CR3 installs are "same-value no-ops today"). Architectural protection holds; **Meltdown side-channel protection does not exist.** There is no retpoline.

### 2. W^X / NX — ✅ shipped for user pages, ⛔ absent for the kernel

`proc_map_page_nx` stamps bit 63 (`agnos/kernel/core/proc.cyr:1029`) and is applied to every non-`PF_X` PT_LOAD segment, the user stack (`agnos/kernel/core/elf.cyr:156`), and all anonymous `mmap` memory. Executable segments stay executable. Shellcode written to a heap or stack is not jumpable.

- ✅ **User stack guard pages.** Both ELF loaders unmap the 2 MB below the stack to trap overflow (`elf.cyr:157-158`).
- ⚠️ **EFER.NXE is inherited from firmware on the shipping boot path.** The gnoboot shim never writes EFER (`boot_shim.cyr:150-303`); an in-source comment elsewhere claiming "EFER.NXE is set at boot" is true only of a dead legacy path. On firmware that leaves NXE clear, an NX mapping becomes a reserved-bit #PF. Nothing asserts this at boot.
- ⛔ **Kernel-side W^X does not exist.** `pt_init` identity-maps all 512 PD entries as present + writable with no NX (`agnos/kernel/arch/x86_64/paging.cyr:5-27`) — **kernel `.text` is RWX**. This is architectural: the syscall entry stub, the IDT stubs and the AP trampoline are all runtime-emitted machine code written into writable pages.
- ⛔ **Kernel stack guard pages do not exist.** Per-process RSP0 stacks are 64 KB slots packed contiguously with no unmapped page between them. A kernel-stack overflow walks silently into the neighbour's stack.

### 3. The syscall trust boundary — ✅ shipped

Every pointer a ring-3 caller passes is range-checked against the user window before the kernel touches it. Quoted verbatim from `agnos/kernel/core/syscall.cyr:274-303` — this is kernel source, not an API to call:

```cyrius
fn is_user_ptr(ptr) {
    if (ptr < 0x200000) { return 0; }
    if (ptr >= 0x40000000) { return 0; }   # above the 1 GB user ceiling
    return 1;
}

fn is_user_range(ptr, len) {
    if (ptr < 0x200000) { return 0; }
    if (ptr + len < ptr) { return 0; }          # wrap check
    if (ptr + len > 0x40000000) { return 0; }    # above the 1 GB user ceiling
    return 1;
}

fn sc_path_ok(ptr, len) {
    if (len < 1) { return 0; }
    return is_user_range(ptr, len);
}
```

`is_user_range` has **48 call sites in `syscall.cyr`** alone (49 occurrences of the name, one of which is the definition at `:280`), plus the GPU, VFS, HDA and ext2 paths. An unknown syscall number returns −1.

⚠️ **There is no copy-in.** Handlers read and write the user VA directly under the caller's CR3, inside a SMAP window the entry stub opens once — `stac` before the handler, `clac` after (`agnos/kernel/arch/x86_64/syscall_hw.cyr:510,515`). **SMAP is disabled for the entire duration of every syscall**, not per-copy as Linux does it.

⚠️ **A documented invariant is stale.** `agnos/docs/development/security-hardening.md:17` (invariant 3) asserts every legitimate user address is below 1 GB; a HIGH `mmap` arena at `[128 GB, 512 GB)` has existed since 1.50.2 and is rejected by every validator above. This fails *closed* — a functional limitation, not a hole — but do not cite the invariant as written.

### 4. Syscall entry hardening — ✅ shipped, with one CPUID gate

- ✅ **SFMASK = 0x40700** clears IF | TF | DF | AC on SYSCALL entry (`syscall_hw.cyr:217-229`). Each bit closes a named attack: TF single-steps the kernel into the bare-`iretq` #DB gate, DF reverses `rep`-string ops, AC pre-disables SMAP ahead of the stub's STAC.
- ⚠️ **IBRS is CPUID-gated** (leaf 7, subleaf 0, EDX bit 26 — `syscall_hw.cyr:249-260`). If the CPU does not advertise it, the MSR writes **are not emitted at all**, and there is no mitigation and no warning.
- ✅ **Stack canaries** — but be precise about what they are. `stack_canary_secret` is RDRAND-seeded at boot with a timer-mixer fallback (`syscall.cyr:6`), and `stack_canary_check` panics on mismatch (`syscall.cyr:20`). ⚠️ **Cyrius emits no automatic stack protector.** Exactly **four** functions in the whole kernel snapshot the canary: `elf_load` (`elf.cyr:20`), `elf_load_from_file` (`elf.cyr:209`), `ksyscall` (`syscall.cyr:6938`), `net_handle_tcp` (`net_tcp.cyr:710`). It is a global, not `gs:0x28`, so it is readable by any kernel-memory disclosure.

### 5. Address-space randomization — 📋 built, ⚠️ not in a shipped build

⚠️ **No address randomization is active in a shipped AGNOS today.** Both halves need naming:

- ⛔ **The allocator half is dead.** `pmm_next_free` is RDRAND-seeded (`agnos/kernel/core/pmm.cyr:533-535`) but **no allocator reads it** — `pmm_alloc` scans top-down (`pmm.cyr:560`), the 2 MB allocators scan from fixed ends. The comment at `pmm.cyr:541-553` records why: the bottom-up first-fit that consumed the seed scattered a 4 KB page into a random 2 MB region and caused a boot-flaky ring-3 #PF. Removed at 1.41.12. Its only surviving reader is a boot diagnostic print.
- 📋 **The image-base slide requires an opt-in build flag nothing sets.** `agnos/scripts/smoke/kaslr-smoke.sh:7,26-29` requires `CYRIUS_PIE=1 ./scripts/build.sh` and hard-errors on the default build: *"build/agnos is ET_EXEC (non-PIE) — KASLR needs: CYRIUS_PIE=1"*. `CYRIUS_PIE` appears in no CI job, no `build.sh` default, and no ISO pipeline. A `readelf -h` of the built kernel reads `Type: EXEC`. gnoboot only slides `e_type == 3`; an ET_EXEC kernel loads at its fixed `p_paddr`.

**Consequence, stated plainly**: kernel text, every global, and every gadget sit at a compile-time-known address in the kernel that ships.

### 6. Irreversible-operation arming — ✅ shipped, and honest about itself

AGNOS gates irreversible operations at the syscall boundary rather than behind a MAC label store. Raw block writes are off by default and enabled only by `blk_open(_, BLK_RW_ARM_MAGIC)`. The kernel's own comment (`agnos/kernel/core/syscall.cyr:6802-6809`) is the correct framing and is quoted rather than paraphrased:

> *"agnos has no per-proc capability/uid yet … so this default-off + explicit-magic-arm is the boundary: a raw disk write can never happen accidentally/incidentally, and the arm call is the exact seam where an aegis/shakti installer-capability check lands **when agnos grows per-proc caps**."*

⚠️ Mechanically, any ring-3 process can arm it — the magic constant is published in the source, and it is never disarmed. **This is anti-accident, not anti-adversary.** `power_sys` says the same thing about shutdown even more plainly (`agnos/kernel/core/power.cyr:338-342`): *"`getuid` is hardcoded 0 and there is no uid model, so a uid check would be a gate that is always open."*

### 7. Agent sandboxing — ⛔ absent on AGNOS / 🐧 real on Linux

**This section previously claimed Landlock filesystem sandboxing, seccomp syscall filtering, namespace isolation and cgroup limits, with a Rust code sample. None of it applies to AGNOS, and none of it will: the roadmap rules those mechanisms out permanently.**

kavach is a genuine sandbox **on Linux** — Landlock with the full right mask, seccomp-BPF with `PR_SET_NO_NEW_PRIVS`, namespaces, cgroup-v2, mount-ns + `chroot`. 🐧 On AGNOS every primitive is `#ifdef CYRIUS_TARGET_AGNOS`-gated to a structured "not supported", never a silent success:

- `kavach/src/security.cyr:157-167` — Landlock returns `err_not_supported("LANDLOCK")`
- `kavach/src/confine.cyr:116-118` — rootfs confinement returns **−1**, not 0
- `kavach/src/confine.cyr:340-350` — `spawn_seccomp_available` returns 0

kavach's own comments name the reasoning better than a summary can. On the rootfs arm (`confine.cyr:113-115`): *"Returning 0 would report 'the payload is confined to `rootfs`' on a platform where nothing of the sort happened — a sandbox that silently is not one. A caller that cannot confine must be told it cannot confine."* And on `confine_child` (`:205-207`): *"Returning 0 here would tell a caller 'the child is confined' on a platform where not one primitive ran — a sandbox that is silently not a sandbox, which is the worst failure mode this file has."* ⚠️ Note also that kavach's `backend_sy_agnos` is inverted from its name — it shells out to docker/podman to run an agnos **container on a Linux host**; it is not agnos-side confinement.

📋 Native confinement is a roadmap item. What exists today, unwired, is kavach's scanner family and HMAC audit chain.

### 8. Permission / identity model — ⛔ absent

**This section previously presented a six-row capability table (`file:read`, `file:write`, `file:delete`, `network:outbound`, `process:spawn`, `agent:delegate`) as a shipped feature. None of those strings exist in any repo.**

- ⛔ **No uid model.** `getuid` returns 0 for every process (`agnos/kernel/core/syscall.cyr:7190`). There is no `setuid`, no `geteuid`, no `st_uid`. "Restrict to root" is not a sentence AGNOS can write.
- ⛔ **No per-agent capability enforcement** — not in the kernel, not in daimon (`daimon/src/agent.cyr`'s `AgentHandle` has no capability field), not behind any config schema.
- ⛔ **No human-approval gate.** There is no `request_permission` anywhere. Critical operations do **not** require human approval today.
- ⛔ **No emergency kill switch.** There is no `emergency_kill_switch`. There are no permissions to revoke and no lockdown mode to enter. What a responder can actually do is stop the agent through daimon.
- ⚠️ **shakti is pre-1.0 (0.7.0), Linux-only, and has no kernel seam behind it.** It authenticates against a userland policy file. Nothing stops a process from simply not asking.

✅ **What ownership checks *do* exist**, verified: `kill`#16 is gated by `proc_may_signal` — init, self, or a direct child only (`agnos/kernel/core/proc.cyr:938`); `shm_free`#74 is owner-gated; `flock`#59 and the audio band check the calling pid. Those are real, narrow, and worth knowing.

### 9. Audit logging — ✅ shipped as a library, ⚠️ detectable ≠ preventable

libro is a real hash-chained audit chain: SHA-256 hash-linked entries, append-only, constant-time verify, Merkle inclusion and RFC 9162 consistency proofs, per-entry Ed25519 signing with key rotation, three stores (`libro/src/{chain,merkle,proof,signing,file_store}.cyr`). daimon writes agent-lifecycle events into it; argonaut verifies chain integrity on open.

⚠️ **Be precise about the tamper model.** The chain makes tampering **detectable**, not **preventable**: the file store is append-only JSONL guarded by `flock`, and on AGNOS every process is uid 0 with no MAC, so any process can truncate or rewrite it. Detection requires an out-of-band copy of the head hash. libro ships anchoring, timestamping and TPM-anchor modules for exactly that; 📋 **none is wired by default**, and per-entry signing is opt-in.

⚠️ The old revision showed an audit record with a `"user": "alice"` field. **That field cannot be populated** — there is no user identity to put in it.

### 10. Aegis — ⚠️ a library with a stub entry point and no wired consumers

The previous revision described aegis as a running daemon performing real-time behavioural monitoring, automated sandbox enforcement, and coordination with kernel LSMs. Verified reality:

- ⚠️ **Not a daemon.** `aegis/src/main.cyr` sets a log level, prints `"aegis ready"`, and returns. No loop, no socket, no hooks.
- ⚠️ **No repo declares `[deps.aegis]`** — including the consumers its own README names.
- ⚠️ **Scanning is metadata-only** — file exists, size zero, world-writable mode bit, size over 500 MB. No content inspection and no signature check. (The world-writable test rests on stat mode bits, which AGNOS does not meaningfully populate.)
- ✅ **Auto-quarantine exists as code** (`aegis/src/lib.cyr:429-458`) — a CRITICAL/HIGH event, if config allows, pushes an entry onto an **in-memory** quarantine list. It does not kill, isolate, or terminate anything.
- ⛔ **The "coordination with kernel security modules (Landlock, seccomp, IMA)" bullet is deleted.** There are no LSMs on AGNOS and no LSM framework.
- ⚠️ `aegis/src/firewall.cyr` *renders* an nftables ruleset; its header says the consumer is responsible for applying it. Nothing applies it.

### 11. Phylax threat detection — ✅ real, ⚠️ one-shot scan only on AGNOS

phylax is substantial and genuinely Cyrius-native with no external AV dependency: a YARA-style rule engine with a real `.yar` lexer and parser (`phylax/src/yara.cyr:875,1212,1534`), Shannon entropy and chi-squared analysis (`phylax/src/analyze.cyr:8,65`), magic-byte file typing (`analyze.cyr:105`), PE and ELF parsing, string extraction, script classification, SSDEEP similarity hashing (`phylax/src/hashing.cyr:139`), SARIF reports, a quarantine index, and LLM triage via hoosh. ⚠️ Its `YARA_PAT_REGEX` type is a *simplified* literal search, not a regex engine (`yara.cyr:15`) — do not describe it as regex matching.

- ✅ **Built-in rules** are loaded by `yara_engine_load_builtin_rules` (`phylax/src/yara.cyr:1667`) — `IsPE`, `IsELF`, `UPXPacked`, `NopSled`, `SuspiciousAPIs`, and more. ⚠️ The old claim of "5 default rules (EICAR test, reverse shell, crypto miner, base64 dropper, credential access)" does not match source — there is no EICAR rule.
- ⛔ The old "`.phylax-db` signature database" and "real-time (fanotify)" scan mode **do not exist**. The only `.phylax` artifact in source is a `.phylax-ignore` list.
- ⚠️ **`watch` mode fails closed on AGNOS** with an explicit message — there is no inotify (`phylax/src/cli.cyr:427-435`). Daemon mode is an `AF_UNIX` listener, which AGNOS also lacks. **One-shot `scan` is the only AGNOS path.**
- ⚠️ **No repo declares `[deps.phylax]`.** It is a standalone CLI; nothing calls it in-process, including aegis.

### 12. Sigil trust and package verification — ✅ shipped, at *install*, by ark

sigil is real and broad, all in-house with zero external crypto dependencies: Ed25519, ECDSA P-256/P-384, X25519, the SHA-2 family, HMAC/HKDF, BLAKE2b, Argon2, RSA with constant-time Montgomery arithmetic and verify-after-sign, AES-GCM with AES-NI dispatch, ChaCha20-Poly1305, X.509/PEM/DER, UEFI Authenticode signing.

✅ **Where verification actually happens is at install, in ark** (`ark/src/ark_package.cyr`), before any file is written: magic and format version, a **SHA-256 root hash** over the verified prefix (`:252-259`), an **Ed25519 signature over that root hash** (`:266-272`), bounded manifest/index/payload offsets, a decompression-bomb cap, **per-file SHA-256** against the index, a zip-slip path-traversal guard that rejects the whole package, and a **trust gate** requiring the signer's pubkey to be in the trust set (`:605-617`).

⚠️ **Two gates are conditional and must be named:**
- The Ed25519 check runs **only if the package carries the signed flag**. An unsigned `.ark` skips it entirely.
- `require_signed` **defaults to 0** (`ark/src/types.cyr:342`; accessor at `:303`). ark's own pre-v1 audit says why that matters: a signature without a trust anchor proves nothing about publisher identity.

✅ **One exception, and it is real: marketplace installs force the gate on.** `ark_marketplace_install` calls `acfg_set_require_signed(amgr_config(mgr), 1)` before every install (`ark/src/marketplace.cyr:57-58`), commented *"Marketplace is an untrusted source: always require a trusted signer (fail closed), regardless of the global `require_signed` default."* So a marketplace package **is** anchored to the trust set at `/etc/agnos/ark/trusted_keys` (`ark/src/types.cyr:24`).

⚠️ **A locally-supplied `.ark` is the ungated path, and an operator cannot close it.** `acfg_set_require_signed` has exactly **one** call site in the whole repo — the marketplace one above. `ark/src/cli.cyr` sets only `color`, `apply`, `system_backend`, `apt_wrapper`, `marketplace_url`, `db_path` and `log_path`: there is **no `--require-signed` flag**, and no config-file parser reads the key. The policy is settable in source only. `ark install ./pkg.ark` therefore performs hash verification but **no publisher-identity check**, and nothing an operator can type changes that.

⛔ **Nothing verifies a signature at exec time.** `agnos/kernel/core/elf.cyr:19-40` checks ELF magic, 64-bit class, an entry point ≥ 0x400000, and program-header bounds, with a pre-pass capping every PT_LOAD before allocation. That is the complete exec-time validation — **there is no hash, no signature, and no reference to sigil in the loader.**

⛔ **TPM-backed attestation and transparency-log integration are deleted from this section.** A grep for `transparency` across `sigil/src` and `libro/src` returns nothing; the attestation flow is unbuilt.

### 13. Boot chain — ⛔ no cryptographic verification at all

**gnoboot 0.6.1 performs no cryptographic verification of anything.** The entire kernel-integrity check is a byte compare of the ELF magic and a PT_LOAD type check (`gnoboot/src/main.cyr:405-425`), repeated at the load address. `gnoboot/cyrius.cyml` declares `[deps] stdlib = ["fnptr"]` — **one stdlib helper and nothing else. sigil is not in the boot path**, so whatever Authenticode capability sigil offers is a library nothing on this path calls.

- 📋 **Secure Boot** is listed under gnoboot's explicit *"post-v1.0 directions — not promises, not committed slots."* There is no enrolment tool.
- 📋 **TPM / measured boot** — same list, same status.
- ⚠️ **Encryption at rest** is installer-side only: agnova offers a LUKS root, but the AGNOS kernel cannot read an encrypted volume, so this applies to host-staged installs. There is no `--tpm` flag.

✅ What the boot chain *does* give you honestly is **attack-surface reduction**: gnoboot replaces GRUB entirely, removing the multiboot2-EFI relocator that wrote to its own `.text`. That is a reliability and surface win, not an integrity control.

⚠️ **Anyone who can write `\boot\agnos` on the ESP owns the machine, and the ESP is a FAT partition.**

### 14. Post-quantum cryptography — ✅ signing only

**One of the three bullets the old revision listed is real.**

- ✅ **ML-DSA-65 (FIPS 204) signing**, default-on since sigil 3.7.6 (`sigil/src/mldsa_params.cyr:10` — *"Only ML-DSA-65 … is parameterised here"*; `sigil/src/lib.cyr:146-157` — the `-D SIGIL_PQC` flag is now a no-op). ⚠️ "Default-on" means the code is compiled in, not that anything in the supply chain is post-quantum signed: ML-DSA appears in two consumers (libro's signing module and t-ron). **ark, takumi, nous, mela, bote, daimon, kavach and the kernel contain no ML-DSA reference. Every signature in the supply chain today is Ed25519.**
- ⛔ **ML-KEM / Kyber does not exist** anywhere in the ecosystem. There is no post-quantum key exchange and no hybrid handshake. `sigil/src/x25519.cyr` is X25519 alone.
- ⛔ **SPHINCS+ / SLH-DSA does not exist** in any form.

### 15. Inter-service communication — ⛔ no mTLS; ⚠️ two services with no auth

**The old revision claimed all inter-service communication used mutual TLS with per-agent client certificates from a local CA and zero-downtime rotation. None of that exists.** There is no mTLS implementation, no local CA and no certificate issuance. `sigil/src/certpin.cyr` provides SPKI pinning primitives; nothing consumes them for service auth. daimon, hoosh and bote all speak plain HTTP.

⚠️ **"Nothing else listens" is false.** The verified surface:

| Service | Port | Bind | Auth |
|---|---|---|---|
| daimon `serve` | 8090 | ⚠️ **`INADDR_ANY` (0.0.0.0)** — `daimon/src/server.cyr:183` | ⛔ **none.** `config_listen_addr` defaults to `"127.0.0.1"` (`daimon/src/config.cyr:10`) and is **never called** |
| hoosh `serve` | 8088 | `127.0.0.1` | ⚠️ **fails open** — `hoosh/src/lib/auth.cyr:6` returns 1 when no tokens are configured, which is the default |
| bote http / bridge | 8390 / 8391 | ✅ `INADDR_LOOPBACK` (`bote/src/main.cyr:146,158`) | ⚠️ opt-in only, via `$BOTE_BEARER_TOKENS` (`bote/src/main_common.cyr:97-105`). Unset ⇒ no validator installed. Bridge additionally sets CORS `*`. Default `bote` with no args is **stdio, not a listener** |
| bote-streamable / bote-ws | 8392 / 8393 | `127.0.0.1` | same opt-in |
| agora (telnet BBS) | 2323 | ⚠️ `INADDR_ANY` (`agora/src/main.cyr:36,2918`) | ✅ sigil Ed25519 challenge/response; anon-read, auth-post |
| kavach credential proxy | caller-chosen | `127.0.0.1` | ⛔ **none** — a secret-name allowlist only. ⚠️ On AGNOS "loopback-only" is not an isolation boundary: every process on the box is a peer |

Several other first-party services (vidya, hadara, mneme, agnosai, the descent MUD) also bind `INADDR_ANY` with no authentication found.

### 16. Agent / MCP security — 📋 built, wired into nothing

t-ron is a **module set**, not a server — its README says so, and it is confirmed: neither `bote/cyrius.cyml` nor `daimon/cyrius.cyml` declares `[deps.tron]`, and no `tron_*` symbol appears in bote's source. What it *would* enforce if wired (`t-ron/src/gate.cyr:14-21`): a parameter-size guard, per-agent ACL policy, token-bucket rate limiting, an injection scan, anomaly patterns, cross-agent correlation, and libro audit — with deny codes `unauthorized / rate_limited / injection_detected / tool_disabled / anomaly_detected / parameter_too_large`. Its injection detector runs six patterns over a Unicode-normalized string (`t-ron/src/safety.cyr:470-491`).

📋 The layered design — input scanning, gateway pre-flight with provenance tags, MCP capability-source policy, irreversible-action confirmation, per-agent capabilities, `UntrustedInput<T>` types — lives in [`docs/development/planning/agent-injection-defense.md`](../development/planning/agent-injection-defense.md), whose own status line reads *"Planning — Design Phase"*. **Cite it as a roadmap, never as a control.**

⚠️ **The concrete unmitigated chain today**: an LLM agent driven by daimon (0.0.0.0:8090, no auth) can invoke any bote MCP tool (no auth unless a bearer env var is set) with no t-ron gate, no provenance tag, no per-agent capability, no sandbox, and no kernel confinement — and can read any secret from kavach's credential proxy if one is running.

### 17. Zero-trust architecture — 📋 aspirational

Zero-trust is the design target, not the current state. Of its five principles: *"never trust, always verify"* has no authorizer; *"least privilege"* has no privilege levels; *"micro-segmentation"* would require network namespaces, which AGNOS does not have and will not emulate; *"continuous verification"* would require aegis to be a running daemon, which it is not. Only *"assume breach"* is partly met — the libro chain gives forensic detectability (§9).

⚠️ [`docs/adr/adr-003-security-and-trust.md`](../adr/adr-003-security-and-trust.md) is the ADR this section used to cite as authority. **It is itself a fossil** — its decision list names Landlock, seccomp with a "basic 20-syscall filter", and network namespaces. Treat it as a historical record until it is superseded.

## What AGNOS Does Not Have

Named in one place so nobody has to infer it from a silence. All verified absent:

**Kernel**: no uid/gid model · no per-process capabilities · no confinement of any kind · no LSM framework · no loadable kernel modules (single Cyrius binary) · no `ptrace` · no `/proc` · no eBPF · no io_uring · no `fork` · no dynamic linker or `LD_PRELOAD` (static binaries only) · no setuid bit · no `AF_UNIX` · no inotify · no namespaces or `unshare` · no sysctl · `umount`#24 and `mount`#11 are no-op stubs — literally `return 0` (`syscall.cyr:7191` and `:7193`) · no in-kernel packet filter · no TLS in the kernel network path.

**Trust**: no signature verification at exec · no boot-chain verification · no Secure Boot enrolment · no measured boot · no mTLS · no local CA · no transparency log · no post-quantum key exchange · no SPHINCS+.

**Userland**: no PAM on AGNOS · no `sudo` · no systemd · no auditd · no rsyslog · no `/etc/passwd`, `/etc/shadow` or `/etc/group` · no docker · no advisory database or CVE feed for first-party code.

## Security Best Practices

### For operators

1. **Treat the machine as the security boundary.** AGNOS is single-owner and single-trust-domain. Do not run code on it you would not run as root, because you are.
2. **Do not expose the box.** daimon binds `0.0.0.0` with no authentication; agora binds `0.0.0.0` on 2323. Keep an AGNOS machine off untrusted networks.
3. **Populate the trust anchor at `/etc/agnos/ark/trusted_keys`** with the Ed25519 pubkeys you accept. This is performable today and it *does* bite: marketplace installs force `require_signed` on and will refuse an untrusted signer. ⚠️ **You cannot enable `require_signed` for a local `.ark`** — there is no CLI flag and no config-file key, only a source-level setter (§12). For anything you did not build yourself, install it **through the marketplace path**, which is gated, rather than by handing `ark install` a local file, which is not.
4. **Copy the audit chain out-of-band** if you care about tamper detection (§9). Concretely: the file store is append-only **JSON Lines**, one record per line, `flock`-guarded (`libro/src/file_store.cyr:1-3`) — so copying the file, or just its last line, to another machine is an ordinary file operation you can do today. ⚠️ **There is no `libro` CLI to print the head hash**: the `libro` binary built from `src/main.cyr` is a **test harness** (466 `assert()` calls, no `argv` handling). The only shipped readout is via daimon's builtin `libro_*` MCP tools (`daimon/src/app.cyr:29`) — which means reaching it goes through the unauthenticated 8090 surface (§15).
5. **Encrypt the root volume at install** via agnova's LUKS option, understanding it applies to host-staged installs only (§13).
6. 📋 Full-disk encryption readable by the AGNOS kernel, TPM sealing, and Secure Boot enrolment are all unbuilt. Do not plan around them.

### For developers

1. **Validate every user pointer with `is_user_range`**, never a bare bounds check — range-form validation is the 1.41.5 audit's standing conclusion. The scalar `is_user_ptr` has **no production call site**; its one reference is the `shsys` boot self-test that checks the ceiling (`agnos/kernel/core/main.cyr:3619`). Do not reach for it.
2. **Fail closed and say so.** kavach's AGNOS arms return a structured "not supported" rather than a silent success. Copy that discipline: a control that silently no-ops is worse than one that refuses.
3. **Do not add a syscall band without an ownership check.** The shm and socket bands are the standing example of what happens when the check is deferred.
4. **Assume no memory safety.** Cyrius is everything-is-i64 with raw loads and stores; every bound in the kernel is a hand-written `if`, and the automatic stack protector does not exist.
5. **Never document a control you have not opened the source for.** This file exists because that rule was not followed.

### For administrators

📋 There is no fleet-management, SIEM, alerting, or incident-response tooling for AGNOS today. See the *Emergency Procedures* section of [SECURITY.md](../../SECURITY.md) for what a responder can actually do, with the gaps named.

## Vulnerability Reporting & Compliance

For vulnerability disclosure policy, bug bounty, response timelines, compliance status, and contact information, see [SECURITY.md](../../SECURITY.md).

For the dependency and supply-chain process — and for what does *not* exist there — see [vulnerability-management.md](vulnerability-management.md). For the testing checklist, see [security-checklist.md](security-checklist.md).

## References

Primary sources for the claims on this page — read these, not a summary:

- `agnos/kernel/core/syscall.cyr` — the syscall dispatcher, the validators (`:274-303`), the canary (`:1-26`), `getuid` (`:7190`), the block-write arm (`:6802-6809`), the shm band (`:7772-7799`)
- `agnos/kernel/core/proc.cyr` — per-process address space (`:553`), the KPTI collapse (`:648-671`), `proc_may_signal` (`:938`), W^X mapping (`:1029`), `sys_mmap` (`:1651-1661`)
- `agnos/kernel/core/elf.cyr` — the only exec-time validation there is (`:19-176`)
- `agnos/kernel/arch/x86_64/syscall_hw.cyr` — SFMASK, IBRS, STAC/CLAC, the collapsed-KPTI note
- `agnos/kernel/arch/x86_64/{paging,gdt,idt,boot_shim}.cyr` — the identity map, TSS/IOPB, installed vectors, SMEP/SMAP
- `gnoboot/src/main.cyr:405-494` — the entire boot verification
- `agnos/docs/development/security-hardening.md` — the S1–S13 record (`:234`, *"closed at v1.28.0"*). ⚠️ Several entries no longer describe the code: S7 KASLR still credits the `pmm_next_free` randomization removed at 1.41.12, S8 KPTI is listed "Partial" but collapsed at 1.40.3, S10 IOMMU describes VT-d while AMD-Vi is disabled on the iron target, S13 lists `net_handle_arp` as a canary site (it no longer is), and invariant 3 predates the HIGH mmap arena
- [`docs/development/planning/kavach-agnos-compat.md`](../development/planning/kavach-agnos-compat.md) — the source-grounded kavach-on-AGNOS audit
- [`docs/development/roadmap.md`](../development/roadmap.md) — the permanent boundary on confinement
- [OWASP Top 10](https://owasp.org/www-project-top-ten/) — applies to the HTTP-serving surface (daimon, hoosh, bote), not the kernel

⚠️ The Linux Security Modules, Landlock and seccomp-BPF references that used to sit here have been **removed**. They pointed at mechanisms AGNOS has permanently ruled out, and a reference list is exactly where a reader goes to learn how something works here.
