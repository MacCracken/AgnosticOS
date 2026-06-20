# AGNOS sched-sweep boot-and-capture container.
# Boots a mounted agnos kernel under QEMU+OVMF+gnoboot and dumps serial to
# stdout. The kernel + gnoboot are MOUNTED at runtime (-v …:/input:ro), not
# baked in — so one image serves every scheduler-selftest build (RING3 / THREAD
# / SMP). No python/netcat/networking — scheduler selftests print PASS markers
# to serial, which the host runner (sched-sweep.sh) greps.
FROM debian:stable-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
        qemu-system-x86 \
        ovmf \
        mtools \
        parted \
    && rm -rf /var/lib/apt/lists/*

COPY boot-serial.sh /usr/local/bin/boot-serial.sh
RUN chmod +x /usr/local/bin/boot-serial.sh
ENTRYPOINT ["/usr/local/bin/boot-serial.sh"]
