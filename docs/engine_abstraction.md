# Engine Abstraction Layer

Specification for multi-engine voice architecture with hot-swapping.

---

## Overview

Griddlecake supports multiple synthesis engines sharing a common interface:
- **Fixed 39-parameter structure** (20 voice + 19 FX) across all engines
- 16-bit LUT navigation (65536 states)
- Hot-swap between engines without restart
- Per-engine LUT generation with weighted distributions
- Cross-engine gesture compatibility (same DAC → different sounds)

---

## Fixed Parameter Architecture

All engines use exactly 39 parameters:
- **Voice slots 0-19**: Engine-specific synthesis params
- **FX slots 20-38**: Shared FX chain (consistent across engines)

Engines that don't need all 20 voice slots use extras for:
- Internal modulation depths
- Random seed offsets
- Sub-parameter fine-tuning
- Reserved for future expansion

This keeps LUT structure uniform and enables gestures/sequences to produce interesting cross-engine results.

---

## Engine Registry

```supercollider
~engines = Dictionary[
    \drone -> (
        name: "Chaos Drone",
        synthDef: \chaosDrone,
        implemented: true,
        voiceParams: [...],  // 20 param specs
        fxParams: [...],     // 19 param specs
        lutGenerator: { |seed| ... },
    ),
    \fm -> (
        name: "FM Synthesis",
        synthDef: \fmEngine,
        implemented: false,
        voiceParams: [...],
        fxParams: [...],
        lutGenerator: { |seed| ... },
    ),
    // ... more engines
];

~engineOrder = [\drone, \fm, \wavetable, \additive, \modal, \feedback, \granular, \spectral];
~currentEngine = \drone;
```

---

## Engine Specification

Each engine must provide:

### 1. SynthDef

```supercollider
SynthDef(\engineName, {
    arg out = 0,
        // 20 voice params (p0-p19)
        p0 = 0, p1 = 0, p2 = 0, p3 = 0, p4 = 0,
        p5 = 0, p6 = 0, p7 = 0, p8 = 0, p9 = 0,
        p10 = 0, p11 = 0, p12 = 0, p13 = 0, p14 = 0,
        p15 = 0, p16 = 0, p17 = 0, p18 = 0, p19 = 0,
        // 19 FX params (p20-p38)
        p20 = 0, p21 = 0, p22 = 0, p23 = 0, p24 = 0,
        p25 = 0, p26 = 0, p27 = 0, p28 = 0, p29 = 0,
        p30 = 0, p31 = 0, p32 = 0, p33 = 0, p34 = 0,
        p35 = 0, p36 = 0, p37 = 0, p38 = 0,
        // Standard controls
        slew_time = 0.1,
        slew_curve = 0,
        amp = 0.5,
        gate = 1;  // for crossfade

    var sig;
    // ... engine implementation
    Out.ar(out, sig * EnvGen.kr(Env.asr(0.05, 1, 0.1), gate, doneAction: 2));
}).add;
```

### 2. Parameter Specs (20 voice + 19 FX = 39 total)

```supercollider
voiceParams: [
    // Slots 0-19: engine-specific
    (idx: 0,  name: \osc1_freq,  min: 20,   max: 2000, curve: \exp, default: 55),
    (idx: 1,  name: \osc1_wave,  min: 0,    max: 3,    curve: \lin, default: 0),
    (idx: 2,  name: \osc1_pw,    min: 0.01, max: 0.99, curve: \lin, default: 0.5),
    // ... slots 3-17
    (idx: 18, name: \internal_mod1, min: 0, max: 1, curve: \lin, default: 0),  // unused → internal
    (idx: 19, name: \internal_mod2, min: 0, max: 1, curve: \lin, default: 0),
],

fxParams: [
    // Slots 20-38: shared FX chain (same across all engines)
    (idx: 20, name: \lofi_bits,    min: 4,     max: 16,    curve: \lin, default: 16),
    (idx: 21, name: \lofi_rate,    min: 1000,  max: 48000, curve: \exp, default: 48000),
    (idx: 22, name: \lofi_mix,     min: 0,     max: 1,     curve: \lin, default: 0),
    // ... through slot 38
],
```

### 3. LUT Generator

