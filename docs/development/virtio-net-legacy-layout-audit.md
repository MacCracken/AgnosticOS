# virtio-net Legacy Queue Layout Audit

**Date**: 2026-05-23
**Auditor**: Claude (Opus 4.7, 1M ctx)
**Target**: `agnos/kernel/core/virtio_net.cyr` (148 LOC) — legacy/transitional virtio PCI device (vendor `0x1AF4`, device `0x1000`)
**Trigger**: QEMU pcap (`-object filter-dump`) captures **zero AGNOS-egress frames**. Only OVMF's IPv6 NS appears (126 bytes total). Kernel prints `dhcp: DISCOVER` but the frame never reaches the wire.
**Hypothesis under test**: AGNOS's six-separate-arrays virtqueue layout violates the virtio legacy spec's contiguous desc/avail/used requirement, so the device reads `avail.idx` from an address the driver never writes.

---

## Verdict

**HYPOTHESIS CONFIRMED.** The single most load-bearing piece of evidence: the virtio legacy spec (and Linux + OpenBSD + FreeBSD in convergent agreement) require desc, avail, and used to be **one physically-contiguous block** whose base address — right-shifted by 12 — is the value written to `VIRTIO_PCI_QUEUE_PFN`. The device reconstructs the avail-ring address as `desc_base + num * sizeof(virtq_desc)` (i.e. `desc_base + 16 * qsz`) and the used-ring as the next 4096-aligned address after that. AGNOS writes `&vnet_tx_desc / 4096` to `QUEUE_PFN`, which means the device interprets `&vnet_tx_desc + 16*qsz` as the avail ring — but `vnet_tx_avail` is a **separate module-global** at an unrelated linker-determined address (4-8 KB away, possibly further). Every avail.idx increment the driver writes lands somewhere the device never reads, so the device's "last seen avail.idx" stays at 0 forever and no TX descriptor is ever consumed. The kernel's view ("I posted a descriptor and rang the doorbell") and the device's view ("avail.idx is still 0, nothing to do") disagree completely. This is consistent with the QEMU pcap evidence.

---

## Spec section (verbatim)

**OASIS virtio 1.0 CS04 / virtio 1.1 CSPRD01, §2.4.2 (1.0) / §2.6.2 (1.1) — "Legacy Interfaces: A Note on Virtqueue Layout"**:

> Each virtqueue occupies two or more physically-contiguous pages (usually defined as 4096 bytes, but depending on the transport; henceforth referred to as Queue Align)

> ```c
> #define ALIGN(x) (((x) + qalign) & ~qalign)
> static inline unsigned virtq_size(unsigned int qsz)
> {
>     return ALIGN(sizeof(struct virtq_desc)*qsz + sizeof(u16)*(3 + qsz))
>          + ALIGN(sizeof(u16)*3 + sizeof(struct virtq_used_elem)*qsz);
> }
> ```

> ```c
> struct virtq {
>     struct virtq_desc desc[ Queue Size ];
>     struct virtq_avail avail;
>     u8 pad[ Padding ];
>     struct virtq_used used;
> };
> ```

The single struct `virtq` literally fixes the in-memory ordering: desc table first, avail ring immediately after, padding to Queue Align (4096), then used ring. There is no transport-side mechanism for the driver to communicate three independent base addresses — only one PFN crosses the doorbell.

**Transport register**: legacy virtio PCI exposes `VIRTIO_PCI_QUEUE_PFN` at BAR0 offset 8 (a 32-bit write of `phys_addr >> 12`). The shift is the canonical "page frame number" encoding — `VIRTIO_PCI_QUEUE_ADDR_SHIFT = 12` in `include/uapi/linux/virtio_pci.h`.

---

## Linux convergence

**`include/uapi/linux/virtio_ring.h`** (Linux v6.6, canonical static-inline definitions, quoted verbatim):

