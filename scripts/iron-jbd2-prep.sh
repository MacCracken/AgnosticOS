#!/usr/bin/env bash
# iron-jbd2-prep.sh — single-command iron-burn variant builder + flash.
#
# Wraps the agnos kernel build (with the right env-var gates) + `install-usb.sh
# --update` so each iron-burn variant is "one command + power-cycle" instead
# of "build-with-correct-flags + remember-which-flag-this-variant-needs + flash".
# Part of the agnos 1.38.9 iron-burn automation per
# `docs/development/ext4-jbd2-iron-burn-audit.md`.
#
# Variants (matches the 6-test rubric in the audit doc):
#   production     — default; covers Tests 1 (clean probe) + 6 (e2fsck post-mortem)
#   no-replay      — JBD2_NO_REPLAY=1; covers Test 2 (dirty-mount refusal)
#   replay         — production but with a pre-staged dirty journal; Tests 3 + 6
#                    (dirties /dev/nvme0n1p2's journal via mk-dirty-journal-img.py
#                    BEFORE the flash; AGNOS replays on next boot)
#   integration    — JBD2_INT_SELFTEST=1; Tests 4 + 6 (selftest opens tx,
#                    routes put_inode through journal, commits + syncs)
#   crash          — JBD2_CRASH_SELFTEST=1; Tests 5 + 6 (100-commit stress loop;
#                    USER pulls power mid-loop; subsequent boot exercises replay)
#
# Usage:
#   sh scripts/iron-jbd2-prep.sh production
#   sh scripts/iron-jbd2-prep.sh no-replay
#   sh scripts/iron-jbd2-prep.sh replay [partition_offset_bytes]   # defaults to 0 (whole-device)
#   sh scripts/iron-jbd2-prep.sh integration
#   sh scripts/iron-jbd2-prep.sh crash
#
# Per [[feedback_iron_burns_block_other_work]] + [[feedback_build_freshness_is_mine]]
# the prep IS Claude's job; this script makes it tag-stable repeatable.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
AGNOS_REPO="$(cd "$SCRIPT_DIR/../../agnos" && pwd)"

VARIANT="${1:-}"
if [ -z "$VARIANT" ]; then
    echo "usage: $0 {production|no-replay|replay|integration|crash} [partition_offset_for_replay]" >&2
    exit 1
fi

# Resolve env-var gate for the build variant.
ENV_FLAG=""
case "$VARIANT" in
    production)  ENV_FLAG="" ;;
    no-replay)   ENV_FLAG="JBD2_NO_REPLAY=1" ;;
    replay)      ENV_FLAG="" ;;                       # production kernel; dirty image is the test input
    integration) ENV_FLAG="JBD2_INT_SELFTEST=1" ;;
    crash)       ENV_FLAG="JBD2_CRASH_SELFTEST=1" ;;
    *)
        echo "ERROR: unknown variant '$VARIANT'" >&2
        echo "       valid: production no-replay replay integration crash" >&2
        exit 1
        ;;
esac

echo "=== iron-jbd2-prep: variant=$VARIANT ==="

# === Step 1: build kernel (with variant env var if any) ===
echo ""
echo "[1/3] building agnos with: ${ENV_FLAG:-<no env vars>}"
if [ -n "$ENV_FLAG" ]; then
    ( cd "$AGNOS_REPO" && env $ENV_FLAG sh scripts/build.sh )
else
    ( cd "$AGNOS_REPO" && sh scripts/build.sh )
fi
KERNEL_SIZE=$(wc -c < "$AGNOS_REPO/build/agnos")
echo "    -> build/agnos = $KERNEL_SIZE bytes"

# === Step 2 (optional): pre-stage a dirty journal for the replay variant ===
if [ "$VARIANT" = "replay" ]; then
    PART_OFFSET="${2:-0}"
    echo ""
    echo "[2/3] dirtying journal on \$NVME_DEV (default /dev/nvme0n1p2) at offset $PART_OFFSET"
    NVME_DEV="${NVME_DEV:-/dev/nvme0n1p2}"
    if [ ! -b "$NVME_DEV" ]; then
        echo "ERROR: $NVME_DEV not a block device. Set NVME_DEV=/dev/yourpart and retry." >&2
        exit 2
    fi
    sudo python3 "$AGNOS_REPO/scripts/mk-dirty-journal-img.py" "$NVME_DEV" "$PART_OFFSET" 1
    echo "    -> journal SB s_start=1 written; AGNOS will replay on next boot"
else
    echo ""
    echo "[2/3] no journal pre-stage needed for variant=$VARIANT"
fi

# === Step 3: flash via install-usb.sh --update (ESP-only; agnos-fs preserved) ===
echo ""
echo "[3/3] flashing via install-usb.sh --update (ESP refresh; agnos-fs partition preserved)"
( cd "$SCRIPT_DIR" && sh install-usb.sh --update )

echo ""
echo "=== iron-jbd2-prep: READY TO BURN ($VARIANT) ==="
echo "Next: power-cycle archaemenid. Read FB for trace + run:"
echo "    sh scripts/iron-jbd2-validate.sh   (post-burn, after rebooting back into Linux)"
