# AGNOS Troubleshooting

> Last Updated: 2026-05-09
>
> **Pre-Beta note:** AGNOS is not yet a running end-user OS. This guide covers what is testable today — the sovereign boot pipeline, the Cyrius toolchain, per-subsystem builds, and the QEMU kernel boot test. Full system-level troubleshooting (services, networking, desktop) arrives with **Phase 13A** and the `agnova` installer.

---

## Table of Contents

1. [Cyrius Toolchain](#cyrius-toolchain)
2. [Sovereign Boot Pipeline](#sovereign-boot-pipeline)
3. [Component Verification](#component-verification)
4. [QEMU Kernel Boot Test](#qemu-kernel-boot-test)
5. [Per-Subsystem Builds](#per-subsystem-builds)
6. [Getting Help](#getting-help)

---

## Cyrius Toolchain

### `cyrius: command not found`

```sh
which cyrius
ls ~/.cyrius/bin/
```

Install options:
- Release tarball: see `cyrius` repo's `docs/development/roadmap.md` for download steps
- Source build: `cd /home/macro/Repos/cyrius && sh scripts/bootstrap.sh`

### Toolchain version mismatch

Every Cyrius project pins a version in `.cyrius-toolchain`:

```sh
cat /home/macro/Repos/agnosticos/scripts/.cyrius-toolchain
cyrius --version
```

If they disagree, install the pinned version (`cyriusly install <version>`) or rebuild the toolchain from source.

### `stdout` or `println` doesn't print

You are calling raw `cc5` (or its predecessor `cc3`) instead of `cyrius build`. Raw `cc5` does not auto-prepend stdlib includes. Always use:

```sh
cyrius build <source.cyr> <output>
```

### `main()` runs but the program exits 0 with no output

Cyrius executes top-level code, not `fn main()` automatically. Programs must call `main()` at the top level:

```cyrius
fn main() { ... return 0; }
var exit_code = main();
syscall(60, exit_code);
```

Study working programs in `/home/macro/Repos/cyrius/programs/*.cyr` (46 examples).

---

## Sovereign Boot Pipeline

### `cyrius build src/boot.cyr build/boot` fails

```sh
cd /home/macro/Repos/agnosticos/scripts
cyrius build src/boot.cyr build/boot
```

Common causes:

| Error | Cause | Fix |
|-------|-------|-----|
| Missing stdlib symbols | `cyrius.cyml` deps stale | `cd scripts && cyrius deps` |
| Include not found | Local source file path wrong | Paths in `src/boot.cyr` are relative to `scripts/` |
| Linker error on `syscall` | Toolchain mismatch | Check `cyrius = "<version>"` in `scripts/cyrius.cyml` matches installed `cyrius --version` |

### `./build/boot --help` prints nothing

The binary built but wasn't linked with stdlib. Re-run via `cyrius build` (not raw `cc5`).

### `make boot` fails

```sh
make boot
```

Runs `cyrius build` under the hood. If it fails, `cd scripts && cyrius build src/boot.cyr build/boot` directly to see the raw error.

---

## Component Verification

### `make iso-check` reports stale artifact

```
STALE: ../kybernet/build/kybernet (expected 1.0.2, found none)
```

The sibling repo hasn't been built. Fix:

```sh
cd /home/macro/Repos/kybernet
cyrius build src/main.cyr build/kybernet
cd /home/macro/Repos/agnosticos
make iso-check
```

### `make iso-check` reports missing repo

A sibling repo path in `scripts/src/boot.cyr` or the Makefile points to a repo that isn't cloned locally. Check `docs/architecture.md` for the canonical repo list.

### Version drift

The version each sibling reports comes from that repo's `VERSION` file. If a sibling was upgraded but `iso-check` still sees the old version, rebuild from source.

---

## QEMU Kernel Boot Test

### `make boot-test` hangs on black screen

QEMU serial is not being forwarded. Run the boot binary directly with `--serial`:

```sh
./scripts/build/boot --test --kernel ../agnos/build/agnos --serial
```

To exit QEMU: `Ctrl-a x`.

### `make boot-test` reports "kernel not found"

The AGNOS kernel isn't built. Fix:

```sh
cd /home/macro/Repos/agnos
sh scripts/build.sh
cd /home/macro/Repos/agnosticos
make boot-test
```

### Kernel boots but panics on first syscall

Most common cause: `agnos` and `agnosys` versions are out of sync. Rebuild both from current sources.

### QEMU version too old

```sh
qemu-system-x86_64 --version  # requires ≥ 7.0
```

Upgrade via your host package manager.

---

## Per-Subsystem Builds

Every subsystem builds standalone. Pattern:

```sh
cd /home/macro/Repos/<name>
cyrius build src/main.cyr build/<name>
./build/<name> --help
```

### Build fails with "dep not resolved"

```sh
cd /home/macro/Repos/<name>
cat cyrius.cyml  # check [deps.*] blocks
cyrius deps      # resolve
```

If a dep points to a sibling repo that isn't cloned, clone it from `MacCracken/<name>`.

### Tests fail after rebase

Each repo has its own test suite. Run from that repo:

```sh
cd /home/macro/Repos/<name>
cyrius test
```

Don't mix test runs across repos — each one pins its own toolchain and deps.

---

## Getting Help

- **Issue tracker**: https://github.com/MacCracken/agnosticos/issues
- **Per-subsystem issues**: file against the specific repo (`MacCracken/<name>/issues`)
- **Security issues**: see [/SECURITY.md](/SECURITY.md) for private disclosure
- **Roadmap**: [../development/roadmap.md](../development/roadmap.md)
- **Phase 13A (Beta blocker)**: tracks the ISO work that closes the "is AGNOS installable?" gap

---

## Historical Note

Prior versions of this document covered `systemctl`, `agent-runtime`, `llm-gateway`, `journalctl`, and desktop-environment issues. Those refer to a Rust-era AGNOS built on a Debian base that was retired 2026-04-01 (monolith extraction) / 2026-04-04 (Cyrius pivot). That content returns — against the sovereign stack — when `agnova` and the Phase 13A ISO ship.
