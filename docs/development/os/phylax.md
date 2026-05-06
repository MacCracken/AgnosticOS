# Phylax

> **Phylax** (Greek: guardian/watchman) — AI-native threat detection engine

| Field | Value |
|-------|-------|
| Status | Released — Cyrius-native v1.0.0 (port complete 2026-04) |
| Repository | [MacCracken/phylax](https://github.com/MacCracken/phylax) |
| Runtime | Cyrius-native (was Rust library crate at v0.22.3) |
| Recipe | `zugot/marketplace/phylax.toml` |
| Live version | see [`development/state.md`](../state.md) |

---

## What It Does

- YARA rule engine for signature-based threat matching
- Entropy analysis to detect packed, encrypted, or obfuscated binaries
- Magic bytes identification for file type verification regardless of extension
- ML-based binary classification for unknown threat detection
- fanotify real-time filesystem scanning with LLM triage via hoosh

## Consumers

- **daimon** — Agent orchestrator (scanning agent outputs and file writes)
- **aegis** — Security daemon (integrated threat response)
- Complements t-ron (t-ron guards MCP inputs, phylax scans outputs/files)

## Architecture

- 5 modules: core (engine), rules (YARA), ml (classifier), scan (fanotify), mcp (tool interface)
- Scan pipeline: magic bytes -> entropy -> YARA -> ML -> LLM triage
- Cyrius-native; integrates with hoosh for LLM triage

## Roadmap

v1.0.0 shipped 2026-04 (Cyrius-native port from Rust v0.22.3). Future: ClamAV signature import, network traffic scanning, threat intelligence feed ingestion. See [`development/state.md`](../state.md) for current cycle status.
