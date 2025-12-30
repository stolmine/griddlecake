# Grid Layout & Interaction

Physical layout and interaction model for 128 Grid (16×8) - Music Mode v0.1.0b.

---

## Quick Reference Map

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                    GRIDDLECAKE v0.1.0b - MUSIC MODE                          ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  Column: 0     1  2  3  4     5  6  7  8     9 10 11 12    13 14 15          ║
║         ┌───┬─────────────┬─────────────┬──────────────┬────────────┐        ║
║  Row 0: │ M │ v  v  v  v  │ h  h  h  h  │ Lv Lv Lv Lv  │ g  g  g    │        ║
║  Row 1: │ G │ v  v  v  v  │ h  h  h  h  │ Lv Lv Lv Lv  │ g  g  g    │        ║
║  Row 2: │ + │ v  v  v  v  │ h  h  h  h  │ Lv Lv Lv Lv  │ g  g  g    │        ║
║  Row 3: │ - │ v  v  v  v  │ h  h  h  h  │ Lv Lv Lv Lv  │ g  g  g    │        ║
║         ├───┼─────────────┼─────────────┼──────────────┼────────────┤        ║
║  Row 4: │ T │ f  f  f  f  │ C  C# D  D# │ Lf Lf Lf Lf  │ g  g  g    │        ║
║  Row 5: │ H │ f  f  f  f  │ E  F  F# G  │ Lf Lf Lf Lf  │ g  g  g    │        ║
║  Row 6: │   │ f  f  f  f  │ G# A  A# B  │ Lf Lf Lf Lf  │ g  g  g    │        ║
║  Row 7: │   │ f  f  f  f  │ S  S  S  S  │ Lf Lf Lf Lf  │ g  g  g    │        ║
║         └───┴─────────────┴─────────────┴──────────────┴────────────┘        ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  GLOBAL (col 0)        │  VOICE/FX DAC (1-4)   │  HARMONY (5-8)              ║
║  M = Mute toggle       │  v = Voice params     │  h = Harmonic DAC (16-bit)  ║
║  G = Gesture ctrl      │      (rows 0-3)       │  C-B = Root select (12)     ║
║  + = Octave up         │  f = FX params        │  S = Scale select (4-bit)   ║
║  - = Octave down       │      (rows 4-7)       │                             ║
║  T = Tuning (TET/Just) │                       │                             ║
║  H = Home state        │                       │                             ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  SLEW (9-12)           │  GESTURES (13-15)                                   ║
║  Lv = Voice slew       │  g = 24 slots (3×8)                                 ║
║       Row 0: Time      │      Rows 0-3: Voice gestures                       ║
║       Row 1: Curve     │      Rows 4-7: FX gestures                          ║
║  Lf = FX slew          │  Tap=record, Tap=stop+play, Double-tap=pause        ║
║       Row 4: Time      │  Hold=clear                                         ║
║       Row 5: Curve     │                                                     ║
╠══════════════════════════════════════════════════════════════════════════════╣
║  SCALES: 0=Major 1=Minor 2=HarmMin 3=MelMin 4=Dorian 5=Phrygian 6=Lydian     ║
║  7=Mixo 8=Locrian 9=PentMaj 10=PentMin 11=Blues 12=Whole 13=Dim 14=Aug 15=Chr║
╚══════════════════════════════════════════════════════════════════════════════╝
```

---

## Physical Layout (Simple)

```
Column: 0    1  2  3  4    5  6  7  8    9 10 11 12   13 14 15
        ┌──┬───────────┬───────────┬────────────┬──────────┐
Row 0:  │M │ v  v  v  v│ h  h  h  h│ Lv Lv Lv Lv│ g  g  g │
Row 1:  │G │ v  v  v  v│ h  h  h  h│ Lv Lv Lv Lv│ g  g  g │
Row 2:  │+ │ v  v  v  v│ h  h  h  h│ Lv Lv Lv Lv│ g  g  g │
Row 3:  │- │ v  v  v  v│ h  h  h  h│ Lv Lv Lv Lv│ g  g  g │
        ├──┼───────────┼───────────┼────────────┼──────────┤
Row 4:  │T │ f  f  f  f│ R  R  R  R│ Lf Lf Lf Lf│ g  g  g │
Row 5:  │H │ f  f  f  f│ R  R  R  R│ Lf Lf Lf Lf│ g  g  g │
Row 6:  │. │ f  f  f  f│ R  R  R  R│ Lf Lf Lf Lf│ g  g  g │
Row 7:  │. │ f  f  f  f│ S  S  S  S│ Lf Lf Lf Lf│ g  g  g │
        └──┴───────────┴───────────┴────────────┴──────────┘
