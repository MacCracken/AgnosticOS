#!/usr/bin/env bash
# read-boot-log.sh — dump the AGNOS kernel boot checkpoint trail from
# CMOS scratch RAM after an iron-boot test.
#
# Background: agnos kernel writes a one-byte checkpoint value to
# CMOS[0x40] at successive points in early boot, and a magic byte
# (0xAB) to CMOS[0x41] at entry. CMOS is battery-backed, so the
# values survive the reset that follows a kernel triple-fault. After
# the box reboots back into Linux, this script reads them.
#
# See agnos/kernel/arch/x86_64/boot_shim.cyr ELF64 path for the
# checkpoint writes themselves. See agnosticos/docs/development/
# iron-boot-testing-log.md § Attempt 8 for the diagnostic flow.

set -euo pipefail

NVRAM=/dev/nvram

if [ ! -r "$NVRAM" ]; then
    echo "error: $NVRAM not readable — try sudo, or load the nvram module:" >&2
    echo "  sudo modprobe nvram && sudo $0" >&2
    exit 1
fi

# /dev/nvram on Linux x86 starts at CMOS offset 0x0E (the 14 RTC
# bytes 0x00-0x0D are NOT exposed). So CMOS offset 0x40 maps to
# /dev/nvram offset 0x40 - 0x0E = 0x32. Same +(-0x0E) shift for 0x41.
CMOS_BASE_OFFSET=14    # 0x0E
CHECKPOINT_CMOS=64     # 0x40
MAGIC_CMOS=65          # 0x41

# Read the two relevant bytes.
checkpoint=$(dd if="$NVRAM" bs=1 count=1 skip=$((CHECKPOINT_CMOS - CMOS_BASE_OFFSET)) 2>/dev/null | od -An -tu1 | tr -d ' ')
magic=$(dd if="$NVRAM" bs=1 count=1 skip=$((MAGIC_CMOS - CMOS_BASE_OFFSET)) 2>/dev/null | od -An -tu1 | tr -d ' ')

printf 'CMOS[0x41] magic    = 0x%02X\n' "$magic"
printf 'CMOS[0x40] checkpt  = 0x%02X (decimal %d)\n' "$checkpoint" "$checkpoint"
echo

if [ "$magic" != "171" ]; then    # 0xAB = 171 decimal
    echo "verdict: kernel did NOT run this boot."
    echo "  Magic byte at CMOS[0x41] is 0x$(printf '%02X' "$magic"), not 0xAB."
    echo "  Either gnoboot never handed off, or the first kernel instruction"
    echo "  (the CMOS magic write) faulted before completing."
    exit 0
fi

case "$checkpoint" in
    1) verdict="kernel reached entry (instruction 1) but died before the visual canary." ;;
    2) verdict="kernel ran the canary loop, died before stack setup." ;;
    3) verdict="kernel set up the stack, died before COM1 UART init." ;;
    4) verdict="kernel finished COM1 init, died inside boot_info_capture_rdi() or before it returned." ;;
    5) verdict="kernel survived boot_info_capture_rdi(); fault is later in top-level kernel init (gdt_init, idt_init, paging, scheduler, ...)." ;;
    *) verdict="unexpected checkpoint value — possibly stale CMOS or a checkpoint not yet defined in this kernel build." ;;
esac

echo "verdict: $verdict"
