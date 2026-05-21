---
name: RAM-disk + VirtIO 1.x Modern — Prior-Art Audit + 1.31.4 Implementation Plan
description: Multi-source convergent audit + one-shot execution plan for the 1.31.4 storage-cycle bite (RAM-disk backend + modern virtio-blk-pci rewrite)
type: engineering-plan
---

# RAM-disk + VirtIO 1.x Modern — 1.31.4 Implementation Plan

**Status:** Pre-implementation. 1.31.3 closed 2026-05-21 with USB MS Phase 2.8 / Attempt 87 PASS. 1.31.4 opens with **RAM-disk + VirtIO-blk modern** per `state.md` storage-target rankings. Per `feedback_redesign_dont_reinvent` (multi-source) + `feedback_known_knowledge_first` — this doc is the **convergent audit + fix plan** before code lands. Per `feedback_iron_burns_block_other_work` — both bites stack into one cut; no incremental laddering.

Neither bite has iron exposure: RAM-disk is RAM-only (no hardware variable); VirtIO doesn't exist on bare metal (QEMU-only validation surface). Risk is contained to QEMU regression — both bites should one-shot on the audit-and-execute pattern that landed NVMe (1.31.0) and AHCI (1.31.1) first-iron-try.

---

## 1. Goals + scope

**1.31.4 cycle scope** (two bites, single cut):

1. **RAM-disk block backend** (~150 LOC, new file `kernel/core/ramdisk.cyr`) — `pmm_alloc`-backed `/dev/ram0`-equivalent, 256 KB default, 512-B sectors, integrates with the existing `block.cyr` tag-dispatch layer as `BLK_RAMDISK=5`. Build-flag-gated (`RAMDISK_ENABLE=1`) so production boots stay lean. Useful for filesystem development without iron and as a regression substrate for fatfs / GPT / future ext2 work.

2. **VirtIO 1.x modern virtio-blk-pci driver** (~600 LOC delta, rewrite of `kernel/core/virtio_blk.cyr`) — replace the transitional 0.9.5 port-I/O driver with a modern PCI-capability-discovery + MMIO + 64-bit feature negotiation + 64-bit virtqueue addressing driver. Same public API (`vblk_blk_read/write/read_sectors`) so `block.cyr` dispatch + `main.cyr` init order stay byte-compatible. **Polled-only** (no MSI-X — kernel has no generic vector-dispatch surface).

**Out of scope** (parked):
- Modern packed virtqueue layout (`VIRTIO_F_RING_PACKED`) — split rings are simpler + QEMU default
- IOMMU / `VIRTIO_F_ACCESS_PLATFORM` — kernel has no IOMMU plumbing; direct phys-addr DMA
- Multi-queue (`VIRTIO_BLK_F_MQ`) — single requestq is sufficient
- Indirect descriptors, event-idx, notification-data — all optimizations, defer to a future cycle
- RAM-disk runtime sizing (ioctl/sysctl) — compile-time `RAMDISK_SIZE_PAGES` constant for MVP

---

## 2. What we have today

| File | LOC | Status | Disposition |
|---|---|---|---|
| `kernel/core/virtio_blk.cyr` | 181 | Transitional 0.9.5 (port-I/O, PCI ID `0x1AF4/0x1001`, 5-state machine, single VQ, 3-desc chains, polled) | **Rewrite in-place** — same `vblk_*` public names, same `blk_register_virtio(capacity)` integration |
| `kernel/core/block.cyr` | 113 | Tag-dispatch over `BLK_NONE/VIRTIO/NVME/AHCI/USB_MS` | **Extend** — add `BLK_RAMDISK=5`, `blk_register_ramdisk`, dispatch arms |
| `kernel/core/pci.cyr` | (relevant subset) | `pci_find_cap(idx, cap_id)` returns first match | **Minimal extension** — add `pci_find_cap_next(idx, start_off, cap_id)` or inline the iteration in virtio_blk_init |
| `kernel/core/initrd.cyr` | 75 | Memory-resident manifest reader (NOT a block backend) | **Untouched** — initrd is a separate concept; ramdisk.cyr is the block-layer surface |
| `kernel/core/main.cyr` lines 276-285 | — | Calls `virtio_blk_init()` if PCI `0x1AF4/0x1001` found | **Extend** — accept device IDs `{0x1001, 0x1042}`; add `#ifdef RAMDISK_ENABLE ramdisk_init();` block |

