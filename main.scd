// Griddlecake - Main Boot File
// Phase 1: Core Engine - LUT, Drone Synth, State Management
//
// Usage: "/path/to/main.scd".load;

(
// ========================================
// BOOT SERVER
// ========================================

"[Griddlecake] Booting server...".postln;

s.waitForBoot({

	// ========================================
	// LOAD ENGINES
	// ========================================

	"[Griddlecake] Loading engines...".postln;

	// Engine registry
	~engines = Dictionary.new;
	~engineOrder = [];  // Ordered list of engine keys for grid display

	// Load engine files - each returns a spec dictionary
	~loadEngine = { |filename|
		var path = thisProcess.nowExecutingPath.dirname +/+ "synthdefs" +/+ filename;
		var spec = path.load;
		if (spec.notNil && spec[\key].notNil) {
			~engines[spec[\key]] = spec;
			~engineOrder = ~engineOrder.add(spec[\key]);
			"[Griddlecake]   Loaded engine: % (%)".format(spec[\name], spec[\key]).postln;
		} {
			"[Griddlecake]   WARNING: Failed to load engine from %".format(filename).warn;
		};
	};

	// Load all engines
	~loadEngine.("drone.scd");
	~loadEngine.("feedback.scd");
	s.sync;

	// Set initial engine
	~currentEngine = \drone;
	"[Griddlecake] Active engine: %".format(~engines[~currentEngine][\name]).postln;

	// ========================================
	// INITIALIZE LUT
	// ========================================

	// Use Date.seed unless ~useSeed is explicitly set before loading
	// To reuse a seed: ~useSeed = 12345; then load main.scd
	if (~useSeed.notNil) {
		~lutSeed = ~useSeed;
		~useSeed = nil;  // Clear so next load gets fresh seed
		"[Griddlecake] Using provided seed: %".format(~lutSeed).postln;
	} {
		~lutSeed = Date.seed;
		"[Griddlecake] Generated new seed: %".format(~lutSeed).postln;
	};

	// LUT cache (per engine + seed)
	~lutCache = Dictionary.new;

	// Get or generate LUTs for an engine
	~getLuts = { |engineKey|
		var cacheKey = (engineKey ++ "_" ++ ~lutSeed).asSymbol;
		var engine = ~engines[engineKey];

		if (~lutCache[cacheKey].isNil) {
			"[Griddlecake] Generating LUTs for % (seed %)...".format(engineKey, ~lutSeed).postln;
			~lutCache[cacheKey] = engine[\lutGenerator].(~lutSeed);
			"[Griddlecake] LUT generation complete".postln;
		};

		~lutCache[cacheKey]
	};

	// Clear LUT cache (call when seed changes)
	~clearLutCache = {
		~lutCache.clear;
		"[Griddlecake] LUT cache cleared".postln;
	};

	// Generate initial LUTs for current engine
	~luts = ~getLuts.(~currentEngine);
	~voiceLut = ~luts[\voice];
	~fxLut = ~luts[\fx];

	"[Griddlecake] Voice LUT: % entries".format(~voiceLut.size).postln;
	"[Griddlecake] FX LUT: % entries".format(~fxLut.size).postln;

	// ========================================
	// PARAMETER NAMES
	// ========================================

	~voiceParamNames = [
		// Oscillators
		\osc1_freq, \osc1_wave, \osc1_pw,
		\osc2_freq, \osc2_wave, \osc2_pw, \osc2_track, \osc2_ratio,
		\fm_amount, \combo_mode, \combo_mix,

		// Noise
		\noise_type, \noise_level, \noise_to_osc1, \noise_to_osc2,

		// Filter
		\filter_freq, \filter_res, \filter_type, \filter_track,

		// Output
		\output_level
	];

	~fxParamNames = [
		// Lo-Fi
		\lofi_bits, \lofi_rate, \lofi_mix,

		// Ring Mod
		\ring_freq, \ring_wave, \ring_mix,

		// Comb
		\comb_freq, \comb_decay, \comb_mix,

		// Delay
		\delay_time, \delay_fb, \delay_mix,

		// MiClouds
		\clouds_pos, \clouds_size, \clouds_dens, \clouds_tex,
		\clouds_mode, \clouds_rvb, \clouds_mix
	];

	// ========================================
	// CREATE SYNTH
	// ========================================

	"[Griddlecake] Creating synth (%)...".format(~currentEngine).postln;
	~synth = Synth(~engines[~currentEngine][\synthDef]);
	s.sync;

	// Alias for backwards compatibility
	~drone = ~synth;

	// ========================================
	// ENGINE SWITCHING
	// ========================================

	// Engine page state
	~onEnginePage = false;
	~pageButtonStates = (s: false, a: false);  // Track page button holds

	// Switch to a different engine
	~switchEngine = { |newEngineKey|
		var engine = ~engines[newEngineKey];

		if (engine.isNil) {
			"[Griddlecake] Unknown engine: %".format(newEngineKey).warn;
		} {
			if (engine[\implemented].not) {
				"[Griddlecake] Engine not implemented: %".format(newEngineKey).warn;
			} {
				var oldSynth = ~synth;
				var luts;

				"[Griddlecake] Switching to engine: %".format(engine[\name]).postln;

				// Get or generate LUTs for new engine
				luts = ~getLuts.(newEngineKey);
				~voiceLut = luts[\voice];
				~fxLut = luts[\fx];

				// Fade out old synth
				oldSynth.set(\gate, 0);

				// Boot new synth after fade
				AppClock.sched(0.12, {
					~synth = Synth(engine[\synthDef], [
						\output_level, 0.5,
						\slew_time, ~getSlewTime.(),
						\slew_curve, ~getSlewCurve.(),
						\gate, 1
					]);
					~drone = ~synth;  // Update alias
					~currentEngine = newEngineKey;

					// Apply current DAC state to new engine
					~applyVoiceState.(~voiceDacState);
					~applyFxState.(~fxDacState);

					"[Griddlecake] Engine switch complete: %".format(engine[\name]).postln;
					nil
				});
			};
		};
	};

	// Note: ~enterEnginePage and ~exitEnginePage are defined inside ~connectGrid
	// because they depend on ~grid and LED update functions

	// ========================================
	// GESTURE RECORDER
	// ========================================

	~gestures = GestureRecorder.new;

	// ========================================
	// SEQUENCER & CLOCK
	// ========================================

	~sequencer = Sequencer.new;
	~transport = \stopped;
	~bpm = 120;
	~clock = TempoClock(~bpm / 60);
	~tapTimes = [];

	// Tap tempo calculation
	~tapTimeout = 3.0;  // Reset if gap > 3s (allows ~20 BPM minimum)
	~tapTempo = {
		var now = Main.elapsedTime;
		var interval, intervals, avgInterval;

		// Reset if too long since last tap
		if (~tapTimes.size > 0) {
			interval = now - ~tapTimes.last;
			if (interval > ~tapTimeout) {
				~tapTimes = [];
				"[Clock] Tap tempo reset (timeout)".postln;
			};
		};

		~tapTimes = ~tapTimes.add(now);

		// Keep only last 4 taps
		if (~tapTimes.size > 4) { ~tapTimes = ~tapTimes.keep(-4) };

		if (~tapTimes.size >= 2) {
			// Calculate intervals between consecutive taps
			intervals = [];
			(~tapTimes.size - 1).do { |i|
				intervals = intervals.add(~tapTimes[i + 1] - ~tapTimes[i]);
			};

			avgInterval = intervals.sum / intervals.size;
			~bpm = (60 / avgInterval).clip(20, 300);
			~clock.tempo = ~bpm / 60;
			"[Clock] Tap tempo: % BPM (interval: %s)".format(
				~bpm.round(0.1),
				avgInterval.round(0.001)
			).postln;
		} {
			"[Clock] Tap % - need 1 more".format(~tapTimes.size).postln;
		};
	};

	// Start transport
	~startTransport = {
		if (~transport == \stopped) {
			~transport = \running;
			~clockRoutine = Routine({
				loop {
					if (~transport == \running) {
						// Process all sequencer rows
						4.do { |row|
							var step = ~sequencer.getStepForRow(row);
							var gestureSlot = ~sequencer.getGesture(row, step);

							// If step has gesture, trigger it (updates row params)
							if (gestureSlot.notNil) {
								~triggerGestureOnRow.(row, gestureSlot);
							};

							~sequencer.advanceStep(row);
						};

						// Always apply blended params (even if no gesture triggered)
						~applyBlendedParams.();

						// Trigger MiClouds on clock
						~drone.set(\t_clock, 1);

						// Update LEDs
						~updateGridLEDs.();
					};
					~clock.beatDur.wait;
				};
			}).play;
			"[Clock] Transport started".postln;
		};
	};

	// Stop transport
	~stopTransport = {
		if (~transport == \running) {
			~transport = \stopped;
			if (~clockRoutine.notNil) {
				~clockRoutine.stop;
				~clockRoutine = nil;
			};
			// Stop all row playback routines
			4.do { |row|
				if (~rowPlaybackRoutines[row].notNil) {
					~rowPlaybackRoutines[row].stop;
					~rowPlaybackRoutines[row] = nil;
				};
			};
			"[Clock] Transport stopped".postln;
		};
	};

	// Toggle transport
	~toggleTransport = {
		if (~transport == \stopped) {
			~startTransport.();
		} {
			~stopTransport.();
		};
	};

	// Apply blended params from sequencer (actual param values, not indices)
	~applyBlendedParams = {
		var blend = ~sequencer.calculateBlendedParams;
		var voiceParams = blend[0];
		var fxParams = blend[1];

		// Apply voice params directly
		~voiceParamNames.do { |name, i|
			~drone.set(name, voiceParams[i]);
		};

		// Apply FX params directly
		~fxParamNames.do { |name, i|
			~drone.set(name, fxParams[i]);
		};
	};

	// Per-row gesture playback routines (for interrupt behavior)
	~rowPlaybackRoutines = Array.newClear(4);

	// Trigger gesture/preset on a row (interrupts any existing playback)
	~triggerGestureOnRow = { |row, gestureSlot|
		var gesture, stepsCopy, preset, voiceParams, fxParams;

		// Stop existing playback on this row
		if (~rowPlaybackRoutines[row].notNil) {
			~rowPlaybackRoutines[row].stop;
			~rowPlaybackRoutines[row] = nil;
		};

		if (~gestures.hasGesture(gestureSlot)) {
			if (~gestures.isPreset(gestureSlot)) {
				// Handle preset: apply immediately, no routine needed
				preset = ~gestures.getPreset(gestureSlot);
				if (preset.notNil) {
					voiceParams = ~voiceLut[preset[0].clip(0, 65535)];
					fxParams = ~fxLut[preset[1].clip(0, 65535)];
					~sequencer.setRowParams(row, voiceParams, fxParams);
					~applyBlendedParams.();
					// Update DAC state for LED display
					~voiceDacState = preset[0];
					~fxDacState = preset[1];
					// Flash preset slot
					~flashGestureSlot.(gestureSlot);
				};
			} {
				// Handle gesture: play full sequence
				gesture = ~gestures.gestures[gestureSlot];
				if (gesture.notNil && gesture[\steps].notNil && (gesture[\steps].size > 0)) {
					// Deep copy steps at trigger time (immune to later clearing)
					stepsCopy = gesture[\steps].collect { |step|
						(time: step[\time], voiceState: step[\voiceState], fxState: step[\fxState])
					};

					// Start playback routine for this row
					~rowPlaybackRoutines[row] = Routine({
						var prevTime = 0;

						stepsCopy.do { |step|
							var waitTime = (step[\time] - prevTime) / 1000.0;
							var vParams = ~voiceLut[step[\voiceState].clip(0, 65535)];
							var fParams = ~fxLut[step[\fxState].clip(0, 65535)];

							if (waitTime > 0) { waitTime.wait };

							// Update row's params
							~sequencer.setRowParams(row, vParams, fParams);

							// Recalculate and apply blend
							~applyBlendedParams.();

							prevTime = step[\time];
						};

						// Gesture complete - row latches at final state
						~rowPlaybackRoutines[row] = nil;
					}).play;
				};
			};
		};
	};

	// ========================================
	// INITIALIZE STATE
	// ========================================

	~voiceIndex = 0;
	~fxIndex = 0;
	~recordingSlot = nil;

	// Initialize all sequencer rows with LUT[0] default params
	4.do { |row|
		~sequencer.setRowParams(row, ~voiceLut[0], ~fxLut[0]);
	};

	// ========================================
	// HELPER FUNCTIONS
	// ========================================

	// Apply voice state immediately (no slew)
	~applyVoiceState = { |index|
		var params = ~voiceLut[index.asInteger.clip(0, 65535)];
		~voiceParamNames.do({ |name, i|
			~drone.set(name, params[i]);
		});
		~voiceIndex = index.asInteger;
	};

	// Apply FX state immediately (no slew)
	~applyFxState = { |index|
		var params = ~fxLut[index.asInteger.clip(0, 65535)];
		~fxParamNames.do({ |name, i|
			~drone.set(name, params[i]);
		});
		~fxIndex = index.asInteger;
	};

	// Apply full state immediately (no slew)
	~applyFullState = { |voiceIdx, fxIdx|
		~applyVoiceState.(voiceIdx);
		~applyFxState.(fxIdx);
		"[Griddlecake] Applied state: voice % / fx %".format(~voiceIndex, ~fxIndex).postln;
	};

	// Set voice state with slew (interpolates parameter VALUES, not indices)
	~setVoiceState = { |targetIndex, slewTime = 1.0|
		var startParams = ~voiceLut[~voiceIndex.clip(0, 65535)];
		var endIndex = targetIndex.asInteger.clip(0, 65535);
		var endParams = ~voiceLut[endIndex];
		var startTime = Main.elapsedTime;
		var duration = slewTime;

		// Stop any existing voice slew routine
		if (~voiceSlewRoutine.notNil) {
			~voiceSlewRoutine.stop;
		};

		// Create new slew routine
		~voiceSlewRoutine = Routine({
			var elapsed, progress, interpParams;

			loop {
				elapsed = Main.elapsedTime - startTime;
				progress = (elapsed / duration).clip(0, 1);

				// Interpolate each parameter value
				interpParams = startParams.collect({ |startVal, i|
					startVal + ((endParams[i] - startVal) * progress);
				});

				// Apply interpolated params directly
				~voiceParamNames.do({ |name, i|
					~drone.set(name, interpParams[i]);
				});

				if (progress >= 1.0) {
					~voiceIndex = endIndex;
					"[Griddlecake] Voice slew complete: index %".format(endIndex).postln;
					~voiceSlewRoutine = nil;
					nil.yield;
				};

				(1/60).wait;
			};
		}).play(AppClock);
	};

	// Set FX state with slew (interpolates parameter VALUES, not indices)
	~setFxState = { |targetIndex, slewTime = 1.0|
		var startParams = ~fxLut[~fxIndex.clip(0, 65535)];
		var endIndex = targetIndex.asInteger.clip(0, 65535);
		var endParams = ~fxLut[endIndex];
		var startTime = Main.elapsedTime;
		var duration = slewTime;

		// Stop any existing FX slew routine
		if (~fxSlewRoutine.notNil) {
			~fxSlewRoutine.stop;
		};

		// Create new slew routine
		~fxSlewRoutine = Routine({
			var elapsed, progress, interpParams;

			loop {
				elapsed = Main.elapsedTime - startTime;
				progress = (elapsed / duration).clip(0, 1);

				// Interpolate each parameter value
				interpParams = startParams.collect({ |startVal, i|
					startVal + ((endParams[i] - startVal) * progress);
				});

				// Apply interpolated params directly
				~fxParamNames.do({ |name, i|
					~drone.set(name, interpParams[i]);
				});

				if (progress >= 1.0) {
					~fxIndex = endIndex;
					"[Griddlecake] FX slew complete: index %".format(endIndex).postln;
					~fxSlewRoutine = nil;
					nil.yield;
				};

				(1/60).wait;
			};
		}).play(AppClock);
	};

	// ========================================
	// TEST HELPERS
	// ========================================

	// Test voice states
	~testVoice = {
		var testIndices = [0, 10000, 30000, 50000, 65535];
		"[Griddlecake] Testing voice states...".postln;
		fork {
			testIndices.do({ |idx|
				~applyVoiceState.(idx);
				"[Griddlecake] Voice test: %".format(idx).postln;
				2.wait;
			});
			"[Griddlecake] Voice test complete".postln;
		};
	};

	// Test FX states
	~testFx = {
		var testIndices = [0, 10000, 30000, 50000, 65535];
		"[Griddlecake] Testing FX states...".postln;
		fork {
			testIndices.do({ |idx|
				~applyFxState.(idx);
				"[Griddlecake] FX test: %".format(idx).postln;
				2.wait;
			});
			"[Griddlecake] FX test complete".postln;
		};
	};

	// Randomize both voice and FX
	~randomize = {
		var voiceIdx = 65535.rand;
		var fxIdx = 65535.rand;
		~applyFullState.(voiceIdx, fxIdx);
		"[Griddlecake] Randomized: voice % / fx %".format(voiceIdx, fxIdx).postln;
	};

	// Show current seed and state
	~showSeed = {
		"[Griddlecake] ========================================".postln;
		"[Griddlecake] LUT Seed: %".format(~lutSeed).postln;
		"[Griddlecake] Voice Index: %".format(~voiceIndex).postln;
		"[Griddlecake] FX Index: %".format(~fxIndex).postln;
		"[Griddlecake] ========================================".postln;
		~lutSeed;  // Return seed value
	};

	// Set slew time (also updates grid state to nearest match)
	~setSlew = { |time, curve|
		var timeBits = time.explin(0.01, 10.0, 0, 15).round.asInteger.clip(0, 15);
		~slewTimeBits = timeBits;
		if (curve.notNil) {
			var curveBits = curve.linlin(-8, 8, 0, 15).round.asInteger.clip(0, 15);
			~slewCurveBits = curveBits;
		};
		~applySlew.();
	};

	// Set slew curve only
	~setCurve = { |curve|
		var curveBits = curve.linlin(-8, 8, 0, 15).round.asInteger.clip(0, 15);
		~slewCurveBits = curveBits;
		~applySlew.();
	};

	// Track flashing slots (so updateGridLEDs doesn't overwrite)
	~flashingSlots = Set.new;

	// Track active preset for mutual exclusion (manual taps only)
	~activePreset = nil;

	// Flash a gesture slot LED (for preset feedback)
	~flashGestureSlot = { |slot|
		var col = slot % 4;
		var row = (slot / 4).floor.asInteger;
		if (~grid.notNil) {
			~flashingSlots.add(slot);
			~grid.led(col + 12, row, GridInterface.ledFull);
			AppClock.sched(0.15, {
				~flashingSlots.remove(slot);
				~updateGridLEDs.();
				nil;
			});
		};
	};

	// Play gesture or apply preset (manual tap version)
	~playGesture = { |slot|
		if (~gestures.isPreset(slot)) {
			// Preset: apply instantly, no loop
			var preset = ~gestures.getPreset(slot);
			if (preset.notNil) {
				~voiceDacState = preset[0];
				~fxDacState = preset[1];
				~applyVoiceState.(~voiceDacState);
				~applyFxState.(~fxDacState);
				~activePreset = slot;  // Mutual exclusion: only this preset active
				~updateGridLEDs.();  // Update LEDs to dim other presets
				~flashGestureSlot.(slot);  // Flash feedback (overrides for this slot)
				"[Grid] Applied preset % (activePreset now %)".format(slot, ~activePreset).postln;
			};
		} {
			// Gesture: play with looping (clears active preset)
			~activePreset = nil;
			~updateGridLEDs.();
			~gestures.play(slot, { |voiceState, fxState|
				~voiceDacState = voiceState;
				~fxDacState = fxState;
				~applyVoiceState.(voiceState);
				~applyFxState.(fxState);
				~updateGridLEDs.();
			});
		};
	};

	// ========================================
	// EQ & COMPRESSOR (SClang control only)
	// ========================================

	// EQ controls
	~eq = { |low=0, mid=0, high=0|
		~drone.set(\eq_low_gain, low, \eq_mid_gain, mid, \eq_high_gain, high);
		"[Griddlecake] EQ: low %dB, mid %dB, high %dB".format(low, mid, high).postln;
	};

	~eqFreqs = { |low=200, mid=1000, high=4000|
		~drone.set(\eq_low_freq, low, \eq_mid_freq, mid, \eq_high_freq, high);
		"[Griddlecake] EQ freqs: low %Hz, mid %Hz, high %Hz".format(low, mid, high).postln;
	};

	~eqMidQ = { |q=0.5|
		~drone.set(\eq_mid_q, q);
		"[Griddlecake] EQ mid Q: %".format(q).postln;
	};

	// Compressor controls
	~comp = { |thresh=0.5, ratio=2, attack=0.01, release=0.1, makeup=1|
		~drone.set(
			\comp_thresh, thresh,
			\comp_ratio, ratio,
			\comp_attack, attack,
			\comp_release, release,
			\comp_makeup, makeup
		);
		"[Griddlecake] Comp: thresh %, ratio %:1, atk %s, rel %s, makeup %".format(
			thresh, ratio, attack, release, makeup
		).postln;
	};

	// Bypass EQ (set all gains to 0)
	~eqBypass = {
		~drone.set(\eq_low_gain, 0, \eq_mid_gain, 0, \eq_high_gain, 0);
		"[Griddlecake] EQ bypassed".postln;
	};

	// Bypass compressor (ratio 1:1)
	~compBypass = {
		~drone.set(\comp_ratio, 1, \comp_makeup, 1);
		"[Griddlecake] Compressor bypassed".postln;
	};

	// ========================================
	// GRID INTEGRATION
	// ========================================

	// Grid config - UPDATE THESE for your setup
	~gridIP = "192.168.1.244";  // iPad IP for oscgrid
	~gridPort = 9000;           // TouchOSC receive port

	// Current page (0 = synth/voice, 1 = FX)
	~currentPage = 0;

	// Separate 16-bit DAC states for each page
	~voiceDacState = 0;
	~fxDacState = 0;

	// Modifier state: track pressed sequencer step for hold+tap gestures
	~pressedSeqStep = nil;  // [row, step] or nil

	// Modifier state: track pressed page button for preset saving
	~pressedPageButton = nil;  // 0 = synth, 1 = FX, nil = none

	// Slew grid state (4-bit each, 0-15)
	~slewTimeBits = 0;    // Row 0: time (10ms-10s)
	~slewCurveBits = 0;   // Row 1: curve (-8 to +8)
	// Row 2, 3: deferred (time offset, curve offset)

	// Convert slew bits to actual values
	~getSlewTime = { ~slewTimeBits.linexp(0, 15, 0.01, 10.0) };
	~getSlewCurve = { ~slewCurveBits.linlin(0, 15, -8, 8) };

	// Apply current slew settings to synth
	~applySlew = {
		var time = ~getSlewTime.();
		var curve = ~getSlewCurve.();
		~drone.set(\slew_time, time, \slew_curve, curve);
		"[Grid] Slew: %s, curve %".format(time.round(0.001), curve.round(0.1)).postln;
	};

	// Connect to grid
	~connectGrid = {
		// Disconnect existing grid first to prevent duplicate handlers
		if (~gestureBreathTask.notNil) {
			~gestureBreathTask.stop;
			~gestureBreathTask = nil;
		};
		if (~grid.notNil) {
			"[Griddlecake] Disconnecting existing grid...".postln;
			~grid.free;
			~grid = nil;
		};

		"[Griddlecake] Connecting to grid at %:%".format(~gridIP, ~gridPort).postln;
		~grid = GridInterface(~gridIP, ~gridPort, oscgrid: true);

		// Set up key handler
		~grid.key({ |x, y, state|
			var zone = ~grid.getZone(x, y);

			// Route to engine page handler if active
			if (~onEnginePage) {
				~handleEnginePage.(x, y, state);
			} {
				// Normal main UI handling
				if (state == 1) {
					switch(zone,
						\navigation, {
							// Column 0: page select + clock controls
							if (y == 0) {
								~currentPage = 0;
								~pressedPageButton = 0;  // Track for preset saving
								~pageButtonStates[\s] = true;
								// Check for engine page entry (both held)
								if (~pageButtonStates[\a]) {
									~enterEnginePage.();
								} {
									"[Grid] Page: Synth".postln;
								};
							};
							if (y == 1) {
								~currentPage = 1;
								~pressedPageButton = 1;  // Track for preset saving
								~pageButtonStates[\a] = true;
								// Check for engine page entry (both held)
								if (~pageButtonStates[\s]) {
									~enterEnginePage.();
								} {
									"[Grid] Page: FX".postln;
								};
							};
						if (y == 2) {
							// Tap tempo - OR set loop length if seq step held
							if (~pressedSeqStep.notNil) {
								var row = ~pressedSeqStep[0];
								var step = ~pressedSeqStep[1];
								~sequencer.setLoopLength(row, step + 1);
								"[Grid] Seq row % loop length: %".format(row, step + 1).postln;
							} {
								~tapTempo.();
							};
						};
						if (y == 3) { ~toggleTransport.() };  // Transport start/stop
						~updateGridLEDs.();
					},
					\paramGrid, {
						// Cols 1-4, rows 0-3: 16-bit DAC toggle
						var bitPos = ((y * 4) + (x - 1));

						// Toggle bit on current page's DAC state
						if (~currentPage == 0) {
							~voiceDacState = ~voiceDacState.bitXor(1 << (15 - bitPos));
							~applyVoiceState.(~voiceDacState);
							"[Grid] Voice DAC: % (bit % toggled)".format(~voiceDacState, 15 - bitPos).postln;
						} {
							~fxDacState = ~fxDacState.bitXor(1 << (15 - bitPos));
							~applyFxState.(~fxDacState);
							"[Grid] FX DAC: % (bit % toggled)".format(~fxDacState, 15 - bitPos).postln;
						};

						// Record step if recording
						if (~recordingSlot.notNil) {
							~gestures.addStep(~recordingSlot, ~voiceDacState, ~fxDacState);
						};

						~updateGridLEDs.();
					},
					\slewGrid, {
						// Cols 8-11, rows 0-3: slew parameters
						var col = x - 8;  // 0-3 within slew grid
						var bitPos = 3 - col;  // bit 3 is leftmost
						var bitMask = 1 << bitPos;

						if (y == 0) {
							~slewTimeBits = ~slewTimeBits.bitXor(bitMask);
							~applySlew.();
						};
						if (y == 1) {
							~slewCurveBits = ~slewCurveBits.bitXor(bitMask);
							~applySlew.();
						};
						// Rows 2-3: deferred

						~updateGridLEDs.();
					},
					\utilities, {
						// Cols 5-7, rows 0-3: row operations on param grid
						// Row 0: bits 15-12, Row 1: bits 11-8, Row 2: bits 7-4, Row 3: bits 3-0
						var rowShift = (3 - y) * 4;  // bit position of row's LSB
						var rowMask = 0xF << rowShift;  // mask for this row's 4 bits
						var dacState = if(~currentPage == 0) { ~voiceDacState } { ~fxDacState };
						var rowBits = (dacState & rowMask) >> rowShift;  // extract row bits
						var newRowBits, newDacState;

						// Flash button at medium brightness
						~grid.led(x, y, GridInterface.ledMedium);

						if (x == 5) {
							// Clear: zero the row
							newRowBits = 0;
							"[Grid] Clear row %".format(y).postln;
						};
						if (x == 6) {
							// Invert: XOR with 0xF
							newRowBits = rowBits.bitXor(0xF);
							"[Grid] Invert row %".format(y).postln;
						};
						if (x == 7) {
							// Shift right: rotate within 4 bits
							newRowBits = ((rowBits >> 1) | ((rowBits & 1) << 3)) & 0xF;
							"[Grid] Shift row %".format(y).postln;
						};

						// Apply new row bits to DAC state
						newDacState = (dacState & rowMask.bitNot) | (newRowBits << rowShift);

						if (~currentPage == 0) {
							~voiceDacState = newDacState;
							~applyVoiceState.(~voiceDacState);
						} {
							~fxDacState = newDacState;
							~applyFxState.(~fxDacState);
						};

						// Record step if recording
						if (~recordingSlot.notNil) {
							~gestures.addStep(~recordingSlot, ~voiceDacState, ~fxDacState);
						};

						~updateGridLEDs.();
					},
					\gestures, {
						// Cols 12-15, rows 0-3: gesture slots
						var slot = ((y * 4) + (x - 12));

						// If seq step is held, assign gesture to that step
						if (~pressedSeqStep.notNil) {
							var row = ~pressedSeqStep[0];
							var step = ~pressedSeqStep[1];
							~sequencer.assignGesture(row, step, slot);
							"[Grid] Seq row % step %: assigned gesture %".format(row, step, slot).postln;
						} {
							// If page button is held, save current state as preset
							if (~pressedPageButton.notNil) {
								~gestures.savePreset(slot, ~voiceDacState, ~fxDacState);
								"[Grid] Saved preset to slot % (voice: %, fx: %)".format(
									slot, ~voiceDacState, ~fxDacState
								).postln;
							} {
								// Normal gesture interaction
								var state = ~gestures.getState(slot);

								// State machine
								switch(state,
									\empty, {
										~gestures.startRecording(slot);
										~recordingSlot = slot;
										"[Grid] Recording gesture %".format(slot).postln;
									},
									\recording, {
										~gestures.stopRecording(slot);
										~recordingSlot = nil;
										"[Grid] Stopped recording gesture %".format(slot).postln;
										// Auto-play after recording
										~playGesture.(slot);
										"[Grid] Playing gesture %".format(slot).postln;
									},
									\stopped, {
										~playGesture.(slot);
										"[Grid] Playing gesture %".format(slot).postln;
									},
									\paused, {
										~playGesture.(slot);
										"[Grid] Resumed gesture %".format(slot).postln;
									},
									\playing, {
										// Ignore single tap while playing
									}
								);
							};
						};

						~updateGridLEDs.();
					},
					\sequencer, {
						// Rows 4-7: sequencer (16 steps × 4 rows)
						var step = x;
						var row = y - 4;

						// Track pressed state for hold+tap gesture assignment
						~pressedSeqStep = [row, step];
						"[Grid] Seq step pressed: row %, step %".format(row, step).postln;

						~updateGridLEDs.();
					}
				);
				} {
					// Key release (state == 0)
					var zone = ~grid.getZone(x, y);
					if (zone == \sequencer) {
						~pressedSeqStep = nil;
					};
					if (zone == \navigation) {
						if (y == 0) {
							~pressedPageButton = nil;
							~pageButtonStates[\s] = false;
						};
						if (y == 1) {
							~pressedPageButton = nil;
							~pageButtonStates[\a] = false;
						};
					};
				};
			};  // end if (~onEnginePage) else
		});

		// Set up hold callback for clearing gestures and transport reset
		~grid.hold({ |x, y|
			var zone = ~grid.getZone(x, y);
			if (zone == \gestures) {
				var slot = ((y * 4) + (x - 12));
				~gestures.clear(slot);
				"[Grid] Gesture % cleared".format(slot).postln;
				~updateGridLEDs.();
			};
			if (zone == \navigation) {
				if (y == 3) {
					// Hold transport = stop and reset to beginning
					~stopTransport.();
					~sequencer.reset;
					"[Clock] Transport reset to beginning".postln;
					~updateGridLEDs.();
				};
			};
			// Note: loop length is set via hold step + tap tempo (handled in navigation)
		});

		// Set up doubleTap callback for pausing gestures and clearing seq steps
		~grid.doubleTap({ |x, y|
			var zone = ~grid.getZone(x, y);
			if (zone == \gestures) {
				var slot = ((y * 4) + (x - 12));
				~gestures.pause(slot);
				"[Grid] Gesture % paused".format(slot).postln;
				~updateGridLEDs.();
			};
			if (zone == \sequencer) {
				var step = x;
				var row = y - 4;
				~sequencer.assignGesture(row, step, nil);
				"[Grid] Seq row % step %: cleared".format(row, step).postln;
				~updateGridLEDs.();
			};
		});

		// Engine page LED update
		~updateEnginePageLEDs = {
			// Clear entire grid
			16.do { |x| 8.do { |y| ~grid.led(x, y, GridInterface.ledOff) } };

			// Back button (col 0, row 0)
			~grid.led(0, 0, GridInterface.ledMedium);

			// Engine slots (row 0, cols 1-N)
			~engineOrder.do { |key, i|
				var x = i + 1;
				var engine = ~engines[key];
				var brightness = case
					{ key == ~currentEngine } { GridInterface.ledFull }   // bright = selected
					{ engine[\implemented] } { GridInterface.ledMedium }  // medium = available
					{ true } { GridInterface.ledDim };                    // dim = not implemented

				~grid.led(x, 0, brightness);
			};

			~grid.dirty = true;  // Force refresh
		};

		// Enter engine page
		~enterEnginePage = {
			~onEnginePage = true;
			~updateEnginePageLEDs.();
			"[Griddlecake] Entered engine select page".postln;
		};

		// Exit engine page
		~exitEnginePage = {
			~onEnginePage = false;
			~updateGridLEDs.();
			"[Griddlecake] Returned to main UI".postln;
		};

		// Engine page key handler
		~handleEnginePage = { |x, y, state|
			if (state == 1) {  // press only
				case
				{ x == 0 && (y == 0) } {
					// Back button
					~exitEnginePage.();
				}
				{ y == 0 && (x > 0) && (x <= ~engineOrder.size) } {
					// Engine selection (row 0, cols 1-N)
					var engineKey = ~engineOrder[x - 1];
					var engine = ~engines[engineKey];

					if (engine[\implemented]) {
						~switchEngine.(engineKey);
						~exitEnginePage.();
					} {
						// Flash dim to indicate not implemented
						~grid.led(x, y, GridInterface.ledDim);
						AppClock.sched(0.1, { ~updateEnginePageLEDs.(); nil });
					};
				};
			};
		};

		// LED update function
		~updateGridLEDs = {
			// Show current page's DAC state on param grid (cols 1-4)
			var dacState = if(~currentPage == 0) { ~voiceDacState } { ~fxDacState };

			4.do { |y| 4.do { |x|
				var bitPos = ((y * 4) + x);
				var isOn = (dacState >> (15 - bitPos)) & 1;
				~grid.led(x + 1, y, isOn * GridInterface.ledFull);
			}};

			// Utilities (cols 5-7) - dim static indicators
			4.do { |row|
				~grid.led(5, row, GridInterface.ledDim);  // Clear
				~grid.led(6, row, GridInterface.ledDim);  // Invert
				~grid.led(7, row, GridInterface.ledDim);  // Shift
			};

			// Slew grid (cols 8-11)
			4.do { |col|
				var bitPos = 3 - col;
				// Row 0: Time
				~grid.led(col + 8, 0, ((~slewTimeBits >> bitPos) & 1) * GridInterface.ledFull);
				// Row 1: Curve
				~grid.led(col + 8, 1, ((~slewCurveBits >> bitPos) & 1) * GridInterface.ledFull);
				// Row 2-3: dim (deferred)
				~grid.led(col + 8, 2, GridInterface.ledDim);
				~grid.led(col + 8, 3, GridInterface.ledDim);
			};

			// Gesture slots (cols 12-15, rows 0-3)
			// Playing slots handled by breath task, flashing slots skipped
			4.do { |row|
				4.do { |col|
					var slot = (row * 4) + col;
					// Skip if slot is currently flashing
					if (~flashingSlots.includes(slot).not) {
						var state = ~gestures.getState(slot);
						if (state != \playing) {
							var brightness;
							var isPreset = ~gestures.isPreset(slot);

							// Active preset (manual) gets full brightness
							if (isPreset && ~activePreset.notNil && (~activePreset == slot)) {
								brightness = GridInterface.ledFull;
							} {
								brightness = switch(state,
									\empty, { GridInterface.ledOff },
									\recording, { GridInterface.ledFull },
									\stopped, {
										// Presets: dim unless active; Gestures: medium
										if (isPreset) { GridInterface.ledDim } { GridInterface.ledMedium }
									},
									\paused, { GridInterface.ledBright },
									{ GridInterface.ledDim }
								);
							};
							~grid.led(col + 12, row, brightness);
						};
					};
				};
			};

			// Page indicator (row 0-1)
			~grid.led(0, 0, if(~currentPage == 0) { GridInterface.ledFull } { GridInterface.ledDim });
			~grid.led(0, 1, if(~currentPage == 1) { GridInterface.ledFull } { GridInterface.ledDim });

			// Tap tempo (row 2) - dim
			~grid.led(0, 2, GridInterface.ledDim);

			// Transport (row 3) - bright when running
			~grid.led(0, 3, if(~transport == \running) { GridInterface.ledFull } { GridInterface.ledDim });

			// Sequencer (rows 4-7, cols 0-15)
			4.do { |row|
				var currentStep = ~sequencer.getStepForRow(row);
				var loopLen = ~sequencer.loopLengths[row];

				16.do { |step|
					var brightness;
					if (step >= loopLen) {
						// Beyond loop length - off
						brightness = GridInterface.ledOff;
					} {
						if (step == currentStep) {
							// Current step - bright
							brightness = GridInterface.ledFull;
						} {
							if (~sequencer.hasGestureAt(row, step)) {
								// Has gesture - medium
								brightness = GridInterface.ledMedium;
							} {
								// Empty step - dim
								brightness = GridInterface.ledDim;
							};
						};
					};
					~grid.led(step, row + 4, brightness);
				};
			};
		};

		// Gesture LED breathing task
		~gestureBreathTask = Routine({
			var phase = 0;
			loop {
				4.do { |row|
					4.do { |col|
						var slot = (row * 4) + col;
						if (~gestures.getState(slot) == \playing) {
							// Breathe between ledMedium (8) and ledFull (15)
							var breath = (phase.sin + 1) / 2;  // 0-1
							var brightness = (GridInterface.ledMedium + (breath * 7)).asInteger;
							~grid.led(col + 12, row, brightness);
						};
					};
				};
				phase = phase + 0.15;  // ~2 second cycle at 30fps
				0.033.wait;
			};
		}).play;

		// Initial LED state
		~updateGridLEDs.();

		"[Griddlecake] Grid connected".postln;
	};

	// Disconnect grid
	~disconnectGrid = {
		if (~gestureBreathTask.notNil) {
			~gestureBreathTask.stop;
			~gestureBreathTask = nil;
		};
		if (~clockRoutine.notNil) {
			~clockRoutine.stop;
			~clockRoutine = nil;
		};
		// Stop all row playback routines
		4.do { |row|
			if (~rowPlaybackRoutines[row].notNil) {
				~rowPlaybackRoutines[row].stop;
				~rowPlaybackRoutines[row] = nil;
			};
		};
		~transport = \stopped;
		if (~grid.notNil) {
			~grid.free;
			~grid = nil;
			"[Griddlecake] Grid disconnected".postln;
		};
	};

	// ========================================
	// BOOT COMPLETE
	// ========================================

	"[Griddlecake] ========================================".postln;
	"[Griddlecake] BOOT COMPLETE".postln;
	"[Griddlecake] ========================================".postln;
	"[Griddlecake] Engine: % (%)".format(~engines[~currentEngine][\name], ~currentEngine).postln;
	"[Griddlecake] Available engines: %".format(~engineOrder).postln;
	"[Griddlecake] LUT seed: %".format(~lutSeed).postln;
	"[Griddlecake] Synth: %".format(~synth).postln;
	"[Griddlecake] ========================================".postln;
	"[Griddlecake] Functions:".postln;
	"[Griddlecake]   ~switchEngine.(key)            - Switch engine".postln;
	"[Griddlecake]   ~applyVoiceState.(index)       - Apply voice state".postln;
	"[Griddlecake]   ~applyFxState.(index)          - Apply FX state".postln;
	"[Griddlecake]   ~randomize.()                  - Randomize both".postln;
	"[Griddlecake]   ~showSeed.()                   - Show LUT seed".postln;
	"[Griddlecake]   ~setSlew.(time, curve)         - Set slew time/curve".postln;
	"[Griddlecake]   ~eq.(low, mid, high)           - Set EQ gains (dB)".postln;
	"[Griddlecake]   ~comp.(th, rat, atk, rel, mk)  - Set compressor".postln;
	"[Griddlecake] Grid:".postln;
	"[Griddlecake]   ~connectGrid.()               - Connect to oscgrid".postln;
	"[Griddlecake]   ~disconnectGrid.()            - Disconnect grid".postln;
	"[Griddlecake]   Hold s+a                      - Engine select page".postln;
	"[Griddlecake] Clock/Transport:".postln;
	"[Griddlecake]   ~tapTempo.()                  - Register tap for tempo".postln;
	"[Griddlecake]   ~startTransport.()            - Start sequencer".postln;
	"[Griddlecake]   ~bpm                          - Current BPM (%)".format(~bpm).postln;
	"[Griddlecake] ========================================".postln;

	// Apply initial state
	~applyFullState.(0, 0);
});

)