```supercollider
lutGenerator: { |seed|
    thisThread.randSeed = seed;

    var voiceLut = 65536.collect { |i|
        if(i == 0) {
            // State 0 = home base (engine-specific safe default)
            Float32Array[55, 0, 0.5, /* ... 17 more */]
        } {
            // Random state with engine-specific weighting
            Float32Array[
                { rrand(20.0, 2000.0) }.().pow(0.5).linexp(0, 1, 20, 2000),  // freq bias low
                4.rand,  // wave select
                rrand(0.01, 0.99),  // pulse width
                // ... 17 more voice params
            ]
        }
    };

    var fxLut = 65536.collect { |i|
        if(i == 0) {
            // State 0 = dry FX
            Float32Array[16, 48000, 0, /* ... 16 more at defaults */]
        } {
            // Random FX state
            Float32Array[
                rrand(4, 16),        // lofi bits
                exprand(1000, 48000), // lofi rate
                rrand(0.0, 0.5),     // lofi mix (bias toward subtle)
                // ... 16 more FX params
            ]
        }
    };

    (voice: voiceLut, fx: fxLut)
}
```

---

## Hot-Swap Process

```
┌─────────────────────────────────────────────────────┐
│  1. User taps engine on Engine Select page          │
└─────────────────────┬───────────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────────┐
│  2. Fade out current synth (gate = 0, ~100ms)       │
└─────────────────────┬───────────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────────┐
│  3. Get LUT for new engine (cached or generate)     │
│     - Uses current seed                             │
│     - ~voiceLut, ~fxLut updated                     │
└─────────────────────┬───────────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────────┐
│  4. Boot new SynthDef instance                      │
│     - ~synth = Synth(\newEngine, [...])             │
└─────────────────────┬───────────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────────┐
│  5. Apply current DAC state to new engine           │
│     - Same ~voiceDacState → new LUT → new sound     │
│     - Same ~fxDacState → new LUT → new FX           │
└─────────────────────┬───────────────────────────────┘
                      ▼
┌─────────────────────────────────────────────────────┐
│  6. Return to main UI                               │
│     - ~currentEngine updated                        │
└─────────────────────────────────────────────────────┘
```

### Crossfade Implementation

```supercollider
~switchEngine = { |newEngineKey|
    var oldSynth = ~synth;
    var engine = ~engines[newEngineKey];
    var luts;

    if(engine.implemented.not) {
        "Engine not implemented: %".format(newEngineKey).warn;
    } {
        // Get or generate LUTs
        luts = ~getLuts.(newEngineKey);
        ~voiceLut = luts.voice;
        ~fxLut = luts.fx;

        // Fade out old synth
        oldSynth.set(\gate, 0);

        // Boot new after fade
        AppClock.sched(0.12, {
            ~synth = Synth(engine.synthDef, [
                \out, 0,
                \amp, ~amp,
                \slew_time, ~slewTime,
                \slew_curve, ~slewCurve,
                \gate, 1
            ] ++ ~buildParamArgs.());

            ~currentEngine = newEngineKey;
            "Switched to engine: %".format(engine.name).postln;
            nil
        });
    };
};
```

---

## Engine Page

### Entry/Exit

```supercollider
// Track page button states
~pageButtonStates = (s: false, a: false);
~onEnginePage = false;

// Check for simultaneous hold
~checkEnginePageEntry = {
    if(~pageButtonStates.s and: ~pageButtonStates.a and: ~onEnginePage.not) {
        ~enterEnginePage.();
    };
};

~enterEnginePage = {
    ~onEnginePage = true;
    ~updateEnginePageLEDs.();
    "Entered engine select page".postln;
};

~exitEnginePage = {
    ~onEnginePage = false;
    ~updateMainLEDs.();
    "Returned to main UI".postln;
};
```

### Grid Handler

```supercollider
~handleEnginePage = { |x, y, state|
    if(state == 1) {  // press only
        case
        { x == 0 and: { y == 0 } } {
            // Back button
            ~exitEnginePage.();
        }
        { y == 0 and: { x > 0 } and: { x <= ~engineOrder.size } } {
            // Engine selection (row 0, cols 1-N)
            var engineKey = ~engineOrder[x - 1];
            var engine = ~engines[engineKey];

            if(engine.implemented) {
                ~switchEngine.(engineKey);
                ~exitEnginePage.();
            } {
                // Flash to indicate not implemented
                ~flashButton.(x, y, 3);  // dim flash
            };
        };
    };
};
```

### LED Feedback

```supercollider
~updateEnginePageLEDs = {
    // Clear entire grid
    16.do { |x| 8.do { |y| ~grid.ledBuffer[x][y] = 0 } };

    // Back button (col 0, row 0)
    ~grid.ledBuffer[0][0] = 8;

    // Engine slots (row 0, cols 1-N)
    ~engineOrder.do { |key, i|
        var x = i + 1;
        var engine = ~engines[key];
        var brightness = case
            { key == ~currentEngine } { 15 }  // bright = selected
            { engine.implemented } { 8 }       // medium = available
            { true } { 3 };                    // dim = not implemented

        ~grid.ledBuffer[x][0] = brightness;
    };

    ~grid.ledDirty = true;
};
```

