# descent-sweep — agnos telnet-MUD server smoke (Docker)

Boots the agnos kernel under `qemu + OVMF + gnoboot` inside a container, drives
**agnsh** (via HMP `sendkey`) to `run /bin/descent serve 4000`, then connects to
the guest over SLIRP `hostfwd` and asserts the **descent** telnet MUD accepts the
connection and serves its login flow — the end-to-end validation of descent's
agnos event-loop port (`sock_listen#56` / `sock_accept#57` + the `sleep_ms`-paced
poll loop + non-blocking `sock_recv#49` session servicing).

This is the server-stage analogue of `docker/net-sweep` (which proves the *kernel*
TCP accept path): descent-sweep proves a **ring-3 sovereign network service** —
the agnos event-loop port of a real MUD — runs where services live.

## Run

Two modes:

```sh
# 1. automated smoke — build, boot, assert, exit (CI-friendly)
./run.sh                       # exit 0 = descent accepted + served a host connection on agnos
HOST_PORT=15500 ./run.sh

# 2. interactive — boot + hold the MUD up so you can telnet in yourself
./run.sh serve                 # or:  SERVE=1 ./run.sh
HOST_PORT=15500 ./run.sh serve
```

In **serve** mode, once the container prints `★ MUD LIVE`, open the MUD from another
terminal on your host:

```sh
telnet 127.0.0.1 4444          # the HOST_PORT (default 4444)
```

You'll get the Yeoman's Descent login banner served straight off the AGNOS kernel —
pick a name, set a passphrase, and play. `Ctrl-C` in the `run.sh` terminal (or
`docker stop agnos-descent-sweep-run`) shuts the guest down.

The driver also runs standalone without Docker (`SERVE_MODE=1 python3 boot-serve.py`),
handy for local iteration.

## What PASS proves

The smoke connects, reads the banner, sends a name, and reads the reply:

```
        Y E O M A N ' S   D E S C E N T
  By what name are you known?
→ Tester
  Welcome, Tester. The Under-Grid stirs.
  ...New operative ... choose a passphrase (4-64 chars):
```

That single exchange exercises: agnsh exec-from-disk → descent serve → kernel
`tcp_listen`/`tcp_accept` over SLIRP → the telnet/session layer → the
non-blocking poll loop reading live input and replying. The serial log also shows
`persist: player saves + audit chain ready` / `filestore: open`, i.e. the libro
audit chain + `io.cyr` flock helpers run on agnos without trapping.

## Inputs (staged into `./stage/` by `run.sh`, gitignored)

| file | from |
|------|------|
| `agnos`         | `../../../agnos/build/agnos` (production kernel) |
| `BOOTX64.EFI`   | `../../../gnoboot/build/BOOTX64.EFI` |
| `agnsh_agnos`   | `../../../agnoshi/build/agnsh_agnos` |
| `descent-agnos` | `../../../cyrius-yeomans-descent/build/descent-agnos` (`cyrius build --agnos`) |
| `rootfs/`       | `../../../agnos/build/rootfs` (`/bin/agnsh` + staged tools) |

`boot-serve.py` is the driver; it also runs standalone against local sibling
repos (no Docker) — handy for fast iteration:

```sh
python3 boot-serve.py            # uses ~/Repos/* by default; HOST_PORT=4444
```

## Notes

- Uses **TCG** (`-cpu max`) to match the proven agnsh keystroke-driving path
  (`agnos/scripts/agnsh-*.py`); KVM is passed through to the container if present
  but the guest boot itself stays TCG-deterministic for the `sendkey` timing.
- Boot is slow under TCG (tens of seconds); the driver polls the serial log for
  the `agnoshi` banner before injecting the `run` command.
