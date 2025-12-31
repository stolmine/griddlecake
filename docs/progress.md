# Progress

Session notes, decisions, and implementation progress.

See [Implementation](implementation.md) for the high-level roadmap.

---

## Current Status

**Phase:** Phase 5 - Polish (in progress)

**Completed:**
- drone.scd SynthDef (39 LUT params + EQ/comp + VarLag slew with curve)
- Split LUT: Voice (20 params) + FX (19 params)
- main.scd boot file with full state management
- EQ and compressor (SClang control only)
- VarLag.kr for smooth morphing with curve shaping
- True parameter value interpolation (not index traversal)
- True 8-bit audio-rate bitwise ops (AND, OR, XOR, GLITCH)
- Weighted frequency distribution in LUT (bias toward low frequencies)
- Separate voice/FX DAC states with independent LED display
- Slew grid: time (row 0) + curve (row 1) with 4-bit toggles
- Utilities: clear/invert/shift row operations on param grid
- GestureRecorder.sc class (16 slots, state machine, timestamped capture)
- Gesture zone handler with hold/double-tap detection in GridInterface
- Gesture recording wired to param/utility state changes
- Gesture playback with timing restoration
- LED feedback for gesture slots
- Sequencer.sc class (4 rows × 16 steps, per-step gesture slots, blending)
- Clock & Transport (TempoClock, tap tempo, start/stop controls)
- Sequencer grid handler (rows 4-7) with gesture assignment and loop control
- Clock-driven gesture playback with blended voice/FX states
- Preset/Gesture separation with tagged types
- Per-step gesture slot assignment with visual LED feedback
- Parameter blending via arithmetic mean across active sequencer rows
- Engine abstraction layer (spec + implementation)
- Feedback Network engine SynthDef (4 cross-feeding paths)
- Engine registry and hot-swap architecture
- Per-engine LUT generators with caching

**In Progress:**
- Engine select page (hold s+a) - logic works but LED display not updating
- Feedback engine hot-swap - synth node timing issue

**Next Steps:**
1. Fix engine page LED display (grid not visually updating)
2. Fix engine switch synth node timing (node freed before new synth ready)
3. Phase 5: Polish (preset UI refinement, save/load, visual feedback improvements)

---

## Session Log

### 2025-12-30 (Session 7)

**Engine Abstraction Layer:**
- Created `docs/engine_abstraction.md` specification
- Fixed 39-param structure across all engines (20 voice + 19 FX)
- Each engine .scd returns spec dictionary with: key, name, synthDef, voiceParams, fxParams, lutGenerator
- LUT caching per engine+seed to avoid regeneration delay
- Engine hot-swap with crossfade (gate envelope, doneAction:2)

**Feedback Network Engine (`synthdefs/feedback.scd`):**
- 4 cross-feeding filter+delay paths with LocalIn/LocalOut
- Exciter types: noise, dust, impulse, gated sine
- 20 voice params: per-path gain/freq/res/delay + global fb/exciter/cross
- Shared FX chain (same as drone)
- LUT weighting: bias toward low frequencies, moderate resonance

**main.scd Integration:**
- Engine registry: `~engines` Dictionary, `~engineOrder` array
- `~loadEngine.("filename.scd")` loads spec from file
- `~getLuts.(engineKey)` generates/caches LUTs using engine's lutGenerator
- `~switchEngine.(key)` with crossfade and synth replacement
- `~synth` as primary reference, `~drone` as alias for compatibility
- Engine page: `~onEnginePage` flag, `~handleEnginePage` handler
- Entry via hold s+a (simultaneous page button hold detection)

**drone.scd Updates:**
- Added `gate=1` param for crossfade envelope
- Returns engine spec dictionary at end of file
- voiceParams/fxParams specs with idx, name, min, max, curve, default
- lutGenerator function with Cyclebox-style weighting

**Bug Fixes:**
- SC syntax: var declarations must precede statements in functions
- Replaced Float32Array with regular arrays (not standard SC class)
- Moved ~enterEnginePage/~exitEnginePage inside ~connectGrid (needed ~grid access)
- Removed direct dirty flag access (read-only in GridInterface)
- Added 300ms debounce after engine page entry
- Removed output_level from voiceParamNames (was getting set to 0 from reserved slot)

