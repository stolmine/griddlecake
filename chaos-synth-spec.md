# Monome Grid Chaos Synth - Technical Specification

## Project Overview

A **drone synthesizer** controlled by a Monome Grid (128 or 256) that uses 16-bit chaotic lookup table synthesis. The 4×4 parameter grid acts as a 16-bit DAC (0-65535) indexing into a randomly-generated lookup table of synth states. Users explore discontinuous timbral space, curate sweet spots as gestures/presets, and sequence evolving textures across 4 independent parameter tracks.

**Key Design Decisions:**
- **Drone architecture** - No envelopes, no VCA gating. Always sounding.
- **Pure SuperCollider** - No Rust/CLI layer. The Grid IS the interface.
- **Cyclebox-inspired** - Bitwise waveform combination modes (AND, XOR, MIN, PONG, etc.)
- **MiClouds granular** - Provides texture, space, and internal reverb

---

## Hardware Requirements

- **Monome Grid** (128 varibright or 256 varibright) OR **iPad with oscgrid**
- **Computer** running SuperCollider 3.12+
- **serialosc** for hardware Grid communication (oscgrid uses same OSC protocol)

---

## Core Concepts

### 1. Chaotic Lookup Table (LUT)

```supercollider
// Boot-time generation with seed for reproducibility
~lutSeed = Date.seed; // or loaded from save file
~lut = Array.fill(65536, { |i|
    thisThread.randSeed = ~lutSeed + i; // deterministic per-index
    [
        // Synth parameters (30+ params - see Voice Architecture section)
        exprand(20, 2000),      // osc1_freq
        exprand(20, 2000),      // osc2_freq
        // ... full param list below
        
        // FX parameters (15+ params - see FX Architecture section)
        rrand(0, 1),            // reverb_mix
        // ... full param list below
    ]
});
```

**Key Properties:**
- 65,536 unique synth states
- Discontinuous by design (adjacent indices ≠ similar sounds)
- Seeded RNG for reproducible chaos
- Single lookup per state change (O(1) access)

### 2. 16-bit DAC Paradigm

The 4×4 parameter grid represents a single 16-bit number:

```
Grid layout (bits 15-0, MSB top-left):
[15][14][13][12]
[11][10][ 9][ 8]
[ 7][ 6][ 5][ 4]
[ 3][ 2][ 1][ 0]

Example state:
[●][○][●][●]  = 0b1011...
[○][○][●][●]  = ...0011...
[●][○][○][●]  = ...1001...
[○][○][●][○]  = ...0010
                = 0b1011001110010010 = 46482
```

**State Updates:**
- Direct toggle: set/clear bit at position
- Clear row: AND with mask
- Invert row: XOR with mask  
- Shift row: rotate 4-bit nibble right

All operations resolve to integer state (0-65535) → LUT lookup → parameter set

### 3. Slew System

Slew operates on the **DAC index integer**, not individual parameters:

```supercollider
// Single lag calculation
~currentIndex = ~targetIndex.lag(~riseTime, ~fallTime, ~curve);

// Lookup at interpolated index
~params = ~lut[~currentIndex.asInteger];

// As index sweeps 23456 -> 51234, SC traverses all intermediate states
// User hears continuous timbral evolution through chaos space
```

**Benefits:**
- One slew calculation (not per-parameter)
- Automatic multi-parameter coordination
- Efficient: control-rate lag (~64 Hz)
- Sweeps through LUT revealing intermediate timbres

**Slew Parameters (from 4×4 slew grid):**
- **Row 1:** Rise time - 16 values (10ms to 10s, exponential mapping)
- **Row 2:** Fall time - 16 values (10ms to 10s, exponential mapping)
- **Row 3:** Curve shape - 16 values (-8 to +8, 0 = linear)
- **Row 4:** Per-parameter offset (advanced feature, may defer to v2)

Slew state is embedded in gestures/presets.

---

## Grid Layout & Interaction

### Physical Layout (16×8 or 16×16 grid)

```
Column: 0  1  2  3  4  5  6  7  8  9  10 11 12 13 14 15
Row 0:  s [p  p  p  p][l  l  l  l] -  i  > [g  g  g  g]
Row 1:  a [p  p  p  p][l  l  l  l] -  i  > [g  g  g  g]
Row 2:  ; [p  p  p  p][l  l  l  l] -  i  > [g  g  g  g]
Row 3:  : [p  p  p  p][l  l  l  l] -  i  > [g  g  g  g]
Row 4:  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x
Row 5:  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x
Row 6:  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x
Row 7:  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x  x
```

