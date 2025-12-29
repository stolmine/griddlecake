# Progress

Session notes, decisions, and implementation progress.

See [Implementation](implementation.md) for the high-level roadmap.

---

## Current Status

**Phase:** Phase 1 - Core Engine (functional, testing)

**Completed:**
- drone.scd SynthDef (39 LUT params + EQ/comp + per-param slew)
- Split LUT: Voice (20 params) + FX (19 params)
- main.scd boot file with full state management
- EQ and compressor (SClang control only)
- Per-param Lag.kr for smooth morphing
- True parameter value interpolation (not index traversal)
- True 8-bit audio-rate bitwise ops (AND, OR, XOR, GLITCH)
- Weighted frequency distribution in LUT (bias toward low frequencies)

**Next Steps:**
1. Grid/oscgrid OSC communication
2. Parameter grid → DAC state → LUT lookup
3. Gesture recording

---

## Session Log

### 2025-12-28

**Implemented Phase 1 Core:**
- `synthdefs/drone.scd` - Complete drone voice
  - 2 oscillators (sin/tri/saw/square) with noise modulation
  - 9 combo modes (OSC1, OSC2, RING, MIN, MAX, AND, OR, XOR, GLITCH)
  - True 8-bit audio-rate bitwise ops for modes 5-8
  - SVF multimode filter (lowpass default)
  - FX chain: Lo-Fi → Ring Mod → Comb → Delay → MiClouds → EQ → Comp → Limiter
  - Per-param `Lag.kr(param, slew_time)` for smooth morphing
- `main.scd` - Boot file
  - Split LUT: `~voiceLut` (20 params) + `~fxLut` (19 params)
  - State 0 = home base (55Hz sine, 100% dry FX)
  - Fresh seed on each reload (use `~useSeed` to override)
  - True parameter interpolation in slew routines

**State Management Functions:**
- `~applyVoiceState.(idx)` / `~applyFxState.(idx)` - immediate
- `~setVoiceState.(idx, time)` / `~setFxState.(idx, time)` - interpolated slew
- `~applyFullState.(voice, fx)` - apply both
- `~testVoice.()` / `~testFx.()` - cycle through test states
- `~randomize.()` - randomize both
- `~showSeed.()` - display LUT seed
- `~setSlew.(time)` - set synth-level param slew time

**EQ & Compressor (SClang only):**
- `~eq.(low, mid, high)` - set gains in dB
- `~eqFreqs.(low, mid, high)` - set frequencies
- `~eqMidQ.(q)` - set mid band Q
- `~eqBypass.()` - flatten EQ
- `~comp.(thresh, ratio, attack, release, makeup)` - full control
- `~compBypass.()` - disable compression

**Bug Fixes:**
- Fixed SuperCollider bitwise ops syntax (`bitAnd:`, `bitOr:`, `bitXor:`)
- Fixed SVF filter API (positional args, not keywords)
- Fixed var declaration order (must precede statements)
- Fixed LUT seed persistence (now fresh each reload)
- Fixed slew to interpolate param values, not traverse random indices

**True Bitwise Ops (inlined in SynthDef):**
- 8-bit audio-rate AND, OR, XOR operations
- Converts audio → 8-bit unsigned int → bitwise op → audio
- Uses `.collect` at compile time to build UGen graph
- `BitOps.sc` class also available for standalone use

**Weighted LUT Frequency Distribution:**
- `rand.pow(n).linexp(...)` biases toward low frequencies
- osc1/2_freq: pow(1.8) → ~55% in bottom third
- filter_freq: pow(1.5) → gentle low bias
- ring/comb_freq: pow(1.8) → moderate low bias
- Creates more musical, bass-heavy random states

---

## Design Decisions

| Date | Decision | Rationale |
|------|----------|-----------|
| 2025-12-28 | Volume bypasses LUT | User needs consistent volume control |
| 2025-12-28 | Split Voice/FX LUT | Independent control, matches grid page layout |
| 2025-12-28 | Per-param Lag.kr | Smooth morphing between states |
| 2025-12-28 | Value interpolation | Slew should morph params, not traverse random states |
| 2025-12-28 | State 0 = home base | Predictable reference: 55Hz sine, dry FX |
| 2025-12-28 | EQ/Comp outside LUT | Master bus control, not part of chaotic exploration |
| 2025-12-28 | Inlined bitwise ops | Avoids class dependency, self-contained SynthDef |
| 2025-12-28 | Weighted freq distribution | More musical random states, favors bass |

---

## Known Issues

_None currently._

---

## Notes

- SVF filter currently locked to lowpass (type switching needs work)
- MiClouds requires mi-UGens extension
- BitOps class in `classes/` requires symlink to Extensions + recompile to use standalone