**Known Issues:**
- Engine select page: logic works but grid LEDs not visually updating
- Engine switch: "Node 1000 not found" - old synth freed before new one ready, ~applyVoiceState called on freed node

---

### 2025-12-29 (Session 6)

**Sequencer Implementation (Phase 4 Complete):**
- Created `Sequencer.sc` class (140 lines)
  - 4 rows × 16 steps with per-row loop lengths
  - Per-step gesture/preset slot assignment
  - Parameter blending: arithmetic mean of actual param values across active rows
  - Stores full param arrays per row (not LUT indices)
- Clock & Transport
  - TempoClock at 120 BPM default
  - Tap tempo with 3s timeout, 20-300 BPM range
  - Transport start/stop (col 0, row 3)
  - Hold transport = stop + reset to step 0
- Sequencer grid handler (rows 4-7)
  - Hold step + tap gesture = assign gesture/preset
  - Hold step + tap tempo = set loop length
  - Double-tap step = clear assignment
  - LED: bright=current, medium=has gesture, dim=empty, off=beyond loop

**Preset/Gesture Separation:**
- Tagged types in GestureRecorder: `(type: \preset)` vs `(type: \gesture, steps: [...])`
- Hold page button (synth/FX) + tap slot = save current state as preset
- Presets apply instantly (no loop), gestures play timed sequence
- Presets flash on trigger (manual or sequencer)

**Bug Fixes:**
- Zone detection: sequencer (y>=4) now checked before navigation (x==0), fixing step 0
- Tap tempo: reduced double-tap threshold to 0.25s, record on press not release
- Gesture clearing no longer crashes sequencer (deep copy steps at trigger time)
- Clock routine always applies blended params each tick

**Known Issues:**
- Preset mutual exclusion (manual tap) not fully working - cosmetic only

---

### 2025-12-29 (Session 5)

**Sequencer Implementation:**
- Created `Sequencer.sc` class (140 lines)
  - 4 rows × 16 steps with per-row loop lengths (1-16)
  - Per-step gesture slot assignment (0-15 or nil)
  - State tracking: rowStates, currentStep, loopLengths, stepGestures, rowIsActive
  - Blending: arithmetic mean of active row states (voice + FX calculated separately)

**Clock & Transport:**
- TempoClock at 120 BPM default
- Tap tempo (col 0, row 2): averages last 4 taps, 20-300 BPM range
- Transport start/stop (col 0, row 3): toggles sequencer running state
- Clock triggers MiClouds (`t_clock`) on each beat

**Sequencer Grid Handler (rows 4-7):**
- Tap step: cycles gesture assignment (nil→0→1→...→15→nil)
- Hold step: sets loop length for that row (1-16, bright LED extends from current step)
- LED feedback: bright=current step, medium=has gesture assignment, dim=empty step, off=beyond loop length
- Press/release gesture playback coordinated with step timing

**Integration:**
- Clock routine advances all rows, triggers queued gestures, calculates blended voice/FX states
- Blend applied directly to synth voice/FX DAC states each beat
- Proper cleanup on disconnect (stopClock, free gestures, clear timers)
- Sequencer and transport controls update main LED feedback in real-time

---

### 2025-12-29 (Session 4)

**Gesture Slots Implementation:**
- Created `GestureRecorder.sc` class (148 lines)
  - 16 slots with state machine: \empty, \recording, \stopped, \playing
  - Timestamped step capture with voiceState + fxState
  - Playback via Routine with delta timing
- Updated `GridInterface.sc` with hold/double-tap detection
  - Hold >500ms: triggers onHold callback
  - Double-tap <300ms: triggers onDoubleTap callback
  - Uses AppClock.sched and Main.elapsedTime
- Integrated gestures into `main.scd`
  - State machine: empty→record, record→stop+play, stopped→play
  - Hold gesture slot = clear gesture
  - Double-tap during playback = stop
  - Recording captures param grid + utility actions
  - LED feedback: off=empty, full=recording, medium=stopped, bright=paused, breathing=playing

**Gesture Playback Enhancements:**
- Gestures now loop continuously until paused or cleared
- Added `\paused` state - double-tap pauses, single-tap resumes
- LED breathing effect for playing gestures (sine wave, ~2s cycle)
- Fixed double-tap detection (check on press, not release)
- Fixed SC `&&` short-circuit issue in handleKeyEvent

**Layout Update:**
Gesture slots fully functional in cols 12-15, rows 0-3.

