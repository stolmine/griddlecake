# Core Concepts

The three fundamental concepts behind the chaos synth.

---

## 1. Chaotic Lookup Table (LUT)

The LUT is an array of 65,536 synth states, each containing 39 parameter values.

```supercollider
// Boot-time generation with seed for reproducibility
~lutSeed = Date.seed; // or loaded from save file
~lut = Array.fill(65536, { |i|
    thisThread.randSeed = ~lutSeed + i; // deterministic per-index
    [
        exprand(20, 2000),      // osc1_freq
        rrand(0, 3).round,      // osc1_wave
        rrand(0, 1),            // osc1_pw
        // ... 36 more params
    ]
});
```

### Key Properties

| Property | Description |
|----------|-------------|
| **Size** | 65,536 entries (2^16) |
| **Params per entry** | 39 |
| **Memory** | ~10.2 MB (65536 × 39 × 4 bytes) |
| **Access time** | O(1) - instant lookup |
| **Reproducibility** | Seeded RNG - same seed = same LUT |

### Discontinuity by Design

Adjacent LUT indices produce **completely different sounds**. This is intentional:
- Index 23456 might be a low drone
- Index 23457 might be a bright, filtered screech
- Index 23458 might be a comb-resonated noise burst

This creates a rich, unpredictable timbral space to explore.

---

## 2. 16-bit DAC Paradigm

The 4×4 parameter grid represents a single 16-bit integer (0-65535).

### Bit Layout

```
Grid layout (bits 15-0, MSB top-left):
[15][14][13][12]
[11][10][ 9][ 8]
[ 7][ 6][ 5][ 4]
[ 3][ 2][ 1][ 0]
```

### Example State

```
[●][○][●][●]  = 0b1011...
[○][○][●][●]  = ...0011...
[●][○][○][●]  = ...1001...
[○][○][●][○]  = ...0010
              = 0b1011001110010010 = 46482
```

### State Operations

| Operation | Description | Implementation |
|-----------|-------------|----------------|
| **Toggle** | Flip single bit | `state ^ (1 << bitPos)` |
| **Clear Row** | Zero out 4 bits | `state & invMask` |
| **Invert Row** | Flip 4 bits | `state ^ mask` |
| **Shift Row** | Rotate 4-bit nibble | Bit manipulation |

```supercollider
~applyAction = { |currentState, action, rowIndex|
    var mask = 0xF << (rowIndex * 4);
    var invMask = 0xFFFF - mask;

    case
    { action == \clearRow } {
        currentState & invMask
    }
    { action == \invertRow } {
        currentState ^ mask
    }
    { action == \shiftRow } {
        var row = (currentState >> (rowIndex * 4)) & 0xF;
        var shifted = ((row << 1) | (row >> 3)) & 0xF;
        (currentState & invMask) | (shifted << (rowIndex * 4))
    };
};
```

### Resolution Flow

```
User action → Bit operation → New integer (0-65535) → LUT lookup → 39 params → Synth.set()
```

---

## 3. Slew System

Slew operates on the **DAC index integer**, not individual parameters.

```supercollider
// Single lag calculation
~currentIndex = ~targetIndex.lag(~riseTime, ~fallTime, ~curve);

// Lookup at interpolated index
~params = ~lut[~currentIndex.asInteger];

// As index sweeps 23456 -> 51234, SC traverses all intermediate states
// User hears continuous timbral evolution through chaos space
```

### Why Slew on Index?

| Approach | Pros | Cons |
|----------|------|------|
| **Per-param slew** | Smooth individual params | 39 lag calculations, params arrive at different times |
| **Index slew** | One calculation, all params move together | Sweeps through intermediate LUT states |

The index slew approach creates unique **timbral sweeps** through the chaos space as intermediate indices are traversed.

### Slew Parameters

Controlled via the 4×4 slew grid (cols 5-8):

| Row | Parameter | Range |
|-----|-----------|-------|
| 0 | Rise time | 10ms - 10s (exponential) |
| 1 | Fall time | 10ms - 10s (exponential) |
| 2 | Curve | -8 to +8 (0 = linear) |
| 3 | Per-param offset | Deferred to v2 |

### Slew in Gestures

Slew state is embedded in gestures/presets - when you recall a gesture, you also recall its slew settings.

---

## Related Documents

- [Voice Architecture](voice_architecture.md) - The 39 parameters
- [Sequencer](sequencer.md) - How slew interacts with blending
- [Grid Layout](grid_layout.md) - Physical slew grid location
