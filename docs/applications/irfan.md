# Ifran

> **Ifran** (Arabic: knowledge/wisdom) — LLM inference & training engine (formerly Synapse → Irfan → Ifran)

| Field | Value |
|-------|-------|
| Status | Released |
| Version | `1.2.0` |
| Repository | `MacCracken/ifran` |
| Runtime | native-binary (~9.6MB) |
| Recipe | `zugot/marketplace/ifran.toml` |
| MCP Tools | 7 `ifran_*` |
| Agnoshi Intents | 7 |
| Port | 8080 |

---

## Why First-Party

Ifran is core infrastructure for hoosh — it manages model downloads, fine-tuning jobs, and serving configuration. No existing tool integrates with the AGNOS LLM pipeline end-to-end. It provides a unified interface across llama.cpp, Candle, Ollama, vLLM, ONNX, and TensorRT backends, with fine-tuning methods (LoRA, QLoRA, full, DPO, RLHF, distillation) that feed directly back into hoosh's model registry.

## What It Does

- Model lifecycle management: download, convert, quantize, serve across multiple backends
- Fine-tuning pipeline: LoRA, QLoRA, full fine-tuning, DPO, RLHF, and distillation
- Backend orchestration for llama.cpp, Candle, Ollama, vLLM, ONNX, and TensorRT
- Training job scheduling with GPU resource management
- Model catalog and version tracking with performance benchmarks

## AGNOS Integration

- **Daimon**: Registers as an agent; publishes model availability events; exposes training job status via API
- **Hoosh**: Direct integration as the model management backend; ifran-managed models are served through hoosh's inference gateway
- **MCP Tools**: `ifran_models`, `ifran_download`, `ifran_finetune`, `ifran_serve`, `ifran_status`, `ifran_benchmark`, `ifran_catalog`
- **Agnoshi Intents**: `ifran models`, `ifran download <model>`, `ifran finetune <config>`, `ifran serve <model>`, `ifran status`, `ifran benchmark <model>`, `ifran catalog`
- **Marketplace**: AI/Infrastructure category; sandbox profile allows GPU access, network for model downloads, read-write model storage directories

## Architecture

- **Crates**:
  - `ifran-core` — model registry, backend abstraction, configuration
  - `ifran-train` — fine-tuning pipeline (LoRA/QLoRA/full/DPO/RLHF/distillation)
  - `ifran-serve` — model serving, backend orchestration, health monitoring
  - `ifran-api` — REST API (port 8080), job management
  - `ifran-cli` — command-line interface
- **Dependencies**: CUDA/ROCm (GPU compute), llama.cpp (GGUF inference), SQLite (job database)

## Roadmap

Active development. Known review items R1-R7:
- R1: Stub RAG integration needs full implementation
- R2: Incomplete hoosh bridge for model hot-swap
- R3: Empty model catalog (seed with curated models)
- R4-R7: Training pipeline hardening, multi-GPU scheduling, checkpoint management