### Control Zones

#### Navigation (Column 0, Rows 0-3)
- **s** (0,0): Synth parameter page
- **a** (0,1): FX parameter page
- **;** (0,2): Tap tempo
- **:** (0,3): Transport start/stop

#### Parameter Grid (4×4, Cols 1-4, Rows 0-3)
- 16 toggle buttons representing bits 15-0 of DAC state
- Two pages: synth params & FX params (switched via s/a)
- Brightness: 0 = off, 15 = on (may show intermediate states during blending)

#### Slew Grid (4×4, Cols 5-8, Rows 0-3)
- Row 0: Rise time (4 bits = 16 time values)
- Row 1: Fall time (4 bits = 16 time values)
- Row 2: Curve shape (4 bits = 16 curve values)
- Row 3: Per-param offset (4 bits, deferred feature)

#### Utilities (Cols 9-11, Rows 0-3)
- **-** (9, 0-3): Clear row in active grid (param or slew)
- **i** (10, 0-3): Invert row in active grid
- **>** (11, 0-3): Shift row right in active grid

**Action Resolution:**
```supercollider
// All actions resolve to state changes
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

#### Gesture Slots (4×4, Cols 12-15, Rows 0-3)
16 total gesture/preset slots.

**Interaction Model:**

**Empty slot:**
1. **First press:** Start recording (slot blinks)
2. **Second press:** Stop recording, auto-playback

**During playback:**
- **Press:** Overdub mode (add to gesture)
- **Double-tap:** Stop playback

**Anytime:**
- **Hold (>500ms):** Delete gesture

**Gesture Data Structure:**
```supercollider
~gestures[slotIndex] = (
    steps: [
        (time: 0,    state: 23456),
        (time: 500,  state: 23200),  // after clearRow
        (time: 750,  state: 46400),  // after shiftRow
        (time: 1200, state: 51234)
    ]
);
```

**Notes:**
- Single-step gesture = preset (instant state change)
- Multi-step gesture = timed state sequence
- Actions (clear/invert/shift) recorded as resulting states, not operations
- Enables averaging (gestures are always integer sequences)

#### Sequencer (4 rows × 16 steps, Cols 0-15, Rows 4-7)

**Per-Step Behavior:**
- **Press:** Select gesture slot to trigger (cycles through 0-15, or use brightness)
- **Hold + tap ;:** Set as last step for that row (loop point)

**Row Behavior:**
- Each row runs independently (polymetric if different loop lengths)
- Step advances on clock tick
- Triggering gesture updates that row's latched state
- No row = no contribution to blend (not zero, just absent)

**Sequencer Grid Visual:**
- **Bright (15):** Current step
- **Medium (8):** Has gesture assigned
- **Dim (3):** Empty step
- **Off (0):** Beyond loop length

---

## Audio Architecture

### Voice Design (Drone Synth)

**No envelopes, no VCA gating.** This is a drone synthesizer - always sounding, timbral exploration via continuous parameter morphing.

**Signal Flow:**
```
┌─────────┐   ┌─────────┐
│  Osc1   │   │  Osc2   │
│ +noise  │   │ +noise  │
└────┬────┘   └────┬────┘
     │             │
     └──────┬──────┘
            │
     ┌──────▼──────┐
     │ Combo Mode  │  (Cyclebox-style: OSC1/RING/MIN/PONG/INLV/AND/XOR/GLCH)
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
     │  Ring Mod   │  (Independent carrier oscillator)
     └──────┬──────┘
            │
     ┌──────▼──────┐
     │  Comb Res   │  (Karplus-Strong resonator)
     └──────┬──────┘
            │
     ┌──────▼──────┐
     │   Delay     │  (Stereo, filtered feedback)
     └──────┬──────┘
            │
     ┌──────▼──────┐
     │  MiClouds   │  (Granular + internal reverb)
     └──────┬──────┘
            │
     ┌──────▼──────┐
     │  Limiter    │  (Always on, not controllable)
     └──────┬──────┘
            │
            ▼
         Output
