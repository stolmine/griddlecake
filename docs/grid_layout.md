# Grid Layout & Interaction

Physical layout and interaction model for 128 Grid (16×8).

---

## Physical Layout

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

Legend:
  s/a   = Page select (synth/fx)
  ;/:   = Tap tempo / Transport
  p     = Parameter grid (4×4 DAC bits)
  l     = Slew grid (4×4)
  -/i/> = Row actions (clear/invert/shift)
  g     = Gesture slots (4×4 = 16 slots)
  x     = Sequencer (4 rows × 16 steps)
```

---

## Control Zones

### Navigation (Column 0, Rows 0-3)

| Button | Position | Function |
|--------|----------|----------|
| **s** | (0,0) | Synth parameter page |
| **a** | (0,1) | FX parameter page |
| **;** | (0,2) | Tap tempo |
| **:** | (0,3) | Transport start/stop |

---

### Parameter Grid (Cols 1-4, Rows 0-3)

16 toggle buttons representing bits 15-0 of DAC state.

```
Bit layout:
[15][14][13][12]   Row 0
[11][10][ 9][ 8]   Row 1
[ 7][ 6][ 5][ 4]   Row 2
[ 3][ 2][ 1][ 0]   Row 3
```

**Pages:**
- **Synth page (s):** Controls synth DAC state
- **FX page (a):** Controls FX DAC state

**Brightness:**
- `0` = bit off
- `15` = bit on
- Intermediate values during blending (future feature)

---

### Slew Grid (Cols 5-8, Rows 0-3)

| Row | Function | Values |
|-----|----------|--------|
| 0 | Rise time | 4 bits → 16 time values (10ms-10s) |
| 1 | Fall time | 4 bits → 16 time values (10ms-10s) |
| 2 | Curve shape | 4 bits → 16 values (-8 to +8) |
| 3 | Per-param offset | Deferred to v2 |

---

### Utilities (Cols 9-11, Rows 0-3)

| Button | Position | Function |
|--------|----------|----------|
| **-** | (9, 0-3) | Clear row in active grid |
| **i** | (10, 0-3) | Invert row in active grid |
| **>** | (11, 0-3) | Shift row right in active grid |

Actions apply to whichever grid is active (param or slew).

---

### Gesture Slots (Cols 12-15, Rows 0-3)

16 total gesture/preset slots arranged in a 4×4 grid.

**Interaction Model:**

| State | Action | Result |
|-------|--------|--------|
| Empty slot | First press | Start recording (slot blinks) |
| Recording | Second press | Stop recording, auto-playback |
| Playing | Press | Overdub mode (add to gesture) |
| Playing | Double-tap | Stop playback |
| Any | Hold >500ms | Delete gesture |

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
- Actions recorded as resulting states, not operations
- Enables averaging (gestures are always integer sequences)

---

### Sequencer (Cols 0-15, Rows 4-7)

4 rows × 16 steps for polymetric sequencing.

**Per-Step Behavior:**
| Action | Result |
|--------|--------|
| Press | Select gesture slot to trigger (cycles 0-15) |
| Hold + tap `;` | Set as last step for that row (loop point) |

**Row Behavior:**
- Each row runs independently (polymetric if different loop lengths)
- Step advances on clock tick
- Triggering gesture updates that row's latched state
- No gesture = no contribution to blend (not zero, just absent)

**Visual Feedback:**
| Brightness | Meaning |
|------------|---------|
| 15 (bright) | Current step |
| 8 (medium) | Has gesture assigned |
| 3 (dim) | Empty step |
| 0 (off) | Beyond loop length |

---

## Related Documents

- [Core Concepts](core_concepts.md) - DAC paradigm details
- [Sequencer](sequencer.md) - Sequencer behavior in depth
- [Clock & Transport](clock_transport.md) - Tap tempo, transport
