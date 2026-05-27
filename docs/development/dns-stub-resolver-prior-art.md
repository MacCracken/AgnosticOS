# DNS Stub Resolver — Multi-Source Prior-Art Audit

> **Status**: audit complete, pre-implementation. Companion to the agnos **1.35.x catchup cycle** (first real bite). Per [[feedback_redesign_dont_reinvent]] — derive the converged shape from multiple independent sources, then diff against AGNOS, then port.
>
> **Scope**: a **stub resolver** — turn a hostname into an IPv4 address by asking a configured recursive resolver over UDP. NOT a recursive/caching resolver (no root-server walk, no zone storage, no DNSSEC validation). The precondition for name-based networking (`ark`/`nous` fetch, `hoosh` gateway hostnames) and the substrate for the **`dig`** userland tool ([[project_tools_stable_ideas]]).
>
> **Created**: 2026-05-27.

---

## 1. Sources surveyed

| Source | What it contributes | Shape |
|---|---|---|
| **RFC 1035** (Domain Names — Implementation) | The wire format: header, question, RR, name encoding + compression | normative |
| **RFC 3596** (DNS Extensions for IPv6) | `AAAA` record type (28); identical framing | normative |
| **RFC 2131 / 2132** (DHCP + options) | Option 6 = Domain Name Server list (the resolver address source) | normative |
| **musl libc** `res_mkquery` / `__res_msend` / `__dns_parse` | Minimal POSIX stub: build query, send to each nameserver in parallel, parse first valid answer; **no cache** | ~300 LOC C |
| **OpenBSD** `asr` (`res_send`, `asr_run`) | Async resolver state machine; same wire format, retransmit/timeout discipline | event-driven |
| **Plan 9** `/sys/src/cmd/ndb/dns` + `dn.c` | Resolver as a server speaking RFC 1035; ndb config supplies nameservers | process-model |
| **lwIP** `dns.c` / **iPXE** `dns.c` | **Closest analog** — embedded stub resolver, no libc, single in-flight query table, UDP, compression handling, A/AAAA | ~200 LOC core |

**Convergence**: all five implementations speak the identical RFC 1035 wire format over UDP/53. They differ only in policy (caching, parallelism, async vs blocking, retransmit cadence) — none of which a minimal kernel stub needs. The embedded pair (lwIP/iPXE) is the right structural model: one query at a time, bounded poll, no cache, no TCP fallback in the minimal cut.

---

## 2. Wire format (RFC 1035 §4) — the load-bearing part

All multi-byte fields are **big-endian** (network order).

### 2.1 Header — 12 bytes

```
 0               1
 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5
+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
|                      ID                       |   2  transaction id (match req↔resp)
+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
|QR| Opcode    |AA|TC|RD|RA|  Z   |   RCODE     |   2  flags
+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
|                   QDCOUNT                      |   2  question count
|                   ANCOUNT                      |   2  answer count
|                   NSCOUNT                      |   2  authority count
|                   ARCOUNT                      |   2  additional count
+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+--+
```

- **Query flags** = `0x0100` → `QR=0` (query), `Opcode=0` (standard QUERY), `RD=1` (recursion desired). Everything else 0.
- **Response check**: `QR=1`, `RCODE=0` (= NOERROR; 3 = NXDOMAIN), `ANCOUNT ≥ 1`. `TC=1` (truncated) → minimal stub treats as failure (no TCP fallback in v1).
- **ID**: pick a non-trivial value (incrementing counter is fine for a single-host stub; randomized is the anti-spoof posture). The response MUST echo it.

### 2.2 Question section — QDCOUNT × { QNAME, QTYPE, QCLASS }

- **QNAME**: a sequence of **length-prefixed labels**, terminated by a zero byte.
  `www.example.com` → `03 77 77 77  07 65 78 61 6d 70 6c 65  03 63 6f 6d  00`.
  Each label ≤ 63 bytes (the two high bits of the length byte are reserved — see compression). Total name ≤ 255 bytes.
- **QTYPE** (2): `A` = **1**, `AAAA` = 28, `CNAME` = 5, `PTR` = 12.
- **QCLASS** (2): `IN` = **1**.

A query is always `QDCOUNT = 1` here (one question per datagram — the universal practice; multi-question is unsupported by virtually all servers).

### 2.3 Resource Record (answer) — NAME, TYPE, CLASS, TTL, RDLENGTH, RDATA