```

---

### Oscillator Section (11 params)

#### Osc1 (Primary)
| Param | Range | Description |
|-------|-------|-------------|
| `osc1_freq` | 20-2000 Hz (exp) | Primary frequency |
| `osc1_wave` | 0-3 | Sin/Tri/Saw/Square |
| `osc1_pw` | 0-1 | Pulse width (square only) |

#### Osc2 (Secondary)
| Param | Range | Description |
|-------|-------|-------------|
| `osc2_freq` | 20-2000 Hz (exp) | Secondary frequency |
| `osc2_wave` | 0-3 | Sin/Tri/Saw/Square |
| `osc2_pw` | 0-1 | Pulse width |
| `osc2_track` | 0-1 | Track osc1 freq (0=free, 1=locked) |
| `osc2_ratio` | 0.25-4.0 | Frequency ratio when tracking |

#### FM & Combination
| Param | Range | Description |
|-------|-------|-------------|
| `fm_amount` | 0-1 | Osc2 → Osc1 FM depth |
| `combo_mode` | 0-8 | Cyclebox-style waveform combination |
| `combo_mix` | 0-1 | Dry osc1 ↔ combo output |

**Combo Modes (Cylonix Cyclebox-inspired):**

```supercollider
// Convert audio signals to 16-bit integer representation
var osc1Bits = (osc1 * 32767).asInteger;
var osc2Bits = (osc2 * 32767).asInteger;

var combo = Select.ar(comboMode, [
    osc1,                                           // 0: OSC1 - pass through
    osc2,                                           // 1: OSC2 - pass through
    osc1 * osc2,                                    // 2: RING - ring modulation
    min(osc1, osc2),                                // 3: MIN - minimum of both
    Select.ar(osc1 > 0, [                           // 4: PONG - conditional routing
        Select.ar(osc2 < 0, [DC.ar(0), osc2]),
        osc1
    ]),
    // Bitwise modes (convert to int, operate, convert back)
    ((osc1Bits & osc2Bits) / 32767),               // 5: AND
    ((osc1Bits | osc2Bits) / 32767),               // 6: OR
    ((osc1Bits ^ osc2Bits) / 32767),               // 7: XOR
    ((osc1Bits.bitXor(osc2Bits.bitNot)) / 32767)   // 8: GLCH - glitchy combo
]);
```

---

### Noise Section (5 params)

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

### Filter Section (4 params)

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

### Timbral FX Chain

#### Lo-Fi (3 params)
| Param | Range | Description |
|-------|-------|-------------|
| `lofi_bits` | 1-16 | Bit depth reduction |
| `lofi_rate` | 100-48000 Hz | Sample rate reduction |
| `lofi_mix` | 0-1 | Dry/wet |

```supercollider
var lofi = (sig * (2.pow(lofiBits - 1))).round / (2.pow(lofiBits - 1));
lofi = Latch.ar(lofi, Impulse.ar(lofiRate));
sig = XFade2.ar(sig, lofi, lofiMix * 2 - 1);
```

#### Ring Mod (3 params)
| Param | Range | Description |
|-------|-------|-------------|
| `ring_freq` | 20-2000 Hz | Carrier frequency |
| `ring_wave` | 0-3 | Sin/Tri/Saw/Square |
| `ring_mix` | 0-1 | Dry/wet |

#### Comb Resonator (3 params)
| Param | Range | Description |
|-------|-------|-------------|
| `comb_freq` | 20-5000 Hz | Resonant frequency |
| `comb_decay` | 0.01-5.0 s | Decay time |
| `comb_mix` | 0-1 | Dry/wet |

```supercollider
var resonated = CombC.ar(sig, 0.05, (1/combFreq).clip(0.0002, 0.05), combDecay);
sig = XFade2.ar(sig, resonated, combMix * 2 - 1);
```

#### Delay (3 params)
| Param | Range | Description |
|-------|-------|-------------|
| `delay_time` | 1-2000 ms | Delay time |
| `delay_fb` | 0-0.99 | Feedback amount |
| `delay_mix` | 0-1 | Dry/wet |

---

### MiClouds Granular (7 params)

| Param | Range | Description |
|-------|-------|-------------|
| `clouds_pos` | 0-1 | Buffer position |
| `clouds_size` | 0-1 | Grain size |
| `clouds_dens` | 0-1 | Grain density (sparse→dense) |
| `clouds_tex` | 0-1 | Grain envelope texture |
| `clouds_mode` | 0-3 | Granular/Pitch/Loop/Spectral |
| `clouds_rvb` | 0-1 | Internal reverb amount |
| `clouds_mix` | 0-1 | Dry/wet |

**Triggering:** MiClouds auto-triggers on sequencer clock. Density parameter controls burst (low) vs continuous drone (high) behavior.

```supercollider
// Triggered on clock tick
var cloudsTrig = Impulse.kr(clockRate);

