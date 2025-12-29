# FX Chain

Timbral effects processing - Lo-Fi, Ring Mod, Comb Resonator, Delay, MiClouds.

---

## Signal Flow

```
Voice Output
     │
┌────▼────┐
│  Lo-Fi  │  Bitcrush + Downsample
└────┬────┘
     │
┌────▼────┐
│Ring Mod │  Independent carrier oscillator
└────┬────┘
     │
┌────▼────┐
│Comb Res │  Karplus-Strong resonator
└────┬────┘
     │
┌────▼────┐
│  Delay  │  Stereo, filtered feedback
└────┬────┘
     │
┌────▼────┐
│MiClouds │  Granular + internal reverb
└────┬────┘
     │
┌────▼────┐
│ Limiter │  Always on, not controllable
└────┬────┘
     │
     ▼
  Output
```

---

## Lo-Fi (3 params)

Bitcrusher and sample rate reducer.

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

---

## Ring Mod (3 params)

Independent ring modulator with its own carrier oscillator.

| Param | Range | Description |
|-------|-------|-------------|
| `ring_freq` | 20-2000 Hz | Carrier frequency |
| `ring_wave` | 0-3 | Sin/Tri/Saw/Square |
| `ring_mix` | 0-1 | Dry/wet |

```supercollider
var carrier = Select.ar(ringWave, [
    SinOsc.ar(ringFreq),
    LFTri.ar(ringFreq),
    LFSaw.ar(ringFreq),
    LFPulse.ar(ringFreq, 0, 0.5, 2, -1)
]);
sig = XFade2.ar(sig, sig * carrier, ringMix * 2 - 1);
```

---

## Comb Resonator (3 params)

Karplus-Strong style comb filter/resonator.

| Param | Range | Description |
|-------|-------|-------------|
| `comb_freq` | 20-5000 Hz | Resonant frequency |
| `comb_decay` | 0.01-5.0 s | Decay time |
| `comb_mix` | 0-1 | Dry/wet |

```supercollider
var resonated = CombC.ar(sig, 0.05, (1/combFreq).clip(0.0002, 0.05), combDecay);
sig = XFade2.ar(sig, resonated, combMix * 2 - 1);
```

---

## Delay (3 params)

Stereo delay with feedback.

| Param | Range | Description |
|-------|-------|-------------|
| `delay_time` | 1-2000 ms | Delay time |
| `delay_fb` | 0-0.99 | Feedback amount |
| `delay_mix` | 0-1 | Dry/wet |

```supercollider
var delayTime = delay_time / 1000;
var delayed = CombC.ar(sig, 2.0, delayTime, delay_fb * 3);
sig = XFade2.ar(sig, delayed, delayMix * 2 - 1);
```

---

## MiClouds Granular (7 params)

Mutable Instruments Clouds granular processor with internal reverb.

| Param | Range | Description |
|-------|-------|-------------|
| `clouds_pos` | 0-1 | Buffer position |
| `clouds_size` | 0-1 | Grain size |
| `clouds_dens` | 0-1 | Grain density (sparse→dense) |
| `clouds_tex` | 0-1 | Grain envelope texture |
| `clouds_mode` | 0-3 | Processing mode |
| `clouds_rvb` | 0-1 | Internal reverb amount |
| `clouds_mix` | 0-1 | Dry/wet |

### Processing Modes

| Mode | Name | Description |
|------|------|-------------|
| 0 | Granular | Classic granular synthesis |
| 1 | Pitch Shifter | More deterministic pitch shifting |
| 2 | Looping Delay | Rhythmic delay-like behavior |
| 3 | Spectral | FFT-based spectral processing |

### Triggering

MiClouds auto-triggers on **sequencer clock**. The `clouds_dens` parameter controls:
- **Low density** → Sparse grain bursts (rhythmic)
- **High density** → Continuous drone texture

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

### Why No Separate Reverb?

MiClouds includes a high-quality internal reverb (`clouds_rvb`). This eliminates the need for a separate reverb effect, simplifying the signal chain.

---

## Limiter

Always-on brickwall limiter at the end of the chain. Not controllable.

```supercollider
sig = Limiter.ar(sig * output_level, 1.0, 0.01);
```

---

## Complete FX Parameter List

```supercollider
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
clouds_mode, clouds_rvb, clouds_mix

// FX subtotal: 19 params
// + Voice params: 20
// = Total: 39 params
```

---

## Related Documents

- [Voice Architecture](voice_architecture.md) - Oscillators, filter, noise
- [Core Concepts](core_concepts.md) - How params are stored in LUT
- [Clock & Transport](clock_transport.md) - Clock triggers MiClouds