Existing precedent that defines the integration shape (don't deviate):
- **`blk_register_<backend>(capacity, lba_bytes)`** function-name pattern
- **`<backend>_blk_read(sector, buf)` / `_write(sector, buf)` / `_read_sectors(start, count, buf)`** public surface (0=success, -1=fail, 512-B sectors)
- **`<backend>_register_block_dev()`** convenience function called from `main.cyr` that handles registration log line + CMOS kcp stamp
- **Build flags:** `KTEST` / `XHCI_VERBOSE` / `AHCI_RW_DEMO` / `MSC_RW_DEMO` pattern documented in `agnos/docs/development/build.md` — `RAMDISK_ENABLE` joins this lane

---

## 3. RAM-disk — convergent prior art

Sources read: Linux `drivers/block/brd.c`, FreeBSD `sys/dev/md/md.c`, NetBSD `sys/dev/md.c`, OpenBSD `sys/dev/rd.c`, Haiku `src/add-ons/kernel/drivers/disk/virtual/ram_disk/ram_disk.cpp`.

### 3.1 Allocation strategy split

Two camps:

- **"Fancy" kernels** (Linux brd / FreeBSD md MD_MALLOC / Haiku) — sparse radix-tree / xarray of 4 KB pages, lazy-allocated on first write, zero-fill on read-miss. Requires a radix-tree implementation and malloc.
- **"Small" kernels** (OpenBSD rd / NetBSD `MD_KMEM_ALLOCATED` mode) — single contiguous allocation up-front, sized at config time. Zero dynamic complexity.

**Convergent finding for sovereign kernels with `pmm_alloc()` only** — the small-kernel pattern is the right port. OpenBSD `rd.c` patches a fixed `char rd_root_image[ROOTBYTES]` BSS array via `rdsetroot` after link; NetBSD `MD_KMEM_ALLOCATED` calls `uvm_km_alloc(... UVM_KMF_WIRED|UVM_KMF_ZERO)` at attach. We get the same behavior by calling `pmm_alloc()` N times at init and storing physical addresses in a `page_table[N]` array indexed by `sector >> 3` (8 sectors per 4 KB page). O(1) lookup, zero dynamic complexity, no radix tree.

### 3.2 Sector size + capacity

512-B sectors are universal in the audit (only Haiku deviates upward to 4 KB). Capacity is either compile-time constant (small kernels) or runtime ioctl (large kernels). All clamp to sector-size multiples.

**Decision: 512-B sectors, compile-time `RAMDISK_SIZE_PAGES`.** Matches existing AGNOS backends (virtio/NVMe/AHCI/USB-MS all standardize on 512 B). No ioctl, no runtime tuning for MVP — that's post-beta scope.

### 3.3 Read/write inner loop

Convergent across all five impls: **bare `memcpy`** in either direction. Nobody adds caching above it — the RAM-disk IS the cache. The only meaningful branch is read-of-unallocated-sector → zero-fill, and only if you went sparse, which we're not (preallocated = every sector is "allocated").

### 3.4 Init + failure mode

Most impls defer backing allocation (Linux brd lazy, FreeBSD md MD_RESERVE opt-in, Haiku VMCache, OpenBSD BSS-baked). The "preallocate up front" path exists in NetBSD `MD_KMEM_ALLOCATED` and FreeBSD `MD_RESERVE`. Failure handling everywhere: free what was allocated, log, refuse to register — boot continues without ramdisk rather than half-registering.

**Decision: preallocate at init.** Simpler than lazy (no fault-handler infrastructure to wire); removes an entire failure mode from the hot path. Boot-time check on every `pmm_alloc()`; if any returns 0, unwind and skip `blk_register_ramdisk`.

### 3.5 Sizing for archaemenid

Current `pmm` budget on archaemenid post-boot: ~354 free pages (~1.4 MB). RAM-disk competes with kybernet + agnoshi + filesystem buffers + userland startup.

| Size | Pages | % of free budget | Use case |
|---|---|---|---|
| 64 KB | 16 | 4.5% | Sentinel write/read smoke tests only; too small for any real FS |
| **256 KB** | **64** | **18%** | **Recommended default** — fits FAT12 / minixfs bring-up; matches OpenBSD `MINIROOTSIZE` precedent (the only OS in the audit shipping a default at all) |
| 512 KB | 128 | 36% | Recommended max until `pmm` budget grows |
| 1 MB+ | 256+ | 72%+ | Will suffocate the rest of the kernel; do not default |

**Decision: `RAMDISK_SIZE_PAGES = 64` (256 KB) default; build-time error if > 128.**

### 3.6 Smallest correct backend — port checklist

1. **Allocate `RAMDISK_SIZE_PAGES` × 4 KB pages** via `pmm_alloc()` at init; store physical addresses in static `ramdisk_pages[RAMDISK_SIZE_PAGES]`. Unwind on partial failure.
2. **Advertise capacity** = `RAMDISK_SIZE_PAGES × 8` sectors, 512 B each, via `blk_register_ramdisk(capacity, 512)`.
3. **Inner I/O loop**: `page_addr = ramdisk_pages[sector >> 3]; offset = (sector & 7) * 512; memcpy(buf, page_addr + offset, 512)` for read; reverse for write. Bounds-check `sector + count <= capacity`.
4. **No lazy alloc, no sparse map, no caching, no DMA, no coherency flush.**
5. **Identity-shape with existing backends** — same signatures, same return codes, same dispatch tag.
6. **One-line init log**: `ramdisk: N pages (K KB) at <phys-of-first-page>`. No control device, no destroy path.

---

## 4. RAM-disk — AGNOS implementation plan

### 4.1 New file: `kernel/core/ramdisk.cyr` (~150 LOC)

State (file-scope globals):
```
var RAMDISK_PAGES = 64;             # 256 KB, compile-time tunable via -DRAMDISK_SIZE_PAGES
var ramdisk_pages[RAMDISK_PAGES];   # physical addresses of backing pages, one per 4 KB
var ramdisk_npages = 0;             # actual allocated count (set at init); 0 = inactive
var ramdisk_capacity = 0;           # in 512-B sectors; npages * 8
```

Functions:
```
fn ramdisk_init()                       # alloc N pages, populate ramdisk_pages[], register
fn ramdisk_blk_read(sector, buf)        # 1-sector read, returns 0/-1
fn ramdisk_blk_write(sector, buf)       # 1-sector write
fn ramdisk_blk_read_sectors(s, c, buf)  # multi-sector loop
fn ramdisk_register_block_dev()         # called from main.cyr; calls blk_register_ramdisk + log line + CMOS kcp
```

Init failure path:
- If any `pmm_alloc()` returns 0 mid-loop: leave `ramdisk_npages = 0`, skip registration, log `ramdisk: pmm exhausted after N pages — disabled` (do NOT free already-allocated pages — `pmm` has no free path today; matches existing AGNOS convention).

Inner I/O loop (single-sector read):
```
fn ramdisk_blk_read(sector, buf) {
    if (ramdisk_npages == 0) { return 0 - 1; }
    if (sector >= ramdisk_capacity) { return 0 - 1; }
    var page = ramdisk_pages[sector >> 3];
    var off  = (sector & 7) * 512;
    # 64 × 8-byte copy = 512 bytes
    for (var i = 0; i < 64; i = i + 1) {
        store64(buf + i * 8, load64(page + off + i * 8));
    }
    return 0;
}
```

Write is mirror-image; `read_sectors` is the obvious loop over `read`. Use `load64`/`store64` directly (no `memcpy` helper currently in kernel/core for this pattern; matches `virtio_blk.cyr` lines 59-61 and 160-162 idiom).

### 4.2 `block.cyr` extension

Add new tag + arms (already partially set up — `BLK_USB_MS = 4` exists, ramdisk follows the same pattern):

```cyrius
var BLK_RAMDISK = 5;

fn blk_register_ramdisk(capacity, lba_bytes) {
    # Policy: takes the slot only when NONE or VIRTIO holds it. RAM-disk
    # is development-only — never override real iron backends (NVMe / AHCI /
    # USB-MS) or higher-priority paravirt (modern virtio-blk).
    if (blk_active == BLK_NONE) {
        blk_active    = BLK_RAMDISK;
        blk_capacity  = capacity;
        blk_lba_bytes = lba_bytes;
    }
    return 0;
}
```

Add arms to `blk_read` / `blk_write` / `blk_read_sectors`:
```
if (blk_active == BLK_RAMDISK) { return ramdisk_blk_read(sector, buf); }
```
…etc, matching the existing pattern verbatim.

### 4.3 `main.cyr` init order

Insert AFTER virtio_blk_init's PCI probe block, BEFORE NVMe Phase 1. Reason: RAM-disk is paravirt-tier; both real-iron backends (NVMe/AHCI/USB-MS) AND modern-virtio-blk should override. By initializing it before NVMe, the NVMe override path naturally wins on real iron; on RAM-only smoke harnesses (no NVMe device), RAM-disk holds the slot.

```cyrius
#ifdef RAMDISK_ENABLE
ramdisk_init();
ramdisk_register_block_dev();
#endif
```

The `#ifdef` gate means production builds (default off) pay zero memory — the 256 KB allocation never happens. Developer builds (`RAMDISK_ENABLE=1` passed via `scripts/build.sh`) get the backing memory at boot.

### 4.4 Build-flag plumbing

Add to `agnos/docs/development/build.md` alongside `KTEST` / `XHCI_VERBOSE` / `AHCI_RW_DEMO` / `MSC_RW_DEMO`:

```
RAMDISK_ENABLE=1   — Enable the RAM-disk block backend (256 KB by default).
                     Off by default; production boots stay lean.
RAMDISK_SIZE_PAGES — Override the default 64 pages. Hard max 128 (build error).
```

Plumb through `scripts/build.sh` the same way `AHCI_RW_DEMO=1` is plumbed (a `-D` define passed to `cyrius build`).

---

## 5. VirtIO 1.x modern — spec primer

Source: OASIS VirtIO v1.2 (csd01, 2022-05-09). Section numbers below reference that PDF.

### 5.1 PCI capability layout — byte-level

Each vendor cap (`cap_vndr = 0x09`) is at least 16 bytes:

| Offset | Size | Field | Meaning |
|---|---|---|---|
| 0 | 1 | `cap_vndr` | Always `0x09` |
| 1 | 1 | `cap_next` | Standard PCI next-cap pointer |
| 2 | 1 | `cap_len` | Length of THIS cap (≥ 16) |
| **3** | **1** | **`cfg_type`** | **Structure selector — see below** |
| 4 | 1 | `bar` | BAR index 0–5 |
| 5 | 1 | `id` | Disambiguator for multiple caps of same type |
| 6 | 2 | `padding[2]` | — |
| 8 | 4 | `offset` | LE32 — offset *within* the chosen BAR |
| 12 | 4 | `length` | LE32 — length of the pointed-to structure |

`cfg_type` values we care about:
- `1` `COMMON_CFG` — the 60-byte register block (§5.2)
- `2` `NOTIFY_CFG` — followed by extra LE32 `notify_off_multiplier` (cap is 20 bytes total)
- `3` `ISR_CFG` — single byte; **we ignore in polled mode**
- `4` `DEVICE_CFG` — `virtio_blk_config` (capacity + optional fields)
- Others (PCI_CFG=5, SHARED_MEMORY_CFG=8, VENDOR_CFG=9) — **skip**

Driver rules (§4.1.4.1): ignore unknown `cfg_type`, ignore unknown `bar`, accept `cap_len > 16` (clamp `length` to what you map). Use the *first* instance of each type.

### 5.2 COMMON_CFG register block (60 bytes)

| Off | Sz | Field | Mode | Scope |
|---|---|---|---|---|
| 0 | 4 | `device_feature_select` | RW | global |
| 4 | 4 | `device_feature` | RO | global |
| 8 | 4 | `driver_feature_select` | RW | global |
| 12 | 4 | `driver_feature` | RW | global |
| 16 | 2 | `config_msix_vector` | RW | global (leave `0xFFFF` — polled) |
| 18 | 2 | `num_queues` | RO | global |
| 20 | 1 | `device_status` | RW | global (write 0 = reset) |
| 21 | 1 | `config_generation` | RO | global |
| 22 | 2 | `queue_select` | RW | global |
| 24 | 2 | `queue_size` | RW | per-VQ |
| 26 | 2 | `queue_msix_vector` | RW | per-VQ (leave `0xFFFF`) |
| 28 | 2 | `queue_enable` | RW | per-VQ |
| 30 | 2 | `queue_notify_off` | RO | per-VQ |
| 32 | 8 | `queue_desc` | RW | per-VQ (64-bit phys) |
| 40 | 8 | `queue_driver` | RW | per-VQ (avail ring phys) |
| 48 | 8 | `queue_device` | RW | per-VQ (used ring phys) |

§4.1.3.1 requires width-correct access (u8 byte access, u16 aligned 16-bit, u32 aligned 32-bit). 64-bit `queue_desc/driver/device` may be split into two 32-bit writes; convention is **low half first, high half second**.

### 5.3 State machine — 8-step init

Status bits: `ACK=1`, `DRIVER=2`, `DRIVER_OK=4`, **`FEATURES_OK=8`** (new), `DEVICE_NEEDS_RESET=64`, `FAILED=128`.

1. **Reset**: write 0 to `device_status`, **spin until read-back returns 0** (§4.1.4.3.2 mandatory).
2. Set `ACKNOWLEDGE` (1).
3. Set `DRIVER` (3 = ACK|DRIVER).
4. Read offered features (64-bit via two select reads), compute accepted subset.
5. **Set `FEATURES_OK`** (11 = ACK|DRIVER|FEATURES_OK). Driver MUST NOT accept new bits after this.
6. **Re-read `device_status`. If `FEATURES_OK` bit is clear → device rejected your subset; set `FAILED`, abort. No retry.** This is the critical new gate.
7. Per-VQ setup: discovery, ring alloc, address writes, `queue_enable=1`.
8. Set `DRIVER_OK` (15 = ACK|DRIVER|FEATURES_OK|DRIVER_OK). Live.

§2.1.2: device MUST NOT touch buffers before `DRIVER_OK`. §2.1.1: driver MUST NOT clear individual bits — only full reset (write 0).

### 5.4 Feature negotiation — 64-bit

Pattern: write `device_feature_select=0`, read `device_feature` (low 32 bits); write `device_feature_select=1`, read `device_feature` (high 32 bits); OR into u64. Same shape on write side with `driver_feature_*`.

**MUST accept** (§6.1): `VIRTIO_F_VERSION_1` (bit 32). Without this, the device's behavior is "legacy" and modern semantics don't apply.

**Skip — do not accept**:
- `VIRTIO_F_ACCESS_PLATFORM` (33) — IOMMU required; we go direct phys
- `VIRTIO_F_RING_PACKED` (34) — split rings are simpler; not accepting falls back to split
- `VIRTIO_F_NOTIFICATION_DATA` (38) — 16-bit doorbell baseline is fine
- `VIRTIO_F_RING_EVENT_IDX` (29), `INDIRECT_DESC` (28), `IN_ORDER` (35), `ORDER_PLATFORM` (36), `NOTIF_CONFIG_DATA` (39), `RING_RESET` (40), `SR_IOV` (37) — all optimizations or platform-specific

**Block-feature bits — skip first cut**: `VIRTIO_BLK_F_FLUSH`, `BLK_SIZE`, `TOPOLOGY`, `CONFIG_WCE`, `MQ`, `DISCARD`, `WRITE_ZEROES`, `SECURE_ERASE`, `LIFETIME`, `GEOMETRY` — none required for IN/OUT. §5.2.5.1 confirms: if you don't ack FLUSH, device commits writes implicitly (writethrough-equivalent), correctness preserved.

**Accept if offered**: `VIRTIO_BLK_F_RO` (5) — read-only flag. If set, we know writes will IOERR; flag it in our blk-layer registration as an info-only print.

### 5.5 Virtqueue setup

Per §4.1.5.1.3 + §2.7:

1. Write VQ index (0 for "requestq") to `queue_select`.
2. Read `queue_size`. 0 = queue doesn't exist (we expect ≥ 1 for blk).
3. Optionally write a smaller power-of-2 to shrink (don't bother — accept device's default).
4. Allocate three regions (alignment per §2.7.1):

| Region | Alignment | Size |
|---|---|---|
| Descriptor table | 16 B | `16 × queue_size` |
| Available ring (Driver Area) | 2 B | `6 + 2 × queue_size` |
| Used ring (Device Area) | 4 B | `6 + 8 × queue_size` |

For `queue_size=256` (QEMU default): desc=4 KB, avail=518 B, used=2054 B. Fits trivially in 3 contiguous pmm pages (matches existing 0.9.5 layout). Modern split rings have **no inter-region padding requirement** — the legacy 4 KB-aligned-used-ring rule is gone (§2.7.2).

5. Write 64-bit byte-physical addresses to `queue_desc`, `queue_driver`, `queue_device`. **No PFN shift** (contrast 0.9.5 `QUEUE_PFN = addr >> 12`).
6. Read `queue_notify_off` (u16). Compute notify address = `notify_bar_base + notify_cap.offset + queue_notify_off × notify_off_multiplier`.
7. Write `queue_enable = 1`. **All other per-VQ fields must be configured first** (§4.1.4.3.2).

### 5.6 Notify mechanism

Doorbell formula (§4.1.4.4):
```
notify_addr = (MMIO base of NOTIFY_CFG cap's BAR)
            + NOTIFY_CFG_cap.offset
            + (queue_notify_off × notify_off_multiplier)
```

`notify_off_multiplier` = LE32 at byte 16 of the NOTIFY_CFG cap (immediately after the 16-byte `virtio_pci_cap` header). MUST be either an even power of 2 OR zero (zero = all VQs share one doorbell). With QEMU's typical 4-byte multiplier and `queue_notify_off=0` for queue 0, the doorbell address simplifies to `notify_bar_base + notify_cap.offset`.

Without `VIRTIO_F_NOTIFICATION_DATA` (we don't negotiate it): write **16-bit value = queue index** (0 for our single requestq).

### 5.7 Request framing — identical to 0.9.5

`virtio_blk_req` (§5.2.6):
```
le32 type;     // 0=IN(read), 1=OUT(write), 4=FLUSH, 8=GET_ID, ...
le32 reserved; // 0 (was ioprio in legacy)
le64 sector;   // 512-B offset; 0 for FLUSH
u8   data[];   // payload
u8   status;   // device-written: 0=OK, 1=IOERR, 2=UNSUPP
```

Three-descriptor chain (same as 0.9.5):
1. Header — device-readable, `F_NEXT`
2. Data buffer — `F_WRITE` set for IN (device writes to guest mem); clear for OUT; `F_NEXT`
3. Status byte — `F_WRITE`, terminal (no `F_NEXT`)

§2.7.4.2: all device-readable descriptors precede device-writable ones — our existing layout already complies.

### 5.8 Pitfalls (from §10 of the spec deep-dive)

| Pitfall | Spec ref | Mitigation |
|---|---|---|
| Reset readback wait | §4.1.4.3.2 | Spin on `device_status == 0` after writing 0 |
| 64-bit queue addr split | §4.1.3.2 | Low half first, high half second |
| `queue_size` must be pow-of-2 | §4.1.4.3.2 | Accept device default; don't shrink |
| All multi-byte fields LE | §4.1.3 + §2.5 | x86_64 is LE-native; no swapping needed |
| `queue_notify_off` is NOT a byte offset | §4.1.4.3 | Multiply by `notify_off_multiplier` |
| wmb before `avail.idx++` | §2.7.13.3.1 | x86 LOCK-prefixed or `mfence`; cc6 should emit on store ordering |
| rmb before reading used-ring | §2.7.13.4.1 | Same — read fence |
| Don't write 0 to `queue_enable` | §4.1.4.3.2 | Once enabled, only full reset disables |
| `cap_len` may exceed spec size | §4.1.4.1 | Don't fail on `length > 60` for COMMON_CFG; clamp |
| FLUSH requires `sector=0` | §5.2.6.1 | We don't issue FLUSH; non-issue |
| `writeback` may only be read after FEATURES_OK | §5.2.5.1 | We don't read `writeback`; non-issue |
| Transitional `0x1001` exposes BOTH legacy I/O BAR0 AND modern caps | §4.1.4.10, §4.1.5.1.1 | Decide via cap-list presence test, not device ID |

---

## 6. VirtIO modern — multi-impl convergent shape

Sources read: Linux `drivers/virtio/virtio_pci_modern.c` + `virtio_blk.c` + `virtio_ring.c`; FreeBSD `sys/dev/virtio/pci/virtio_pci_modern.c` + `sys/dev/virtio/block/virtio_blk.c`; OpenBSD `sys/dev/pci/virtio_pci.c` + `sys/dev/pv/vioblk.c` + `sys/dev/pv/virtio.c`.

### 6.1 Convergent ABI — port checklist

1. **Capability walk**: iterate `PCI_CAP_ID_VNDR` (0x09) chain; classify by `cfg_type` byte at cap+3. Require types 1/2/3; type 4 (DEVICE) optional but useful for capacity readout.
2. **BAR map**: per required cap, read `bar` (u8), `offset` (u32 LE), `length` (u32 LE); validate `bar < 6`, no `offset+length` overflow (Linux flagged this as a kernel-level security check — overflow → fail-init), clamp length ≤ actual BAR size.
3. **Notify multiplier**: LE32 at NOTIFY_CFG cap + 16 bytes (immediately after the 16-byte cap header).
4. **Reset sequence**: write 0 to `device_status`, spin on readback.
5. Status progression: `|= ACK`, `|= DRIVER`.
6. Feature read: 2-iteration select=0/1 → u64. Mask with driver-supported bits. Write both halves via `driver_feature_select=0/1`.
7. `|= FEATURES_OK`. Read back. **If cleared, fail hard — no retry.**
8. VQ setup: select → size read → allocate vring (single page-contiguous works for QEMU default size 256) → write 64-bit phys addrs to queue_desc/driver/device → read queue_notify_off → compute notify addr → `queue_enable = 1`.
9. `|= DRIVER_OK`.
10. **Request submission**: header (device-read) + data (direction-dependent) + status (device-write) descriptor chain.
11. **Avail-ring publish**: write descriptor chain → write `avail->ring[avail->idx % N] = head` → **wmb** → increment `avail->idx`.
12. **Doorbell**: write 16-bit queue index to cached notify_addr.
13. **Used consume (polled)**: read `used->idx`; if advanced past `last_used_idx`, **rmb** → read `used->ring[last_used_idx % N].id` → process status byte → increment `last_used_idx`. **No ISR byte read needed in polled mode** — OpenBSD's `virtio_pci_poll_intr` explicitly bypasses it.

### 6.2 Three top pitfalls (cross-impl flagged)

1. **wmb between avail-ring slot write and `avail->idx` increment**. All three impls flag this with explicit barriers (Linux `virtio_wmb` at `virtio_ring.c:1230`, FreeBSD `wmb()` at `virtqueue.c:979`, OpenBSD `virtio_membar_producer`). Symmetric **rmb** between `used->idx` read and used-ring entry read.
2. **`offset+length` overflow validation on BAR submap**. Linux `virtio_pci_modern_dev.c:57-62` explicit check with error string "map wrap-around %u+%u". Without this, a malicious or buggy device can crash the kernel by advertising a wrap-around offset.
3. **FEATURES_OK readback failure = reset, not retry**. Spec §3.1.1 step 6 and all three impls confirm: once cleared, no further config — only full reset. Easy footgun to write a "renegotiate with reduced bits" loop; it's a spec violation.

### 6.3 Port-reference order

Per the audit recommendation:
- **OpenBSD `virtio.c`** for state-machine shape (most compact, polled path explicit)
- **FreeBSD `virtio_pci_modern.c`** for cap-walk + VQ-setup (cleanest single-file C)
- **Linux `virtio_ring.c`** for barrier discipline (most rigorously commented)

We will NOT mechanically copy Linux's structure — it's the most idiomatic to Linux's internal abstractions (gendisk, request_queue, virtio_device class). The transport-agnostic compactness of OpenBSD's `virtio.c` is the closer model.

---

## 7. VirtIO modern — AGNOS implementation plan

### 7.1 Rewrite `kernel/core/virtio_blk.cyr` (~600 LOC)

**Public surface UNCHANGED** — these names are stable contracts with `block.cyr` and `main.cyr`:

```
fn virtio_blk_init()                    # PCI probe + full modern init
fn vblk_blk_read(sector, buf)           # 1-sector read
fn vblk_blk_write(sector, buf)          # 1-sector write
fn vblk_blk_read_sectors(start, count, buf)
var vblk_active                          # for main.cyr's status print
var vblk_capacity                        # for main.cyr's status print
```

**New file-scope state** (replacing port-I/O scalars):

```
# MMIO bases (resolved from cap-list walk)
var vblk_common_cfg  = 0;   # 60-byte COMMON_CFG register block
var vblk_notify_base = 0;   # NOTIFY_CFG cap BAR + offset
var vblk_notify_mul  = 0;   # notify_off_multiplier
var vblk_device_cfg  = 0;   # DEVICE_CFG (virtio_blk_config) — optional

# Per-queue notify offset for queue 0
var vblk_q0_notify_addr = 0;  # precomputed = notify_base + queue_notify_off × notify_mul

# Virtqueue (single requestq)
var vblk_qsize  = 0;          # 256 by QEMU default
var vblk_desc   = 0;          # descriptor table phys
var vblk_avail  = 0;          # available ring phys
var vblk_used   = 0;          # used ring phys
var vblk_idx    = 0;          # next avail-ring slot
var vblk_used_last = 0;       # last consumed used-ring idx

# Capacity (from DEVICE_CFG or VIRTIO_BLK_F_RO scan)
var vblk_capacity = 0;        # in 512-B sectors
var vblk_readonly = 0;        # 1 if VIRTIO_BLK_F_RO accepted

# Request structures (DMA-accessible BSS, same posture as 0.9.5)
var vblk_req_hdr[16];         # 16-byte virtio_blk_req header
var vblk_req_status[1];       # 1-byte status
var vblk_dma_buf[64];         # 512-byte DMA buffer (8 × 64-bit words)
var vblk_active = 0;
```

### 7.2 `virtio_blk_init` skeleton (audit-and-execute order)

```
fn virtio_blk_init() {
    # Step 1: PCI probe — accept BOTH transitional 0x1001 AND modern 0x1042
    var idx = pci_find(0x1AF4, 0x1042);
    if (idx < 0) { idx = pci_find(0x1AF4, 0x1001); }
    if (idx < 0) { return 0 - 1; }

    # Step 2: Enable bus-master for DMA
    pci_enable_bus_master(PciDev_slot(&pci_devs + idx * 32));

    # Step 3: Walk PCI capability list, classify by cfg_type
    # — find COMMON_CFG (type 1), NOTIFY_CFG (type 2), ISR_CFG (type 3),
    #   optionally DEVICE_CFG (type 4)
    # — if any required cap missing, fail-init (transitional 0x1001 with
    #   disable-modern=true would land here — driver MUST fail gracefully
    #   per spec §4.1.5.1.1.1)
    if (vblk_scan_caps(idx) < 0) { return 0 - 1; }

    # Step 4: Reset device — write 0 to device_status, spin on readback
    store8(vblk_common_cfg + 20, 0);
    var spin = 0;
    while (load8(vblk_common_cfg + 20) != 0) {
        spin = spin + 1;
        if (spin > 1000000) { return 0 - 1; }
    }

    # Step 5: ACK | DRIVER
    store8(vblk_common_cfg + 20, 1);
    store8(vblk_common_cfg + 20, 3);

    # Step 6: 64-bit feature read
    store32(vblk_common_cfg + 0, 0);            # device_feature_select = 0
    var feat_lo = load32(vblk_common_cfg + 4);
    store32(vblk_common_cfg + 0, 1);            # device_feature_select = 1
    var feat_hi = load32(vblk_common_cfg + 4);

    # Step 7: Compute accepted subset
    # — MUST: VIRTIO_F_VERSION_1 (bit 32 → feat_hi bit 0)
    # — ACCEPT if offered: VIRTIO_BLK_F_RO (bit 5 → feat_lo bit 5)
    # — REJECT all others
    if ((feat_hi & 1) == 0) { return 0 - 1; }   # device must offer VERSION_1
    var driver_lo = 0;
    var driver_hi = 1;                           # VERSION_1
    if ((feat_lo & 0x20) != 0) { driver_lo = driver_lo | 0x20; vblk_readonly = 1; }

    # Step 8: Write driver-accepted features back
    store32(vblk_common_cfg + 8, 0);             # driver_feature_select = 0
    store32(vblk_common_cfg + 12, driver_lo);
    store32(vblk_common_cfg + 8, 1);
    store32(vblk_common_cfg + 12, driver_hi);

    # Step 9: FEATURES_OK + readback gate
    store8(vblk_common_cfg + 20, 11);            # ACK | DRIVER | FEATURES_OK
    if ((load8(vblk_common_cfg + 20) & 8) == 0) {
        store8(vblk_common_cfg + 20, 128);       # FAILED
        return 0 - 1;
    }

    # Step 10: Read capacity from DEVICE_CFG (if present)
    if (vblk_device_cfg != 0) {
        var cap_lo = load32(vblk_device_cfg + 0);
        var cap_hi = load32(vblk_device_cfg + 4);
        vblk_capacity = cap_lo | (cap_hi << 32);
    }

    # Step 11: Per-VQ setup
    if (vblk_setup_queue_0() < 0) { return 0 - 1; }

    # Step 12: DRIVER_OK
    store8(vblk_common_cfg + 20, 15);
    vblk_active = 1;

    # Step 13: Register with block layer (same shape as before)
    blk_register_virtio(vblk_capacity);
    return 0;
}
```

### 7.3 `vblk_scan_caps` — capability-list iteration

We extend the existing `pci_find_cap(idx, 0x09)` pattern by walking past the first match. Simplest approach: inline the walk in `virtio_blk.cyr`, don't extend `pci.cyr`. Each cap header read returns the `cfg_type` byte at `+3`; classify; map BAR window; continue via `cap_next`.

```
fn vblk_scan_caps(idx) {
    # Bounded walk over the PCI capability list, classifying virtio caps
    # by cfg_type byte at cap+3. Sets vblk_common_cfg / vblk_notify_base /
    # vblk_notify_mul / vblk_device_cfg as MMIO bases (resolved through
    # pci_bar_phys[] lookup + cap offset). Returns 0 on success (all required
    # types found), -1 on missing required (COMMON / NOTIFY / ISR).
    ...
}
```

Required for one-shot: validate `bar < 6`, validate `offset + length` doesn't wrap (32-bit overflow check), look up the BAR's phys via `pci_bar_phys[idx * 6 + bar]` (or similar — confirm exact side-array layout in `pci.cyr`).

### 7.4 `vblk_setup_queue_0` — virtqueue programming

```
fn vblk_setup_queue_0() {
    # queue_select = 0
    store16(vblk_common_cfg + 22, 0);

    # queue_size read (QEMU default: 256)
    vblk_qsize = load16(vblk_common_cfg + 24);
    if (vblk_qsize == 0) { return 0 - 1; }

    # Allocate three contiguous pages for desc + avail + used
    # (256 entries × 16 = 4 KB desc, fits in 1 page; avail = 518 B fits;
    # used = 2054 B fits — total ≤ 3 pages contiguous)
    var p1 = pmm_alloc();
    var p2 = pmm_alloc();
    var p3 = pmm_alloc();
    if (p1 == 0) { return 0 - 1; }
    if (p2 == 0) { return 0 - 1; }
    if (p3 == 0) { return 0 - 1; }
    # Identity-map ensures phys == virt; zero all three
    # (loop over 64 × 8-byte stores per page, matches existing virtio_blk.cyr:59)

    vblk_desc  = p1;
    vblk_avail = p2;
    vblk_used  = p3;

    # Write 64-bit addrs (LOW half first, high half second)
    store32(vblk_common_cfg + 32, vblk_desc  & 0xFFFFFFFF);
    store32(vblk_common_cfg + 36, (vblk_desc  >> 32) & 0xFFFFFFFF);
    store32(vblk_common_cfg + 40, vblk_avail & 0xFFFFFFFF);
    store32(vblk_common_cfg + 44, (vblk_avail >> 32) & 0xFFFFFFFF);
    store32(vblk_common_cfg + 48, vblk_used  & 0xFFFFFFFF);
    store32(vblk_common_cfg + 52, (vblk_used  >> 32) & 0xFFFFFFFF);

    # Read queue_notify_off, compute notify addr
    var qno = load16(vblk_common_cfg + 30);
    vblk_q0_notify_addr = vblk_notify_base + qno * vblk_notify_mul;

    # Enable queue (MUST be last)
    store16(vblk_common_cfg + 28, 1);

    vblk_idx = 0;
    vblk_used_last = 0;
    return 0;
}
```

### 7.5 `vblk_do_request` — same logic as 0.9.5, modern transport

Three-descriptor chain logic is identical to existing `virtio_blk.cyr` lines 85-148 (header / data / status, NEXT/WRITE flags, avail-ring slot write, used-ring poll). What changes:

1. **Doorbell**: `outw(vblk_iobase + 16, 0)` becomes `store16(vblk_q0_notify_addr, 0)` (write 16-bit queue index 0 to the MMIO notify address).
2. **Polling**: `inw(qbase + ...)` becomes `load16(vblk_used + 2)` — same semantics, MMIO instead of computed ring offset.
3. **Memory barrier before `avail.idx++`**: insert explicit `mfence` via inline asm between the avail-ring slot write (line 128 in current code) and the `avail.idx` increment (line 130). Same on the consume path (rmb between `used.idx` read and used-ring entry read).

The barrier is THE critical correctness item — flagged by all three reference impls. On x86_64 a single `mfence` or any LOCK-prefixed op suffices; we'll use `mfence` for portability of the source (aarch64 stub will need `dmb ish` later).

Inline asm pattern (mirrors the existing PIO patterns in `pci.cyr`):
```cyrius
asm { 0x0F; 0xAE; 0xF0; }   # mfence
```

### 7.6 `main.cyr` adjustment

Today (line 276):
```
if (pci_find(0x1AF4, 0x1001) >= 0) {
    if (virtio_blk_init() == 0) { ... }
}
```

Modern path needs to accept either ID. Simplest:
```
if ((pci_find(0x1AF4, 0x1042) >= 0) | (pci_find(0x1AF4, 0x1001) >= 0)) {
    if (virtio_blk_init() == 0) { ... }
}
```

Or just have `virtio_blk_init` do the device-ID search itself (current pattern in §7.2 — preferred; cleaner contract).

---

## 8. Build flags + init order + smoke-test rubric

### 8.1 Init order (final, post-1.31.4)

```
1. virtio_blk_init()        # modern (or transitional w/ modern caps); registers BLK_VIRTIO
2. #ifdef RAMDISK_ENABLE
       ramdisk_init();      # 64 pages preallocated
       ramdisk_register_block_dev();  # registers BLK_RAMDISK ONLY if slot is NONE
   #endif
3. nvme_*()                 # overrides whatever's in the slot if NVMe present
4. ahci_*()                 # registers secondary if NVMe; overrides VIRTIO/RAMDISK if not
5. msc_register_block_dev() # tertiary; overrides only if slot is NONE/VIRTIO/RAMDISK
```

Effective priority (highest active wins): NVMe > AHCI > USB-MS > VIRTIO > RAMDISK > NONE.

Rationale for RAMDISK below VIRTIO: RAM-disk is a development substrate; modern virtio-blk is a paravirt-real backend that QEMU CI might run against. If both are enabled (smoke test boot with `RAMDISK_ENABLE=1` and `-device virtio-blk-pci,...`), the user generally wants virtio's content (the disk image they passed in), not the empty RAM-disk. Either way both register; RAMDISK's `if (blk_active == BLK_NONE)` guard keeps it from stomping.

### 8.2 Build-flag matrix

| Flag | Default | Effect |
|---|---|---|
| `RAMDISK_ENABLE=1` | off | Compile in ramdisk.cyr; preallocate at init |
| `RAMDISK_SIZE_PAGES=<N>` | 64 | Override default; build error if N > 128 |
| (existing) `KTEST=1` | off | Self-test path; orthogonal |
| (existing) `XHCI_VERBOSE=1` | off | xhci traces; orthogonal |

### 8.3 QEMU smoke-test invocations

**Modern virtio-blk default path** (QEMU q35 + modern PCI):
```
qemu-system-x86_64 -kernel build/agnos \
    -drive file=test.img,if=none,id=blk,format=raw \
    -device virtio-blk-pci,drive=blk,disable-legacy=on,disable-modern=off \
    -serial stdio -display none
```
Expected log lines:
```
VirtIO-blk: <capacity_in_sectors> sectors
FAT16 filesystem mounted   (or whatever fatfs_init prints)
```

**Transitional path** (default QEMU `-device virtio-blk-pci`, no disable flags):
- Driver sees device ID 0x1001 with full cap list present
- Same boot log; cap-list scan finds modern caps; legacy I/O BAR0 ignored

**RAM-disk only** (no virtio device at all):
```
qemu-system-x86_64 -kernel build/agnos_ramdisk_enabled -serial stdio -display none
```
Expected:
```
ramdisk: 64 pages (256 KB) at 0x<addr>
```
followed by the boot continuing normally. `blk_active` becomes `BLK_RAMDISK` since no other backend is present.

**Combined** (RAM-disk + virtio in same boot — useful for testing dispatch policy):
- Both register; `blk_active` becomes `BLK_VIRTIO` (virtio runs first, but RAMDISK won't override since virtio's register set `blk_active != NONE`)
- Confirms the override-vs-take policy

### 8.4 Success rubric (for the implementation pass)

**Full success** — all three of these on QEMU:
1. `virtio-blk-pci,disable-legacy=on` (modern-only) — driver finds modern caps, completes init, FAT16 mounts, file read returns expected bytes
2. `virtio-blk-pci` default (transitional with modern caps) — same outcome via cap-list scan, legacy BAR0 ignored
3. `RAMDISK_ENABLE=1` standalone boot — RAM-disk registers, FAT16 init can run against it (if pre-formatted via a build-helper or test fixture)

**Partial** — modern path works, transitional path fails the cap-list scan (likely `pci_find_cap` missed the next-pointer chain). Diagnostic: dump cap_type values seen during scan.

**Failure** — FEATURES_OK readback cleared (driver accepted a bit the device didn't actually offer — check driver_features write back). Reset and abort per spec; no retry. Diagnose by logging exact accepted vs offered bits.

---

## 9. Implementation order + risk analysis

### 9.1 Recommended order within the single cut

1. **RAM-disk first** (~150 LOC, lowest risk). New file, no PCI/MMIO/DMA, pure `memcpy`. Validates the build-flag plumbing pattern + the block-layer registration extension. Done in ~30 min.
2. **`block.cyr` extension** (~15 LOC). Add `BLK_RAMDISK`, `blk_register_ramdisk`, dispatch arms. Done in ~10 min.
3. **VirtIO modern rewrite** (~600 LOC). Larger, but well-specified — the audit doc is the line-by-line spec. The descriptor-chain logic is unchanged from 0.9.5, so the rewrite is concentrated in: (a) cap-list scan, (b) state-machine restructure, (c) feature negotiation, (d) MMIO replacement of port I/O, (e) barrier insertion. Done in ~3-4 hours of focused work.
4. **`main.cyr` adjustment** (~5 LOC). Accept both device IDs.
5. **QEMU smoke** — 3 invocations per §8.3. Each ~1 min.

### 9.2 Risk ranking

| Item | Risk | Mitigation |
|---|---|---|
| FEATURES_OK readback failure (driver accepts unoffered bit) | Low — we only accept VIRTIO_F_VERSION_1 + optional RO; both are universally offered by QEMU | Log accepted-vs-offered bitmaps on failure |
| Cap-list scan misses NOTIFY_CFG | Medium — easy off-by-one in cap_next walk | Cross-check against `lspci -v` output from the QEMU guest; first-iteration debug print |
| Wrong notify multiplier math | Low — formula is `notify_base + cap.offset + qno × mul`; we cache once at init | Compute and print at init; eyeball against QEMU defaults (typically multiplier=4) |
| Missing memory barrier → device sees stale descriptor | Medium-high — silent corruption, not crash | Insert `mfence` explicitly; cross-reference all three impl barriers |
| BAR offset+length overflow | Low — QEMU never produces this; defensive only | Add the check anyway (Linux flagged it; ~3 lines of code) |
| RAM-disk pmm exhaustion mid-init | Low — 64 pages on ~354 free is comfortable | Unwind gracefully (skip registration, continue boot) |
| `pmm_alloc` non-contiguity for virtqueue | Low — we use 3 separate allocations (desc/avail/used), each fits in 1 page | Modern spec allows non-contiguous; only legacy required contiguity |

**Highest risk = barrier discipline.** Mitigation: explicit `mfence` (3-byte opcode `0F AE F0`) inline-asm'd in the avail-ring publish path. Cross-check against all three reference impls before declaring done.

### 9.3 Carry-forward / out-of-cycle

If the implementation lands clean but smoke surfaces an unexpected issue (e.g., QEMU offers a feature bit we didn't anticipate that gates a config-space field), park it as carry-forward into 1.31.5 (which is ext2 work; unrelated). Don't expand 1.31.4 scope mid-flight.

The barrier work introduces an inline-asm pattern that could be promoted to a `kernel/lib/mem_barrier.cyr` helper if more consumers appear (NVMe doorbell, AHCI command issue both have similar requirements but are currently using stronger PIO-implicit ordering). Not required for 1.31.4; flag for future cleanup.

---

## 10. Sign-off rubric

Before this plan goes to code:

- [ ] User has read §1-§4 (scope + RAM-disk plan) and §7 (virtio modern plan)
- [ ] User confirms init-order policy in §8.1 (RAMDISK below VIRTIO)
- [ ] User confirms build-flag default (RAMDISK_ENABLE off)
- [ ] User confirms scope: split virtqueue only (no packed), no IOMMU acceptance, polled-only, no FLUSH

After code lands:

- [ ] QEMU smoke 3/3 per §8.3
- [ ] No regression on existing NVMe + AHCI + USB-MS smoke harnesses
- [ ] `build/agnos` size delta in CHANGELOG matches estimate (+150 RAM-disk + ~600 virtio rewrite delta, less the ~180 LOC retired from the old driver, net ~+570 LOC / ~+15 KB build size)
- [ ] CHANGELOG `[1.31.4]` entry per `feedback_changelog_captures_movement` describes what landed; no forward scope

---

## Sources

**OASIS spec:**
- VirtIO v1.2 csd01: https://docs.oasis-open.org/virtio/virtio/v1.2/csd01/virtio-v1.2-csd01.pdf
  - §2.1 Device Status Field, §2.2 Feature Bits, §2.7 Split Virtqueues, §3.1.1 Driver Init, §4.1 Virtio Over PCI, §5.2 Block Device, §6.1 Reserved Feature Bits

**Linux:**
- `drivers/virtio/virtio_pci_modern.c`, `drivers/virtio/virtio_pci_modern_dev.c`, `drivers/block/virtio_blk.c`, `drivers/virtio/virtio_ring.c`

**FreeBSD:**
- `sys/dev/virtio/pci/virtio_pci_modern.c`, `sys/dev/virtio/block/virtio_blk.c`, `sys/dev/virtio/virtqueue.c`

**OpenBSD:**
- `sys/dev/pci/virtio_pci.c`, `sys/dev/pv/vioblk.c`, `sys/dev/pv/virtio.c`

**RAM-disk references:**
- Linux `drivers/block/brd.c`; FreeBSD `sys/dev/md/md.c`; NetBSD `sys/dev/md.c`; OpenBSD `sys/dev/rd.c`; Haiku `src/add-ons/kernel/drivers/disk/virtual/ram_disk/ram_disk.cpp`

**AGNOS internal:**
- `kernel/core/virtio_blk.cyr` (existing 0.9.5 transitional, 181 LOC)
- `kernel/core/block.cyr` (existing dispatch layer)
- `kernel/core/nvme.cyr`, `kernel/core/ahci.cyr` (the proven `_register_block_dev` + Phase-N pattern this plan follows)
- `kernel/core/pci.cyr` (existing `pci_find_cap` + `pci_bar_phys` infrastructure)