---

### 2025-12-29 (Session 3)

**Slew Grid Implementation:**
- Updated SynthDef: `Lag.kr` → `VarLag.kr(in, time, curve)`
- Added `slew_curve` parameter (-8 to +8)
- Slew grid moved to cols 8-11
- Row 0: time (4-bit, 10ms-10s exponential)
- Row 1: curve (4-bit, -8 to +8 linear)
- Rows 2-3: dim (deferred)

**Utilities Implementation:**
- Utilities placed between param grid and slew (cols 5-7)
- Col 5: Clear row (zeros 4 bits)
- Col 6: Invert row (XOR with 0xF)
- Col 7: Shift right (rotate within 4 bits)
- Flash medium brightness on touch

**Bug Fixes:**
- Fixed separate voice/FX DAC state tracking
- Fixed duplicate OSC handler issue (auto-disconnect on reconnect)
- Fixed zone detection bounds in GridInterface

**Layout Update:**
```
Col: 0  1-4  5-7    8-11   12-15
     N  [P]  [-i>]  [L]    [G]

N=Nav, P=Param, -i>=Utils, L=Slew, G=Gestures
```

---

### 2025-12-28 (Session 2)

**Grid Communication Research & Planning:**
- Explored local oscgrid repo (`~/repos/oscgrid`)
- Researched serialosc protocol (Monome official docs)
- Created `grid_communication.md` spec document

**Key Findings - oscgrid:**
- Uses `/grid/key x y` + `/grid/led x y` messages (no prefix)
- **1-indexed** coordinates (1-16, 1-8) - must convert to 0-indexed internally
- Default config: IP 10.0.1.11, port 9000 (edit `lib/oscgrid.lua` lines 6-7)
- TouchOSC template in `.touchosc` format (zip with XML)

**Key Findings - serialosc:**
- Port 12002 for device discovery
- Uses `/prefix/grid/key x y state` format (0-indexed)
- Supports batch LED updates: `/grid/led/level/row`, `/grid/led/level/map`
- Varibright: 16 brightness levels (0-15)

**Critical Timing Consideration:**
- **Never** update LEDs on every key event - causes Grid blackout!
- Solution: Timer-driven refresh at ~30fps with dirty flag pattern
- Store LED state in buffer, only send when dirty flag set

**GridInterface.sc Design:**
- LED buffer (16x8 array of brightness values)
- Dirty flag for efficient refresh
- 30fps timer-driven `sendLEDs` routine
- Coordinate conversion (oscgrid 1-indexed → internal 0-indexed)
- Button zone detection (nav, param, slew, util, gesture, seq)

