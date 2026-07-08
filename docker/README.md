# docker/ — AGNOS Container Images

Shippable AGNOS container images. Test-sweep harnesses do **not** live here — see
[What is NOT here](#what-is-not-here--qemu-in-a-container) at the bottom.

## Images

| Path | Image | Status | What it is |
|---|---|---|---|
| `Dockerfile.dev` | `agnos-dev` | **0.1.0 target** | The agnos dev userland on the **mirshi model**: `FROM scratch` + `/mirshi` (the shim) + agnos-target static ELFs (iam / kii / owl / kriya / sit / cyim / bnrmr / cmdrs) + `/data`. **No Linux base, no GNU shell, no QEMU** — the agnos tools run as native Linux processes under mirshi's syscall translation (cf. [`mirshi/docker/Dockerfile`](https://github.com/MacCracken/mirshi/blob/main/docker/Dockerfile)). Built by `build-dev.sh`. |
| `mirshi-fanout/` | `agnos-mirshi-fanout` | internal | The **native** container path: the real agnos-target userland ELF run on the host kernel via [mirshi](https://github.com/MacCracken/mirshi) (the AGNOS↔Linux syscall shim) — **no VM**. The Linux-swallow + cloud-deployability surface. Plan: [`../docs/development/planning/mirshi.md`](../docs/development/planning/mirshi.md). |
| `archive-pre-cyrius/` | — | **reference only** | 17 Rust-era Dockerfiles (Ubuntu + rustc). Historical; **do not resurrect** — AGNOS builds with `cycc` now, not Rust. |

### Build & run the dev image

`build-dev.sh` compiles `mirshi` (Linux-target) + the agnos dev tools
(agnos-target, via cyrius) and stages them into a `FROM scratch` context. Stock
Docker's default seccomp blocks `ptrace`, so add the caps to run:

```sh
docker/build-dev.sh                                  # -> agnos-dev (FROM scratch)
docker run --rm --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
  agnos-dev /bin/iam
docker run --rm --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
  agnos-dev /bin/kii /data/logo.png
```

**No interactive `agnsh` shell yet** — agnsh runs programs via `execwait#37`,
which mirshi returns ENOSYS for (the #36–39 ABI gap; mirshi has `spawn#3` /
`waitpid#4`, but agnsh binds execwait). So the image ships the agnos dev *tools*
that run within mirshi's covered surface (info-getters / fs / console / winsize /
net), one tool per `docker run`. A shell env waits on mirshi `execwait#37`
coverage.

## The installer is the ISO, not a Docker image

AGNOS installs from the **ISO `.img` / `.iso`** cut by `scripts/src/iso.cyr`
(gnoboot + agnos kernel + ext4 rootfs — see
[`../docs/development/iso-stage4-plan.md`](../docs/development/iso-stage4-plan.md)),
not from a container. `agnova` (the native installer) is the server-stage
successor. So there is **no `Dockerfile.installer`** — that role is the ISO.

## Later (deferred)

- **edge** image — thin / edge deployment.
- **aarch64** dev image — Pi / Apple-Silicon host, behind the x86 line.
- **stiva** image — when the OCI runtime ([stiva](https://github.com/MacCracken/stiva))
  ports from its Rust scaffold; a `stiva`-served container story is post-0.1.0.

## What is NOT here — QEMU-in-a-container

Running the agnos kernel under QEMU *inside* a Docker container
("VM-in-a-container") is a **dead approach**. Kernel / net / SMP validation lives
on **QEMU-direct + iron**; the container test surface is **mirshi**
(userland-native, above). The old `net-sweep` / `sched-sweep` / `descent-sweep`
harnesses were retired 2026-07-07.

**This includes the dev image.** `Dockerfile.dev` deliberately ships **no
`qemu`/`ovmf`** — you build the kernel + ecosystem and assemble media inside it,
then run the QEMU smoke battery **QEMU-direct on the host** (parsa/dev box), not
in the container.
