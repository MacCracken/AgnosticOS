# descent-smoke — agnos telnet-MUD bench (direct QEMU, no Debian/Docker)

> **The Debian/Docker layer was removed.** This is a **direct-QEMU dev bench** — it runs
> `qemu-system-x86_64` straight on the host (archaemenid / any Linux box with qemu + OVMF
> + mtools/parted/e2fsprogs). No container, no Debian. *(The `docker/` path is legacy and
> should be relocated — e.g. to `agnos/scripts/descent-smoke.py` alongside the other agnsh
> smokes.)*

Short-term test rig for the descent → agnos port: it boots agnos, drives **agnsh** (HMP
`sendkey`) to `run /bin/descent serve 4000`, then connects over SLIRP `hostfwd` to exercise
the socket/net syscalls + in/out traffic path (`sock_listen`#56 / `sock_accept`#57 +
the `sleep_ms` poll loop + non-blocking `sock_recv`#49). It is **not** a deployment target —
descent's real home is **bare metal** (staged into the agnos-fs, archaemenid booted on iron,
zero host OS underneath). The bench is just the dev-loop shock absorber so we don't re-burn
iron for every syscall tweak.

## Run

```sh
python3 boot-serve.py            # automated smoke: boot → run descent → telnet assert → exit
SERVE_MODE=1 python3 boot-serve.py   # interactive: hold it up, then telnet 127.0.0.1:4444
```

Env: `HOST_PORT` (default 4444), `QEMU_TIMEOUT`, plus path overrides
(`AGNOS_KERNEL` / `GNOBOOT_EFI` / `AGNSH_BIN` / `DESCENT_BIN` / `AGNOS_ROOTFS` / `DESCENT_DATA`).
Defaults resolve from `~/Repos/*`.

## Notes

- **TCG, not KVM.** agnsh keystroke injection via HMP `sendkey` is timing-sensitive — under
  KVM's fast clock agnos's xHCI key-ring drops keys (`serve` → `erve`). TCG keeps the `run`
  command intact (matches `agnos/scripts/agnsh-*.py`).
- Boots a full agnos-fs (ESP gnoboot+kernel + ext2 rootfs with `/bin/{agnsh,descent}` +
  `/data` world content), so it exercises the real exec-from-disk + persistence paths.
