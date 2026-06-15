# Docker AGNOS Service-Sweep Harness — Plan

> **Status**: Planning | **Created**: 2026-06-14 | **Owner**: agnosticos (testing surface)
> The founder's **closed-beta Phase-1** apparatus: stand up the AGNOS server-stage services in containers and **sweep-test them to find the weak points** before the closed beta opens (Late June / Early July 2026, gated on "server base work"). See [`roadmap.md`](../roadmap.md) § *Closed Beta — Phase 1*.

---

## 1. Why — the validation surface climbs the ladder of realism

**iron → QEMU → containers.**

| Surface | Question it answers | Status |
|---|---|---|
| **Iron** | Does it boot + run on bare metal? | ✅ (archaemenid, boot-to-shell + live keyboard + DOOM) |
| **QEMU** | Does it run portably under virtualization? | ✅ (the smoke battery: agnsh / tcp / dns / doom) |
| **Containers** | **Does it run where the majority of modern services actually live?** | ⏳ gated on sockets |

Docker / OCI / K8s is the dominant deployment substrate in 2026 — it is *where services run*. A sovereign OS that only runs on bare metal is a curiosity; one that drops into the container ecosystem is a **participant**. Container-capability is therefore both the **biggest, most-realistic test surface the project has had** *and* a real **deployment path**, not just a test path. This harness is the first exploitation of that surface.

## 2. The socket prerequisite chain — "sockets are the major hurdle to container usage"

AGNOS can only *host* a networked service in a container once it can **`accept()` inbound connections over its own sockets**. Today it has the **client** half (1.45.x): `sock_connect`#47 / `sock_send`#48 / `sock_recv`#49 / `sock_close`#50, plus UDP #51-54 + `icmp_echo`#55. The **server** half is the gate:

