# State Persistence

Save/load system using JSON files.

---

## Save File Format

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
    }
  ],

  "sequencer": {
    "rows": [
      {
        "steps": [5, null, 3, null, 12, null, null, 5],
        "loop_length": 16
      }
    ]
  },

  "row_states": [23456, 51234, 8192, 61000],

  "slew_config": {
    "rise_time": 8,
    "fall_time": 8,
    "curve": 8,
    "per_param": 0
  }
}
```

---

## What Gets Saved

| Data | Description |
|------|-------------|
| `lut_seed` | Seed for LUT regeneration (critical for reproducibility) |
| `tempo` | Current BPM |
| `current_page` | Which page is active (synth/fx) |
| `gestures` | All 16 gesture slots with steps |
| `sequencer` | 4 rows with step assignments and loop lengths |
| `row_states` | Current DAC state per row |
| `slew_config` | Slew parameters |

### What's NOT Saved

- The LUT itself (regenerated from seed)
- Transport state (always starts stopped)
- Current step positions (always start at 0)

---

## File Location

```supercollider
~saveDir = Platform.userAppSupportDir +/+ "Griddlecake/saves/";
~saveFile = ~saveDir +/+ "slot_" ++ slotNum ++ ".json";

// Example: ~/Library/Application Support/SuperCollider/Griddlecake/saves/slot_0.json
```

---

## Save/Load UI

### Save Mode

1. Hold `s` + `a` → Enter save mode (all gesture slots blink)
2. Tap gesture slot 0-15 → Save to that slot
3. Auto-exit save mode after save

### Load Mode

1. Hold `s` + `a` + `:` → Enter load mode (all gesture slots blink differently)
2. Tap gesture slot 0-15 → Load from that slot
3. Auto-exit load mode after load

---

## LUT Regeneration

The LUT is **not saved** - only the seed is saved. On load, the identical LUT is regenerated:

```supercollider
~loadProject = { |slotNum|
    var data = File.readAllString(~saveDir +/+ "slot_" ++ slotNum ++ ".json").parseJSON;

    // Restore seed
    ~lutSeed = data["lut_seed"];

    // Regenerate identical LUT
    ~lut = Array.fill(65536, { |i|
        thisThread.randSeed = ~lutSeed + i;
        [
            exprand(20, 2000),      // osc1_freq
            rrand(0, 3).round,      // osc1_wave
            // ... same generation code as boot
        ]
    });

    // Restore gestures
    ~gestures = data["gestures"].collect { |g|
        (
            slot: g["slot"],
            steps: g["steps"].collect { |s|
                (time: s["time"], state: s["state"])
            }
        )
    };

    // Restore sequencer
    data["sequencer"]["rows"].do { |row, i|
        ~sequencerSteps[i] = row["steps"];
        ~loopLengths[i] = row["loop_length"];
    };

    // Restore row states
    ~rowStates = data["row_states"];

    // Restore slew
    ~riseTime = data["slew_config"]["rise_time"];
    ~fallTime = data["slew_config"]["fall_time"];
    ~curve = data["slew_config"]["curve"];

    // Restore tempo
    ~clock.tempo = data["tempo"] / 60;
};
```

---

## Save Implementation

```supercollider
~saveProject = { |slotNum|
    var data = (
        version: "1.0.0",
        lut_seed: ~lutSeed,
        tempo: ~clock.tempo * 60,
        current_page: ~currentPage,
        gestures: ~gestures.collect { |g|
            (
                slot: g.slot,
                steps: g.steps.collect { |s|
                    (time: s.time, state: s.state)
                }
            )
        },
        sequencer: (
            rows: 4.collect { |i|
                (
                    steps: ~sequencerSteps[i],
                    loop_length: ~loopLengths[i]
                )
            }
        ),
        row_states: ~rowStates,
        slew_config: (
            rise_time: ~riseTime,
            fall_time: ~fallTime,
            curve: ~curve,
            per_param: 0
        )
    );

    File.use(~saveDir +/+ "slot_" ++ slotNum ++ ".json", "w", { |f|
        f.write(data.asJSON);
    });
};
```

---

## Why Save Seed Instead of LUT?

| Approach | Size | Pros | Cons |
|----------|------|------|------|
| Save LUT | ~10 MB | Instant load | Large files |
| Save seed | ~4 bytes | Tiny files | ~1s regeneration time |

The seed approach is preferred because:
- Save files are tiny (< 1 KB)
- LUT regeneration is fast (~1 second)
- Deterministic - same seed always produces same LUT
- Easy to share/backup

---

## Related Documents

- [Core Concepts](core_concepts.md) - LUT and seeded randomness
- [Grid Layout](grid_layout.md) - Save/load button combinations
- [Implementation](implementation.md) - StateManager class
