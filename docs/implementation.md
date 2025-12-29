# Implementation

Build phases, priorities, and getting started guide.

---

## Implementation Phases

### Phase 1: Core Engine

| # | Task | Status |
|---|------|--------|
| 1 | LUT generation with seeded randomness (39 params) | ✅ |
| 2 | Drone synth voice (2 osc + combo modes + filter) | ✅ |
| 3 | Complete FX chain (Lo-Fi → Ring → Comb → Delay → Clouds) | ✅ |
| 4 | Split LUT architecture (Voice 20 + FX 19) | ✅ |
| 5 | Slew with true parameter interpolation | ✅ |
| 6 | True 8-bit audio-rate bitwise ops | ✅ |
| 7 | Weighted LUT frequency distribution | ✅ |

### Phase 2: Grid Integration

| # | Task | Status |
|---|------|--------|
| 8 | GridInterface.sc class (LED buffer, dirty flag, 30fps refresh) | ✅ |
| 9 | oscgrid connection (1-indexed conversion, /grid/key, /grid/led) | ✅ |
| 10 | Button zone detection (nav, param, slew, util, gesture, seq) | ✅ |
| 11 | Param grid → 16-bit DAC → LUT lookup wiring | ✅ |
| 12 | LED feedback (brightness levels, state indication) | ✅ |
| 13 | Page switching (Synth/FX via s/a navigation) | ✅ |
| 14 | Connection test utilities | ✅ |

### Phase 3: Gestures

| # | Task | Status |
|---|------|--------|
| 15 | Gesture recording/playback (state sequences) | ⏳ |
| 16 | Action resolution (clear/invert/shift → states) | ⏳ |
| 17 | 16 gesture slots with visual feedback | ⏳ |

### Phase 4: Sequencer

| # | Task | Status |
|---|------|--------|
| 18 | 4-row × 16-step sequencer | ⏳ |
| 19 | Per-row loop length | ⏳ |
| 20 | Gesture triggering and blending (MEAN) | ⏳ |
| 21 | Clock → MiClouds trigger routing | ⏳ |
| 22 | Live intervention during playback | ⏳ |

### Phase 5: Polish

| # | Task | Status |
|---|------|--------|
| 23 | Tap tempo and transport | ⏳ |
| 24 | Save/load system (JSON) | ⏳ |
| 25 | Visual feedback refinement | ⏳ |
| 26 | Slew parameter mapping (4×4 grid) | ⏳ |

### Phase 6: Advanced Features (v2)

- Hardware Grid support (serialosc)
- MIDI clock sync
- Per-parameter slew offsets
- Gesture morphing/interpolation modes
- Osc2 ratio snapping option
- Additional combo modes

---

## Project Structure

```
griddlecake/
├── docs/
│   ├── documentation_index.md   # This index
│   ├── overview.md
│   ├── core_concepts.md
│   ├── grid_layout.md
│   ├── voice_architecture.md
│   ├── fx_chain.md
│   ├── sequencer.md
│   ├── clock_transport.md
│   ├── state_persistence.md
│   ├── implementation.md
│   └── technical_notes.md
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
└── main.scd                    # Boot file
```

---

## Dependencies

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

---

## Getting Started

### 1. Install Dependencies

See above.

### 2. Initialize LUT

```supercollider
~lut = LUT.new(seed: Date.seed);  // Generate 65536 × 39 param sets
```

### 3. Connect Grid/oscgrid

```supercollider
// oscgrid sends to SC on port 8000 by default
~grid = GridInterface.new(port: 8000);
```

### 4. Boot Drone Synth

```supercollider
~drone = Synth(\chaosDrone);  // Always running
```

### 5. Start Main Loop

```supercollider
ChaosDrone.boot;  // Connects grid, starts sequencer, runs LED refresh
```

---

## Recommended Build Order

1. **SynthDef first** - Get sound working without grid
2. **LUT generation** - Verify random param sets sound interesting
3. **Grid OSC** - Connect oscgrid, verify button presses arrive
4. **Param grid → synth** - Toggle bits, hear changes
5. **Slew** - Add lag to index, verify smooth transitions
6. **Effects** - Add FX chain one effect at a time
7. **Gestures** - Recording/playback
8. **Sequencer** - Step triggering and blending
9. **Save/load** - Persistence

---

## Testing Strategy

### Unit Tests

- LUT generation determinism (same seed = same LUT)
- Bit operations (toggle, clear, invert, shift)
- Gesture recording/playback timing
- JSON serialization/deserialization

### Integration Tests

- Grid button → param change → sound change
- Sequencer step → gesture trigger → state blend
- Save → load → identical state

### Manual Tests

- Slew sounds musical
- MiClouds triggers on clock
- Transport start/stop
- Tap tempo accuracy

---

## Related Documents

- [Technical Notes](technical_notes.md) - SC architecture details
- [Overview](overview.md) - Project summary
- [Documentation Index](documentation_index.md) - All docs
