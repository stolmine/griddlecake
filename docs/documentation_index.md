# Griddlecake Documentation Index

Monome Grid Chaos Drone Synthesizer - Pure SuperCollider implementation.

---

## Quick Reference

| Document | Description |
|----------|-------------|
| [Progress](progress.md) | **Session log, decisions, current status** |
| [Overview](overview.md) | Project summary, key decisions, hardware requirements |
| [Core Concepts](core_concepts.md) | LUT, 16-bit DAC paradigm, slew system |
| [Grid Layout](grid_layout.md) | Physical layout, control zones, interaction model |
| [Voice Architecture](voice_architecture.md) | Oscillators, noise, filter, combo modes |
| [FX Chain](fx_chain.md) | Lo-Fi, Ring Mod, Comb, Delay, MiClouds |
| [Sequencer](sequencer.md) | 4-row sequencer, blending, live intervention |
| [Clock & Transport](clock_transport.md) | Tap tempo, transport, clock distribution |
| [State Persistence](state_persistence.md) | JSON save/load, LUT regeneration |
| [Implementation](implementation.md) | Phases, priorities, getting started |
| [Technical Notes](technical_notes.md) | Performance, SC architecture, OSC protocol |
| [Grid Communication](grid_communication.md) | OSC protocol, oscgrid/serialosc setup, timing |
| [Engine Abstraction](engine_abstraction.md) | Multi-engine architecture, hot-swap, LUT per engine |

---

## Architecture Summary

```
┌─────────────────────────────────────────────────────┐
│           iPad (oscgrid) / Hardware Grid            │
└──────────────────────┬──────────────────────────────┘
                       │ OSC
                       ▼
┌─────────────────────────────────────────────────────┐
│              SuperCollider (sclang)                  │
├─────────────────────────────────────────────────────┤
│  GridInterface  │  LUT (65536×N)   │  Sequencer     │
│  GestureRecorder│  ~lutLib         │  Clock         │
├─────────────────────────────────────────────────────┤
│  ~fxLib (shared FX blocks)                          │
├─────────────────────────────────────────────────────┤
│  Engines: drone | feedback | fm4op                  │
│  (hot-swappable with per-engine LUT + FX chain)     │
└─────────────────────────────────────────────────────┘
```

---

## Key Design Decisions

- **Drone architecture** - No envelopes, no VCA. Always sounding.
- **Pure SuperCollider** - No Rust/CLI layer. Grid IS the interface.
- **Multi-engine** - Hot-swappable synthesis engines with per-engine LUTs
- **Shared libraries** - `lut_lib.scd` (random generators), `fx_lib.scd` (FX blocks)
- **MiClouds granular** - Provides texture, space, and internal reverb

---

## Engines

| Engine | Voice Params | FX Params | Character |
|--------|--------------|-----------|-----------|
| drone | 20 | 19 | 2-osc + bitwise combo modes |
| feedback | 24 | 25 | 4 cross-feeding filter+delay paths |
| fm4op | 20 | 20 | 4-operator FM with 8 algorithms |

---

## Dependencies

- SuperCollider 3.12+
- mi-UGens (MiClouds) - https://github.com/v7b1/mi-UGens
- oscgrid (iPad) - https://github.com/okyeron/oscgrid
- OR serialosc (hardware Grid) - https://monome.org/docs/serialosc/

---

## References

- [Monome Grid Documentation](https://monome.org/docs/grid/)
- [SuperCollider Documentation](https://doc.sccode.org/)
- [Cylonix Cyclebox User Guide](https://www.cylonix.com/docs/cyclebox2_users_guide.pdf)
- Monokit: `/Users/why/repos/monokit`

---

**Version:** 2.1.0-draft
**Last Updated:** 2025-12-31
