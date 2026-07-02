# agnos-mirshi-fanout — the ecosystem-userland fanout image.
#
# FROM scratch: mirshi (Linux-target supervisor) + the real agnos-target
# userland tools (iam, kii, …) as agnos-ABI static ELFs + sample data. No base
# OS, no shell, and — the load-bearing property — NO QEMU. The agnos tools run
# as native Linux processes under mirshi's syscall translation, sharing the host
# kernel (direction 1). Assembled by build.sh (which builds mirshi + stages the
# tool ELFs from their sibling repos).
#
# On a stock Docker whose default seccomp profile blocks ptrace, add the caps:
#   docker run --rm --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \
#     agnos-mirshi-fanout /bin/iam
#   docker run ... agnos-mirshi-fanout /bin/kii /data/ramgon.png
FROM scratch

# The Linux-target supervisor (entrypoint).
COPY mirshi /mirshi
# The agnos-target userland — agnos-ABI static ELFs mirshi supervises.
COPY bin/ /bin/
# Sample data the tools read (kii's image, etc.).
COPY data/ /data/

# mirshi is the entrypoint; the agnos tool path + its args are the arguments
# (mirshi forwards the child's argv as of v1.10.0).
ENTRYPOINT ["/mirshi"]
CMD ["/bin/iam"]
