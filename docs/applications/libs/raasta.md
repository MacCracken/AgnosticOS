# Raasta

> **Raasta** (Hindi: path/road) — Navigation and pathfinding library

- **Version**: 1.0.0
- **Repository**: [github.com/MacCracken/raasta](https://github.com/MacCracken/raasta)
- **License**: GPL-3.0-only
- **Status**: v1.0+ stable

See the [shared-crates registry](../../development/applications/shared-crates.md) for full context and dependency graph.

---

## What It Does

- A* pathfinding with customizable heuristics and cost functions
- HPA* (Hierarchical Pathfinding A*) for large-scale maps with precomputed clusters
- Navigation mesh generation and query for 3D environments
- Spatial navigation with obstacle avoidance and steering behaviors
- Grid, graph, and navmesh representations with unified query API

## Consumers

- **kiran** — Game engine (entity navigation, AI movement)
- **joshua** — Game manager (NPC navigation and patrol routes)

## Architecture

- Generic over graph type via trait-based abstraction
- Built on hisab spatial structures (BVH, k-d tree) for acceleration