```
NAME      variable  — usually a compression pointer back to the question
TYPE      2         — 1 = A, 5 = CNAME, 28 = AAAA
CLASS     2         — 1 = IN
TTL       4         — seconds (ignored by a non-caching stub)
RDLENGTH  2         — length of RDATA
RDATA     RDLENGTH  — for A: 4 bytes = IPv4; for AAAA: 16 bytes; for CNAME: a name
```

### 2.4 Name compression (RFC 1035 §4.1.4) — the parsing trap

A name in the answer is frequently a **pointer**, not inline labels: a length byte with the **top two bits set** (`0xC0`) signals a pointer; the low 14 bits (this byte's low 6 + the next byte) are an **offset from the start of the DNS message** to where the name continues.

**For a stub that only wants the A-record RDATA, full name decompression is unnecessary** — we only need to *skip past* each name to reach TYPE/CLASS/TTL/RDLEN/RDATA. Skipping a name:

```
loop:
  b = msg[p]
  if (b & 0xC0) == 0xC0:   # pointer — 2 bytes, name ends here
      p += 2; done
  elif b == 0x00:          # root label — 1 byte, name ends here
      p += 1; done
  else:                    # ordinary label of length b
      p += 1 + b; continue
```

This "skip, don't decompress" shortcut is what lwIP/iPXE use in their answer walk. We adopt it: the resolver never needs to *reconstruct* a compressed name, only to step over it.

---

## 3. The converged resolver loop (minimal stub)

Distilled from musl `__res_msend` + lwIP `dns.c`, stripped to the single-query blocking case:

```
dns_resolve(hostname, out_ip):
  1. server = configured resolver (DHCP opt 6 → static fallback)
  2. id = next_query_id()
     src_port = ephemeral (e.g. 0xC000 + id&0xFFF)
  3. build query buffer:
       header{ id, flags=0x0100, qd=1, an=0, ns=0, ar=0 }
       qname(hostname) + qtype=A(1) + qclass=IN(1)
  4. udp_bind(src_port)
     udp_send_from(net_ip, server, src_port, 53, query, qlen)
  5. poll for response with bounded timeout (net_poll loop, N spins):
       resp = udp_recv_from(listener, ...)
       validate: resp.id == id AND QR==1 AND RCODE==0 AND ANCOUNT>=1
  6. parse answer:
       p = 12 (skip header)
       skip question: skip_name(p); p += 4 (qtype+qclass)
       for i in 0..ANCOUNT:
         skip_name(p)
         type=u16(p); class=u16(p+2); ttl=u32(p+4); rdlen=u16(p+8); p+=10
         if type==A and class==IN and rdlen==4:
             out_ip = u32(p);  return OK
         p += rdlen          # skip non-A (CNAME/AAAA/etc.)
  7. timeout / NXDOMAIN / no-A → return error
```

**Policy decisions for the v1 cut** (each matches at least one embedded source):
- **One in-flight query, blocking** — no async table (lwIP has one; we don't need concurrency yet).
- **No cache** — musl doesn't cache either; add later if a consumer needs it.
- **No TCP fallback** — `TC=1` is a failure; rare for A queries under 512 B.
- **No EDNS0** — skip the OPT record; 512-byte UDP is the classic floor and sufficient.
- **CNAME handling** — if the answer is a CNAME chain, a well-behaved recursive resolver returns the final A record in the *same* response (it resolves the chain). So walking all ANCOUNT records and taking the first `A` is correct without us chasing CNAMEs ourselves. (Documented lwIP/iPXE behavior.)
- **Anti-spoof floor** — match transaction ID + the bound source port (the kernel only delivers to the bound listener). Question-section match is a stretch goal, not v1.

---

## 4. Resolver address acquisition — DHCP option 6

Per RFC 2132 §3.8, **option 6** carries a list of DNS server IPv4 addresses (length = 4×N; first is preferred). AGNOS's DHCP client **already requests it** (param-request-list option 55 includes tag 6 — `net.cyr` DISCOVER builder), but the ACK handler currently parses only option 1 (subnet) and option 3 (gateway) and **drops option 6**.

The fix is symmetric with the existing gateway capture: in the ACK path, `dhcp_find_option(opts, len, 6)` → store the first 4 bytes as `net_dns_server`. **Fallback** when DHCP supplies none (or DHCP is bypassed for STATIC): use a configured static (the gateway is a reasonable LAN default; `1.1.1.1` / `8.8.8.8` as a public last resort). The fallback choice is a one-liner and can be revisited.

---

## 5. Diff against AGNOS current state (`kernel/core/net.cyr`, 1190 LOC)

| Need | AGNOS today | Gap |
|---|---|---|
| UDP egress | `udp_send` / `udp_send_from` ✓ | none |
| UDP bind + receive | `udp_bind` / `udp_recv_from` + 8-listener table (1024-B buffers) + `net_handle_udp` ingress demux ✓ (built for DHCP) | none — **the old roadmap "UDP ingress is the gap" framing is stale; the 1.32.x DHCP work already built it** |
| Resolver address | DHCP opt 6 **requested** (param-list) but **not captured**; no `net_dns_server` global | **Bite 1**: capture opt 6 in ACK handler + static fallback |
| DNS wire layer | none | **Bite 2**: `dns_build_query` + `dns_parse_answer` (skip-name walk) + `dns_resolve` |
| Name skip (compression) | none | part of Bite 2 (`dns_skip_name`) |
| User-facing test | none | **Bite 2**: `dns`/`resolve` shell verb (dig substrate) |
| Big-endian u16/u32 helpers | `dhcp_store_u32_be` etc. exist; `ip4()` exists | reuse |

**Net**: the transport is done. The work is the ~per-RFC-1035 protocol layer (~150–200 LOC) + a 4-line DHCP-option capture. Smaller than the network-arc or FAT bites.

---

## 6. Bite plan

- **Bite 1 — DHCP option-6 capture** (~10 LOC). In the DHCP ACK handler, `dhcp_find_option(..., 6)` → `net_dns_server` (new global, mirrors `net_gateway`). Static fallback assignment when absent. Validatable immediately under QEMU/SLIRP (SLIRP hands out option 6 = `10.0.2.3`).
- **Bite 2 — RFC 1035 resolver** (~150–200 LOC): `dns_qname_encode`, `dns_build_query`, `dns_skip_name`, `dns_parse_answer`, `dns_resolve(host, out_ip)`; a `dns <hostname>` shell verb that prints the resolved dotted-quad. New `scripts/dns-smoke.sh` QEMU gate (resolve a known name through SLIRP's resolver, assert a sane A record).

No iron burn required for either bite — DNS rides the same r8169/DHCP path that's already iron-COMPLETE (1.32.9); QEMU/SLIRP is the validation surface. An opportunistic iron confirmation can ride the next scheduled burn (per [[feedback_iron_burns_block_other_work]]), but it does not gate the cut.

---

## 7. Falsification / test rubric

The `dns-smoke.sh` gate (QEMU + SLIRP + r8169 or virtio-net):

1. **Build clean** + `scripts/test.sh` 4/4 (no regression).
2. **Option-6 capture** — boot prints the captured `net_dns_server` (SLIRP = `10.0.2.3`); a non-zero value falsifies "opt 6 still dropped."
3. **Forward lookup** — `dns example.com` (or a SLIRP-reachable name) returns a syntactically valid dotted-quad, ANCOUNT-derived, not a hardcoded constant. A wrong/zero answer falsifies the parse.
4. **NXDOMAIN path** — `dns nonexistent.invalid` returns a clean error (RCODE=3 handled), not a hang or garbage IP.
5. **Compression walk** — the answer NAME is a `0xC0` pointer in practice (SLIRP/most resolvers compress); a correct A extraction proves `dns_skip_name` handles the pointer case.

**Pre-bound outcome**: if the parse returns the right IP for a real name through SLIRP, the wire layer is proven; iron is then a formality on the already-validated DHCP/r8169 path.

---

## 8. Out of scope (explicitly deferred)

- Caching (TTL-respecting cache) — add when a consumer's query volume justifies it.
- TCP fallback for `TC=1` truncated responses.
- EDNS0 / DNSSEC.
- AAAA / IPv6 (the framing is identical — TYPE 28, 16-byte RDATA — but AGNOS has no IPv6 stack yet).
- Multiple-nameserver parallelism (musl-style) — single configured resolver suffices.
- `/etc/resolv.conf`-equivalent config file — DHCP opt 6 + static fallback is the v1 source; a config surface can come with the `dig` tool / ark networking.
