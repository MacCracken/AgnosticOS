#!/usr/bin/env bash
# build.sh — assemble the agnos-mirshi-fanout image: mirshi (Linux-target
# supervisor, BUILT here so the image always carries the current mirshi) + the
# ecosystem's real agnos-target userland tools (STAGED from their sibling repos'
# build/ artifacts) + sample data. FROM scratch, no QEMU.
#
# The tool table below is the single place to add a tool: give its repo subdir,
# its agnos-target ELF path, and the command to (re)build that ELF. Missing ELFs
# fail loud with the build hint (like net-sweep's prereq table) — the vehicle
# STAGES release artifacts, it does not resolve each tool's cross-repo deps.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
repos="$(cd "$here/../../.." && pwd)"          # ~/Repos (agnosticos/docker/mirshi-fanout → up 3)
img="${IMG:-agnos-mirshi-fanout}"

# "name : repo-subdir : agnos-ELF (relative to repo) : build-hint"
# Run-once tools (iam, kii) are exercised by smoke.sh; server tools (agora) by
# serve-smoke.sh — mirshi's net band lets an agnos server accept in a container.
TOOLS=(
    "iam:iam:build/iam_agnos:cd ~/Repos/iam && cyrius build --agnos src/main.cyr build/iam_agnos"
    "kii:kii:build/kii_agnos:cd ~/Repos/kii && cyrius build --agnos src/main.cyr build/kii_agnos"
    "agora:agora:build/agora_agnos:cd ~/Repos/agora && cyrius build --agnos src/main.cyr build/agora_agnos"
    "descent:cyrius-yeomans-descent:build/descent-agnos:cd ~/Repos/cyrius-yeomans-descent && cyrius build --agnos src/main.cyr build/descent-agnos"
)

stage="$(mktemp -d)"; trap 'rm -rf "$stage"' EXIT
mkdir -p "$stage/bin" "$stage/data"

echo "==> building mirshi (Linux-target supervisor) from $repos/mirshi"
( cd "$repos/mirshi" && CYRIUS_NO_WARN_PIN_DRIFT=1 cyrius build src/main.cyr build/mirshi >/dev/null )
cp "$repos/mirshi/build/mirshi" "$stage/mirshi"

echo "==> staging agnos-target tools"
for entry in "${TOOLS[@]}"; do
    IFS=: read -r name sub bin hint <<<"$entry"
    src="$repos/$sub/$bin"
    if [ ! -x "$src" ]; then
        echo "!! missing $src — build it first:" >&2
        echo "     $hint" >&2
        exit 1
    fi
    cp "$src" "$stage/bin/$name"
    echo "   + /bin/$name  ($(wc -c <"$src") bytes)"
done

# Sample data the tools read.
cp "$repos/kii/tests/fixtures/RAMGON.png" "$stage/data/ramgon.png"    # kii render target

# descent world data — it uses ABSOLUTE /data/... paths (agnos VFS), so its world
# lives at the image root /data/ (the FROM-scratch container root IS the rootfs;
# no mirshi --root needed). Only the world is staged; descent's persist_init
# creates /data/players + /data/audit.libro fresh in the container's writable layer.
des="$repos/cyrius-yeomans-descent"
if [ -d "$des/data/zones" ]; then
    cp -r "$des/data/zones" "$stage/data/zones"
    cp "$des/data/classes.cyml" "$stage/data/classes.cyml"
    echo "   + /data/zones + /data/classes.cyml (descent world)"
fi

cp "$here/Dockerfile" "$stage/Dockerfile"
echo "==> docker build -t $img (FROM scratch)"
docker build -t "$img" "$stage" >/dev/null
docker image inspect "$img" --format '    image: {{.Size}} bytes, layers: {{len .RootFS.Layers}}' 2>/dev/null || true
echo "==> built $img"
