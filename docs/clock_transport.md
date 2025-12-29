# Clock & Transport

Tap tempo, transport control, and clock distribution.

---

## Tap Tempo

**Button:** `;` (position 0,2)

### Behavior

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

### Visual Feedback

Button blinks on each tap to confirm input.

---

## Transport

**Button:** `:` (position 0,3)

### States

| State | Description |
|-------|-------------|
| **Stopped** | All rows frozen, no step advance |
| **Running** | All rows advance on clock |

### Behavior

```supercollider
~transport = \stopped;

~startTransport = {
    ~transport = \running;
    ~clock.play;
    // Optional: Reset all row positions to step 0
};

~stopTransport = {
    ~transport = \stopped;
    ~clock.stop;
    // Row states remain latched (no reset)
};
```

### Important Note

When transport stops:
- Synth continues droning (no envelope, no gate)
- Row states remain latched at their current values
- Manual editing still works
- Only sequencer step advance is paused

---

## Clock Distribution

```supercollider
~clock = TempoClock.new(120/60); // 120 BPM default

~clock.schedAbs(~clock.beats.ceil, {
    if (~transport == \running) {
        // Advance all 4 rows
        4.do { |rowIndex|
            ~currentStep[rowIndex] = (~currentStep[rowIndex] + 1) % ~loopLengths[rowIndex];
            ~triggerStep.(rowIndex, ~currentStep[rowIndex]);
        };

        // Trigger MiClouds grain generation
        ~synth.set(\t_clock, 1);
    };
    1; // reschedule every beat
});
```

---

## Clock → MiClouds

The sequencer clock automatically triggers MiClouds grain generation:

```supercollider
// In clock callback
~synth.set(\t_clock, 1);

// In SynthDef
sig = MiClouds.ar(sig, trig: t_clock, ...);
```

This means:
- Faster tempo = more grain triggers
- `clouds_dens` parameter controls how many grains per trigger
- Low density + slow clock = sparse, rhythmic bursts
- High density + fast clock = continuous granular texture

---

## Tempo Range

| BPM | Use Case |
|-----|----------|
| 20-60 | Slow, evolving drones |
| 60-120 | Standard tempos |
| 120-240 | Fast rhythmic textures |
| 240+ | Continuous grain stream |

---

## Future Enhancements (v2)

- **MIDI clock sync** - Slave to external clock
- **Clock division** - Per-row clock dividers
- **Swing** - Shuffle timing
- **External clock out** - Send clock to other devices

---

## Related Documents

- [Sequencer](sequencer.md) - How clock drives step advance
- [FX Chain](fx_chain.md) - MiClouds triggering
- [Grid Layout](grid_layout.md) - Button positions
