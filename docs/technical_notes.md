# Technical Notes

Performance considerations, SuperCollider architecture, and OSC communication.

---

## Performance Considerations

### CPU Efficiency

| Aspect | Notes |
|--------|-------|
| LUT size | ~10.2 MB RAM (65536 × 39 × 4 bytes) |
| Voice count | 1 (mono drone, no polyphony) |
| Param updates | Control-rate (~64 Hz) |
| Slew calculations | 1 per update (index slew, not per-param) |
| Voice allocation | None (always running) |
| Signal routing | Fixed (no live patching) |

### Grid Communication

| Aspect | Value |
|--------|-------|
| Protocol | OSC over UDP |
| Refresh rate | ~60-120 Hz (varibright) |
| Button latency | <20ms |
| LED updates | Batched per frame |

---

## SuperCollider Architecture

**Pure SC implementation** - all logic lives in sclang:
- Grid OSC communication
- LUT generation and lookup
- Gesture recording/playback
- Sequencer and clock
- State persistence (JSON)

### Control Flow

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

---

## SynthDef Sketch

```supercollider
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
    // ... (see fx_chain.md)

    // MiClouds (triggered on clock)
    sig = MiClouds.ar(sig, trig: t_clock, /* params */);

    // Limiter (always on)
    sig = Limiter.ar(sig * output_level, 1.0, 0.01);

    Out.ar(0, sig ! 2);
}).add;
```

---

## Grid OSC Communication

### Incoming (from Grid)

```supercollider
OSCdef(\gridKey, { |msg|
    var x = msg[1];
    var y = msg[2];
    var state = msg[3]; // 1 = press, 0 = release

    ~handleGridPress.(x, y, state);
}, '/monome/grid/key');
```

### Outgoing (to Grid)

```supercollider
// Set single LED
~gridAddr.sendMsg('/monome/grid/led/set', x, y, brightness);

// Set row (more efficient)
~gridAddr.sendMsg('/monome/grid/led/row', 0, row, *brightnessArray);

// Set all
~gridAddr.sendMsg('/monome/grid/led/all', brightness);
```

### oscgrid vs serialosc

| Aspect | oscgrid | serialosc |
|--------|---------|-----------|
| Device | iPad app | Hardware Grid |
| Protocol | Same OSC messages | Same OSC messages |
| Default port | 8000 | 8080 (configurable) |
| Discovery | Manual IP config | Automatic via serialosc |

The OSC messages are identical - only the connection setup differs.

---

## LUT Parameter Scaling

Each LUT entry stores raw values. Scaling happens at lookup time:

```supercollider
~paramSpecs = [
    // [index, name, min, max, curve]
    [0, \osc1_freq, 20, 2000, \exp],
    [1, \osc1_wave, 0, 3, \lin],
    [2, \osc1_pw, 0, 1, \lin],
    // ...
];

~scaleParam = { |rawValue, spec|
    var min = spec[2], max = spec[3], curve = spec[4];
    if (curve == \exp) {
        rawValue.linexp(0, 1, min, max)
    } {
        rawValue.linlin(0, 1, min, max)
    }
};

~applyParams = { |lutIndex|
    var rawParams = ~lut[lutIndex];
    ~paramSpecs.do { |spec, i|
        var scaled = ~scaleParam.(rawParams[i], spec);
        ~drone.set(spec[1], scaled);
    };
};
```

---

## Glossary

| Term | Definition |
|------|------------|
| **DAC** | 16-bit parameter grid as integer 0-65535 |
| **LUT** | Lookup Table - 65536 synth states, 39 params each |
| **Slew** | Smooth transition via lag on index integer |
| **Gesture** | Recorded sequence of grid states with timing |
| **Preset** | Single-step gesture (instant state change) |
| **Combo Mode** | Cyclebox waveform combination |
| **Drone** | Always-sounding synth with no envelope/gate |
| **oscgrid** | iPad app that emulates Monome Grid via OSC |
| **serialosc** | Daemon for hardware Monome Grid communication |

---

## Related Documents

- [Implementation](implementation.md) - Build phases
- [Voice Architecture](voice_architecture.md) - Synth params
- [FX Chain](fx_chain.md) - Effects params
