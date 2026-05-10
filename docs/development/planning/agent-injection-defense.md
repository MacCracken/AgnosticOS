# Agent Injection Defense — Encoded-Payload Hardening

> **Status**: Planning — Design Phase | **Last Updated**: 2026-05-10
>
> Defense in depth against **encoded prompt injection** — instructions hidden in representations the LLM decodes natively (Morse, Base64, Unicode tricks, etc.) but pre-LLM safety filters don't recognize as instructions.
>
> **Trigger event**: 2026-05 incident — third-party AI agent drained for $200K via Morse code embedded in a tweet ([CCN report](https://www.ccn.com/news/crypto/ai-agent-drained-for-200k-with-this-one-tweet-hack-heres-how/)). Pattern is general; the attack class is the concern, not the specific platform.
>
> **Scope**: Cross-cutting — spans phylax, t-ron, hoosh, kavach, libro, agnostik. This doc is the design spine; per-repo issues track the implementation.
>
> **Companion**: [first-party-standards.md § Security Hardening](first-party-standards.md#security-hardening-required-before-every-release) — the existing per-release audit pattern. This doc extends it for AI-agent-specific surfaces.

---

## The attack class

**Encoded prompt injection** is not a single technique — it's a category of attacks that exploit the gap between:

- What pre-LLM safety filters scan for (typically: English instructions, common jailbreak patterns)
- What the LLM understands natively (any encoding it learned in pretraining)

When those two diverge, an attacker can put instructions through the filter that the LLM will decode and act on. The encoding is the carrier; **the real payload is the agent's authorized capability set.**

### Known encodings

| Encoding | Description | Filter-bypass mechanism |
|---|---|---|
| **Morse code** | `... --- ...` style dots/dashes | Looks like noise / formatting; LLM decodes it natively |
| **Base64** | `aWdub3JlIHByZXZpb3Vz...` | Ignored by English-pattern scanners; LLM decodes |
| **Hex** | `0x69676e6f7265...` | Same — LLM reads hex strings as text |
| **ROT-N / Caesar** | Shift-cipher text | Plain-text filters miss the rotation |
| **Unicode bidi overrides** | U+202E + payload | Renders one way visually, parses another way to LLM |
| **Zero-width characters** | U+200B/C/D between letters | Visually identical, alters tokenization |
| **Tag characters** | U+E0000+ block (invisible Unicode) | Carries hidden text payload |
| **Homoglyphs** | Cyrillic 'а' instead of Latin 'a' | Looks identical, reads as different word |
| **Foreign-language smuggling** | Instructions in a low-resource language | Filter trained on English patterns |
| **Steganography in markdown** | Instructions in URL fragments, alt-text, comments | Easy to overlook in casual scanning |

The list grows. **Defense by enumeration is fragile.** Defense by structural impossibility is durable. Both layers go in.

### Why "ban LLMs from acting" isn't the answer

Refusing to let agents take actions cripples the use case. AGNOS is built to deploy agents that act on the real world. The defense isn't *no actions*, it's **action authorization that doesn't trust the input that prompted it** — capability gates that survive even if the LLM is fully compromised by the input.

---

## The six-layer defense

Each layer addresses the attack at a different boundary. **Failure of any single layer should not cause loss.**

### L1 — Input scanning (pre-LLM)

**Owner**: `phylax` — extends the existing threat-detection rule set.

**What it does**: scans untrusted input for encoded-content signals before the input reaches the LLM.

- **Morse-density heuristic** — runs of dot/dash with regular separators above a threshold
- **Base64 likelihood** — detects high-entropy chunks with the Base64 alphabet
- **Hex blob detection** — runs of `0-9a-f` characters above a length threshold
- **Unicode-trick scanner**:
  - Zero-width characters (U+200B / U+200C / U+200D / U+FEFF)
  - Bidirectional control codes (U+202A–E, U+2066–9)
  - Tag characters (U+E0000–U+E007F)
  - Mixed-script clusters (Latin + Cyrillic in same word — homoglyph signal)
- **Recursive decode + rescan** — if any encoding detected with high confidence, decode and run the scan again on the decoded payload (catches nested encodings)
- **Instruction-pattern detection on decoded content** — look for verbs of action ("transfer", "send", "approve", "delete", "ignore previous", "you are now"), urgency markers, and known jailbreak phrases

**Output**: confidence-scored finding `(input, encoding, decoded, instruction-pattern-detected)`. Caller decides what to do with it (strip, flag, refuse, pass-with-annotation).

**Implementation locus**: new `phylax/src/encoded_injection.cyr` module + rules. Existing phylax YARA-style pattern infrastructure is the right shape.

### L2 — LLM gateway pre-flight

**Owner**: `hoosh` — runs phylax filter before passing untrusted content to any provider.

**What it does**: applies provenance tagging + scanning at the LLM gateway layer. Any agent inference that ingests external content (tweets, RSS, web pages, emails, etc.) goes through this gate.

- **Provenance channel** — every input carries a tag: `system` / `user` / `external` / `tool-output`
- **External content always scanned** — `external` and `tool-output` (when the tool reads untrusted sources) trigger phylax pre-scan
- **Configurable response policy** per-deployment:
  - `strip` — remove flagged content, pass remainder
  - `flag` — annotate the input with `[FLAGGED-EXTERNAL-CONTENT]` markers, let LLM see but be aware
  - `refuse` — return error to the agent, do not call provider
  - `pass-with-annotation` — pass content unchanged but log finding (testing/observability mode)
- **Default policy**: `flag` for low-privilege agents, `refuse` for agents with irreversible capabilities

**Implementation locus**: hoosh middleware between request handler and provider clients. Phylax called as a library (zero-dep, in-process).

### L3 — MCP boundary

**Owner**: `t-ron` — already does authorization for MCP tool calls; extends with capability-source policy.

**What it does**: tracks the **provenance** of every tool call (which content channel triggered it) and refuses high-privilege calls when provenance is "external."

- **Capability-source policy** — declarative per-tool: which provenance channels can invoke this tool?
  - `system-only` — only agent's own goals can invoke (e.g., self-shutdown)
  - `user-or-system` — explicit user request OK (e.g., file operations)
  - `any-source` — fine-grained tools usable from any channel (e.g., date/time queries)
  - `external-with-confirmation` — external content can request, but requires explicit human auth before execution
- **Default**: any tool tagged `irreversible: true` requires `user-or-system` minimum
- **Audit** — every tool call logs `{tool, provenance, decision, reason}` to libro

**Implementation locus**: t-ron policy schema extension + per-tool annotations. Daimon publishes the provenance chain; t-ron evaluates.

### L4 — Sandbox capabilities

**Owner**: `kavach` — agent profiles already declare capabilities; add **irreversible-action gating**.

**What it does**: even when an agent is "authorized" to call a tool, irreversible actions get a runtime confirmation step that the LLM cannot synthesize.

- **`irreversible` capability flag** — declarative per-capability in the agent profile
- **Confirmation token requirement** — irreversible action requires a token the LLM cannot generate (e.g., human-typed at terminal, hardware-key-pressed, or out-of-band confirmation)
- **Token scope** — single-use, scoped to a specific action signature, time-limited
- **Capabilities tagged irreversible by default**:
  - Wallet / crypto / financial operations
  - File deletion outside agent's working directory
  - Network operations to external endpoints (configurable allowlist)
  - System operations (reboot, shutdown, package install)
  - Outbound communication (email, SMS, Slack, post-to-feed)

**Implementation locus**: kavach profile schema extension + runtime confirmation hooks. Pairs with shakti for privilege boundary.

### L5 — Audit chain

**Owner**: `libro` — already provides cryptographic hash-chained event logging.

**What it does**: every external-content ingestion + every capability invocation logged with full input + reasoning chain. After-the-fact forensics; cryptographic integrity makes tampering detectable.

- **Per-agent audit feed** — `(timestamp, agent_id, channel, content_hash, capability_invoked, decision, reason)`
- **Full-input retention** — original encoded content + decoded version + phylax findings preserved
- **Cross-reference to libro chain** — every t-ron / kavach decision references the audit entry that caused it

**Implementation locus**: already exists. Extension is the schema additions for provenance + injection-finding fields.

### L6 — Structural typing

**Owner**: `agnostik` — shared types library.

**What it does**: provides an `UntrustedInput<T>` wrapper that propagates the "external content" provenance through the entire pipeline at the type level. Type system makes accidental privilege escalation harder to write.

```cyrius
struct UntrustedInput<T> {
    content: T,
    source: ContentSource,
    provenance: Vec<ProvenanceStep>,
    scanned: Option<PhylaxFinding>,
}

enum ContentSource {
    System,           // agent's own goal / system prompt
    UserDirect,       // explicit user input
    External,         // tweet, web page, RSS, email
    ToolOutput,       // result from another tool (transitive)
}
```

- Functions that perform irreversible actions take `Trusted<T>`, never `UntrustedInput<T>`
- `UntrustedInput<T>` → `Trusted<T>` requires explicit conversion via t-ron policy or kavach confirmation
- The conversion site is auditable and reviewable

**Implementation locus**: agnostik type additions. Backward-compatible — existing code doesn't break, new high-privilege code adopts the type.

---

## The structural-immunity story

L1–L3 are *detection* layers. They will fail eventually — defense by enumeration always does.

L4 + L6 together provide **structural immunity at the agent-capability layer**. Even if every detection layer misses the encoding and the LLM is fully compromised by the injected payload, **the wallet drain doesn't happen because the capability gate doesn't exist for unconfirmed external-input-origin calls.**

This mirrors AGNOS's existing structural-immunity pattern — same shape as the kernel being immune to CVE-2026-31431 because the syscall surface doesn't expose AF_ALG. The kernel doesn't *patch* the vulnerability; it doesn't *contain* the vulnerable subsystem. Whole categories of attacks are unreachable.

Same idea, different layer:

| Layer | Pattern | Example |
|---|---|---|
| **Kernel syscalls** | Syscall surface refuses to expose vulnerable subsystems | CVE-2026-31431 — no `socket`/`splice`/AF_ALG → AEAD bug class unreachable |
| **Agent capabilities** | Capability gate refuses to authorize irreversible actions from untrusted-origin calls | Encoded prompt injection → wallet capability requires human confirmation that the LLM cannot synthesize |

This is the **canonical second instance** of the absence-by-design pattern. Worth documenting in `docs/design-patterns.md` once L4 + L6 ship — alongside the kernel example.

---

## Cross-repo implementation markers

Implementation tracking lives in each owning repo's roadmap, with backlinks here. Markers placed 2026-05-10:

| Layer | Repo | Marker location |
|---|---|---|
| L1 — Input scanning | `phylax` | TBD — encoded-injection rule set + Unicode-trick scanner pending roadmap entry |
| L2 — Gateway pre-flight | `hoosh` | TBD — provenance-tagging middleware + phylax pre-flight pending roadmap entry |
| **L3 — MCP boundary** | **`t-ron`** | ✅ [`t-ron/docs/development/roadmap.md` § Phase 2A](https://github.com/MacCracken/t-ron/blob/main/docs/development/roadmap.md) — capability-source policy schema, provenance-chain ingestion, default policy, audit emission, per-tool annotation sweep, backward-compat migration |
| **L4 — Capability gating** | **`kavach`** | ✅ [`kavach/docs/development/roadmap.md` § Agent Injection Defense](https://github.com/MacCracken/kavach/blob/main/docs/development/roadmap.md) — `irreversible` capability flag, confirmation-token requirement, token-scope schema, confirmation-mechanism decision (open), agnoshi integration, hardware-key backend, migration path (shadow → audit-only → enforce) |
| L5 — Audit chain | `libro` | Already shipped — schema additions for provenance + injection-finding fields needed (small extension, no roadmap entry yet) |
| L6 — Structural typing | `agnostik` | TBD — `UntrustedInput<T>` + `Trusted<T>` types pending roadmap entry |

The next marker pass (phylax / hoosh / agnostik) earns its way in once the L3+L4 schema decisions stabilize — those three depend on the policy shape settled in t-ron + the capability-flag schema in kavach.

---

## Phased implementation

### Phase 1 — Detection foundation (post-closed-beta)

Goal: make encoded-injection detectable without changing existing agent semantics.

| # | Action | Repo | Estimate |
|---|--------|------|----------|
| 1 | Phylax encoded-content scanner module — Morse, Base64, hex, Unicode tricks | `phylax` | M |
| 2 | Recursive decode + rescan | `phylax` | S |
| 3 | Instruction-pattern detection on decoded content | `phylax` | S |
| 4 | Hoosh middleware — provenance tagging + phylax pre-flight | `hoosh` | M |
| 5 | Default `flag` policy for external-tagged content | `hoosh` | S |

Outcome: every existing agent gets injection-finding annotations in libro audit log. No behavior change yet — pure observability.

### Phase 2 — Capability gating (post-public-beta)

Goal: structural immunity layer comes online.

| # | Action | Repo | Estimate |
|---|--------|------|----------|
| 6 | t-ron capability-source policy schema | `t-ron` | M |
| 7 | Per-tool source-tagging | daimon, ark, hoosh tools | M |
| 8 | Kavach irreversible-action capability flag | `kavach` | M |
| 9 | Confirmation token mechanism — terminal / hardware-key / OOB | `kavach` + agnoshi | L |
| 10 | Default `irreversible` annotations on wallet / file-delete / network / system caps | applicable repos | M |
| 11 | agnostik `UntrustedInput<T>` + `Trusted<T>` types | `agnostik` | M |
| 12 | Type adoption sweep across high-privilege call sites | applicable repos | L |

Outcome: structural immunity at agent layer. An LLM compromised by injection cannot drain a wallet, delete files outside its sandbox, or execute irreversible system ops without human confirmation that the injection cannot synthesize.

### Phase 3 — Documentation + narrative (parallel with Phase 2)

| # | Action | Repo | Estimate |
|---|--------|------|----------|
| 13 | Add absence-by-design pattern (agent layer) to `docs/design-patterns.md` | agnosticos | S |
| 14 | Article: *"Why AGNOS-native agents can't be drained by a tweet"* — paired with summer-2026-arc Beat 2 (Black Hat receipts) | agnosticos | M |
| 15 | Update SECURITY.md with structural-immunity entries (kernel + agent) | agnosticos | S |
| 16 | Per-repo CLAUDE.md updates documenting the policy expectations | applicable repos | M |

Outcome: the narrative around "why AGNOS-native agents are different" is shipped, with receipts.

---

## Open design questions

These are the calls that need an explicit decision before implementation.

1. **Confirmation token mechanism** — terminal-typed phrase? Hardware key (YubiKey)? Out-of-band (Signal message)? Per-deployment configurable, but a default is needed.
2. **Default `irreversible` set** — what's the canonical list? Wallet/financial is obvious; file delete is obvious; what about *outbound network calls*? Too noisy if every API call needs confirmation. Probably allowlist-by-domain at the kavach profile level.
3. **L1 detection thresholds** — false-positive rate matters; calibrate against a corpus of normal external content (tweets, RSS, web pages) before shipping defaults.
4. **Backward compatibility** — existing agents may break when L4 ships. Migration path: shadow mode → audit-only mode → enforce mode, with per-deployment configurable.
5. **L6 type adoption** — do we mandate `UntrustedInput<T>` in agnostik for all new code, or is it opt-in for high-privilege call sites? Probably mandate at first-party-standards level for v1.0+ AI integration.

---

## Threat model — non-obvious surfaces

Beyond the obvious "LLM reads tweet, executes Morse-encoded instruction" path, watch for:

- **Tool output as injection vector** — agent calls a search tool, search tool returns content from a hostile page, agent processes that content as input to the next inference. The provenance chain must propagate through tool outputs.
- **RAG corpus poisoning** — vector store contains hostile content embedded by attacker; future query retrieves it; LLM acts on it. RAG retrieval results are `external` provenance.
- **Multi-agent collusion** — agent A receives external content, makes a recommendation to agent B, agent B acts on the recommendation. Provenance chain must transitively flag agent A's recommendation as external-derived.
- **Long-context injection** — instructions buried deep in a long document where the LLM's attention is uneven; safety filter trained on short-form jailbreaks misses the long-form payload.
- **Self-modifying prompts** — agent writes to its own working memory file, attacker crafts content that causes the agent to write hostile instructions to its own context. Working-memory writes need provenance tracking too.

---

## References

- [CCN — *AI Agent Drained for $200K With This One Tweet Hack*](https://www.ccn.com/news/crypto/ai-agent-drained-for-200k-with-this-one-tweet-hack-heres-how/) — trigger event (2026-05)
- [`first-party-standards.md` § Security Hardening](first-party-standards.md#security-hardening-required-before-every-release) — pre-release audit checklist (extended by this doc for AI-agent surfaces)
- [`SECURITY.md` § Notable Hardening](../../../SECURITY.md#notable-hardening--structural-immunity) — kernel-layer absence-by-design example (canonical first instance)
- [`docs/design-patterns.md`](../../design-patterns.md) — pattern catalog (absence-by-design pattern receives second instance once L4 + L6 ship)
- [`development/state.md`](../state.md) — sweep status tracking

---

*Last Updated: 2026-05-10. Rewrite-in-place as phases land. This doc is the design spine — per-repo issues track implementation.*