- **Kernel primitives already exist** — `tcp_listen(port)` / `tcp_bind(port,ip)` / `tcp_accept(listen_id)` in [`agnos/kernel/core/net_tcp.cyr:546-604`](https://github.com/MacCracken/agnos/blob/main/kernel/core/net_tcp.cyr) (LISTEN state 5, `TCP_FLAG_IS_LISTENING`, passive-open SYN_RCVD path; 8-conn cap). They are **not exposed to ring 3 yet.**
- **Phase-B = expose them** as `sock_listen` / `sock_bind` / `sock_accept` ring-3 syscalls (the same "expose existing primitive" pattern as #47-55; all non-blocking, no sti-window needed; the accepted conn_id reuses `sock_send`#48 / `sock_recv`#49 / `sock_close`#50). The 1.45.2 conn-slot reclaim already pre-cleared their exhaustion.
- **agora additionally needs `fork`/`waitpid`** for its fork-per-accept model (ADR 0007); descent uses a single-thread **epoll** loop instead (so it needs the epoll/non-blocking-accept surface, not fork). Confirm which process primitives each service binds on AGNOS vs Linux.

**So the build order is a chain, not a choice:** Phase-B server sockets (+ the cyrius `CYRIUS_TARGET_AGNOS` peer binding `sock_listen`/`accept`) → AGNOS is container-network-capable → this harness becomes possible.

## 3. Container architecture — two tracks, different jobs

The characterization surfaced three options; the harness uses **two of them as complementary tracks**:

### Track A (primary) — HYBRID: Linux harness driver + AGNOS-under-QEMU service containers
- **Outer harness container** (Debian + Python/Go): generates load, fuzzes, parses results, aggregates a findings ledger.
- **Inner AGNOS service containers**: each runs `qemu-system-x86_64` + OVMF + gnoboot + the agnos kernel (reuse the existing smoke boot scaffolding — `agnos/scripts/{agnsh,tcp,dns}-smoke.sh` already boot AGNOS under QEMU with **SLIRP user-mode networking + host-port forwarding**), with one or more ring-3 services bound to ports.
- **Why primary:** this is the *only* track that actually validates the AGNOS kernel + ring-3 socket syscalls + the net-stack state machine + the resource caps — i.e. it answers "does *AGNOS* work in a container," which is the founder-sweep's whole point.
- **Cost:** QEMU is slow per connection (the ~8 s SYN-ACK ceiling × thousands of conns = hours) and heavy (~512 MB + 1-4 vCPU per instance). ⇒ **This track sweeps for CORRECTNESS + weak points (crashes / hangs / leaks / races / resource-exhaustion / auth / fuzz), NOT raw throughput.** Throughput benchmarking stays on iron / native.

### Track B (secondary) — Cyrius-Linux service builds in Docker (fast regression)
- Dockerfile `FROM debian-slim` + cyrius, build agora / descent / sandhi as **Linux** ELF (the "portable to any system save the kernel" property — the services compile + run cross-platform). Services call Linux sockets directly.
- **Why secondary:** ~100× the throughput, ~⅕ the resource overhead — great for **fast service-logic regression + load that QEMU can't reach**, and for bisecting "is this a *service* bug or a *kernel* bug?" (a bug reproducing on Track B is service-side; a bug only on Track A is AGNOS-side).
- **Caveat:** ZERO AGNOS-kernel validation. Never confuse a green Track B with "AGNOS works."

> Track-A finds where AGNOS is weak; Track-B finds where the *services* are weak and runs the high-volume load. Both feed the same findings ledger.

**Existing infra:** `agnosticos/docker/` holds only `archive-pre-cyrius/` (13 Rust-era Dockerfiles — reference only, do not resurrect). The reusable asset is the **QEMU smoke-boot scaffolding** in `agnos/scripts/`, not the old Docker tree.

## 4. The service suite — status (server stage ~50%)

| Service | Repo / ver | Interface | Concurrency | Ready? |
|---|---|---|---|---|
| **agora** (BBS) | agora 1.4.3 | telnet :2323 (RFC 854/1184 LINEMODE) | **fork-per-accept** | ✅ production |
| **descent** (MUD) | cyrius-yeomans-descent 1.0.1 | telnet | **single-thread epoll** (≤64 events) | ✅ production |
| **web server** | sandhi 1.4.11 (`sandhi_server_run_async`) | HTTP/1.1 + HTTP/2 | epoll, `max_conns` (default 8) | ✅ exists |
| **sit serve** | sit 1.0.1 | read-only HTTP, bearer-token auth | — | ✅ exists |
| **remote-shell** | — | — | — | ❓ verify / likely planned |
| **ark/nous server-side** | ark 0.8.0 / nous 1.2.5 | package-repo daemon | — | ❌ **not built** (CLI only) — FUTURE |

⇒ The first harness ships against **agora + descent + sandhi-HTTP + sit-serve**; ark/nous server + remote-shell are slotted when they exist.

## 5. Per-service sweep matrix (weak-point taxonomy)

Prioritised by the characterization's severity calls. **CRITICAL** items are the ones a founder sweep must hit first.

### agora (BBS)
- 🔴 **Ed25519 auth boundary** (`main.cyr:1812-1884`) — wrong-key/tampered-handle/cross-user-fp-collision verify; 30 s challenge-deadline enforcement; nonce entropy; hex round-trip; the O(n≤1024) handle scan. *Auth bypass = worst-case.*
- 🔴 **flock'd shared-world race** (door games + chat, ADR 0010/0011/0014) — 8 conns all in **Ashes of Empire** (universe-only, forces a flock txn per line): lock contention, flock inheritance across forked children, world-snapshot >8 KB (`DOOR_WORLD_CAP`) partial-write under `O_TRUNC`, chat ring-buffer wrap vs seq watermark.
- 🟠 telnet RFC conformance (malformed IAC / subneg / NAWS / DO-DONT spam / 256 B `tx_buf` overflow); fork-per-accept exhaustion (`RLIMIT_NPROC`, `waitpid(WNOHANG)` zombie reap, backlog 16); board input hardening (NUL/ESC/CRLF injection, 4 KB subject / 65 KB post caps); slowloris (60 s recv timeout pins a worker).

### descent (MUD)
- 🔴 **session lifecycle under flood** (epoll `MAX_EPOLL_EVENTS`=64 boundary; unbounded `Session` heap growth until idle-evict); **combat-tick drift** (measure `drift_p99` under sustained load); **multi-user world-state invariants** (room presence walked during tick).
- 🟠 telnet IAC state machine (`telnet_feed` fuzz); verb-noun tokenizer (`parser_tokenize` `NORM_CAP`=4096 overflow); auth + persistence (sigil/libro); zone-data load (malformed/truncated CYML).

### sandhi HTTP server + sit serve
- 🔴 **HTTP connection flood** (`max_conns`=8 default; epoll batch-drain limit) — large `Content-Length`, chunked-transfer abuse, pipelined floods, slow-body.
- 🟠 **sit-serve bearer-token boundary** (token load-before-serve; refusal path on missing/bad token).

### Cross-cutting (kernel — the AGNOS sweep proper)
- 🔴 **conn_id / arg forgery** — ring-3 conn_id is caller-controlled; `sock_recv(conn_id=999)` must return −1, not WOULD_BLOCK (the exact class the 1.45.2 review caught). Forge out-of-range conn_id / listener_id / buf pointers across *every* socket syscall.
- 🟠 **resource caps** — 9th `sock_connect` returns −1 (8-conn cap); 9th `udp_bind` returns −1 (8-listener cap); slot **reclaim** after close (the 1.45.2 fix) holds under churn.
- 🟠 **state-machine integrity** — trace CLOSED→SYN_SENT→ESTABLISHED→FIN_WAIT and LISTEN→SYN_RCVD→ESTABLISHED→CLOSE_WAIT under load; **retransmit** behaviour under injected loss (QEMU `netem loss 10%`).

## 6. Sweep methodology (9 dimensions)

1. **Connection-exhaustion & cap-reclaim** — sequential churn (open/close ×256+) → validate 8-slot TCP reclaim; hit the 8-conn / 8-listener caps and assert the −1s.
2. **Load & throughput (data plane)** — 8 conns pushing bulk repeating-pattern at line rate; bytes/sec. *(Track B for volume; Track A for correctness-under-load.)*
3. **Fuzz / malformed input** — crafted segments (bad checksum, seq chaos, flag mayhem) + protocol fuzz (telnet IAC, HTTP headers, MUD verbs, auth hex).
4. **Soak / memory-leak** — 1 h+ open/write/close at ~10 Hz; sample **heap-free via `sysinfo`#35** every N cycles + klug ring; assert no monotonic leak.
5. **Concurrency / race (shared-world)** — agora + descent on separate ports in one AGNOS instance; 8+ clients hammer both → stress flock txns + epoll + tick.
6. **Resource-exhaustion (kernel limits)** — the 8-conn / 8-listener / `RLIMIT_NPROC` / fd ceilings.
7. **Retransmit / timeout (B2 arc)** — `netem`-injected loss; retransmit count + recovery.
8. **Security / auth boundary** — conn_id forgery (above) + Ed25519 / bearer-token bypass attempts.
9. **State-machine integrity** — TCP state traces client + server side.

## 7. Driver + observability

**Drivers** (in the Track-A harness container, reusable against Track B): telnet flooder (fork/parallel hold-open, vary rate/payload), telnet+HTTP fuzzers (IAC / headers / verbs / auth-hex), HTTP/1.1+/2 load generator (chunked / pipelined / large-body), raw-packet crafter (`scapy`/raw sockets) for segment fuzz, the `netem` loss injector.

**Observability** (AGNOS-under-QEMU):
- **Serial console** — QEMU `-serial stdio`; kernel boot/panic + any `klog`#36 markers → per-test log file (`test-NNN-<dim>.log`), greppable (`grep "tcp_accept" test-*.log`). The primary channel (no serial on iron, but QEMU has it — smokes already rely on this).
- **klug log ring** (`klog`#36) — in-kernel structured events drained to serial.
- **`sysinfo`#35** — heap-free counter sampled by drivers for leak detection.
- **Framebuffer** — last-resort visual (the iron channel); QEMU screenshot on hang.
- **Findings ledger** — each driver writes structured rows (service · dimension · input · observed · severity) → a per-run `findings.jsonl`; weak points roll up into the roadmap's **P1 list**.

## 8. Build sequence — the "few updates away"

1. ✅ **Phase-B server sockets** (agnos kernel) — **DONE at agnos 1.45.5**: `sock_listen`#56 (bind+listen merged) + `sock_accept`#57 (non-blocking, net_poll-drives the handshake). `tcp-listen-smoke` 2/2 host→AGNOS. *The gate — cleared.* Open downstream: agora's fork-per-accept needs an AGNOS path (spawn#3/#43 + waitpid#4, no Unix `fork`); descent's epoll model maps cleanly — a service/peer concern, not the kernel's.
2. **cyrius `CYRIUS_TARGET_AGNOS` peer** (hands-off) — bind `sock_listen`/`bind`/`accept` so agora/descent/sandhi build for AGNOS (extends the #45-55 proposal: [`cyrius/.../2026-06-14-agnos-net-entropy-clock-syscalls.md`](https://github.com/MacCracken/cyrius/blob/main/docs/development/proposals/2026-06-14-agnos-net-entropy-clock-syscalls.md)).
3. **AGNOS-in-QEMU-in-Docker boot container** — Dockerfile wrapping the existing smoke boot (QEMU+OVMF+gnoboot+kernel) with SLIRP port-forward; one service bound, reachable from the harness container.
4. **Harness driver container + per-service sweep scripts** — the drivers above + the 9-dimension matrix, parameterised per service.
5. **Findings ledger + roll-up** — `findings.jsonl` → P1 list; CI-runnable for regression.
6. *(parallel)* **Track B** — Cyrius-Linux service Docker images for fast regression + high-volume load.

## 9. Scope honesty

- **Server suite is ~50%**: agora + descent + sandhi-HTTP + sit-serve are real; **ark/nous server-side + remote-shell are not built** — the harness covers them when they exist.
- **Track A is correctness, not throughput**: QEMU's per-connection cost caps volume; raw perf numbers come from iron / native, not this harness. Don't publish QEMU throughput as AGNOS throughput.
- **Phase-B server sockets are a hard prerequisite** for Track A — until they land, only Track B (Linux service regression) can run, and it validates *services*, never the AGNOS kernel.
- **The 8-conn / 8-listener caps are MVP-real**: the harness should *document* hitting them as expected behaviour, not file them as bugs — until a per-process-socket-ownership arc (post-1.46.x kstacks) raises them.
- **SYN_RCVD half-open exhaustion is a KNOWN MVP-class limitation** (surfaced by the 1.45.6 audit): an inbound SYN to a LISTEN port allocates a slot + buffers in SYN_RCVD; an attacker who never completes the 3-way handshake holds it ~31 s (5 RTO retries), and 8 such SYNs fill the 8-slot table → legit connects fail for that window. The harness **should measure this** (a SYN-flood driver: open N half-opens, never ACK, time how long legit accept is denied) and report it, but **do not file it as a new bug** — the proper fix (SYN-cookies / a real backlog / a short SYN_RCVD timeout) is a deferred arc, not part of the MVP server base. It's the first concrete "where are we weak" item this sweep is *for*.

---

*Derived from a 4-agent characterization sweep of agora / descent / sandhi+sit / the socket-container architecture (2026-06-14). Refresh when Phase-B server sockets land or a new server-stage service ships.*
