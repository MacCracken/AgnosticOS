#!/usr/bin/env bash
# iron-jbd2-validate.sh — post-burn validation: read CMOS JBD2 stamps + run
# e2fsck on the agnos-fs partition + inspect journal SB on disk.
#
# Run AFTER booting back into Linux from an archaemenid iron burn. Reports:
#   - JBD2 CMOS telemetry (0xA0-0xA4 — probe outcome / replay attempt-outcome-count / commit-tx count)
#   - host `e2fsck -fn` on the agnos-fs partition (the dispositive gate)
#   - on-disk journal SB state (s_start / s_sequence / magic)
#
# Part of the agnos 1.38.9 iron-burn automation per
# `docs/development/ext4-jbd2-iron-burn-audit.md`.
#
# Usage:
#   sudo sh scripts/iron-jbd2-validate.sh
#   sudo NVME_DEV=/dev/nvme0n1p2 sh scripts/iron-jbd2-validate.sh
#
# Read-only on disk; safe to run after any burn.

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NVME_DEV="${NVME_DEV:-/dev/nvme0n1p2}"
PART_OFFSET="${PART_OFFSET:-0}"

echo "=== iron-jbd2-validate ==="

# === 1. CMOS JBD2 telemetry (via the Cyrius read-boot-log binary) ===
echo ""
echo "[1/3] CMOS JBD2 telemetry (jbd2 lines from read-boot-log)"
if [ "$(id -u)" != "0" ]; then
    echo "    SKIP: requires sudo (port I/O for CMOS read). Re-run with sudo for telemetry."
else
    READ_BOOT_LOG="$SCRIPT_DIR/read-boot-log.sh"
    if [ -x "$READ_BOOT_LOG" ]; then
        # Show the JBD2-specific section. The full read-boot-log output is long;
        # filter to the new section + any warn lines.
        "$READ_BOOT_LOG" 2>/dev/null | awk '/JBD2 iron-burn telemetry/,/^$/' | sed 's/^/    /'
    else
        echo "    ERROR: $READ_BOOT_LOG not found"
    fi
fi

# === 2. Host e2fsck -fn on the agnos-fs partition (dispositive) ===
echo ""
echo "[2/3] host e2fsck -fn on $NVME_DEV"
if [ ! -b "$NVME_DEV" ]; then
    echo "    ERROR: $NVME_DEV not a block device. Set NVME_DEV=/dev/yourpart and retry."
else
    if e2fsck -fn "$NVME_DEV" 2>&1 | sed 's/^/    /'; then
        echo "    PASS: e2fsck -fn clean"
    else
        rc=$?
        echo "    FAIL: e2fsck -fn returned $rc"
    fi
fi

# === 3. Journal-SB on-disk inspection (Python — no driver dependency) ===
echo ""
echo "[3/3] post-burn journal SB on disk"
python3 - "$NVME_DEV" "$PART_OFFSET" <<'PY' 2>&1 | sed 's/^/    /'
import struct, sys
img = sys.argv[1]; part_off = int(sys.argv[2])
try:
    with open(img, 'rb') as f:
        f.seek(part_off + 1024); sb = f.read(1024)
        if len(sb) < 1024:
            print(f"SHORT FS-SB read ({len(sb)} B)"); sys.exit(2)
        bs = 1024 << struct.unpack_from('<I', sb, 24)[0]
        first_data_block = struct.unpack_from('<I', sb, 20)[0]
        inodes_per_group = struct.unpack_from('<I', sb, 40)[0]
        inode_size = struct.unpack_from('<H', sb, 88)[0] or 128
        j_inum = struct.unpack_from('<I', sb, 224)[0]
        feature_incompat = struct.unpack_from('<I', sb, 96)[0]
        desc_size = struct.unpack_from('<H', sb, 254)[0] or 32
        is_64bit = bool(feature_incompat & 0x80)
        if j_inum == 0:
            print("no journal (s_journal_inum=0)"); sys.exit(0)
        j_index = j_inum - 1
        j_group = j_index // inodes_per_group
        bgdt_off = part_off + (first_data_block + 1) * bs + j_group * desc_size
        f.seek(bgdt_off); bgdt = f.read(desc_size)
        itab_lo = struct.unpack_from('<I', bgdt, 8)[0]
        itab_hi = struct.unpack_from('<I', bgdt, 32)[0] if (is_64bit and desc_size >= 64) else 0
        itab_block = (itab_hi << 32) | itab_lo
        inode_off = part_off + itab_block * bs + (j_index % inodes_per_group) * inode_size
        f.seek(inode_off); inode = f.read(inode_size)
        flags = struct.unpack_from('<I', inode, 32)[0]
        if flags & 0x80000:
            ee_start_hi = struct.unpack_from('<H', inode, 58)[0]
            ee_start_lo = struct.unpack_from('<I', inode, 60)[0]
            first_phys = (ee_start_hi << 32) | ee_start_lo
        else:
            first_phys = struct.unpack_from('<I', inode, 40)[0]
        f.seek(part_off + first_phys * bs); jsb = f.read(1024)
        magic = struct.unpack_from('>I', jsb, 0)[0]
        s_sequence = struct.unpack_from('>I', jsb, 24)[0]
        s_start = struct.unpack_from('>I', jsb, 28)[0]
        print(f"journal inode={j_inum} first_phys={first_phys}")
        print(f"journal SB: magic=0x{magic:08x} s_start={s_start} s_sequence={s_sequence}")
        if magic != 0xC03B3998: print(f"WARN: bad magic"); sys.exit(3)
        if s_start == 0:
            print(f"VERDICT: journal CLEAN (s_start=0; next-expected seq={s_sequence})")
        else:
            print(f"VERDICT: journal DIRTY (s_start={s_start}; AGNOS replay didn't run or didn't clean)")
except Exception as e:
    print(f"ERROR: {e}"); sys.exit(1)
PY

echo ""
echo "=== iron-jbd2-validate: done ==="
