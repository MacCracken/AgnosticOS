# RTC Boot Clock — Design + Prior-Art Note

> **Status**: design complete, drives agnos **1.35.5**. The companion to 1.35.2's NTP/SNTP: NTP sets a wall clock *from the network*; the RTC sets one *locally* at boot, so the kernel knows the time even with no network or no reachable SNTP server. NTP then refines/overrides it.
>
> **Scope**: read the MC146818 CMOS RTC once at boot, convert to Unix seconds, seed the existing wall-clock base (`net_unix_time` / `net_ntp_synctick`). No RTC *writes* (no `hwclock --systohc`), no periodic re-read, no alarm/IRQ8 wiring.
>
> **Created**: 2026-05-27.

---

## 1. Why now

1.35.2 gave the kernel its first wall clock, but only via a successful SNTP round-trip — the NTP audit explicitly flagged *"the RTC was never read."* So today, with no network (or SLIRP without an NTP server, or a real LAN with no reachable time server), `ntp_now()` returns 0 and `date` says "not synced." Every PC has a battery-backed RTC that already knows the date; reading it at boot is the obvious local fallback. It also gives TLS-cert-validity checks (the eventual driver of the whole comms arc) a plausible clock before any network is up.

## 2. The hardware (MC146818 / "CMOS RTC")

Industry-standard since the IBM PC/AT; QEMU, every real x86 board, and every BIOS/UEFI implement it. Accessed through the **same two I/O ports as `write_boot_checkpoint`**: `0x70` (register index — top bit is the NMI-disable, leave it clear) and `0x71` (data). Time/date live in registers:

| Reg | Field | Reg | Field |
|---|---|---|---|
| 0x00 | seconds | 0x08 | month |
| 0x02 | minutes | 0x09 | year (2-digit) |
| 0x04 | hours | 0x32 | century (ACPI FADT; commonly here) |
| 0x07 | day of month | 0x0A | Status A — bit 7 = **UIP** (update in progress) |
|  |  | 0x0B | Status B — bit 1 = 24h, bit 2 = **binary** (else BCD) |

Two encoding quirks the read must handle, both advertised in **Status Register B**:
- **BCD vs binary** (bit 2): default on most BIOSes is **BCD** — `0x59` means 59, not 89. Decode `(v & 0x0F) + (v >> 4) * 10`.
- **12h vs 24h** (bit 1): default is 24h, but in 12h mode the hours byte's bit 7 is the PM flag and must be folded out (12 AM→0, PM→+12 except 12 PM).

## 3. Prior art (multi-source per [[feedback_redesign_dont_reinvent]])

The read algorithm is identical across every source — the only correctness trap is the **update window** (the RTC ticks ~once/second; reading mid-update yields a torn value):

- **MC146818A datasheet** — UIP bit (Status A bit 7) is set ~244 µs before each update and clear otherwise; read while UIP=0.
- **OSDev RTC wiki** — the canonical idiom: **read all registers twice and loop until two consecutive full reads agree** (catches a tick that lands between the first and last register read, which the UIP poll alone can miss). Plus the BCD/12h Status-B handling above.
- **Linux `arch/x86/kernel/rtc.c` `mach_get_cmos_time`** — polls UIP, reads, applies the century register, BCD-decodes via `bcd2bin`, calls `mktime64`. Same shape.
- **SeaBIOS / EDK2** — same UIP-aware read; SeaBIOS notes real chips can leave UIP asserted, so the wait must be **bounded** (give up rather than hang).

Convergent shape adopted: **bounded UIP wait → read all → re-read seconds; if it moved, re-read all (bounded retries) → BCD/12h-normalize → century-or-2000 → `civil_to_unix`.**

## 4. The epoch math — `civil_to_unix`

