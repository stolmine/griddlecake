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
│  GridInterface  │  LUT (65536×39)  │  Sequencer     │
│  GestureRecorder│  StateManager    │  Clock         │
├─────────────────────────────────────────────────────┤
│              SynthDef(\chaosDrone)                  │
│  Osc1+Osc2 → Combo → Filter → Lo-Fi → Ring Mod →   │
│  Comb → Delay → MiClouds → Limiter → Out           │
└─────────────────────────────────────────────────────┘
```

---

## Key Design Decisions

- **Drone architecture** - No envelopes, no VCA. Always sounding.
- **Pure SuperCollider** - No Rust/CLI layer. Grid IS the interface.
- **Cyclebox-inspired** - 9 bitwise waveform combination modes
- **MiClouds granular** - Provides texture, space, and internal reverb
- **39 parameters** in LUT (~10.2 MB total)

---

## Parameter Summary

| Section | Count | Key Params |
|---------|-------|------------|
| Oscillators | 11 | freq, wave, pw, track, ratio, fm, combo |
| Noise | 4 | type, level, to_osc1, to_osc2 |
| Filter | 4 | freq, res, type, track |
| Lo-Fi | 3 | bits, rate, mix |
| Ring Mod | 3 | freq, wave, mix |
| Comb Res | 3 | freq, decay, mix |
| Delay | 3 | time, fb, mix |
| MiClouds | 7 | pos, size, dens, tex, mode, rvb, mix |
| Output | 1 | level (user-controlled, not in LUT) |
| **Total** | **39** | (38 in LUT + 1 user volume) |

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

**Version:** 2.0.0-draft
**Last Updated:** 2025-12-28
