# Phylax

> **Phylax** (Greek: guardian/watchman) — AI-native threat detection engine (Cyrius-native, ported)

- **Repository**: [github.com/MacCracken/phylax](https://github.com/MacCracken/phylax)
- **License**: GPL-3.0-only
- **Status**: Stable - See Repo
- **Language**: Cyrius

See the [libs registry](../README.md) for the full catalog and dependency context.

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
- Scan pipeline: magic bytes → entropy → YARA → ML → LLM triage
- Depends on hoosh for LLM triage
