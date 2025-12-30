// Griddlecake v0.1.0b - Music Mode
// 3-osc chord drone with harmonic LUT control
//
// Usage: "/path/to/main.scd".load;

(
// ========================================
// BOOT SERVER
// ========================================

"[Griddlecake] Booting server...".postln;

s.waitForBoot({

	// ========================================
	// LOAD SYNTHDEF
	// ========================================

	"[Griddlecake] Loading drone SynthDef...".postln;
	(thisProcess.nowExecutingPath.dirname +/+ "synthdefs/drone.scd").load;
	s.sync;

	// ========================================
	// INITIALIZE LUTS
	// ========================================

	// Seed management
	if (~useSeed.notNil) {
		~lutSeed = ~useSeed;
		~useSeed = nil;
		"[Griddlecake] Using provided seed: %".format(~lutSeed).postln;
	} {
		~lutSeed = Date.seed;
		"[Griddlecake] Generated new seed: %".format(~lutSeed).postln;
	};

	// ----------------------------------------
	// HARMONIC LUT (controls pitch)
	// ----------------------------------------

	"[Griddlecake] Generating Harmonic LUT (65536 × 8 params)...".postln;
	~harmonicLut = HarmonicLUT(~lutSeed);
	"[Griddlecake] Harmonic LUT complete".postln;

	// ----------------------------------------
	// VOICE LUT (non-pitch params only)
	// ----------------------------------------

	"[Griddlecake] Generating Voice LUT (65536 × 23 params)...".postln;

	~voiceLut = Array.fill(65536, { |i|
		if (i == 0) {
			// State 0: Home base - clean sine, no effects
			[
				0,     // osc1_wave - sine
				0.5,   // osc1_pw
				0,     // osc2_wave - sine
				0.5,   // osc2_pw
				1,     // osc2_track - tracking osc1
				1,     // osc2_ratio - unison
				0,     // osc3_wave - sine
				0.5,   // osc3_pw
				1,     // osc3_track - tracking osc1
				1,     // osc3_ratio - unison
				0,     // fm_amount
				0,     // combo_mode - CHORD
				1.0,   // combo_mix - full combo (not dry osc1)
				0,     // detune - none
				0,     // noise_type
				0,     // noise_level
				0,     // noise_to_osc1
				0,     // noise_to_osc2
				20000, // filter_freq - wide open
				0,     // filter_res
				0,     // filter_type - lowpass
				0,     // filter_track
				0.5    // output_level
			]
		} {
			thisThread.randSeed = ~lutSeed + i;
			[
				rrand(0, 3).round,        // osc1_wave
				rrand(0.0, 1.0),          // osc1_pw
				rrand(0, 3).round,        // osc2_wave
				rrand(0.0, 1.0),          // osc2_pw
				0,                        // osc2_track (always use HarmonicLUT freq)
				1.0,                      // osc2_ratio (unused when track=0)
				rrand(0, 3).round,        // osc3_wave
				rrand(0.0, 1.0),          // osc3_pw
				0,                        // osc3_track (always use HarmonicLUT freq)
				1.0,                      // osc3_ratio (unused when track=0)
				rrand(0.0, 0.15).pow(1.5), // fm_amount (subtle, bias toward 0)
				[0,0,0,1,2,3,4,5,6,7,8,9,10,11,12,13].choose, // combo_mode
				rrand(0.7, 1.0),          // combo_mix (always hear the chord)
				rrand(0.0, 0.3).pow(1.5), // detune (very subtle)
				rrand(0, 2).round,        // noise_type
				rrand(0.0, 0.1).pow(2.0), // noise_level (subtle texture only)
				rrand(0.0, 0.02),         // noise_to_osc1 (minimal pitch mod)
				rrand(0.0, 0.02),         // noise_to_osc2 (minimal pitch mod)
				1.0.rand.pow(1.2).linexp(0, 1, 400, 20000), // filter_freq (higher min)
				rrand(0.0, 0.6).pow(1.5), // filter_res (no self-oscillation)
				[0, 0, 0, 1].choose,      // filter_type (bias toward lowpass)
				rrand(0.0, 0.3),          // filter_track (subtle)
				rrand(0.4, 0.7)           // output_level
			]
		}
	});

	"[Griddlecake] Voice LUT complete (%.2f MB)".format((65536 * 23 * 4) / 1048576).postln;

	// ----------------------------------------
	// FX LUT
	// ----------------------------------------

	"[Griddlecake] Generating FX LUT (65536 × 19 params)...".postln;

	~fxLut = Array.fill(65536, { |i|
		if (i == 0) {
			// State 0: 100% dry
			[
				16,    // lofi_bits
				48000, // lofi_rate
				0,     // lofi_mix
				440,   // ring_freq
				0,     // ring_wave
				0,     // ring_mix
				440,   // comb_freq
				0.5,   // comb_decay
				0,     // comb_mix
				250,   // delay_time
				0,     // delay_fb
				0,     // delay_mix
				0.5,   // clouds_pos
				0.5,   // clouds_size
				0.5,   // clouds_dens
				0.5,   // clouds_tex
				0,     // clouds_mode
				0,     // clouds_rvb
				0      // clouds_mix
			]
		} {
			thisThread.randSeed = ~lutSeed + 65536 + i;
			[
				rrand(10, 16).round,      // lofi_bits (less harsh)
				1.0.rand.pow(1.2).linexp(0, 1, 12000, 48000), // lofi_rate (less aliasing)
				rrand(0.0, 0.5),          // lofi_mix
				1.0.rand.pow(1.5).linexp(0, 1, 100, 2000), // ring_freq
				[0, 0, 0, 1].choose,      // ring_wave (bias toward sine)
				rrand(0.0, 0.35),         // ring_mix
				1.0.rand.pow(1.5).linexp(0, 1, 100, 3000), // comb_freq
				exprand(0.01, 1.0),       // comb_decay
				rrand(0.0, 0.5),          // comb_mix
				1.0.rand.pow(1.2).linexp(0, 1, 50, 800), // delay_time
				rrand(0.0, 0.5),          // delay_fb
				rrand(0.0, 0.5),          // delay_mix
				rrand(0.0, 1.0),          // clouds_pos
				rrand(0.3, 0.7),          // clouds_size (moderate)
				rrand(0.3, 0.7),          // clouds_dens (moderate)
				rrand(0.2, 0.6),          // clouds_tex (smooth)
				[0, 0, 1, 2].choose,      // clouds_mode (bias toward cleaner)
				rrand(0.0, 0.4),          // clouds_rvb
				rrand(0.0, 0.5)           // clouds_mix
			]
		}
	});

	"[Griddlecake] FX LUT complete (%.2f MB)".format((65536 * 19 * 4) / 1048576).postln;

	// ========================================
	// PARAMETER NAMES
	// ========================================

	~voiceParamNames = [
		\osc1_wave, \osc1_pw,
		\osc2_wave, \osc2_pw, \osc2_track, \osc2_ratio,
		\osc3_wave, \osc3_pw, \osc3_track, \osc3_ratio,
		\fm_amount, \combo_mode, \combo_mix, \detune,
		\noise_type, \noise_level, \noise_to_osc1, \noise_to_osc2,
		\filter_freq, \filter_res, \filter_type, \filter_track,
		\output_level
	];

	~fxParamNames = [
		\lofi_bits, \lofi_rate, \lofi_mix,
		\ring_freq, \ring_wave, \ring_mix,
		\comb_freq, \comb_decay, \comb_mix,
		\delay_time, \delay_fb, \delay_mix,
		\clouds_pos, \clouds_size, \clouds_dens, \clouds_tex,
		\clouds_mode, \clouds_rvb, \clouds_mix
	];

	// ========================================
	// CREATE DRONE SYNTH
	// ========================================

	"[Griddlecake] Creating drone synth...".postln;
	~drone = Synth(\chaosDrone);
	s.sync;

	// ========================================
	// GESTURE RECORDER
	// ========================================

	~gestures = GestureRecorder.new;

	// ========================================
	// STATE VARIABLES
	// ========================================

	// DAC states (16-bit indices)
	~voiceDacState = 0;
	~fxDacState = 0;
	~harmonicDacState = 0;

	// Harmonic system
	~rootIndex = 0;       // 0-11: C, C#, D, D#, E, F, F#, G, G#, A, A#, B
	~scaleIndex = 0;      // 0-15: see HarmonicLUT scales
	~tuningSystem = \tet; // \tet or \just
	~octaveOffset = 0;    // -2 to +2
	~baseFreq = 55;       // A1 as base (can be adjusted)

	// Mute state
	~muted = false;

	// Slew states (separate for voice and FX)
	~voiceSlewTimeBits = 0;
	~voiceSlewCurveBits = 0;
	~fxSlewTimeBits = 0;
	~fxSlewCurveBits = 0;

	// Convert slew bits to values
	~getSlewTime = { |bits| bits.linexp(0, 15, 0.01, 10.0) };
	~getSlewCurve = { |bits| bits.linlin(0, 15, -8, 8) };

	// ========================================
	// APPLY STATE FUNCTIONS
	// ========================================

	// Apply voice state (non-pitch params)
	~applyVoiceState = { |index|
		var params = ~voiceLut[index.asInteger.clip(0, 65535)];
		~voiceParamNames.do({ |name, i|
			// Skip output_level if muted
			if ((name == \output_level) && ~muted) {
				~drone.set(\output_level, 0);
			} {
				~drone.set(name, params[i]);
			};
		});
	};

	// Apply FX state
	~applyFxState = { |index|
		var params = ~fxLut[index.asInteger.clip(0, 65535)];
		~fxParamNames.do({ |name, i|
			~drone.set(name, params[i]);
		});
	};

	// Apply harmonic state (frequencies from HarmonicLUT)
	~applyHarmonicState = { |index|
		var freqs = ~harmonicLut.getFreqs(
			index,
			~rootIndex,
			~scaleIndex,
			~tuningSystem,
			~baseFreq * (2 ** ~octaveOffset)
		);
		var detune = ~harmonicLut.getDetune(index);

		~drone.set(
			\osc1_freq, freqs[0],
			\osc2_freq, freqs[1],
			\osc3_freq, freqs[2],
			\detune, detune
		);

		"[Harmonic] Freqs: %, %, % (root: %, scale: %)".format(
			freqs[0].round(0.1),
			freqs[1].round(0.1),
			freqs[2].round(0.1),
			["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"][~rootIndex],
			HarmonicLUT.scaleNames[~scaleIndex]
		).postln;
	};

	// Apply all states
	~applyFullState = {
		~applyVoiceState.(~voiceDacState);
		~applyFxState.(~fxDacState);
		~applyHarmonicState.(~harmonicDacState);
	};

	// Apply voice slew settings
	~applyVoiceSlew = {
		var time = ~getSlewTime.(~voiceSlewTimeBits);
		var curve = ~getSlewCurve.(~voiceSlewCurveBits);
		~drone.set(\slew_time, time, \slew_curve, curve);
		"[Slew] Voice: %s, curve %".format(time.round(0.001), curve.round(0.1)).postln;
	};

	// Apply FX slew settings
	~applyFxSlew = {
		var time = ~getSlewTime.(~fxSlewTimeBits);
		var curve = ~getSlewCurve.(~fxSlewCurveBits);
		~drone.set(\fx_slew_time, time, \fx_slew_curve, curve);
		"[Slew] FX: %s, curve %".format(time.round(0.001), curve.round(0.1)).postln;
	};

	// Toggle mute
	~toggleMute = {
		~muted = ~muted.not;
		if (~muted) {
			~drone.set(\output_level, 0);
			"[Griddlecake] MUTED".postln;
		} {
			var params = ~voiceLut[~voiceDacState];
			~drone.set(\output_level, params[22]); // output_level index
			"[Griddlecake] UNMUTED".postln;
		};
	};

	// Home state
	~goHome = {
		~voiceDacState = 0;
		~fxDacState = 0;
		~harmonicDacState = 0;
		~applyFullState.();
		"[Griddlecake] Home state applied".postln;
	};

	// ========================================
	// TEST HELPERS
	// ========================================

	~testVoice = {
		var testIndices = [0, 10000, 30000, 50000, 65535];
		"[Griddlecake] Testing voice states...".postln;
		fork {
			testIndices.do({ |idx|
				~voiceDacState = idx;
				~applyVoiceState.(idx);
				"[Test] Voice: %".format(idx).postln;
				2.wait;
			});
		};
	};

	~testHarmonic = {
		var testIndices = [0, 10000, 30000, 50000, 65535];
		"[Griddlecake] Testing harmonic states...".postln;
		fork {
			testIndices.do({ |idx|
				~harmonicDacState = idx;
				~applyHarmonicState.(idx);
				"[Test] Harmonic: %".format(idx).postln;
				2.wait;
			});
		};
	};

	~randomize = {
		~voiceDacState = 65535.rand;
		~fxDacState = 65535.rand;
		~harmonicDacState = 65535.rand;
		~applyFullState.();
		"[Griddlecake] Randomized: voice % / fx % / harmonic %".format(
			~voiceDacState, ~fxDacState, ~harmonicDacState
		).postln;
	};

	~showSeed = {
		"[Griddlecake] ========================================".postln;
		"[Griddlecake] LUT Seed: %".format(~lutSeed).postln;
		"[Griddlecake] Voice DAC: %".format(~voiceDacState).postln;
		"[Griddlecake] FX DAC: %".format(~fxDacState).postln;
		"[Griddlecake] Harmonic DAC: %".format(~harmonicDacState).postln;
		"[Griddlecake] Root: % (%)".format(~rootIndex, ["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"][~rootIndex]).postln;
		"[Griddlecake] Scale: % (%)".format(~scaleIndex, HarmonicLUT.scaleNames[~scaleIndex]).postln;
		"[Griddlecake] Tuning: %".format(~tuningSystem).postln;
		"[Griddlecake] ========================================".postln;
		~lutSeed;
	};

	// ========================================
	// EQ & COMPRESSOR
	// ========================================

	~eq = { |low=0, mid=0, high=0|
		~drone.set(\eq_low_gain, low, \eq_mid_gain, mid, \eq_high_gain, high);
	};

	~eqFreqs = { |low=200, mid=1000, high=4000|
		~drone.set(\eq_low_freq, low, \eq_mid_freq, mid, \eq_high_freq, high);
	};

	~comp = { |thresh=0.5, ratio=2, attack=0.01, release=0.1, makeup=1|
		~drone.set(\comp_thresh, thresh, \comp_ratio, ratio,
			\comp_attack, attack, \comp_release, release, \comp_makeup, makeup);
	};

	~eqBypass = { ~drone.set(\eq_low_gain, 0, \eq_mid_gain, 0, \eq_high_gain, 0) };
	~compBypass = { ~drone.set(\comp_ratio, 1, \comp_makeup, 1) };

	// ========================================
	// GRID INTEGRATION
	// ========================================

	~gridIP = "192.168.1.244";
	~gridPort = 9000;

	// Gesture recording state
	~recordingSlot = nil;
	~flashingSlots = Set.new;
	~activePreset = nil;

	// Connect to grid
	~connectGrid = {
		if (~gestureBreathTask.notNil) {
			~gestureBreathTask.stop;
			~gestureBreathTask = nil;
		};
		if (~grid.notNil) {
			~grid.free;
			~grid = nil;
		};

		"[Griddlecake] Connecting to grid at %:%".format(~gridIP, ~gridPort).postln;
		~grid = GridInterface(~gridIP, ~gridPort, oscgrid: true);

		// Key handler
		~grid.key({ |x, y, state|
			var zone = ~grid.getZone(x, y);

			if (state == 1) {
				// Key press
				switch(zone,
					\global, {
						// Column 0: global controls
						switch(y,
							0, { ~toggleMute.() },           // Row 0: Mute
							1, { /* Gesture start/stop - TODO */ },  // Row 1
							2, { ~octaveOffset = (~octaveOffset + 1).clip(-2, 2);
								~applyHarmonicState.(~harmonicDacState);
								"[Grid] Octave: %".format(~octaveOffset).postln;
							},  // Row 2: Octave up
							3, { ~octaveOffset = (~octaveOffset - 1).clip(-2, 2);
								~applyHarmonicState.(~harmonicDacState);
								"[Grid] Octave: %".format(~octaveOffset).postln;
							},  // Row 3: Octave down
							4, { ~tuningSystem = if(~tuningSystem == \tet) { \just } { \tet };
								~applyHarmonicState.(~harmonicDacState);
								"[Grid] Tuning: %".format(~tuningSystem).postln;
							},  // Row 4: Tuning toggle
							5, { ~goHome.() }                // Row 5: Home
						);
						~updateGridLEDs.();
					},
					\voiceDac, {
						// Cols 1-4, rows 0-3: Voice DAC
						var bitPos = ((y * 4) + (x - 1));
						~voiceDacState = ~voiceDacState.bitXor(1 << (15 - bitPos));
						~applyVoiceState.(~voiceDacState);
						"[Grid] Voice DAC: %".format(~voiceDacState).postln;

						if (~recordingSlot.notNil) {
							~gestures.addStep(~recordingSlot, ~voiceDacState, ~fxDacState, ~harmonicDacState);
						};
						~updateGridLEDs.();
					},
					\fxDac, {
						// Cols 1-4, rows 4-7: FX DAC
						var bitPos = (((y - 4) * 4) + (x - 1));
						~fxDacState = ~fxDacState.bitXor(1 << (15 - bitPos));
						~applyFxState.(~fxDacState);
						"[Grid] FX DAC: %".format(~fxDacState).postln;

						if (~recordingSlot.notNil) {
							~gestures.addStep(~recordingSlot, ~voiceDacState, ~fxDacState, ~harmonicDacState);
						};
						~updateGridLEDs.();
					},
					\harmonicDac, {
						// Cols 5-8, rows 0-3: Harmonic DAC
						var bitPos = ((y * 4) + (x - 5));
						~harmonicDacState = ~harmonicDacState.bitXor(1 << (15 - bitPos));
						~applyHarmonicState.(~harmonicDacState);
						"[Grid] Harmonic DAC: %".format(~harmonicDacState).postln;

						if (~recordingSlot.notNil) {
							~gestures.addStep(~recordingSlot, ~voiceDacState, ~fxDacState, ~harmonicDacState);
						};
						~updateGridLEDs.();
					},
					\rootSelect, {
						// Cols 5-8, rows 4-6: Root selection (12 buttons)
						var buttonIndex = ((y - 4) * 4) + (x - 5);
						if (buttonIndex < 12) {
							~rootIndex = buttonIndex;
							~applyHarmonicState.(~harmonicDacState);
							"[Grid] Root: % (%)".format(~rootIndex,
								["C","C#","D","D#","E","F","F#","G","G#","A","A#","B"][~rootIndex]).postln;
						};
						~updateGridLEDs.();
					},
					\scaleSelect, {
						// Cols 5-8, row 7: Scale selection (4-bit)
						var bitPos = 3 - (x - 5);
						~scaleIndex = ~scaleIndex.bitXor(1 << bitPos);
						~scaleIndex = ~scaleIndex.clip(0, 15);
						~applyHarmonicState.(~harmonicDacState);
						"[Grid] Scale: % (%)".format(~scaleIndex, HarmonicLUT.scaleNames[~scaleIndex]).postln;
						~updateGridLEDs.();
					},
					\voiceSlew, {
						// Cols 9-12, rows 0-3: Voice slew
						var col = x - 9;
						var bitPos = 3 - col;
						var bitMask = 1 << bitPos;

						if (y == 0) { ~voiceSlewTimeBits = ~voiceSlewTimeBits.bitXor(bitMask) };
						if (y == 1) { ~voiceSlewCurveBits = ~voiceSlewCurveBits.bitXor(bitMask) };
						~applyVoiceSlew.();
						~updateGridLEDs.();
					},
					\fxSlew, {
						// Cols 9-12, rows 4-7: FX slew
						var col = x - 9;
						var bitPos = 3 - col;
						var bitMask = 1 << bitPos;

						if (y == 4) { ~fxSlewTimeBits = ~fxSlewTimeBits.bitXor(bitMask) };
						if (y == 5) { ~fxSlewCurveBits = ~fxSlewCurveBits.bitXor(bitMask) };
						~applyFxSlew.();
						~updateGridLEDs.();
					},
					\gestures, {
						// Cols 13-15, rows 0-7: Gesture slots (24 total)
						// Rows 0-3: voice gestures, Rows 4-7: FX gestures
						var col = x - 13;
						var slot = (y * 3) + col;
						var state = ~gestures.getState(slot);

						switch(state,
							\empty, {
								~gestures.startRecording(slot);
								~recordingSlot = slot;
								"[Grid] Recording gesture %".format(slot).postln;
							},
							\recording, {
								~gestures.stopRecording(slot);
								~recordingSlot = nil;
								"[Grid] Stopped recording %".format(slot).postln;
								~playGesture.(slot);
							},
							\stopped, { ~playGesture.(slot) },
							\paused, { ~playGesture.(slot) },
							\playing, { /* ignore */ }
						);
						~updateGridLEDs.();
					}
				);
			};
		});

		// Hold callback
		~grid.hold({ |x, y|
			var zone = ~grid.getZone(x, y);
			if (zone == \gestures) {
				var col = x - 13;
				var slot = (y * 3) + col;
				~gestures.clear(slot);
				"[Grid] Gesture % cleared".format(slot).postln;
				~updateGridLEDs.();
			};
		});

		// Double-tap callback
		~grid.doubleTap({ |x, y|
			var zone = ~grid.getZone(x, y);
			if (zone == \gestures) {
				var col = x - 13;
				var slot = (y * 3) + col;
				~gestures.pause(slot);
				"[Grid] Gesture % paused".format(slot).postln;
				~updateGridLEDs.();
			};
		});

		// LED update function
		~updateGridLEDs = {
			// Global column (col 0)
			~grid.led(0, 0, if(~muted) { GridInterface.ledFull } { GridInterface.ledDim }); // Mute
			~grid.led(0, 1, GridInterface.ledDim);  // Gesture ctrl
			~grid.led(0, 2, GridInterface.ledDim);  // Oct up
			~grid.led(0, 3, GridInterface.ledDim);  // Oct down
			~grid.led(0, 4, if(~tuningSystem == \just) { GridInterface.ledFull } { GridInterface.ledDim }); // Tuning
			~grid.led(0, 5, GridInterface.ledDim);  // Home
			~grid.led(0, 6, GridInterface.ledOff);  // Reserved
			~grid.led(0, 7, GridInterface.ledOff);  // Reserved

			// Voice DAC (cols 1-4, rows 0-3)
			4.do { |y| 4.do { |x|
				var bitPos = ((y * 4) + x);
				var isOn = (~voiceDacState >> (15 - bitPos)) & 1;
				~grid.led(x + 1, y, isOn * GridInterface.ledFull);
			}};

			// FX DAC (cols 1-4, rows 4-7)
			4.do { |y| 4.do { |x|
				var bitPos = ((y * 4) + x);
				var isOn = (~fxDacState >> (15 - bitPos)) & 1;
				~grid.led(x + 1, y + 4, isOn * GridInterface.ledFull);
			}};

			// Harmonic DAC (cols 5-8, rows 0-3)
			4.do { |y| 4.do { |x|
				var bitPos = ((y * 4) + x);
				var isOn = (~harmonicDacState >> (15 - bitPos)) & 1;
				~grid.led(x + 5, y, isOn * GridInterface.ledFull);
			}};

			// Root select (cols 5-8, rows 4-6) - 12 buttons
			3.do { |row| 4.do { |col|
				var buttonIndex = (row * 4) + col;
				if (buttonIndex < 12) {
					~grid.led(col + 5, row + 4,
						if(buttonIndex == ~rootIndex) { GridInterface.ledFull } { GridInterface.ledDim });
				} {
					~grid.led(col + 5, row + 4, GridInterface.ledOff);
				};
			}};

			// Scale select (cols 5-8, row 7)
			4.do { |col|
				var bitPos = 3 - col;
				var isOn = (~scaleIndex >> bitPos) & 1;
				~grid.led(col + 5, 7, isOn * GridInterface.ledFull);
			};

			// Voice slew (cols 9-12, rows 0-3)
			4.do { |col|
				var bitPos = 3 - col;
				~grid.led(col + 9, 0, ((~voiceSlewTimeBits >> bitPos) & 1) * GridInterface.ledFull);
				~grid.led(col + 9, 1, ((~voiceSlewCurveBits >> bitPos) & 1) * GridInterface.ledFull);
				~grid.led(col + 9, 2, GridInterface.ledDim);  // Reserved
				~grid.led(col + 9, 3, GridInterface.ledDim);  // Reserved
			};

			// FX slew (cols 9-12, rows 4-7)
			4.do { |col|
				var bitPos = 3 - col;
				~grid.led(col + 9, 4, ((~fxSlewTimeBits >> bitPos) & 1) * GridInterface.ledFull);
				~grid.led(col + 9, 5, ((~fxSlewCurveBits >> bitPos) & 1) * GridInterface.ledFull);
				~grid.led(col + 9, 6, GridInterface.ledDim);  // Reserved
				~grid.led(col + 9, 7, GridInterface.ledDim);  // Reserved
			};

			// Gesture slots (cols 13-15, rows 0-7)
			8.do { |row| 3.do { |col|
				var slot = (row * 3) + col;
				if (~flashingSlots.includes(slot).not) {
					var state = ~gestures.getState(slot);
					if (state != \playing) {
						var brightness = switch(state,
							\empty, { GridInterface.ledOff },
							\recording, { GridInterface.ledFull },
							\stopped, { GridInterface.ledMedium },
							\paused, { GridInterface.ledBright },
							{ GridInterface.ledDim }
						);
						~grid.led(col + 13, row, brightness);
					};
				};
			}};
		};

		// Play gesture helper
		~playGesture = { |slot|
			if (~gestures.isPreset(slot)) {
				var preset = ~gestures.getPreset(slot);
				if (preset.notNil) {
					~voiceDacState = preset[0];
					~fxDacState = preset[1];
					~harmonicDacState = preset[2] ? ~harmonicDacState;
					~applyVoiceState.(~voiceDacState);
					~applyFxState.(~fxDacState);
					~applyHarmonicState.(~harmonicDacState);
					~updateGridLEDs.();
				};
			} {
				~gestures.play(slot, { |voiceState, fxState, harmonicState|
					~voiceDacState = voiceState;
					~fxDacState = fxState;
					~harmonicDacState = harmonicState ? ~harmonicDacState;
					~applyVoiceState.(voiceState);
					~applyFxState.(fxState);
					~applyHarmonicState.(~harmonicDacState);
					~updateGridLEDs.();
				});
			};
		};

		// Gesture breathing task
		~gestureBreathTask = Routine({
			var phase = 0;
			loop {
				8.do { |row| 3.do { |col|
					var slot = (row * 3) + col;
					if (~gestures.getState(slot) == \playing) {
						var breath = (phase.sin + 1) / 2;
						var brightness = (GridInterface.ledMedium + (breath * 7)).asInteger;
						~grid.led(col + 13, row, brightness);
					};
				}};
				phase = phase + 0.15;
				0.033.wait;
			};
		}).play;

		~updateGridLEDs.();
		"[Griddlecake] Grid connected".postln;
	};

	// Disconnect grid
	~disconnectGrid = {
		if (~gestureBreathTask.notNil) {
			~gestureBreathTask.stop;
			~gestureBreathTask = nil;
		};
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
	"[Griddlecake] v0.1.0b MUSIC MODE - BOOT COMPLETE".postln;
	"[Griddlecake] ========================================".postln;
	"[Griddlecake] LUT seed: %".format(~lutSeed).postln;
	"[Griddlecake] ========================================".postln;
	"[Griddlecake] Functions:".postln;
	"[Griddlecake]   ~applyFullState.()         - Apply all states".postln;
	"[Griddlecake]   ~randomize.()              - Randomize all".postln;
	"[Griddlecake]   ~goHome.()                 - Reset to home".postln;
	"[Griddlecake]   ~showSeed.()               - Show current state".postln;
	"[Griddlecake]   ~testVoice.()              - Test voice states".postln;
	"[Griddlecake]   ~testHarmonic.()           - Test harmonic states".postln;
	"[Griddlecake]   ~eq.(low, mid, high)       - EQ (dB)".postln;
	"[Griddlecake]   ~comp.(th, rat, atk, rel, mk)".postln;
	"[Griddlecake] Grid:".postln;
	"[Griddlecake]   ~connectGrid.()            - Connect".postln;
	"[Griddlecake]   ~disconnectGrid.()         - Disconnect".postln;
	"[Griddlecake] ========================================".postln;

	// Apply initial state
	~goHome.();
});

)