sig = MiClouds.ar(
    sig,
    pit: 0.5,  // No pitch shift (center)
    pos: cloudsPos,
    size: cloudsSize,
    dens: cloudsDens,
    tex: cloudsTex,
    drywet: cloudsMix,
    rvb: cloudsRvb,  // Internal reverb (no separate reverb needed)
    mode: cloudsMode,
    trig: cloudsTrig
);
```

---

### Output Section

| Param | Notes |
|-------|-------|
| `output_level` | Master output (0-1) |
| **Limiter** | `Limiter.ar(sig, 1.0, 0.01)` - always on, not controllable |

---

### Complete Parameter List (39 total)

```supercollider
~lut[index] = [
    // Oscillators (11 params)
    osc1_freq, osc1_wave, osc1_pw,
    osc2_freq, osc2_wave, osc2_pw, osc2_track, osc2_ratio,
    fm_amount, combo_mode, combo_mix,

    // Noise (4 params)
    noise_type, noise_level, noise_to_osc1, noise_to_osc2,

    // Filter (4 params)
    filter_freq, filter_res, filter_type, filter_track,

    // Lo-Fi (3 params)
    lofi_bits, lofi_rate, lofi_mix,

    // Ring Mod (3 params)
    ring_freq, ring_wave, ring_mix,

    // Comb Resonator (3 params)
    comb_freq, comb_decay, comb_mix,

    // Delay (3 params)
    delay_time, delay_fb, delay_mix,

    // MiClouds (7 params)
    clouds_pos, clouds_size, clouds_dens, clouds_tex,
    clouds_mode, clouds_rvb, clouds_mix,

    // Output (1 param)
    output_level
];
```

**LUT Memory:** 65536 entries × 39 params × 4 bytes = **~10.2 MB**

---

## Sequencer Behavior (Drone Voice)

### Core Principles

1. **No home state:** Parameters latch at current position indefinitely
2. **Per-row independence:** Each of 4 rows maintains separate DAC state
3. **Continuous blending:** Final output = arithmetic mean of all active row states
4. **Slew-controlled transitions:** Smooth (slew>0) or hard cuts (slew=0)
5. **Always sounding:** No gate/trigger for voice - drone synth architecture
6. **Clock triggers MiClouds:** Sequencer clock auto-triggers grain generation

### Execution Model

**Initialization (boot or load):**
```supercollider
~rowStates = [0, 0, 0, 0]; // All rows at state 0
```

**Step Trigger Event:**
```supercollider
// Row 2, Step 7 fires, assigned to gesture slot 5
~currentGesture = ~gestures[5];
~rowStates[2] = ~currentGesture.steps[0].state; // start gesture playback

// Gesture playback updates row state over time
~currentGesture.steps.do { |step|
    (step.time / 1000).wait;
    ~rowStates[2] = step.state;
};

// After gesture completes, row latches at final state
~rowStates[2] = ~currentGesture.steps.last.state;
```

**Blending Calculation (every control cycle):**
```supercollider
// Only include active rows (non-silent)
~activeRows = ~rowStates.select { |state, i| ~rowIsActive[i] };
~blendedState = (~activeRows.sum / ~activeRows.size).asInteger;

// Apply slew to blended state
~targetIndex = ~blendedState;
~currentIndex = ~targetIndex.lag(~riseTime, ~fallTime, ~curve);

// Lookup and set synth params
~params = ~lut[~currentIndex.asInteger];
~synth.set(\osc1_freq, ~params[0], \osc2_freq, ~params[1], ...);
```

**Visual Example:**
```
Time t=0:
Row 1: latched at 23456
Row 2: latched at 51234
Row 3: latched at 8192
Row 4: latched at 61000

