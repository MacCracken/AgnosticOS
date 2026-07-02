#!/usr/bin/env bash
# serve-smoke.sh — SERVER-mode gate for the mirshi-fanout vehicle. smoke.sh covers
# run-once tools (iam/kii); this runs each agnos SERVER (agora, descent) under
# mirshi in a plain FROM-scratch container with a published port, connects from
# the host, and asserts it served — mirshi's supervisor-emulated sock_listen#56/
# accept#57 accepting inbound in a container, no QEMU. The descent-class server
# test, containerised. Add a server: one row in SERVERS + stage its data in build.sh.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
img="${IMG:-agnos-mirshi-fanout}"
caps=(--cap-add=SYS_PTRACE --security-opt seccomp=unconfined)

"$here/build.sh"

# Host-side telnet client: connect, read the banner (strip telnet IAC / non-print).
client="$(mktemp)"; trap 'rm -f "$client"' EXIT
cat > "$client" <<'PY'
import socket, sys, time
hp = int(sys.argv[1]); deadline = time.time() + 25; data = b""
while time.time() < deadline:
    try:
        c = socket.create_connection(("127.0.0.1", hp), timeout=2); c.settimeout(3)
        try:
            for _ in range(5):
                b = c.recv(2048)
                if not b: break
                data += b
                if len(data) > 80: break
        except OSError:
            pass
        c.close()
        if data: break
    except OSError:
        time.sleep(0.3)
sys.stdout.write("".join(chr(x) for x in data if x == 10 or 32 <= x < 127))
PY

# "name : /bin/elf : serve-args (PORT is substituted) : banner assert-regex"
# mirshi flags precede the ELF; the tool's args follow it (mirshi forwards argv,
# v1.10.0). --net-listen-any binds 0.0.0.0 in the container (docker -p maps it out).
# agora uses --store; descent reads absolute /data/... world staged by build.sh.
SERVERS=(
    "agora:/bin/agora:serve PORT --store /data/agora-store:agora [0-9]"
    "descent:/bin/descent:serve PORT:YEOMAN|Under-Grid|descent"
)

fail=0; idx=0
for entry in "${SERVERS[@]}"; do
    IFS=: read -r name elf sargs assert <<<"$entry"
    port=$((4000 + idx)); host_port=$((12300 + idx)); idx=$((idx + 1))
    run_args="${sargs/PORT/$port}"
    echo "== $name under mirshi-in-docker — serve :$port -> host :$host_port =="
    cid="$(docker run -d --rm "${caps[@]}" -p "$host_port:$port" "$img" \
        --net-listen-any "$elf" $run_args)"
    out="$(python3 "$client" "$host_port")"
    if echo "$out" | grep -qiE "$assert"; then
        echo "   OK: $name served (banner reached over telnet, no QEMU)"
        echo "$out" | grep -iE "$assert" | head -1 | sed 's/^ */       /'
    else
        echo "   FAIL: $name did not serve"
        docker logs "$cid" 2>&1 | grep -viE "WARNING" | head -6 | sed 's/^/       /'
        echo "       client got: '$(echo "$out" | head -c 80)'"
        fail=1
    fi
    docker rm -f "$cid" >/dev/null 2>&1 || true
done

if [ "$fail" -eq 0 ]; then
    echo "== serve-smoke PASSED (all servers) =="
else
    echo "== serve-smoke FAILED =="; exit 1
fi
