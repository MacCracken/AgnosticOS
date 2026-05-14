#!/usr/bin/env bash
# read-boot-log.sh — thin wrapper around the sovereign Cyrius
# implementation at src/read-boot-log.cyr.
#
# The bash version was retired 2026-05-13: /dev/nvram on
# archaemenid (AMD Beelink SER, UEFI) refuses every read with
# -EIO because the Linux nvram driver's CMOS checksum check
# rejects the BIOS's checksum layout. The Cyrius binary
# bypasses the driver via iopl(3) + direct port I/O.
#
# Usage: sudo ./scripts/read-boot-log.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/src/read-boot-log.cyr"
BIN="$SCRIPT_DIR/build/read-boot-log"

if [ ! -x "$BIN" ] || [ "$SRC" -nt "$BIN" ]; then
    echo "(rebuilding $BIN from $SRC)" >&2
    ( cd "$SCRIPT_DIR" && cyrius build src/read-boot-log.cyr build/read-boot-log >&2 )
fi

exec "$BIN" "$@"