Blended = (23456 + 51234 + 8192 + 61000) / 4 = 35970
→ ~lut[35970] → synth receives params[35970]
```

### Live Intervention During Playback

**User presses param grid toggle:**
```supercollider
// Which row is "active" for manual editing?
// Option A: Edit whichever row you're on (page system tracks this)
// Option B: Edit a "manual override" row that persists

// Recommended: Track "focused row" (cycles on shift key or always row 0)
~focusedRow = 0;

// User toggles bit 7
~rowStates[~focusedRow] = ~rowStates[~focusedRow] ^ (1 << 7);

// Manual change persists until next sequencer trigger on that row
```

**User applies action (clear/invert/shift):**
```supercollider
// Same logic - applies to focused row
~rowStates[~focusedRow] = ~applyAction.(~rowStates[~focusedRow], \invertRow, 2);
```

**Actions work identically during:**
- Gesture recording (captured as resulting states)
- Sequencer playback (override row state)
- Manual performance (direct state manipulation)

---

## Clock & Transport

### Tap Tempo

**Button: `;` (0, 2)**

**Behavior:**
```supercollider
~tapTimes = [];
~calculateTempo = {
    ~tapTimes = ~tapTimes.add(Main.elapsedTime);
    if (~tapTimes.size > 4) { ~tapTimes = ~tapTimes[1..] }; // keep last 4
    
    if (~tapTimes.size >= 2) {
        ~intervals = (~tapTimes[1..] - ~tapTimes[..(~tapTimes.size-2)]);
        ~avgInterval = ~intervals.mean;
        ~bpm = 60 / ~avgInterval;
        ~clock.tempo = ~bpm / 60;
    };
};
```

**Visual feedback:** Button blinks on each tap

### Transport

**Button: `:` (0, 3)**

**States:**
- **Stopped:** All rows frozen, no step advance
- **Running:** All rows advance on clock

**Behavior:**
```supercollider
~transport = \stopped;

~startTransport = {
    ~transport = \running;
    ~clock.play;
    // Reset all row positions to step 0 (optional)
};

~stopTransport = {
    ~transport = \stopped;
    ~clock.stop;
    // Row states remain latched (no reset)
};
```

### Clock Distribution

```supercollider
~clock = TempoClock.new(120/60); // 120 BPM default

