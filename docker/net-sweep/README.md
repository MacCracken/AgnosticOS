# AGNOS net-sweep — Track-A boot container

The **AGNOS-in-QEMU-in-Docker boot container** — step 3 of the
[Docker service-sweep harness plan](../../docs/development/planning/docker-service-sweep-harness.md).

It boots the agnos kernel under `qemu-system-x86_64 + OVMF + gnoboot` inside a
container and forwards an inbound TCP port through SLIRP to the guest, so an
external client can exercise AGNOS's kernel TCP `accept()` path **from outside
the container**. This is the containerised analogue of
`agnos/scripts/tcp-listen-smoke.sh` — the foundational proof that *AGNOS runs
where modern services live* (the validation ladder: iron → QEMU → **containers**).

## What it validates

```
host client ──▶ docker -p ──▶ container ──▶ qemu SLIRP hostfwd ──▶ AGNOS guest :8080
                                                                   tcp_listen(8080) → accept()
```

A green run means the AGNOS kernel's server-socket path (`sock_listen`#56 /
`sock_accept`#57, kernel `tcp_listen`/`tcp_accept`, landed agnos 1.45.5)
completes an inbound connection across the Docker boundary.

## Prerequisites (sibling repos, built)

| Input | Build command |
|---|---|
| `agnos/build/agnos` (TCP_LISTEN_SMOKE) | `cd ../../../agnos && TCP_LISTEN_SMOKE=1 sh scripts/build.sh` |
| `gnoboot/build/BOOTX64.EFI` | `cd ../../../gnoboot && CYRIUS_TARGET_EFI=1 cyrius build src/main.cyr build/BOOTX64.EFI` |

Host needs `docker` + `python3`. QEMU/OVMF/mtools live **inside** the image.

## Run

```sh
./run-sweep.sh                 # stage inputs → build image → run → assert accept
HOST_PORT=15555 ./run-sweep.sh # override the published port
```

`run-sweep.sh` stages the kernel + gnoboot into `stage/` (gitignored), builds
the image, runs it with `-p $HOST_PORT:8080`, connects from the host, and
asserts both the guest banner **and** the kernel-side `tcp_accept` serial log.
Exit 0 = AGNOS accepted in Docker.

If `/dev/kvm` is present it is passed through (`--device /dev/kvm`) for hardware
acceleration; otherwise QEMU falls back to TCG (slower boot — timeouts are sized
for it).

## Scope (per the plan)

- **Track A = correctness / weak-points**, not throughput (QEMU per-connection
  cost caps volume; raw perf stays on iron/native).
- This container is the **boot substrate**. The harness driver container
  (load/fuzz generators + the 9-dimension sweep matrix + findings ledger) and
  the long-lived **Cyrius service** containers (agora/descent/sandhi) layer on
  top once the cyrius `CYRIUS_TARGET_AGNOS` server-socket peer lands so a Cyrius
  service — not just the kernel selftest — can `bind`/`accept`.
- The `8-conn` TCP / `8-listener` UDP caps and SYN_RCVD half-open exhaustion are
  **MVP-real**: the sweep documents hitting them, it does not file them as bugs.
