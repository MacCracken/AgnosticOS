# AGNOS descent-sweep — boot agnos in a container, drive agnsh to launch the
# `descent` telnet MUD, and prove a host TCP client is accepted + served over
# SLIRP. The containerised analogue of agnos/scripts/agnsh-smoke.sh crossed with
# docker/net-sweep — it validates descent's agnos event-loop port end-to-end
# (sock_listen#56 / sock_accept#57 + the sleep_ms poll loop + sock_recv#49).
#
# Build context = agnosticos/docker/descent-sweep/ AFTER run.sh stages the
# binaries + rootfs into ./stage/ (they live in sibling repos, not this dir).
FROM debian:stable-slim

# qemu + OVMF + image-assembly tooling (mtools/parted/gdisk/e2fsprogs) + python3.
RUN apt-get update && apt-get install -y --no-install-recommends \
        qemu-system-x86 \
        ovmf \
        mtools \
        parted \
        gdisk \
        e2fsprogs \
        python3 \
    && rm -rf /var/lib/apt/lists/*

COPY stage/agnos          /opt/agnos/agnos
COPY stage/BOOTX64.EFI    /opt/agnos/BOOTX64.EFI
COPY stage/agnsh_agnos    /opt/agnos/agnsh_agnos
COPY stage/descent-agnos  /opt/agnos/descent-agnos
COPY stage/rootfs         /opt/agnos/rootfs
COPY boot-serve.py        /usr/local/bin/boot-serve.py

ENV AGNOS_KERNEL=/opt/agnos/agnos \
    GNOBOOT_EFI=/opt/agnos/BOOTX64.EFI \
    AGNSH_BIN=/opt/agnos/agnsh_agnos \
    DESCENT_BIN=/opt/agnos/descent-agnos \
    AGNOS_ROOTFS=/opt/agnos/rootfs \
    HOST_PORT=4000

# Guest :4000 is forwarded to this container port; publish it with docker -p.
EXPOSE 4000
ENTRYPOINT ["python3", "/usr/local/bin/boot-serve.py"]