```c
struct vring {
    unsigned int num;
    vring_desc_t *desc;
    vring_avail_t *avail;
    vring_used_t *used;
};

static inline void vring_init(struct vring *vr, unsigned int num, void *p,
                              unsigned long align)
{
    vr->num = num;
    vr->desc = p;
    vr->avail = (struct vring_avail *)((char *)p + num * sizeof(struct vring_desc));
    vr->used  = (void *)(((uintptr_t)&vr->avail->ring[num] + sizeof(__virtio16)
                          + align - 1) & ~(align - 1));
}

static inline unsigned vring_size(unsigned int num, unsigned long align)
{
    return ((sizeof(struct vring_desc) * num + sizeof(__virtio16) * (3 + num)
             + align - 1) & ~(align - 1))
           + sizeof(__virtio16) * 3 + sizeof(struct vring_used_elem) * num;
}
```

**Formula (Linux, distilled)**:

- `desc_base = p` (the caller-provided base pointer)
- `avail_base = p + 16 * num`        — `sizeof(struct vring_desc) == 16` is a hard ABI fact (8B addr + 4B len + 2B flags + 2B next)
- `used_base  = ALIGN_UP(avail_base + 6 + 2*num, align)` — the `+6` is `flags(2) + idx(2) + used_event(2)` past the `num`-entry avail ring; `align` is `VIRTIO_PCI_VRING_ALIGN = 4096`
- The full block is one contiguous allocation of `vring_size(num, 4096)` bytes

**`drivers/virtio/virtio_pci_legacy.c`** confirms the single allocation pattern: `setup_vq` (now `vp_setup_vq` in v6.6) calls `vring_create_virtqueue(index, num, VIRTIO_PCI_VRING_ALIGN, ...)` which internally `dma_alloc_coherent`s one contiguous block, then computes:

```c
q_pfn = virtqueue_get_desc_addr(vq) >> VIRTIO_PCI_QUEUE_ADDR_SHIFT;
vp_legacy_set_queue_address(&vp_dev->ldev, index, q_pfn);
```

i.e., **only the desc base PFN is given to the device.** Everything else is implied by the spec formula.

**`include/uapi/linux/virtio_pci.h`** (verbatim):

```c
#define VIRTIO_PCI_QUEUE_PFN          8
#define VIRTIO_PCI_QUEUE_ADDR_SHIFT  12
#define VIRTIO_PCI_VRING_ALIGN     4096
```

---

## BSD convergence

**OpenBSD `sys/dev/pv/virtio.c`** — `virtio_alloc_vq()`, line ~748:

```c
#define VIRTQUEUE_ALIGN(n) (((n)+(VIRTIO_PAGE_SIZE-1))&~(VIRTIO_PAGE_SIZE-1))

allocsize1 = VIRTQUEUE_ALIGN(sizeof(struct vring_desc) * vq_size
                + sizeof(uint16_t) * (hdrlen + vq_size));
allocsize2 = VIRTQUEUE_ALIGN(sizeof(uint16_t) * hdrlen
                + sizeof(struct vring_used_elem) * vq_size);
...
allocsize  = allocsize1 + allocsize2 + allocsize3;
```

OpenBSD performs **one allocation of size `allocsize`** with `VIRTIO_PAGE_SIZE` (4096) alignment. Region offsets within that single block (lines 823-833):

- desc + avail: offset `0` (size `allocsize1`)
- used: offset `allocsize1`
- indirect descriptors (optional): offset `allocsize1 + allocsize2`

Same formula as Linux, just expressed as offsets-into-one-buffer rather than ALIGN-up arithmetic.

**FreeBSD `sys/dev/virtio/virtqueue.c`**, line ~317:

```c
vq->vq_ring_size = round_page(vring_size(size, align));
...
error = bus_dmamem_alloc(vq->vq_ring_dmat, &vq->vq_ring_mem,
        BUS_DMA_NOWAIT | BUS_DMA_ZERO | BUS_DMA_COHERENT,
        &vq->vq_ring_mapp);
...
vring_init(vr, size, ring_mem, vq->vq_ring_paddr, vq->vq_alignment);
```