---

## Planned Engines

| Slot | Key | Name | Voice Params | Status |
|------|-----|------|--------------|--------|
| 1 | `\drone` | Chaos Drone | 2 osc, combo, filter, noise | Implemented |
| 2 | `\fm` | FM Synthesis | 4-6 ops, ratios, feedback, algorithm | Planned |
| 3 | `\wavetable` | Wavetable | position, morph, frame, tables | Planned |
| 4 | `\additive` | Additive | partials, amplitudes, phases | Planned |
| 5 | `\modal` | Modal/Physical | modes, decay, strike, material | Planned |
| 6 | `\feedback` | Feedback Network | routing gains, filter positions | Planned |
| 7 | `\granular` | Multi-Granular | streams, rates, positions, sizes | Planned |
| 8 | `\spectral` | Spectral/FFT | bins, freeze, delays, smear | Planned |

---

## Shared FX Chain

All engines share the same FX parameter mapping (slots 20-38):

| Slot | Name | Range | Description |
|------|------|-------|-------------|
| 20 | lofi_bits | 4-16 | Bit depth reduction |
| 21 | lofi_rate | 1k-48k | Sample rate reduction |
| 22 | lofi_mix | 0-1 | Lo-Fi wet/dry |
| 23 | ring_freq | 20-2000 | Ring mod frequency |
| 24 | ring_wave | 0-3 | Ring mod waveform |
| 25 | ring_mix | 0-1 | Ring mod wet/dry |
| 26 | comb_freq | 20-2000 | Comb filter frequency |
| 27 | comb_decay | 0.1-10 | Comb decay time |
| 28 | comb_mix | 0-1 | Comb wet/dry |
| 29 | delay_time | 0.01-2 | Delay time |
| 30 | delay_fb | 0-0.95 | Delay feedback |
| 31 | delay_mix | 0-1 | Delay wet/dry |
| 32 | clouds_pos | 0-1 | Grain position |
| 33 | clouds_size | 0-1 | Grain size |
| 34 | clouds_dens | 0-1 | Grain density |
| 35 | clouds_tex | 0-1 | Grain texture |
| 36 | clouds_mode | 0-3 | MiClouds mode |
| 37 | clouds_rvb | 0-1 | Internal reverb |
| 38 | clouds_mix | 0-1 | Granular wet/dry |

---

## LUT Caching

```supercollider
~lutCache = Dictionary[];

~getLuts = { |engineKey|
    var cacheKey = (engineKey ++ "_" ++ ~seed).asSymbol;

    if(~lutCache[cacheKey].isNil) {
        var engine = ~engines[engineKey];
        "Generating LUT for %...".format(engineKey).postln;
        ~lutCache[cacheKey] = engine.lutGenerator.(~seed);
    };

    ~lutCache[cacheKey]
};

~clearLutCache = {
    ~lutCache.clear;
    "LUT cache cleared".postln;
};

// Clear cache when seed changes
~setSeed = { |newSeed|
    ~seed = newSeed;
    ~clearLutCache.();
};
```

---

## State Persistence

```supercollider
~saveState = { |path|
    (
        engine: ~currentEngine,
        seed: ~seed,
        voiceDac: ~voiceDacState,
        fxDac: ~fxDacState,
        slewTime: ~slewTime,
        slewCurve: ~slewCurve,
        amp: ~amp,
        gestures: ~exportGestures.(),
        sequencer: ~exportSequencer.(),
    ).writeArchive(path ?? { ~statePath });
};

~loadState = { |path|
    var state = Object.readArchive(path ?? { ~statePath });

    ~seed = state.seed;
    ~switchEngine.(state.engine);
    ~voiceDacState = state.voiceDac;
    ~fxDacState = state.fxDac;
    ~slewTime = state.slewTime;
    ~slewCurve = state.slewCurve;
    ~amp = state.amp;
    ~importGestures.(state.gestures);
    ~importSequencer.(state.sequencer);

    ~applyCurrentState.();
};
```

---

## Cross-Engine Gestures

Gestures store DAC states (16-bit indices), not parameter values. When played on a different engine:
- Same DAC state → different LUT → different params → different sound
- Creates unexpected but musically interesting results
- Encourages experimentation across engines

If precise cross-engine behavior is needed later, gestures could optionally store:
- Engine tag (only play on matching engine)
- Normalized param values (0-1 range, remapped per engine)

For now, embrace the chaos.

---

**Version:** 0.1.0-draft
**Last Updated:** 2025-12-30
