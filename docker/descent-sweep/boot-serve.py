#!/usr/bin/env python3
# AGNOS descent-sweep — boot agnos, drive agnsh to `run /bin/descent serve`,
# then connect from the host over SLIRP hostfwd and assert the telnet MUD
# accepts a connection and serves the login flow. This validates descent's
# agnos event-loop port end-to-end: sock_listen#56 / sock_accept#57 +
# the sleep_ms-paced poll loop + non-blocking sock_recv#49 session servicing.
#
# Runnable standalone against local sibling repos, OR inside the descent-sweep
# container (binaries baked under /opt/agnos, env-overridden below).
#
# PASS = agnsh launches /bin/descent, descent prints "listening", a host TCP
# connection is accepted, the client receives the login banner, AND descent
# responds to a sent name (the poll loop services the live session).
import os, sys, time, socket, subprocess, shutil

REPOS   = os.environ.get("REPOS", os.path.expanduser("~/Repos"))
KERNEL  = os.environ.get("AGNOS_KERNEL", f"{REPOS}/agnos/build/agnos")
GNOBOOT = os.environ.get("GNOBOOT_EFI",  f"{REPOS}/gnoboot/build/BOOTX64.EFI")
AGNSH   = os.environ.get("AGNSH_BIN",    f"{REPOS}/agnoshi/build/agnsh_agnos")
DESCENT = os.environ.get("DESCENT_BIN",  f"{REPOS}/cyrius-yeomans-descent/build/descent-agnos")
ROOTFS  = os.environ.get("AGNOS_ROOTFS", f"{REPOS}/agnos/build/rootfs")
PORT    = int(os.environ.get("HOST_PORT", "4444"))    # forwarded -> guest :4000

WORK = "/tmp/descent-sweep"
IMG, SER, MON, SEED = (f"{WORK}/agnos-descent.img", f"{WORK}/serial.log",
                       f"{WORK}/mon.sock", f"{WORK}/seed")
PART_OFFSET = 33 * 1048576
PART_BLOCKS = (67 * 1048576) // 4096
EXT2_FEATURES = "^resize_inode,^dir_index,^metadata_csum,^64bit,^uninit_bg"

def p(*a): print(*a, flush=True)
def die(m): p("FAIL:", m); sys.exit(1)

for f in (KERNEL, GNOBOOT, AGNSH, DESCENT):
    if not os.path.isfile(f): die(f"missing input: {f}")
if not os.path.isdir(ROOTFS): die(f"missing rootfs: {ROOTFS}")

OVMF_CODE = next((c for c in [
    "/usr/share/edk2/x64/OVMF_CODE.4m.fd", "/usr/share/edk2/x64/OVMF_CODE.fd",
    "/usr/share/OVMF/OVMF_CODE_4M.fd", "/usr/share/OVMF/OVMF_CODE.fd",
    "/usr/share/edk2-ovmf/x64/OVMF_CODE.fd", "/usr/share/qemu/OVMF_CODE.fd",
] if os.path.isfile(c)), None)
OVMF_VARS = next((c for c in [
    "/usr/share/edk2/x64/OVMF_VARS.4m.fd", "/usr/share/edk2/x64/OVMF_VARS.fd",
    "/usr/share/OVMF/OVMF_VARS_4M.fd", "/usr/share/OVMF/OVMF_VARS.fd",
    "/usr/share/edk2-ovmf/x64/OVMF_VARS.fd", "/usr/share/qemu/OVMF_VARS.fd",
] if os.path.isfile(c)), None)
if not OVMF_CODE or not OVMF_VARS: die("OVMF firmware not found")

