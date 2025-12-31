# Engine Abstraction Layer

Specification for multi-engine voice architecture with hot-swapping.

---

## Overview

Griddlecake supports multiple synthesis engines sharing a common interface:
- **Variable parameter counts** - Voice (20-24) + FX (19-25) per engine
- **16-bit LUT navigation** (65536 states per engine)
- **Hot-swap** between engines without restart
- **Per-engine LUT generation** with weighted distributions
- **Shared libraries** loaded centrally (fx_lib, lut_lib)

---

## Engine File Pattern

All engine files follow this structure:

```supercollider
// 1. Header comments describing params
// Note: fx_lib.scd and lut_lib.scd are loaded by main.scd

// 2. SynthDef at file level (uses ~fx functions)
SynthDef(\engineName, {
    arg gate = 1,
    // voice params...
    // fx params...
    output_level = 0.5;

    var sig;
    // ... synthesis
    // ... FX chain using ~fxWavefold, ~fxChorus, etc.
    // ... EQ + compression
    sig = sig * EnvGen.kr(Env.asr(0.1, 1, 0.5), gate, doneAction: 2);
    Out.ar(0, sig ! 2);
}).add;

// 3. Engine spec dictionary (returned by file)
(
    key: \engineName,
    name: "Human Readable Name",
    synthDef: \engineName,  // symbol, not function
    implemented: true,

    voiceParams: [...],  // param specs
    fxParams: [...],

    lutGenerator: { |seed| ... }  // uses ~lutLib
)
```

**Key points:**
- Do NOT load fx_lib.scd - main.scd loads it before engines
- SynthDef defined at file level with `.add`
- `synthDef:` is a symbol, not a function
- `implemented: true` required for engine to be selectable

---

## Shared Libraries

### Loaded by main.scd (before engines)

```supercollider
// synthdefs/lut_lib.scd - Random generators with musical weighting
~lutLib = (
    freq: { |min, max, bias| ... },   // biased frequency
    time: { |min, max, bias| ... },   // biased time
    curved: { |max, bias| ... },      // biased 0-max
    linear: { |min, max| ... },       // uniform
    exp: { |min, max| ... },          // exponential
    int: { |max| ... },               // integer 0 to max-1
    choose: { |array| ... },          // random pick
    clouds: { ... },                  // 7 MiClouds params
    buildPair: { |seed, vHome, vGen, fxHome, fxGen| ... }
)

// synthdefs/fx_lib.scd - FX building blocks
~fxLofi, ~fxRing, ~fxComb, ~fxDelay, ~fxClouds,
~fxWavefold, ~fxChorus, ~fxFilter, ~fxTape, ~fxShimmer,
~fxFreeze, ~fxEQ, ~fxComp, ~fxFilterBank4, ...
```

---

## Engine Loading

```supercollider
// main.scd loads libraries, then engines
~synthdefs_dir = thisProcess.nowExecutingPath.dirname +/+ "synthdefs";
~lutLib = (~synthdefs_dir +/+ "lut_lib.scd").load;
(~synthdefs_dir +/+ "fx_lib.scd").load;

~loadEngine = { |filename|
    var spec = (~synthdefs_dir +/+ filename).load;
    // Validates: key, synthDef, voiceParams, fxParams, lutGenerator
    ~engines[spec[\key]] = spec;
    ~engineOrder = ~engineOrder.add(spec[\key]);
};

~loadEngine.("drone.scd");
~loadEngine.("feedback.scd");
~loadEngine.("fm4op.scd");
```

---

## Parameter Names (Engine-Derived)

Param names are derived from current engine spec, not hardcoded:

```supercollider
~getEngineParamNames = {
    var engine = ~engines[~currentEngine];
    ~voiceParamNames = engine[\voiceParams].collect({ |p| p[\name] });
    ~fxParamNames = engine[\fxParams].collect({ |p| p[\name] });
};

// Called on boot and engine switch
~getEngineParamNames.();
```

---

## LUT Generator Pattern

Using shared `~lutLib` for DRY random generation:

```supercollider
lutGenerator: { |seed|
    var lib = ~lutLib;

    var voiceHome = [...];  // safe defaults
    var fxHome = [...];

    var voiceGen = {
        [
            lib[\freq].(20, 2000, 1.8),   // low-freq bias
            lib[\int].(4),                 // 0-3
            lib[\choose].([1, 2, 3, 4]),  // from array
            lib[\curved].(0.8, 1.5),      // subtle bias
            // ...
        ]
    };

    var fxGen = {
        lib[\lofi].(mixMax: 0.5)
        ++ lib[\ring].(mixMax: 0.4)
        ++ lib[\clouds].()
    };

    lib[\buildPair].(seed, voiceHome, voiceGen, fxHome, fxGen)
}
```

**Overriding bias per-engine:**
```supercollider
// drone.scd - strong low bias
lib[\freq].(20, 2000, 1.8)

// feedback.scd - slight high bias
lib[\freq].(20, 4000, 0.5)

// fm4op.scd - harmonic ratios
lib[\choose].([1, 2, 3, 4, 0.5, 1.5, 2.5])
```

---

## Hot-Swap Process

```
1. User selects engine in modal
          ↓
2. Get/generate LUTs for new engine
   - ~voiceLut, ~fxLut updated
          ↓
3. Update param names from spec
   - ~getEngineParamNames.()
          ↓
4. Fade out old synth (gate = 0)
          ↓
5. Create new synth (fork + s.sync)
          ↓
6. Apply current DAC state
   - ~applyVoiceState, ~applyFxState
```

---

## Implemented Engines

| Key | Name | Voice | FX | FX Chain |
|-----|------|-------|----|----|
| `\drone` | Chaos Drone | 20 | 19 | lofi→ring→comb→delay→clouds (Chain A) |
| `\feedback` | Feedback Network | 24 | 25 | tape→filterBank→shimmer→freeze→clouds (Chain B) |
| `\fm4op` | 4-Op FM | 20 | 20 | wavefold→chorus→filter→delay→clouds (Chain B) |
| `\wavetable` | Wavetable | 20 | 20 | phaser→chorus→delay→clouds (Chain C) |

---

## Adding a New Engine

1. Create `synthdefs/newengine.scd` following the pattern above
2. Add `~loadEngine.("newengine.scd");` to main.scd
3. Define SynthDef using `~fx*` functions from fx_lib
4. Define param specs with idx, name, min, max, curve, default
5. Create lutGenerator using `~lutLib` helpers
6. Set `implemented: true` in spec

The engine will automatically:
- Have param names derived from spec
- Support hot-swap with crossfade
- Use shared LUT caching
- Integrate with Grid UI

---

## Cross-Engine Gestures

Gestures store DAC states (16-bit indices), not parameter values. When played on a different engine:
- Same DAC state → different LUT → different sound
- Creates unexpected but musically interesting results
- Encourages experimentation across engines

---

**Version:** 0.2.0
**Last Updated:** 2025-12-31
