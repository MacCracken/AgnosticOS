#!/bin/bash
# AGNOS descent-sweep — host-side runner.
#
# Stages the kernel + gnoboot + agnsh + descent + rootfs from the sibling repos,
# builds the boot container, and runs the descent telnet-MUD smoke inside it:
# boot agnos -> drive agnsh `run /bin/descent serve 4000` -> connect over SLIRP
# and assert the login banner + a name-response are served on agnos.
#
# Exit 0 = descent accepted + served a host connection on agnos; 1 = failed.
#
# Usage:  ./run.sh                 # build descent if needed, then build + run
#         HOST_PORT=15500 ./run.sh # publish the guest MUD on a host port too
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
REPOS="$(cd "$HERE/../../.." && pwd)"          # /home/macro/Repos
KERNEL="$REPOS/agnos/build/agnos"
GNOBOOT="$REPOS/gnoboot/build/BOOTX64.EFI"
AGNSH="$REPOS/agnoshi/build/agnsh_agnos"
DESCENT="$REPOS/cyrius-yeomans-descent/build/descent-agnos"
ROOTFS="$REPOS/agnos/build/rootfs"
IMAGE="agnos-descent-sweep"; CTR="agnos-descent-sweep-run"
HOST_PORT="${HOST_PORT:-4444}"

red(){ printf '\033[31m%s\033[0m\n' "$*"; }
grn(){ printf '\033[32m%s\033[0m\n' "$*"; }
cleanup(){ docker rm -f "$CTR" >/dev/null 2>&1 || true; }
trap cleanup EXIT

# --- build descent --agnos if missing --------------------------------------
if [ ! -f "$DESCENT" ]; then
    echo "==> building descent --agnos"
    ( cd "$REPOS/cyrius-yeomans-descent" && cyrius build --agnos src/main.cyr build/descent-agnos ) \
        || { red "descent --agnos build failed"; exit 1; }
fi
for f in "$KERNEL" "$GNOBOOT" "$AGNSH" "$DESCENT"; do
    [ -f "$f" ] || { red "missing input: $f"; exit 1; }
done
[ -d "$ROOTFS" ] || { red "missing rootfs: $ROOTFS"; exit 1; }

# --- stage inputs into the build context -----------------------------------
echo "==> staging kernel + gnoboot + agnsh + descent + rootfs"
rm -rf "$HERE/stage"; mkdir -p "$HERE/stage"
cp    "$KERNEL"  "$HERE/stage/agnos"
cp    "$GNOBOOT" "$HERE/stage/BOOTX64.EFI"
cp    "$AGNSH"   "$HERE/stage/agnsh_agnos"
cp    "$DESCENT" "$HERE/stage/descent-agnos"
cp -a "$ROOTFS"  "$HERE/stage/rootfs"

# --- build + run ------------------------------------------------------------
echo "==> docker build $IMAGE"
docker build -t "$IMAGE" "$HERE" || { red "docker build failed"; exit 1; }

KVM_ARG=""
if [ -e /dev/kvm ] && [ -r /dev/kvm ] && [ -w /dev/kvm ]; then
    KVM_ARG="--device /dev/kvm"
fi
cleanup
# `serve` mode (./run.sh serve  or  SERVE=1 ./run.sh): boot agnos + descent and
# HOLD it up so you can telnet into the MUD yourself from the host. Otherwise the
# default is the automated assert-and-exit smoke.
if [ "${1:-}" = "serve" ] || [ "${SERVE:-}" = "1" ]; then
    grn "==> interactive serve — boot agnos + descent, publish guest :4000 on host :$HOST_PORT"
    echo "    once you see '★ MUD LIVE', from another terminal:   telnet 127.0.0.1 $HOST_PORT"
    echo "    (Ctrl-C here, or 'docker stop $CTR', to shut the guest down)"
    exec docker run --rm -it --name "$CTR" $KVM_ARG \
        -e SERVE_MODE=1 -e "HOST_PORT=4000" -e "PUBLISHED_PORT=$HOST_PORT" \
        -p "$HOST_PORT:4000" "$IMAGE"
fi
echo "==> docker run $IMAGE (smoke; guest MUD :4000 published on host :$HOST_PORT)"
docker run --rm --name "$CTR" $KVM_ARG -e "HOST_PORT=4000" -p "$HOST_PORT:4000" "$IMAGE"
rc=$?
echo "------------------------------------------------------------------"
[ "$rc" -eq 0 ] && grn "descent-sweep: PASS — descent served a connection on agnos in Docker" \
                || red "descent-sweep: FAIL (exit $rc)"
exit $rc