FreeBSD allocates `round_page(vring_size(size, 4096))` as one DMA-coherent block and calls `vring_init` (same definition as Linux's header) to lay out the three regions. The legacy PCI transport (`virtio_pci_legacy.c`, `vtpci_legacy_set_vq` lines 750-757):

```c
vtpci_legacy_write_header_4(sc, VIRTIO_PCI_QUEUE_PFN,
    virtqueue_paddr(vq) >> VIRTIO_PCI_QUEUE_ADDR_SHIFT);
```

Identical: only the desc-base PFN crosses to the device. **Three independent references (Linux, OpenBSD, FreeBSD) converge on the exact same layout.** Per project memory `feedback_redesign_dont_reinvent`, this is solid convergent prior art — there is no portable virtio-legacy host that accepts split desc/avail/used.

---

## AGNOS divergence (line-by-line)

### The declarations (`virtio_net.cyr:6-13`)

```cyrius
var vnet_tx_desc[64];      # module-global var X[N] = 8N bytes -> 512 bytes
var vnet_tx_avail[8];      # -> 64 bytes
var vnet_tx_used[8];       # -> 64 bytes
var vnet_rx_desc[64];      # -> 512 bytes
var vnet_rx_avail[8];      # -> 64 bytes
var vnet_rx_used[8];       # -> 64 bytes
```

These are **six independent module-global allocations**, each placed at a linker-determined address inside the kernel BSS/data segment. There is no guarantee — and in practice no possibility — that `&vnet_tx_avail == &vnet_tx_desc + 16*qsz`. The Cyrius linker has no awareness of virtio layout requirements; the addresses are whatever the symbol table assigns.

**Sizing also wrong**: with the de-facto queue size of `64` slots (the array dimension the driver clearly assumed, though the driver actually reads `qsz` from `vnet_iobase + 12` and ignores the return for sizing), legacy spec requires:

- desc table: `16 * 64 = 1024 bytes` — AGNOS has `512` bytes (8 descriptors' worth). **Half the required size.** `vnet_tx_desc[64]` at module scope is 64×u64 = 512 bytes, which is 32 descriptors, not 64 (per project memory `cyrius-var-array-u64-units`).
- avail ring: `4 + 2*64 + 2 = 134 bytes` — AGNOS has `64` bytes. Avail ring entries past index ~30 walk off the end.
- used ring: `4 + 8*64 + 2 = 518 bytes` — AGNOS has `64` bytes. Wildly under-sized.

If QEMU advertises the customary 256-slot queue, the under-sizing is far worse: avail/used would need ~518/2054 bytes vs AGNOS's 64.

### The init path (`virtio_net.cyr:39-47`)

```cyrius
var tx_addr = &vnet_tx_desc;
outl(vnet_iobase + 8, tx_addr / 4096);    # line 41
...
var rx_addr = &vnet_rx_desc;
outl(vnet_iobase + 8, rx_addr / 4096);    # line 47
```

The driver writes only `&vnet_tx_desc / 4096` (and `&vnet_rx_desc / 4096`) to `QUEUE_PFN`. The device now believes:

- TX desc base = `(&vnet_tx_desc / 4096) * 4096` — but `&vnet_tx_desc` is **not page-aligned** unless the Cyrius linker happens to put it on a page boundary. Integer division truncates, so the device is told a base that is **off by `&vnet_tx_desc mod 4096`** from where the driver actually wrote the descriptors. **First-order bug**, before we even reach the avail-ring issue.
- TX avail base = device-computed = `desc_base + 16 * qsz`. With `qsz` whatever QEMU reports (typically 256 for virtio-net), that's `desc_base + 4096` — pointing to some unrelated symbol in the kernel BSS, **not** `&vnet_tx_avail`.
- TX used base = `ALIGN_UP(avail_base + 6 + 2*qsz, 4096)` — pointing yet further into unrelated memory.

### The send path (`virtio_net.cyr:80-105`)

The driver writes the descriptor (lines 93-96), then increments avail.idx (lines 98-100):

```cyrius
store16(&vnet_tx_avail, 0);                       # line 98  (flags = 0)
store16(&vnet_tx_avail + 2, vnet_tx_idx + 1);     # line 99  (idx = N+1)
store16(&vnet_tx_avail + 4, 0);                   # line 100 (ring[0] = desc index 0)
outw(vnet_iobase + 16, 0);                        # line 103 (doorbell: notify queue 0)
```

The store to `&vnet_tx_avail + 2` lands in the standalone `vnet_tx_avail` global. The device, when notified, **reads avail.idx from `desc_base_PFN*4096 + 16*qsz + 2`** — which is some other kernel symbol, untouched, presumably zero (BSS-initialized). Device sees `avail.idx == last_seen_avail.idx == 0`, concludes nothing's new, returns. **Frame never egresses.** This precisely matches the pcap evidence.

### Consequence summary

The kernel completes `virtio_net_send` happily (returns `len`, the doorbell is rung), but **the device's model of the queue has no overlap with the driver's model of the queue.** They share only the desc-table-base (and even that is misaligned by `&vnet_tx_desc mod 4096`). Doorbells fire into the void. Zero frames cross the chip.

The RX path has the symmetric bug — `vnet_rx_avail` and `vnet_rx_used` are also separate allocations — but RX failure is silent in pcap (no incoming frames to be missed when the only inbound traffic is OVMF NS, which the driver couldn't process anyway because the descriptor was never visible to the device). The RX bug would surface as "no DHCPOFFER seen" *if* TX worked, but TX doesn't, so RX is currently masked.

---

## Minimum-viable fix shape (structural sketch, NO code)

The repair has three structural requirements, all driven by the spec formula `desc | avail | pad-to-Queue-Align | used` in **one contiguous, page-aligned block per queue**.

### (1) One page-aligned buffer per queue

Replace the six separate arrays `vnet_tx_desc / vnet_tx_avail / vnet_tx_used / vnet_rx_desc / vnet_rx_avail / vnet_rx_used` with **two** page-aligned contiguous buffers, one per queue. Concretely:

- `vnet_tx_ring` — single buffer, page-aligned, sized for `vring_size(qsz, 4096)`. For `qsz = 256`: `16*256 + 4 + 2*256 + 2 = 4102` bytes for desc+avail, rounded up to 4096 = `4096` (won't fit) — so it spills to next page: `8192` bytes; plus used ring `4 + 8*256 + 2 = 2054`, rounded to 4096 = `4096`. Total = `8192 + 4096 = 12288` bytes (3 pages). For a small `qsz = 16`: `16*16 + 4 + 2*16 + 2 = 294`, ALIGN to 4096 = `4096`; plus `4 + 8*16 + 2 = 134`, ALIGN to 4096 = `4096`. Total = **8192 bytes (2 pages)** — the spec-minimum "two or more physically-contiguous pages."
- `vnet_rx_ring` — same shape.

Because Cyrius module-global `var X[N]` allocates `N*8` bytes and there is no `[[align(4096)]]` directive in current Cyrius, the page-alignment requirement has two viable approaches:

- **Approach A: over-allocate + offset.** Declare each ring buffer at least `vring_size + 4096` bytes; at init compute `ring_base = (&vnet_tx_ring + 4095) & ~4095`. Trades 4 KB of slack per queue for zero-language-feature-requirement. Recommended for MVP.
- **Approach B: use the kernel's page allocator.** If `agnos/kernel/core/mm.cyr` or equivalent exposes a `alloc_pages(n)` returning page-aligned addresses, ask for `n = vring_size / 4096` pages per queue and store the returned base in a `var vnet_tx_ring_base = 0;` module-global. Cleaner, but requires that allocator to exist and be callable from network init (init-order question).

### (2) Use the device-reported `qsz`, don't hardcode

`virtio_net.cyr:37` already reads `tx_qsz = inw(vnet_iobase + 12)` but **never uses it**. The buffer sizing and the descriptor-index masks in `virtio_net_poll` (line 116: `& 0xFF`, hardcoded to 256) must be derived from `tx_qsz` and `rx_qsz`. Otherwise the ring goes silent the first time QEMU picks a different default.

Store `vnet_tx_qsz` and `vnet_rx_qsz` as module globals at init time; use them everywhere a queue-size constant is needed.

### (3) Compute offsets per the spec at every access

The init code should compute, **per queue**:

```
desc_off  = 0
avail_off = 16 * qsz
used_off  = ALIGN_UP(avail_off + 6 + 2*qsz, 4096)
```

…and store them once as `vnet_tx_desc_off / vnet_tx_avail_off / vnet_tx_used_off` (and the RX counterparts), then every read/write in `virtio_net_send` and `virtio_net_poll` is `ring_base + <slot>_off + field_offset`. Drops the dependency on the six rogue addresses entirely.

### (4) Write the page-aligned ring base to QUEUE_PFN

After page-alignment is established, the `outl(vnet_iobase + 8, ring_base / 4096)` write is correct (no more truncation-induced misalignment).

### TX/RX symmetry

The fix is symmetric. Both queues need the same treatment. No queue-specific shortcuts.

---

## LOC estimate

**Net ~+40 LOC** in `virtio_net.cyr`:

- Declarations: -6 lines (remove the six split arrays) + 4 lines (two ring buffers, two `*_qsz` and two `*_ring_base` globals) = **net -2**
- `virtio_net_init`: +12 lines (page-align both ring bases, compute and store the desc/avail/used offsets per queue, store `qsz` globals, zero the rings)
- `virtio_net_send`: ~+8 lines of churn (replace every `&vnet_tx_desc` / `&vnet_tx_avail` reference with `vnet_tx_ring_base + offset`; mask `vnet_tx_idx` by `qsz - 1` rather than implicitly)
- `virtio_net_poll`: ~+12 lines of similar churn, including replacing the hardcoded `& 0xFF` mask with `& (vnet_rx_qsz - 1)` and the entry-offset arithmetic with `used_off + 4 + (idx & (qsz-1)) * 8`
- `virtio_net_mac`: 0 lines (untouched)

Final file likely **~190 LOC** vs the current 148.

---

## Risk + secondary findings

1. **RX path is also broken** by the same layout bug (above). Even after the layout fix, RX has additional issues: the descriptor flags `2` on line 52 (`VIRTQ_DESC_F_WRITE`) are correct for RX, but the descriptor is only ever re-posted to slot 0 (`store16(&vnet_rx_desc, ...)` on line 130, not `&vnet_rx_desc + (idx & mask) * 16`). After the layout fix, RX will work for the first packet and then quietly stop. **Recommended**: roll the descriptor-slot-rotation fix into the same cycle.

2. **Feature negotiation is unchecked.** Line 32-33: `outl(vnet_iobase + 4, features)` writes back *all* device features without filtering. The spec requires the driver to ack *only* the subset it understands. Notable feature bit consequences:
   - `VIRTIO_NET_F_MRG_RXBUF` (bit 15) — if accepted, virtio-net header grows from 10 to 12 bytes. AGNOS hardcodes `hdr_len = 10` (line 84, 121). QEMU advertises this by default on legacy. **If QEMU sets it, AGNOS frames will be off-by-2.**
   - `VIRTIO_NET_F_CTRL_VQ` (bit 17) — if accepted, the device exposes a *third* queue. AGNOS only configures queues 0 and 1. Unlikely to cause egress failure but breaks spec.
   - **Recommended**: mask `features` down to `VIRTIO_NET_F_MAC` (bit 5) only for MVP. Defer MRG_RXBUF + CSUM offload to a later cycle.

3. **No `VIRTIO_CONFIG_S_FAILED` handling.** If the device rejects the driver's feature set (it can, on legacy by signaling status), AGNOS doesn't notice. Low priority but spec-mandated.

4. **The `vnet_tx_idx` field is `var ... = 0` once and incremented without modulo.** After 65,536 sends, it wraps via u16 truncation in `store16`. That's actually correct per spec (avail.idx is a 16-bit free-running counter and *should* wrap). No bug, but worth a comment when the fix lands.

5. **No queue-reset on init.** Spec recommends writing `0` to `QUEUE_PFN` before configuring a fresh PFN, to ensure the device discards any stale state. The reset at line 25 (`outb(vnet_iobase + 18, 0)`) is the *device* reset, which subsumes queue reset, so this is fine — but worth documenting why no per-queue reset is needed.

6. **Doorbell value semantics.** Line 103 / 139 write the queue index as the doorbell value (`outw(vnet_iobase + 16, 0)` for TX queue 0). Per spec this is correct for legacy. No bug.

7. **Build target**: this is iron + QEMU. After the fix lands, validate on QEMU first (pcap evidence is cheap), then plan an iron burn on archaemenid (per memory `iron_burns_block_other_work`, do not bundle this with unrelated work). r8169 on archaemenid is the working comparison surface.

---

## Cross-references

**Spec**:
- OASIS virtio 1.0 CS04, §2.4.2 "Legacy Interfaces: A Note on Virtqueue Layout" — https://docs.oasis-open.org/virtio/virtio/v1.0/cs04/virtio-v1.0-cs04.html
- OASIS virtio 1.1 CSPRD01, §2.6.2 (same content, renumbered) — https://docs.oasis-open.org/virtio/virtio/v1.1/csprd01/virtio-v1.1-csprd01.html

**Linux**:
- `include/uapi/linux/virtio_ring.h` (vring_init, vring_size, struct vring) — https://raw.githubusercontent.com/torvalds/linux/v6.6/include/uapi/linux/virtio_ring.h
- `drivers/virtio/virtio_pci_legacy.c` (setup_vq → vring_create_virtqueue → QUEUE_PFN write) — https://raw.githubusercontent.com/torvalds/linux/v6.6/drivers/virtio/virtio_pci_legacy.c
- `include/uapi/linux/virtio_pci.h` (`VIRTIO_PCI_QUEUE_PFN=8`, `VIRTIO_PCI_QUEUE_ADDR_SHIFT=12`, `VIRTIO_PCI_VRING_ALIGN=4096`) — https://raw.githubusercontent.com/torvalds/linux/v6.6/include/uapi/linux/virtio_pci.h

**OpenBSD**:
- `sys/dev/pv/virtio.c` (virtio_alloc_vq, VIRTQUEUE_ALIGN, single-allocation layout) — https://github.com/openbsd/src/blob/master/sys/dev/pv/virtio.c

**FreeBSD**:
- `sys/dev/virtio/virtqueue.c` (vq_ring_size = round_page(vring_size(...)), single bus_dmamem_alloc, vring_init) — https://github.com/freebsd/freebsd-src/blob/main/sys/dev/virtio/virtqueue.c
- `sys/dev/virtio/pci/virtio_pci_legacy.c` (vtpci_legacy_set_vq writing `virtqueue_paddr(vq) >> 12` to QUEUE_PFN) — https://github.com/freebsd/freebsd-src/blob/main/sys/dev/virtio/pci/virtio_pci_legacy.c

**AGNOS**:
- `agnos/kernel/core/virtio_net.cyr` — the driver under audit
- `agnos/kernel/core/ext2.cyr:28-44` — canonical Cyrius `var X[N]` scope-unit example (per project memory `cyrius-var-array-u64-units`)

---

## Closeout

Hypothesis **confirmed**. The split-array layout is the root cause of the zero-egress symptom. Three independent prior-art sources (Linux, OpenBSD, FreeBSD) converge on the contiguous-block formula `desc | avail | pad-to-4096 | used` per queue, and the legacy virtio PCI transport gives the device only the desc-base PFN — leaving no mechanism by which AGNOS could communicate its separate avail/used addresses even if it wanted to. Fix shape is a structured rewrite of the declarations + init path (~+40 LOC net), no language-feature dependencies. RX descriptor-slot-rotation is a closely-coupled secondary bug worth folding into the same cycle. Feature-mask discipline (drop MRG_RXBUF) is a recommended companion fix to avoid the 10-vs-12-byte header trap.