NTP (1.35.2) already does Unix→civil for the `date` breakdown; the RTC needs the **inverse** (civil→Unix). Use the well-known branch-free **days-from-civil** algorithm (Howard Hinnant's, used widely incl. in `<chrono>`): shift the year so March is month 0 (leap day lands at year's end), compute the day-of-era within a 400-year era, then `days*86400 + h*3600 + m*60 + s`. Exact for all dates ≥ 1970, pure integer ops (no tables, no per-month branching beyond the March shift). This becomes a reusable kernel primitive (a future `time()`/`gettimeofday` syscall and any "set RTC" path would share it).

## 5. Diff against AGNOS

| Need | Today | Gap |
|---|---|---|
| CMOS port I/O (0x70/0x71) | `outb`/`inb` ✓ (used by `write_boot_checkpoint`) | reuse |
| Wall-clock base + free-running `now()` | `net_unix_time` / `net_ntp_synctick` / `ntp_now()` ✓ (1.35.2) | reuse — seed the same fields |
| civil → Unix seconds | none (NTP only does the reverse) | **`civil_to_unix`** (new primitive) |
| CMOS RTC read (UIP-safe, BCD, 12h, century) | none | **`rtc_read_unix`** |
| boot-time seed + source tracking | none | seed call in x86 `main.cyr` + `net_clock_source` (0/RTC/NTP) |

`net.cyr` and `core/main.cyr` are both compiled x86-only (inside `#ifdef ARCH_X86_64`), so all of this lands in `net.cyr` beside the NTP code with **no aarch64 stub** — aarch64 has its own `main.cyr` and net stubs.

## 6. Design

- **`civil_to_unix(y, mo, d, h, mi, s)`** (`net.cyr`) — days-from-civil → Unix seconds.
- **`rtc_read_unix()`** (`net.cyr`) — `cmos_read` helper (`outb 0x70` / `inb 0x71`); bounded UIP wait; double-read-until-stable; BCD + 12h normalize per Status B; year = century-reg (if it decodes plausibly, 19–21) else `2000 + yy`; sanity-reject `< 1970` → return 0; else `civil_to_unix(...)`.
- **`net_clock_seed_rtc()`** (`net.cyr`) — if not already NTP-synced, set `net_unix_time = rtc_read_unix()`, `net_ntp_synctick = timer_ticks`, `net_ntp_synced = 1`, `net_clock_source = 1` (RTC). A later `ntp_sync` overrides the base and sets `net_clock_source = 2` (NTP wins — more precise).
- **`main.cyr`** — call `net_clock_seed_rtc()` in the x86 boot sequence (after the timer is live so `timer_ticks` is meaningful).
- **`shell.cyr`** — `date` reports the source (`RTC` / `NTP`) alongside the time.

`net_ntp_synced` keeps its meaning of "the wall clock is set" (now settable by RTC too); `net_clock_source` disambiguates for display. `ntp_now()` is unchanged — it just starts returning a real time at boot instead of after the first SNTP query.

## 7. Validation

`RTC_SELFTEST` boot-hook + `rtc-smoke.sh`:
- **Hermetic** — `civil_to_unix` against known anchors (shares NTP's: 2024-01-01 00:00:00 = `1704067200`; +3661 s = 01:01:01; and a leap case 2024-03-01 = `1709251200`), and BCD decode (`0x59`→59).
- **Live-bounded** — `rtc_read_unix()` under QEMU reads the emulated CMOS (host time); assert the result is a plausible epoch (`> 2020-01-01`) so the UIP/BCD/century read path is exercised, without depending on the exact host time.
- Gate: `rtc: clock PASS`.

## 8. Out of scope (deferred)

- **RTC write** (`systohc`) — set the hardware clock from NTP-corrected time. Needs the write side of the CMOS protocol + Status-B SET bit; only matters once AGNOS is the primary OS keeping time across reboots.
- **IRQ8 periodic / alarm interrupts** — the RTC can fire a periodic IRQ; unused (the 100 Hz PIT/APIC timer already drives the tick).
- **`time()` / `gettimeofday` syscall** — expose `ntp_now()` to userland. Slot when a userland consumer wants it (`civil_to_unix` is the shared primitive it would build on).
