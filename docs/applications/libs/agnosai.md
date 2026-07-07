# AgnosAI

> **AgnosAI** (AGNOS + AI) — Provider-agnostic AI orchestration framework

- **Repository**: [github.com/MacCracken/agnosai](https://github.com/MacCracken/agnosai)
- **License**: GPL-3.0-only
- **Status**: Stable - See Repo
- **Language**: Rust

See the [libs registry](../README.md) for the full catalog and dependency context.

---

## What It Does

- Crew management with role-based agent assignment and lifecycle
- Task DAG execution with dependency resolution and parallel stages
- Tool execution framework with sandboxed invocation
- Fleet distribution for spreading crews across nodes
- CrewAI replacement for the AGNOS ecosystem

## Consumers

- **agnostic** — Python/CrewAI agent automation platform (primary consumer)
- **daimon** — Agent orchestrator (crew scheduling)
- **joshua** — Game manager (NPC crew behavior and AI teams)

## Architecture

- Crew/Task/Tool abstraction layers with trait-based extensibility
- DAG scheduler with topological sort and cycle detection
- Depends on hoosh for LLM calls
