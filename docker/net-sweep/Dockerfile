# AGNOS net-sweep boot container (Track-A step 3).
# Boots the agnos kernel under QEMU+OVMF+gnoboot inside a container so an
# external client can reach AGNOS's ring-3 / kernel TCP accept path over SLIRP.
#
# Build context = agnosticos/docker/net-sweep/ AFTER run-sweep.sh stages the
# kernel + gnoboot into ./stage/ (they live in sibling repos, not this dir).
#
#   ../../  -> agnosticos repo root
#   stage/agnos        — TCP_LISTEN_SMOKE kernel  (from ../../../agnos/build/agnos)
#   stage/BOOTX64.EFI  — gnoboot UEFI app         (from ../../../gnoboot/build/BOOTX64.EFI)
FROM debian:stable-slim

# qemu + OVMF firmware + ESP-assembly tooling (mtools/parted) + a probe client.
RUN apt-get update && apt-get install -y --no-install-recommends \
        qemu-system-x86 \
        ovmf \
        mtools \
        parted \
        python3 \
        netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

COPY stage/agnos        /opt/agnos/agnos
COPY stage/BOOTX64.EFI  /opt/agnos/BOOTX64.EFI
COPY boot-listen.sh     /usr/local/bin/boot-listen.sh
RUN chmod +x /usr/local/bin/boot-listen.sh

# Guest :8080 is forwarded to this container port; publish it with docker -p.
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/boot-listen.sh"]
