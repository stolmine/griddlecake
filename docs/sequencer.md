# Sequencer Behavior

4-row × 16-step polymetric sequencer with gesture triggering and state blending.

---

## Core Principles

1. **No home state** - Parameters latch at current position indefinitely
2. **Per-row independence** - Each of 4 rows maintains separate DAC state
3. **Continuous blending** - Final output = arithmetic mean of all active row states
4. **Slew-controlled transitions** - Smooth (slew>0) or hard cuts (slew=0)
5. **Always sounding** - No gate/trigger for voice (drone architecture)
6. **Clock triggers MiClouds** - Sequencer clock auto-triggers grain generation

---

## Execution Model

### Initialization

```supercollider
~rowStates = [0, 0, 0, 0]; // All rows at state 0
~rowIsActive = [true, true, true, true];
~currentStep = [0, 0, 0, 0];
~loopLengths = [16, 16, 16, 16];
```

### Step Trigger Event

When a sequencer step fires and has a gesture assigned:

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

### Blending Calculation

Every control cycle (~64 Hz):

```supercollider
// Only include active rows
~activeRows = ~rowStates.select { |state, i| ~rowIsActive[i] };
~blendedState = (~activeRows.sum / ~activeRows.size).asInteger;

// Apply slew to blended state
~targetIndex = ~blendedState;
~currentIndex = ~targetIndex.lag(~riseTime, ~fallTime, ~curve);

// Lookup and set synth params
~params = ~lut[~currentIndex.asInteger];
~synth.set(\osc1_freq, ~params[0], \osc2_freq, ~params[1], ...);
```

---

## Blending Example

```
Time t=0:
Row 1: latched at 23456
Row 2: latched at 51234
Row 3: latched at 8192
Row 4: latched at 61000

Blended = (23456 + 51234 + 8192 + 61000) / 4 = 35970
→ ~lut[35970] → synth receives params[35970]
```

---

## Row Behavior

| Aspect | Behavior |
|--------|----------|
| **Independence** | Each row has its own step position, loop length, state |
| **Polymetric** | Different loop lengths = polymetric patterns |
| **Empty steps** | Maintain last state (no gaps in blend) |
| **No gesture** | Row contributes its current latched state |

---

## Live Intervention

### Manual Bit Toggle

```supercollider
// Track "focused row" for manual editing
~focusedRow = 0;

// User toggles bit 7 on param grid
~rowStates[~focusedRow] = ~rowStates[~focusedRow] ^ (1 << 7);

// Manual change persists until next sequencer trigger on that row
```

### Row Actions (Clear/Invert/Shift)

```supercollider
// Same logic - applies to focused row
~rowStates[~focusedRow] = ~applyAction.(~rowStates[~focusedRow], \invertRow, 2);
```

### When Actions Apply

Actions work identically during:
- **Gesture recording** - Captured as resulting states
- **Sequencer playback** - Override row state
- **Manual performance** - Direct state manipulation

---

## Open Questions

### Focused Row Tracking

How does user select which row to edit during playback?

| Option | Description |
|--------|-------------|
| A | Always row 0 (simple) |
| B | Cycle with shift key |
| C | Visual page system (one row per page) |

**Recommendation:** Start with Option A (always row 0).

### Empty Sequencer Steps

Do they silence the row or maintain last state?

**Recommendation:** Maintain last state (no gaps in blend).

### Gesture Overdub

How do new steps integrate with existing recording?

**Recommendation:** Append to end (extend gesture length).

---

## Visual Feedback

| Brightness | Meaning |
|------------|---------|
| 15 (bright) | Current step |
| 8 (medium) | Has gesture assigned |
| 3 (dim) | Empty step |
| 0 (off) | Beyond loop length |

---

## Related Documents

- [Grid Layout](grid_layout.md) - Sequencer grid location
- [Clock & Transport](clock_transport.md) - Clock distribution
- [Core Concepts](core_concepts.md) - Slew and blending