~clock.schedAbs(~clock.beats.ceil, {
    if (~transport == \running) {
        4.do { |rowIndex|
            ~currentStep[rowIndex] = (~currentStep[rowIndex] + 1) % ~loopLengths[rowIndex];
            ~triggerStep.(rowIndex, ~currentStep[rowIndex]);
        };
    };
    1; // reschedule every beat
});
```

---

## State Persistence

### Save File Format (JSON)

```json
{
  "version": "1.0.0",
  "lut_seed": 1234567890,
  "tempo": 120,
  "current_page": "synth",
  
  "gestures": [
    {
      "slot": 0,
      "steps": [
        {"time": 0, "state": 23456},
        {"time": 500, "state": 23200},
        {"time": 750, "state": 46400}
      ]
    },
    // ... up to 16 gestures
  ],
  
  "sequencer": {
    "rows": [
      {
        "steps": [5, null, 3, null, 12, null, null, 5, ...], // 16 steps, gesture slot indices
        "loop_length": 16
      },
      // ... 4 rows
    ]
  },
  
  "row_states": [23456, 51234, 8192, 61000],
  
  "slew_config": {
    "rise_time": 8,      // 0-15 index into time LUT
    "fall_time": 8,
    "curve": 8,          // 0-15, maps to -8 to +8
    "per_param": 0       // deferred feature
  }
}
```

### Save/Load UI

**Save Mode:**
1. Hold `s` + `a` → Enter save mode (all gesture slots blink)
2. Tap gesture slot 0-15 → Save to that slot
3. Auto-exit save mode after save

**Load Mode:**
1. Hold `s` + `a` + `:` → Enter load mode (all gesture slots blink differently)
2. Tap gesture slot 0-15 → Load from that slot
3. Auto-exit load mode after load

**File Location:**
```
~saveDir = Platform.userAppSupportDir +/+ "ChaosGridSynth/saves/";
~saveFile = ~saveDir +/+ "slot_" ++ slotNum ++ ".json";
```

### LUT Regeneration

On load:
```supercollider
~loadProject = { |slotNum|
    var data = slotNum.loadJSON;
    ~lutSeed = data["lut_seed"];
    
    // Regenerate identical LUT
    ~lut = Array.fill(65536, { |i|
        thisThread.randSeed = ~lutSeed + i;
        // ... same generation code as boot
    });
    
    // Restore gestures, sequencer, etc.
};
```

---

## Implementation Priorities

### Phase 1: Core Engine
1. ⏳ LUT generation with seeded randomness (39 params)
2. ⏳ Parameter grid → DAC state → LUT lookup
3. ⏳ Drone synth voice (2 osc + combo modes + filter)
4. ⏳ Slew on index integer
5. ⏳ Grid/oscgrid OSC communication

### Phase 2: Voice Complete
6. ⏳ Cyclebox combo modes (9 modes)
7. ⏳ Noise section (type, level, FM routing)
8. ⏳ Timbral FX chain (Lo-Fi, Ring Mod, Comb Res)
9. ⏳ Delay + MiClouds integration
10. ⏳ Limiter (inline, always on)

### Phase 3: Gestures
11. ⏳ Gesture recording/playback (state sequences)
12. ⏳ Action resolution (clear/invert/shift → states)
13. ⏳ 16 gesture slots with visual feedback

### Phase 4: Sequencer
14. ⏳ 4-row × 16-step sequencer
15. ⏳ Per-row loop length
16. ⏳ Gesture triggering and blending (MEAN)
17. ⏳ Clock → MiClouds trigger routing
18. ⏳ Live intervention during playback

### Phase 5: Polish
19. ⏳ Tap tempo and transport
20. ⏳ Save/load system (JSON)
21. ⏳ Visual feedback (brightness for states)
22. ⏳ Slew parameter mapping (4×4 grid)

### Phase 6: Advanced Features (v2)
- Hardware Grid support (serialosc)
- MIDI clock sync
- Per-parameter slew offsets
- Gesture morphing/interpolation modes
- Osc2 ratio snapping option
- Additional combo modes

---

## Technical Notes

### Performance Considerations

**CPU Efficiency:**
- LUT is pure data structure (~2-4 MB RAM for 65536 × 40 floats)
- One synth instance (mono voice, no polyphony)
- Control-rate parameter updates (~64 Hz)
- Single lag calculation per update
- No dynamic voice allocation
- Fixed signal routing (no live patching)

**Grid Communication:**
- serialosc → OSC messages
- ~60-120 Hz refresh rate (varibright)
- Button press latency: <20ms
- Brightness updates batched per frame

### SuperCollider Architecture (Pure SC)

**No external control layer.** All logic lives in sclang:
- Grid OSC communication
- LUT generation and lookup
- Gesture recording/playback
- Sequencer and clock
- State persistence (JSON)

```supercollider
// Main drone synth (always sounding)
SynthDef(\chaosDrone, {
    arg // Oscillators
        osc1_freq=220, osc1_wave=0, osc1_pw=0.5,
        osc2_freq=220, osc2_wave=0, osc2_pw=0.5,
        osc2_track=0, osc2_ratio=1,
        fm_amount=0, combo_mode=0, combo_mix=0,
        // Noise
        noise_type=0, noise_level=0, noise_to_osc1=0, noise_to_osc2=0,
        // Filter
        filter_freq=1000, filter_res=0, filter_type=0, filter_track=0,
        // Lo-Fi
        lofi_bits=16, lofi_rate=48000, lofi_mix=0,
        // Ring Mod
        ring_freq=440, ring_wave=0, ring_mix=0,
        // Comb
        comb_freq=440, comb_decay=0.5, comb_mix=0,
        // Delay
        delay_time=250, delay_fb=0, delay_mix=0,
        // Clouds
        clouds_pos=0.5, clouds_size=0.5, clouds_dens=0.5,
        clouds_tex=0.5, clouds_mode=0, clouds_rvb=0, clouds_mix=0,
        // Output
        output_level=0.5,
        // Clock (for MiClouds trigger)
        t_clock=0;

    var osc1, osc2, noise, combo, sig;
    var osc1Bits, osc2Bits;

    // Noise generator
    noise = Select.ar(noise_type, [WhiteNoise.ar, PinkNoise.ar, BrownNoise.ar]);

    // Oscillators with noise modulation
    osc1 = Select.ar(osc1_wave, [
        SinOsc.ar(osc1_freq * (1 + (noise * noise_to_osc1 * 0.5))),
        LFTri.ar(osc1_freq * (1 + (noise * noise_to_osc1 * 0.5))),
        LFSaw.ar(osc1_freq * (1 + (noise * noise_to_osc1 * 0.5))),
        LFPulse.ar(osc1_freq * (1 + (noise * noise_to_osc1 * 0.5)), 0, osc1_pw, 2, -1)
    ]);

    // Osc2 with optional tracking
    osc2 = Select.ar(osc2_wave, [
        SinOsc.ar(Select.kr(osc2_track, [osc2_freq, osc1_freq * osc2_ratio]) * (1 + (noise * noise_to_osc2 * 0.5))),
        // ... other waveforms
    ]);

    // FM modulation
    osc1 = osc1 + (osc2 * fm_amount * osc1_freq);

    // Cyclebox combo modes
    osc1Bits = (osc1 * 32767).asInteger;
    osc2Bits = (osc2 * 32767).asInteger;
    combo = Select.ar(combo_mode, [
        osc1,                                    // 0: OSC1
        osc2,                                    // 1: OSC2
        osc1 * osc2,                             // 2: RING
        min(osc1, osc2),                         // 3: MIN
        // ... PONG, AND, OR, XOR, GLCH
    ]);
    sig = XFade2.ar(osc1, combo, combo_mix * 2 - 1);

    // Add noise to output
    sig = sig + (noise * noise_level);

    // Filter (SVF)
    sig = SVF.ar(sig, filter_freq, filter_res.linlin(0, 1, 0.1, 1), /* type select */);

    // Lo-Fi → Ring Mod → Comb → Delay → MiClouds
    // ... (see voice architecture)

    // MiClouds (triggered on clock)
    sig = MiClouds.ar(sig, trig: t_clock, /* params */);

    // Limiter (always on)
    sig = Limiter.ar(sig * output_level, 1.0, 0.01);

    Out.ar(0, sig ! 2);
}).add;
```

**Control Flow:**
```
┌─────────────────────────────────────────────────────┐
│                   iPad (oscgrid)                     │
│              or Hardware Grid (serialosc)            │
└──────────────────────┬──────────────────────────────┘
                       │ OSC (/monome/grid/key, /led/set)
                       ▼