def sh(cmd):
    r = subprocess.run(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    if r.returncode != 0: die(f"build step `{cmd}`: {r.stderr.decode('latin1')[:300]}")

# --- assemble GPT image: ESP (gnoboot+kernel) + ext2 (rootfs + /bin/descent) ---
shutil.rmtree(WORK, ignore_errors=True); os.makedirs(WORK, exist_ok=True)
subprocess.run(["cp", "-a", ROOTFS, SEED], check=True)
shutil.copy(DESCENT, f"{SEED}/bin/descent"); os.chmod(f"{SEED}/bin/descent", 0o755)
if not os.path.isfile(f"{SEED}/bin/agnsh"):
    shutil.copy(AGNSH, f"{SEED}/bin/agnsh"); os.chmod(f"{SEED}/bin/agnsh", 0o755)
# World content: descent loads data/zones/*.cyml + data/classes.cyml via relative
# paths (CWD-relative; agnos's process CWD is "/"), so place them at the agnos-fs
# root's /data — without this the server runs "roomless" (no zone). data/players
# is created empty for persisted saves.
DESCENT_DATA = os.environ.get("DESCENT_DATA",
                              os.path.join(os.path.dirname(os.path.dirname(DESCENT)), "data"))
staged_data = False
if os.path.isdir(DESCENT_DATA):
    os.makedirs(f"{SEED}/data/players", exist_ok=True)
    if os.path.isdir(f"{DESCENT_DATA}/zones"):
        shutil.copytree(f"{DESCENT_DATA}/zones", f"{SEED}/data/zones", dirs_exist_ok=True)
    if os.path.isfile(f"{DESCENT_DATA}/classes.cyml"):
        shutil.copy(f"{DESCENT_DATA}/classes.cyml", f"{SEED}/data/classes.cyml")
    staged_data = True
p(f"seed: /bin/descent ({os.path.getsize(DESCENT)} B) + /bin/agnsh"
  + (" + /data (zones + classes)" if staged_data else " (NO data — will run roomless!)"))
sh(f"dd if=/dev/zero of={IMG} bs=1M count=128 status=none")
sh(f"parted -s {IMG} mklabel gpt mkpart ESP fat32 1MiB 33MiB set 1 esp on mkpart agnos-fs ext2 33MiB 100MiB")
sh(f"sgdisk -t 2:8300 {IMG} >/dev/null")
sh(f"mformat -i {IMG}@@1048576 -F")
sh(f"mmd -i {IMG}@@1048576 ::EFI ::EFI/BOOT ::boot")
sh(f"mcopy -i {IMG}@@1048576 {GNOBOOT} ::EFI/BOOT/BOOTX64.EFI")
sh(f"mcopy -i {IMG}@@1048576 {KERNEL} ::boot/agnos")
sh(f"mkfs.ext2 -F -q -L AGNOS-DESC -b 4096 -m 0 -O {EXT2_FEATURES} -d {SEED} -E offset={PART_OFFSET} {IMG} {PART_BLOCKS}")
shutil.copy(OVMF_VARS, f"{WORK}/vars.fd"); os.chmod(f"{WORK}/vars.fd", 0o644)
open(SER, "w").close()
try: os.unlink(MON)
except FileNotFoundError: pass
p(f"booting agnos — guest :4000 -> host :{PORT} (TCG; this is slow)")

# Pin TCG (-cpu max), NOT KVM. agnsh keystroke injection via HMP `sendkey` is
# timing-sensitive: under KVM's fast clock agnos's xHCI key-ring drops keys
# (chars vanish mid-line — `serve` typed as `erve`/`sere`), regardless of the
# inter-key delay. TCG keeps keystrokes deterministic (matches agnos's own
# scripts/agnsh-*.py). Boot is slower, but the `run` command lands intact.
qemu = subprocess.Popen([
    "qemu-system-x86_64", "-machine", "q35", "-m", "512M", "-cpu", "max",
    "-drive", f"if=pflash,format=raw,readonly=on,file={OVMF_CODE}",
    "-drive", f"if=pflash,format=raw,file={WORK}/vars.fd",
    "-drive", f"file={IMG},format=raw,if=none,id=disk0",
    "-device", "nvme,drive=disk0,serial=AGNOS-DESC",
    "-device", "qemu-xhci,id=xhci", "-device", "usb-kbd,bus=xhci.0",
    "-netdev", f"user,id=u1,hostfwd=tcp::{PORT}-:4000",
    "-device", "virtio-net-pci,netdev=u1",
    "-serial", f"file:{SER}", "-display", "none", "-no-reboot",
    "-monitor", f"unix:{MON},server,nowait",
], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

rc = 1
try:
    s = None
    for _ in range(80):
        try: s = socket.socket(socket.AF_UNIX); s.connect(MON); break
        except OSError: time.sleep(0.2)
    if s is None: die("no QEMU monitor")
    s.settimeout(1.0)
    def drain():
        try:
            while True: s.recv(65536)
        except OSError: pass
    def ser():
        try: return open(SER, "rb").read().decode("latin1")
        except OSError: return ""
    km = {' ': 'spc', '\n': 'ret', '-': 'minus', '.': 'dot', '/': 'slash'}
    def typ(word, settle=1.0):
        for ch in word:
            key = km.get(ch, ch)
            if ch.isupper(): key = "shift-" + ch.lower()
            s.sendall(("sendkey " + key + "\n").encode()); time.sleep(0.10); drain()
        time.sleep(settle)

    ok = False
    for _ in range(900):
        if "agnoshi" in ser(): ok = True; break
        time.sleep(0.25)
    p("agnsh banner:", ok)
    if not ok:
        p("=== serial tail ==="); p(ser()[-800:]); die("agnsh did not launch")
    time.sleep(1.0)

    # HMP sendkey occasionally drops a key even on TCG (e.g. `run`->`ru`), which
    # leaves agnsh with a bad command. Type, verify the agnsh echo shows the whole
    # command intact, and retry on a drop (a wrong command just re-prompts).
    def type_cmd(cmd, tries=5):
        for _ in range(tries):
            before = len(ser())
            typ(cmd + "\n", settle=1.0)
            time.sleep(0.5)
            if cmd in ser()[before:]:
                return True            # echoed intact + submitted
            p(f"  (keystroke drop typing '{cmd}' — retrying)")
            time.sleep(0.4)
        return False

    mark = len(ser())
    if not type_cmd("run /bin/descent serve 4000"):
        p("=== serial tail ==="); p(ser()[-500:]); die("could not type the run command (keystroke drops)")
    listening = False
    deadline = time.time() + 60
    while time.time() < deadline:
        seg = ser()[mark:]
        if "listening on port" in seg or "starting event-loop listener" in seg:
            listening = True; break
        time.sleep(0.5)
    p("descent listening:", listening)
    time.sleep(1.0)

    if os.environ.get("SERVE_MODE"):
        # Interactive: hold the box up so a telnet client on YOUR host can play
        # the MUD through the published port. No auto-assert — runs until stopped.
        if not listening:
            p("=== serial tail ==="); p(ser()[-700:]); die("descent did not reach 'listening'")
        pub = os.environ.get("PUBLISHED_PORT", str(PORT))
        p("")
        p("  ================================================================")
        p("   ★ MUD LIVE — descent is serving on agnos (guest :4000).")
        p(f"   Telnet in from your host:   telnet 127.0.0.1 {pub}")
        p("   (Ctrl-C, or `docker stop`, to shut the guest down.)")
        p("  ================================================================")
        p("")
        try:
            qemu.wait()                 # block until the container/guest is stopped
        except KeyboardInterrupt:
            pass
        rc = 0
    else:
        banner = b""; resp = b""
        try:
            c = socket.create_connection(("127.0.0.1", PORT), timeout=10); c.settimeout(8)
            time.sleep(0.5)
            try: banner = c.recv(1024)
            except socket.timeout: pass
            c.sendall(b"Tester\r\n"); time.sleep(2.5)   # dwell across one 2.5s combat tick
            try: resp = c.recv(2048)
            except socket.timeout: pass
            c.close()
        except Exception as e:
            p("telnet error:", e)

        accepted, responded = bool(banner), bool(resp)
        p("=== client banner (printable) ==="); p("".join(ch if 32 <= ord(ch) < 127 or ch in "\r\n" else "." for ch in banner.decode("latin1"))[:400] or "(none)")
        p("=== client response after name ==="); p("".join(ch if 32 <= ord(ch) < 127 or ch in "\r\n" else "." for ch in resp.decode("latin1"))[:400] or "(none)")
        p("=== serial tail ==="); p(ser()[-700:])
        if listening and accepted and responded:
            p("descent-sweep: PASS — agnsh launched descent; host TCP accepted; login banner + name-response served on agnos")
            rc = 0
        else:
            p(f"descent-sweep: FAIL (listening={listening} accepted={accepted} responded={responded})")
        s.sendall(b"quit\n"); time.sleep(0.2)
finally:
    qemu.terminate()
    try: qemu.wait(timeout=3)
    except subprocess.TimeoutExpired: qemu.kill()
sys.exit(rc)
