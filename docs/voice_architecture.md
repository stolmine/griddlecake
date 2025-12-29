# Voice Architecture

Drone synth voice design - no envelopes, no VCA gating, always sounding.

---

## Design Philosophy

This is a **drone synthesizer** - timbral exploration via continuous parameter morphing, not note-based triggering.

- No attack/decay/sustain/release
- No gate or trigger for the voice
- Always producing sound
- MiClouds provides rhythmic texture via clock-triggered grains

---

## Oscillator Section (11 params)

### Osc1 (Primary)

| Param | Range | Description |
|-------|-------|-------------|
| `osc1_freq` | 20-2000 Hz (exp) | Primary frequency |
| `osc1_wave` | 0-3 | Sin/Tri/Saw/Square |
| `osc1_pw` | 0-1 | Pulse width (square only) |

### Osc2 (Secondary)

| Param | Range | Description |
|-------|-------|-------------|
| `osc2_freq` | 20-2000 Hz (exp) | Secondary frequency |
| `osc2_wave` | 0-3 | Sin/Tri/Saw/Square |
| `osc2_pw` | 0-1 | Pulse width |
| `osc2_track` | 0-1 | Track osc1 freq (0=free, 1=locked) |
| `osc2_ratio` | 0.25-4.0 | Frequency ratio when tracking |

### FM & Combination

| Param | Range | Description |
|-------|-------|-------------|
| `fm_amount` | 0-1 | Osc2 → Osc1 FM depth |
| `combo_mode` | 0-8 | Cyclebox-style waveform combination |
| `combo_mix` | 0-1 | Dry osc1 ↔ combo output |

---

## Combo Modes (Cylonix Cyclebox-inspired)

| Mode | Name | Operation |
|------|------|-----------|
| 0 | OSC1 | Pass through osc1 |
| 1 | OSC2 | Pass through osc2 |
| 2 | RING | Ring modulation (osc1 × osc2) |
| 3 | MIN | Minimum of both signals |
| 4 | PONG | Osc1 when +, osc2 when -, else 0 |
| 5 | AND | Bitwise AND |
| 6 | OR | Bitwise OR |
| 7 | XOR | Bitwise XOR |
| 8 | GLCH | Glitchy bitwise combo |

```supercollider
// Convert audio signals to 16-bit integer representation
var osc1Bits = (osc1 * 32767).asInteger;
var osc2Bits = (osc2 * 32767).asInteger;

var combo = Select.ar(comboMode, [
    osc1,                                           // 0: OSC1
    osc2,                                           // 1: OSC2
    osc1 * osc2,                                    // 2: RING
    min(osc1, osc2),                                // 3: MIN
    Select.ar(osc1 > 0, [                           // 4: PONG
        Select.ar(osc2 < 0, [DC.ar(0), osc2]),
        osc1
    ]),
    ((osc1Bits & osc2Bits) / 32767),               // 5: AND
    ((osc1Bits | osc2Bits) / 32767),               // 6: OR
    ((osc1Bits ^ osc2Bits) / 32767),               // 7: XOR
    ((osc1Bits.bitXor(osc2Bits.bitNot)) / 32767)   // 8: GLCH
]);
```

---

## Noise Section (4 params)

| Param | Range | Description |
|-------|-------|-------------|
| `noise_type` | 0-2 | White / Pink / Brown |
| `noise_level` | 0-1 | Noise mixed to output |
| `noise_to_osc1` | 0-1 | Noise → Osc1 frequency modulation |
| `noise_to_osc2` | 0-1 | Noise → Osc2 frequency modulation |

```supercollider
var noise = Select.ar(noiseType, [
    WhiteNoise.ar,
    PinkNoise.ar,
    BrownNoise.ar
]);

// Noise modulates oscillator frequencies
var osc1Freq = osc1BaseFreq * (1 + (noise * noiseToOsc1 * 0.5));
var osc2Freq = osc2BaseFreq * (1 + (noise * noiseToOsc2 * 0.5));

// Noise also mixed to output
sig = sig + (noise * noiseLevel);
```

---

## Filter Section (4 params)

| Param | Range | Description |
|-------|-------|-------------|
| `filter_freq` | 20-20000 Hz (exp) | Cutoff frequency |
| `filter_res` | 0-0.99 | Resonance |
| `filter_type` | 0-3 | LP / HP / BP / Notch |
| `filter_track` | 0-1 | Track osc1 frequency |

```supercollider
// SVF multimode filter
var cutoff = filterFreq + (filterTrack * osc1Freq);
sig = SVF.ar(sig, cutoff.clip(20, 20000), filterRes,
    lowpass: (filterType == 0),
    highpass: (filterType == 1),
    bandpass: (filterType == 2),
    notch: (filterType == 3)
);
```

---

## Output Section (1 param)

| Param | Notes |
|-------|-------|
| `output_level` | Master volume (0-1), **user-controlled, NOT in LUT** |
| **Limiter** | `Limiter.ar(sig, 1.0, 0.01)` - always on, not controllable |

### Volume Control

Volume is intentionally excluded from the LUT to give users consistent control:

- **Access:** Hold tap button (`;`) + press param grid button (1-16 levels)
- **Behavior:** Persists across LUT state changes
- **Rationale:** Chaotic LUT would cause unpredictable volume jumps

See [Grid Layout](grid_layout.md) for button mapping.

---

## Complete Parameter List

```supercollider
// Oscillators (11 params)
osc1_freq, osc1_wave, osc1_pw,
osc2_freq, osc2_wave, osc2_pw, osc2_track, osc2_ratio,
fm_amount, combo_mode, combo_mix,

// Noise (4 params)
noise_type, noise_level, noise_to_osc1, noise_to_osc2,

// Filter (4 params)
filter_freq, filter_res, filter_type, filter_track,

// Output (1 param)
output_level

// Voice subtotal: 20 params
```

---

## Related Documents

- [FX Chain](fx_chain.md) - Effects processing (19 more params)
- [Core Concepts](core_concepts.md) - How params are stored in LUT
- [Technical Notes](technical_notes.md) - Full SynthDef code