**Updated Implementation Roadmap:**
- Phase 1 now complete (7/7 tasks)
- Phase 2 "Grid Integration" defined (7 tasks: #8-14)
- Renumbered all subsequent phases

**Implemented Grid Integration:**
- `classes/GridInterface.sc` - Full implementation (129 lines)
  - LED buffer with dirty flag pattern
  - 30fps timer-driven refresh
  - oscgrid (1-indexed) and serialosc (0-indexed) support
  - Zone detection helper
  - Brightness level constants
- `tests/test_grid.scd` - Connection test utilities
  - Quick connection, echo, zone, sweep, latency tests
  - Hardware Grid discovery helper
- `main.scd` updated with grid integration
  - `~connectGrid.()` / `~disconnectGrid.()`
  - Param grid → 16-bit DAC → LUT lookup
  - Page switching (Synth/FX)
  - LED feedback for param state
- Created symlink: `~/Library/.../Extensions/griddlecake` → `classes/`
- **Requires:** SuperCollider recompile to load GridInterface class

**Debugging Session - OSC Path Format Discovery:**
- oscgrid TouchOSC template embeds x,y coordinates IN the path: `/grid/key 9 4`
- This is NOT `/grid/key` with args `[9, 4, state]`
- Standard `OSCdef` cannot match paths with embedded spaces
- Solution: Use `thisProcess.addOSCRecvFunc` for low-level OSC handling
- LED output uses same format: `/grid/led 9 4` with brightness as arg
- iPad IP discovered: `192.168.1.244` (was hardcoded as `10.0.1.11`)
- oscgrid repo (`~/repos/oscgrid`) is norns-specific, but TouchOSC template works directly with SC

---

### 2025-12-28 (Session 1)

**Implemented Phase 1 Core:**
- `synthdefs/drone.scd` - Complete drone voice
  - 2 oscillators (sin/tri/saw/square) with noise modulation
  - 9 combo modes (OSC1, OSC2, RING, MIN, MAX, AND, OR, XOR, GLITCH)
  - True 8-bit audio-rate bitwise ops for modes 5-8
  - SVF multimode filter (lowpass default)
  - FX chain: Lo-Fi → Ring Mod → Comb → Delay → MiClouds → EQ → Comp → Limiter
  - Per-param `Lag.kr(param, slew_time)` for smooth morphing
- `main.scd` - Boot file
  - Split LUT: `~voiceLut` (20 params) + `~fxLut` (19 params)
  - State 0 = home base (55Hz sine, 100% dry FX)
  - Fresh seed on each reload (use `~useSeed` to override)
  - True parameter interpolation in slew routines

**State Management Functions:**
- `~applyVoiceState.(idx)` / `~applyFxState.(idx)` - immediate
- `~setVoiceState.(idx, time)` / `~setFxState.(idx, time)` - interpolated slew
- `~applyFullState.(voice, fx)` - apply both
- `~testVoice.()` / `~testFx.()` - cycle through test states
- `~randomize.()` - randomize both
- `~showSeed.()` - display LUT seed
- `~setSlew.(time)` - set synth-level param slew time

**EQ & Compressor (SClang only):**
- `~eq.(low, mid, high)` - set gains in dB
- `~eqFreqs.(low, mid, high)` - set frequencies
- `~eqMidQ.(q)` - set mid band Q
- `~eqBypass.()` - flatten EQ
- `~comp.(thresh, ratio, attack, release, makeup)` - full control
- `~compBypass.()` - disable compression

**Bug Fixes:**
- Fixed SuperCollider bitwise ops syntax (`bitAnd:`, `bitOr:`, `bitXor:`)
- Fixed SVF filter API (positional args, not keywords)
- Fixed var declaration order (must precede statements)
- Fixed LUT seed persistence (now fresh each reload)
- Fixed slew to interpolate param values, not traverse random indices

**True Bitwise Ops (inlined in SynthDef):**
- 8-bit audio-rate AND, OR, XOR operations
- Converts audio → 8-bit unsigned int → bitwise op → audio
- Uses `.collect` at compile time to build UGen graph
- `BitOps.sc` class also available for standalone use

**Weighted LUT Frequency Distribution:**
- `rand.pow(n).linexp(...)` biases toward low frequencies
- osc1/2_freq: pow(1.8) → ~55% in bottom third
- filter_freq: pow(1.5) → gentle low bias
- ring/comb_freq: pow(1.8) → moderate low bias
- Creates more musical, bass-heavy random states

---

## Design Decisions

| Date | Decision | Rationale |
|------|----------|-----------|
| 2025-12-28 | Volume bypasses LUT | User needs consistent volume control |
| 2025-12-28 | Split Voice/FX LUT | Independent control, matches grid page layout |
| 2025-12-28 | Per-param Lag.kr | Smooth morphing between states |
| 2025-12-28 | Value interpolation | Slew should morph params, not traverse random states |
| 2025-12-28 | State 0 = home base | Predictable reference: 55Hz sine, dry FX |
| 2025-12-28 | EQ/Comp outside LUT | Master bus control, not part of chaotic exploration |
| 2025-12-28 | Inlined bitwise ops | Avoids class dependency, self-contained SynthDef |
| 2025-12-28 | Weighted freq distribution | More musical random states, favors bass |
| 2025-12-29 | Record states not operations | Enables arithmetic averaging for blending |
| 2025-12-29 | Auto-play after recording | Immediate feedback, natural workflow |
| 2025-12-29 | Hold to clear, double-tap to stop | Discoverable gestures without mode keys |
| 2025-12-29 | Gestures loop continuously | More useful for performance, pause to stop |
| 2025-12-29 | Breathing LEDs for playing | Clear visual distinction between states |

---

## Known Issues

- Preset mutual exclusion (manual tap) not fully working - cosmetic only (preset flash timing may overlap)

---

## Notes

- SVF filter currently locked to lowpass (type switching needs work)
- MiClouds requires mi-UGens extension
- BitOps class in `classes/` requires symlink to Extensions + recompile to use standalone
