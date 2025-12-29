# Project Overview

A **drone synthesizer** controlled by a Monome Grid (128 or 256) that uses 16-bit chaotic lookup table synthesis.

The 4×4 parameter grid acts as a 16-bit DAC (0-65535) indexing into a randomly-generated lookup table of synth states. Users explore discontinuous timbral space, curate sweet spots as gestures/presets, and sequence evolving textures across 4 independent parameter tracks.

---

## Key Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Synth type** | Drone | No EG/VCA, always sounding, timbral exploration |
| **Control layer** | Pure SuperCollider | Grid IS the interface, no TUI needed |
| **Grid interface** | oscgrid initially | iPad emulation, serialosc for hardware later |
| **Combo modes** | 9 Cyclebox-style | OSC1/OSC2/RING/MIN/PONG/AND/OR/XOR/GLCH |
| **Osc2 tracking** | Free ratio (0.25-4.0) | Snapping deferred to v2 |
| **MiClouds trigger** | Auto on clock | Density controls drone vs burst |
| **Reverb** | MiClouds internal only | No separate reverb needed |

---

## Hardware Requirements

- **Monome Grid** (128 varibright or 256 varibright) OR **iPad with oscgrid**
- **Computer** running SuperCollider 3.12+
- **serialosc** for hardware Grid communication (oscgrid uses same OSC protocol)

---

## Signal Flow

```
┌─────────┐   ┌─────────┐
│  Osc1   │   │  Osc2   │
│ +noise  │   │ +noise  │
└────┬────┘   └────┬────┘
     │             │
     └──────┬──────┘
            │
     ┌──────▼──────┐
     │ Combo Mode  │  (Cyclebox-style)
     └──────┬──────┘
            │
     ┌──────▼──────┐
     │   Filter    │  (SVF: LP/HP/BP/Notch)
     └──────┬──────┘
            │
     ┌──────▼──────┐
     │   Lo-Fi     │  (Bitcrush + Downsample)
     └──────┬──────┘
            │
     ┌──────▼──────┐
     │  Ring Mod   │  (Independent carrier)
     └──────┬──────┘
            │
     ┌──────▼──────┐
     │  Comb Res   │  (Karplus-Strong)
     └──────┬──────┘
            │
     ┌──────▼──────┐
     │   Delay     │  (Stereo)
     └──────┬──────┘
            │
     ┌──────▼──────┐
     │  MiClouds   │  (Granular + reverb)
     └──────┬──────┘
            │
     ┌──────▼──────┐
     │  Limiter    │  (Always on)
     └──────┬──────┘
            │
            ▼
         Output
```

---

## Why "Chaos"?

The lookup table contains **65,536 unique synth states**, generated with seeded randomness at boot time. Adjacent indices produce **completely different sounds** - the parameter space is intentionally discontinuous.

This creates a unique instrument where:
- Flipping a single bit can drastically change the sound
- Slewing between states sweeps through unpredictable intermediate timbres
- The same seed always produces the same LUT (reproducible chaos)
- Users discover "sweet spots" and save them as gestures/presets

---

## Related Documents

- [Core Concepts](core_concepts.md) - LUT, DAC, Slew details
- [Voice Architecture](voice_architecture.md) - Full parameter list
- [Implementation](implementation.md) - Build phases
