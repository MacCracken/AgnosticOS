#!/bin/bash
# AGNOS net-sweep — Track-A boot-container smoke runner (host side).
#
# Stages the kernel + gnoboot from the sibling repos, builds the boot
# container, runs it with a published port, connects from the host, and
# asserts AGNOS accepted the inbound TCP connection inside Docker.
#
# This is the containerised analogue of agnos/scripts/tcp-listen-smoke.sh:
# it proves "AGNOS runs where services live" — the foundational Track-A
# capability of the Docker service-sweep harness.
#
# Usage:  ./run-sweep.sh            # build + run + assert, then clean up
#         HOST_PORT=15555 ./run-sweep.sh
#
# Exit 0 = AGNOS accepted the connection in the container; 1 = failed.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPOS="$(cd "$HERE/../../.." && pwd)"          # /home/macro/Repos
AGNOS_KERNEL="$REPOS/agnos/build/agnos"
GNOBOOT_EFI="$REPOS/gnoboot/build/BOOTX64.EFI"
IMAGE="agnos-net-sweep"
CTR="agnos-net-sweep-run"
HOST_PORT="${HOST_PORT:-15555}"
BOOT_TIMEOUT="${BOOT_TIMEOUT:-90}"

red() { printf '\033[31m%s\033[0m\n' "$*"; }
grn() { printf '\033[32m%s\033[0m\n' "$*"; }

cleanup() { docker rm -f "$CTR" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# --- 1. validate inputs -----------------------------------------------------
[ -f "$AGNOS_KERNEL" ] || { red "kernel not built: $AGNOS_KERNEL"; echo "  build it: cd $REPOS/agnos && TCP_LISTEN_SMOKE=1 sh scripts/build.sh"; exit 1; }
[ -f "$GNOBOOT_EFI" ]  || { red "gnoboot not built: $GNOBOOT_EFI"; echo "  build it: cd $REPOS/gnoboot && CYRIUS_TARGET_EFI=1 cyrius build src/main.cyr build/BOOTX64.EFI"; exit 1; }
if ! strings "$AGNOS_KERNEL" | grep -q "tcp_listen(8080)"; then
    red "kernel was NOT built with TCP_LISTEN_SMOKE=1 (no listen hook)"
    echo "  rebuild: cd $REPOS/agnos && TCP_LISTEN_SMOKE=1 sh scripts/build.sh"
    exit 1
fi

# --- 2. stage build inputs into the build context --------------------------
echo "==> staging kernel + gnoboot into build context"
mkdir -p "$HERE/stage"
cp "$AGNOS_KERNEL" "$HERE/stage/agnos"
cp "$GNOBOOT_EFI"  "$HERE/stage/BOOTX64.EFI"

# --- 3. build the image ----------------------------------------------------
echo "==> docker build $IMAGE"
docker build -t "$IMAGE" "$HERE" || { red "docker build failed"; exit 1; }

# --- 4. run the boot container ---------------------------------------------
KVM_ARG=""
if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    KVM_ARG="--device /dev/kvm"
    echo "==> /dev/kvm available — passing through for hardware accel"
else
    echo "==> no /dev/kvm — container will use TCG (slower boot)"
fi
cleanup
echo "==> docker run $IMAGE (publishing :$HOST_PORT)"
docker run -d --rm --name "$CTR" $KVM_ARG \
    -e "QEMU_TIMEOUT=$BOOT_TIMEOUT" \
    -p "$HOST_PORT:8080" "$IMAGE" >/dev/null || { red "docker run failed"; exit 1; }

# --- 5. probe from the host: connect through Docker -> SLIRP -> AGNOS -------
echo "==> probing AGNOS tcp_listen(8080) via host :$HOST_PORT (boot takes time under TCG)"
banner=""
for _ in $(seq 1 40); do
    sleep 3
    docker ps -q -f "name=$CTR" | grep -q . || { red "container exited early"; break; }
    banner="$(python3 - "$HOST_PORT" <<'PY'
import socket, sys
try:
    s = socket.create_connection(("127.0.0.1", int(sys.argv[1])), timeout=3)
    s.settimeout(3)
    data = s.recv(256); s.close()
    sys.stdout.buffer.write(data or b"")
except Exception:
    pass
PY
)"
    [ -n "$banner" ] && break
done

# --- 6. assert -------------------------------------------------------------
echo "------------------------------------------------------------------"
logs="$(docker logs "$CTR" 2>&1 || true)"
accepted=0
echo "$logs" | grep -q "tcp_accept" && accepted=1

if [ -n "$banner" ] && [ "$accepted" -eq 1 ]; then
    grn "PASS — AGNOS accepted an inbound TCP connection inside Docker"
    echo "  banner from guest : $(printf '%s' "$banner" | tr -d '\r')"
    echo "  kernel accept log : $(echo "$logs" | grep -m1 'tcp_accept')"
    exit 0
fi

red "FAIL — AGNOS did not complete an accept in the container"
echo "  banner received   : '${banner:-<none>}'"
echo "  kernel accept log : $([ "$accepted" -eq 1 ] && echo present || echo ABSENT)"
echo "  --- last serial lines ---"
echo "$logs" | tail -20
exit 1