┌─────────────────────────────────────────────────────┐
│              SuperCollider (sclang)                  │
├─────────────────────────────────────────────────────┤
│  ~grid         - OSC routing, LED state buffer      │
│  ~lut          - 65536 × 39 param array             │
│  ~gestures     - 16 gesture slots (state+time)      │
│  ~sequencer    - 4 rows × 16 steps, clock           │
│  ~state        - Current DAC values, row states     │
├─────────────────────────────────────────────────────┤
│              SynthDef(\chaosDrone)                  │
│  Always running, params updated via .set()          │
└─────────────────────────────────────────────────────┘
```

### Grid OSC Communication

**Incoming (from Grid):**
```supercollider
OSCdef(\gridKey, { |msg|
    var x = msg[1];
    var y = msg[2];
    var state = msg[3]; // 1 = press, 0 = release
    
    ~handleGridPress.(x, y, state);
}, '/monome/grid/key');
```

**Outgoing (to Grid):**
```supercollider
// Set single LED
~grid.ledSet(x, y, brightness); // brightness 0-15

// Set row
~grid.ledRow(row, brightness_array); // array of 16 brightness values

// Set all
~grid.ledAll(brightness); // 0-15
```

---

## Open Questions / Design Decisions

### Resolved:
- ✅ Voice architecture: Mono, based on Monokit + bitwise waveshaping
- ✅ Slew target: Integer index (efficient, all params slew together)
- ✅ Gesture storage: Resulting states (not actions), enables averaging
- ✅ Sequencer blend: Arithmetic mean of active row states
- ✅ Live intervention: Actions modify focused row, persist until seq trigger

### To Decide:
- **Focused row tracking:** How does user select which row to edit during playback?
  - Option A: Always row 0 (simple)
  - Option B: Cycle with shift key
  - Option C: Visual page system (one row per page)
  
- **Empty sequencer steps:** Do they silence the row or maintain last state?
  - Recommendation: Maintain last state (no gaps in blend)
  
- **Gesture overdub:** How do new steps integrate with existing recording?
  - Recommendation: Append to end (extend gesture length)
  
- **Brightness mapping:** Show current blended state on param grid?
  - Recommendation: Start with binary (on/off), add blending visualization later

---

## References

- **Monome Grid Documentation:** https://monome.org/docs/grid/
- **SuperCollider Documentation:** https://doc.sccode.org/
- **mi-UGens (MiClouds):** https://github.com/v7b1/mi-UGens
- **oscgrid (iPad Grid emulator):** https://github.com/okyeron/oscgrid
- **Cylonix Cyclebox User Guide:** https://www.cylonix.com/docs/cyclebox2_users_guide.pdf
- **Monokit:** /Users/why/repos/monokit (voice/FX architecture reference)

---

## Project Structure

```
griddlecake/
├── classes/
│   ├── ChaosDrone.sc           # Main application class
│   ├── GridInterface.sc        # Grid/oscgrid OSC communication
│   ├── LUT.sc                  # 65536-entry lookup table
│   ├── GestureRecorder.sc      # Gesture record/playback
│   ├── Sequencer.sc            # 4-row × 16-step sequencer
│   └── StateManager.sc         # JSON save/load
├── synthdefs/
│   └── drone.scd               # Drone synth voice (single SynthDef)
├── saves/
│   └── slot_*.json             # User project files
├── tests/
│   └── test_*.scd              # Unit tests
├── chaos-synth-spec.md         # This specification
└── main.scd                    # Boot file