```

**Legend:**
- **M** = Mute (on/off toggle)
- **G** = Gesture start/stop (reserved)
- **+/-** = Octave up/down
- **T** = Tuning toggle (12TET / Just Intonation)
- **H** = Home state
- **.** = Reserved
- **v** = Voice chaos DAC (4×4 = 16-bit)
- **f** = FX chaos DAC (4×4 = 16-bit)
- **h** = Harmonic DAC (4×4 = 16-bit chord voicing)
- **R** = Root select (12 chromatic, mutually exclusive)
- **S** = Scale select (4-bit = 16 scales)
- **Lv** = Voice slew (time/curve)
- **Lf** = FX slew (time/curve)
- **g** = Gesture slots (3×8 = 24 total)

---

## Control Zones

### Global Controls (Column 0)

| Row | Button | Function |
|-----|--------|----------|
| 0 | **M** | Mute toggle |
| 1 | **G** | Gesture start/stop (reserved) |
| 2 | **+** | Octave up (-2 to +2 range) |
| 3 | **-** | Octave down |
| 4 | **T** | Tuning toggle (12TET ↔ Just) |
| 5 | **H** | Home state (reset to 0,0,0) |
| 6-7 | **.** | Reserved |

**LED Feedback:**
- Mute: Full when muted, dim otherwise
- Tuning: Full when Just, dim when 12TET
- Others: Dim static

---

### Voice DAC (Cols 1-4, Rows 0-3)

16 toggle buttons representing bits 15-0 of voice chaos state.

```
Bit layout:
[15][14][13][12]   Row 0
[11][10][ 9][ 8]   Row 1
[ 7][ 6][ 5][ 4]   Row 2
[ 3][ 2][ 1][ 0]   Row 3
```

**Controls (non-pitch):**
- Oscillator waveforms and pulse widths
- Tracking and ratios for osc2/osc3
- FM amount, combo mode, combo mix, detune
- Noise parameters
- Filter frequency, resonance, type, tracking
- Output level

---

### FX DAC (Cols 1-4, Rows 4-7)

16 toggle buttons for FX chaos state. Same bit layout as voice DAC.

**Controls:**
- Lo-Fi: bits, rate, mix
- Ring Mod: freq, wave, mix
- Comb: freq, decay, mix
- Delay: time, feedback, mix
- MiClouds: position, size, density, texture, mode, reverb, mix

---

### Harmonic DAC (Cols 5-8, Rows 0-3)

16-bit index into HarmonicLUT for chord voicing selection.

**LUT Entry Structure:**
- osc1_degree (weighted toward root)
- osc2_degree, osc3_degree
- Octave offsets for each oscillator
- Voicing spread
- Detune amount

Frequencies are calculated from degree + root + scale + tuning.

---

### Root Select (Cols 5-8, Rows 4-6)

12 buttons for chromatic root selection (mutually exclusive).

```
[C ][C#][D ][D#]   Row 4
[E ][F ][F#][G ]   Row 5
[G#][A ][A#][B ]   Row 6
```

**LED Feedback:**
- Selected root: Full brightness
- Others: Dim

---

### Scale Select (Cols 5-8, Row 7)

4-bit binary selection → 16 scales.

| Index | Scale |
|-------|-------|
| 0 | Major (Ionian) |
| 1 | Natural Minor |
| 2 | Harmonic Minor |
| 3 | Melodic Minor |
| 4 | Dorian |
| 5 | Phrygian |
| 6 | Lydian |
| 7 | Mixolydian |
| 8 | Locrian |
| 9 | Pentatonic Major |
| 10 | Pentatonic Minor |
| 11 | Blues |
| 12 | Whole Tone |
| 13 | Diminished |
| 14 | Augmented |
| 15 | Chromatic |

---

### Voice Slew (Cols 9-12, Rows 0-3)

| Row | Function | Range |
|-----|----------|-------|
| 0 | Time | 4-bit → 10ms-10s (exponential) |
| 1 | Curve | 4-bit → -8 to +8 (linear) |
| 2 | Reserved | - |
| 3 | Reserved | - |

Uses VarLag for smooth parameter transitions with curve shaping.

---

### FX Slew (Cols 9-12, Rows 4-7)

| Row | Function | Range |
|-----|----------|-------|
| 4 | Time | 4-bit → 10ms-10s (exponential) |
| 5 | Curve | 4-bit → -8 to +8 (linear) |
| 6 | Reserved | - |
| 7 | Reserved | - |

Independent slew control for FX parameters.

---

### Gesture Slots (Cols 13-15, Rows 0-7)

24 total gesture/preset slots (3 columns × 8 rows).

**Split by Row:**
- Rows 0-3: Voice gestures (12 slots)
- Rows 4-7: FX gestures (12 slots)

**Interaction Model:**

| State | Action | Result |
|-------|--------|--------|
| Empty | Tap | Start recording |
| Recording | Tap | Stop recording, auto-play |
| Stopped | Tap | Play gesture (loops) |
| Paused | Tap | Resume playback |
| Playing | Double-tap | Pause playback |
| Any | Hold >500ms | Clear gesture |

**LED Feedback:**

| State | Brightness |
|-------|------------|
| Empty | Off (0) |
| Recording | Full (15) |
| Stopped | Medium (8) |
| Paused | Bright (12) |
| Playing | Breathing (8↔15) |

---

## Related Documents

- [Core Concepts](core_concepts.md) - DAC paradigm details
- [Voice Architecture](voice_architecture.md) - 3-oscillator system
- [Implementation](implementation.md) - Development phases
