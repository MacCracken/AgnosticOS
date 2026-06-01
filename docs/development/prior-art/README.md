# Prior-Art & Iron-Burn-Audit Archive

Multi-source prior-art research and iron-burn audit docs for **completed (or dead-end) kernel arcs**.
Consolidated here 2026-05-31 to keep `docs/development/` focused on live/forward docs (state, roadmap,
active iron logs, current-reference bring-up docs).

These are **dated engineering artifacts** — they record the research/audit that drove a shipped arc and the
hardware-burn evidence that validated it. Per the doc-audit discipline they are **not refreshed in place**;
they go *dated*, not stale. Read them for the convergent-prior-art reasoning behind a subsystem, not for
current state (current state → [`../state.md`](../state.md)).

**Active research stays in `../` (not here):** `shell-separation-prior-art.md` (1.41.x, open),
`uefi-boot-prior-art.md` + `path-c-sovereign-uefi.md` (current production bring-up reference),
`exec-iron-manual-tests.md` + `iron-bring-up-process.md` (process). The agnos kernel's normative syscall ABI
contract lives in the **agnos** repo (`agnos/docs/development/agnos-userland-abi.md`).

| Arc | Docs |
|-----|------|
| Storage (1.31.x) | `ext2-iron-burn-audit`, `ext4-64bit-prior-art`, `ext2-ext4-extents-prior-art`, `ahci-iron-burn-audit`, `usb-ms-iron-burn-audit`, `msc-reset-recovery-prior-art`, `ramdisk-virtio-modern-prior-art`, `xhci-prior-art-audit` |
| Networking (1.32.x) | `network-arc-prior-art`, `r8169-{iron-burn,chip-init,rx-path,tally-counter,tx-wedge}-audit`, `r8169-live-linux-register-dump-2026-05-25`, `dhcp-{end-to-end,offer-downstream,and-outbound-l3-audit-2026-05-24,probe-vs-kernel-diff}`, `virtio-net-legacy-layout-audit` |
| ext2/4 WRITE + extents + jbd2 (1.33/1.37/1.38) | `ext2-ext4-write-prior-art`, `flush-cache-prior-art`, `metadata-csum-write-iron-burn-audit`, `ext4-extent-alloc-prior-art`, `ext4-jbd2-prior-art`, `ext4-jbd2-iron-burn-audit` |
| FAT-family (1.34.x) | `fat-family-prior-art`, `exfat-prior-art` |
| Comms substrate (1.35.x) | `dns-stub-resolver-prior-art`, `tcp-hardening-prior-art`, `ntp-sntp-prior-art`, `rtc-boot-clock-prior-art`, `mmap-prior-art`, `arc-close-hardening-1-35` |
| Refactor / VFS / exec (1.36/1.39/1.40) | `refactor-net-cyr-split`, `vfs-generic-write-prior-art`, `exec-from-disk-prior-art` |
| Dead-end / superseded | `path-a-elf64-multiboot2` (GRUB MB2-EFI W^X blocker → Path C), `true-font-swap-plan` (1.30.12, done) |