Dependencies:
- SuperCollider 3.12+
- mi-UGens (MiClouds) - https://github.com/v7b1/mi-UGens
- oscgrid (for iPad) - https://github.com/okyeron/oscgrid
- OR serialosc (for hardware Grid) - https://monome.org/docs/serialosc/
```

---

## Getting Started (For Implementation)

1. **Install dependencies:**
   ```bash
   # SuperCollider 3.12+
   brew install supercollider  # macOS

   # mi-UGens (includes MiClouds)
   # Download from https://github.com/v7b1/mi-UGens/releases
   # Copy to ~/Library/Application Support/SuperCollider/Extensions/

   # For iPad: oscgrid
   # https://github.com/okyeron/oscgrid

   # For hardware Grid: serialosc
   # https://monome.org/docs/serialosc/setup/
   ```

2. **Initialize LUT:**
   ```supercollider
   ~lut = LUT.new(seed: Date.seed);  // Generate 65536 × 39 param sets
   ```

3. **Connect Grid/oscgrid:**
   ```supercollider
   // oscgrid sends to SC on port 8000 by default
   ~grid = GridInterface.new(port: 8000);
   ```

4. **Boot drone synth:**
   ```supercollider
   ~drone = Synth(\chaosDrone);  // Always running
   ```

5. **Start main loop:**
   ```supercollider
   ChaosDrone.boot;  // Connects grid, starts sequencer, runs LED refresh
   ```

---

## Glossary

- **DAC:** Digital-to-Analog Converter (here: 16-bit parameter grid as integer 0-65535)
- **LUT:** Lookup Table (array of 65536 synth states, 39 params each)
- **Slew:** Smooth transition between values (lag on index integer)
- **Gesture:** Recorded sequence of grid states with timing
- **Preset:** Single-step gesture (instant state change)
- **Combo Mode:** Cyclebox-inspired waveform combination (OSC1/RING/MIN/PONG/AND/OR/XOR/GLCH)
- **Drone:** Always-sounding synth with no envelope/gate
- **Grid:** Monome Grid controller (128 or 256 LED button matrix)
- **oscgrid:** iPad app that emulates Monome Grid via OSC
- **MiClouds:** Mutable Instruments Clouds granular processor (mi-UGens)
- **serialosc:** Daemon for hardware Monome Grid communication

---

**Version:** 2.0.0-draft
**Last Updated:** 2025-12-28
**Author:** Bram Adams / Claude (Anthropic)

**Changelog:**
- v2.0.0: Drone architecture (no EG/VCA), pure SC, Cyclebox combo modes, MiClouds integration
- v1.0.0: Initial specification
