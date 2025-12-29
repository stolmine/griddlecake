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
	// LOAD SYNTHDEF
	// ========================================

	"[Griddlecake] Loading drone SynthDef...".postln;
	(thisProcess.nowExecutingPath.dirname +/+ "synthdefs/drone.scd").load;
	s.sync;

	// ========================================
	// INITIALIZE LUT
	// ========================================

	"[Griddlecake] Generating Voice LUT (65536 × 20 params)...".postln;

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

	// Generate 65536 randomized voice parameter sets
	~voiceLut = Array.fill(65536, { |i|
		if (i == 0) {
			// State 0: Simple 55Hz sine (home base)
			[
				55,    // osc1_freq - 55Hz (A1)
				0,     // osc1_wave - sine
				0.5,   // osc1_pw
				55,    // osc2_freq
				0,     // osc2_wave - sine
				0.5,   // osc2_pw
				0,     // osc2_track - free
				1,     // osc2_ratio
				0,     // fm_amount - none
				0,     // combo_mode - OSC1 only
				0,     // combo_mix - dry osc1
				0,     // noise_type
				0,     // noise_level - none
				0,     // noise_to_osc1 - none
				0,     // noise_to_osc2 - none
				20000, // filter_freq - wide open
				0,     // filter_res - none
				0,     // filter_type - lowpass
				0,     // filter_track - none
				0.5    // output_level
			]
		} {
			thisThread.randSeed = ~lutSeed + i; // Deterministic per-index
			[
				// Oscillators - pow(1.8) moderate bias toward low frequencies
				// ~55% of values fall in bottom third of range
				1.0.rand.pow(1.8).linexp(0, 1, 20, 2000),  // osc1_freq
				rrand(0, 3).round,        // osc1_wave
				rrand(0.0, 1.0),          // osc1_pw
				1.0.rand.pow(1.8).linexp(0, 1, 20, 2000),  // osc2_freq
				rrand(0, 3).round,        // osc2_wave
				rrand(0.0, 1.0),          // osc2_pw
				rrand(0.0, 1.0),          // osc2_track
				1.0.rand.pow(1.2).linexp(0, 1, 0.25, 4.0), // osc2_ratio (gentle low bias)
				rrand(0.0, 1.0),          // fm_amount
				rrand(0, 8).round,        // combo_mode
				rrand(0.0, 1.0),          // combo_mix
				rrand(0, 2).round,        // noise_type
				rrand(0.0, 1.0),          // noise_level
				rrand(0.0, 1.0),          // noise_to_osc1
				rrand(0.0, 1.0),          // noise_to_osc2
				// Filter - pow(1.5) gentle low bias
				1.0.rand.pow(1.5).linexp(0, 1, 20, 20000), // filter_freq
				rrand(0.0, 0.99),         // filter_res
				rrand(0, 3).round,        // filter_type
				rrand(0.0, 1.0),          // filter_track
				rrand(0.3, 0.7)           // output_level
			]
		}
	});

	"[Griddlecake] Voice LUT complete (%.2f MB)".format((65536 * 20 * 4) / 1048576).postln;

	"[Griddlecake] Generating FX LUT (65536 × 19 params)...".postln;

	// Generate 65536 randomized FX parameter sets
	~fxLut = Array.fill(65536, { |i|
		if (i == 0) {
			// State 0: 100% dry (all FX bypassed)
			[
				16,    // lofi_bits - full resolution
				48000, // lofi_rate - full sample rate
				0,     // lofi_mix - dry
				440,   // ring_freq
				0,     // ring_wave
				0,     // ring_mix - dry
				440,   // comb_freq
				0.5,   // comb_decay
				0,     // comb_mix - dry
				250,   // delay_time
				0,     // delay_fb
				0,     // delay_mix - dry
				0.5,   // clouds_pos
				0.5,   // clouds_size
				0.5,   // clouds_dens
				0.5,   // clouds_tex
				0,     // clouds_mode
				0,     // clouds_rvb - no reverb
				0      // clouds_mix - dry
			]
		} {
			thisThread.randSeed = ~lutSeed + 65536 + i; // Different seed offset
			[
				// Lo-Fi
				rrand(1, 16).round,       // lofi_bits
				1.0.rand.pow(1.5).linexp(0, 1, 100, 48000),  // lofi_rate (gentle low bias)
				rrand(0.0, 1.0),          // lofi_mix
				// Ring mod - moderate low bias
				1.0.rand.pow(1.8).linexp(0, 1, 20, 2000),  // ring_freq
				rrand(0, 3).round,        // ring_wave
				rrand(0.0, 1.0),          // ring_mix
				// Comb - moderate low bias
				1.0.rand.pow(1.8).linexp(0, 1, 20, 5000),  // comb_freq
				exprand(0.01, 5.0),       // comb_decay
				rrand(0.0, 1.0),          // comb_mix
				// Delay
				1.0.rand.pow(1.2).linexp(0, 1, 1, 2000),   // delay_time (ms)
				rrand(0.0, 0.99),         // delay_fb
				rrand(0.0, 1.0),          // delay_mix
				rrand(0.0, 1.0),          // clouds_pos
				rrand(0.0, 1.0),          // clouds_size
				rrand(0.0, 1.0),          // clouds_dens
				rrand(0.0, 1.0),          // clouds_tex
				rrand(0, 3).round,        // clouds_mode
				rrand(0.0, 1.0),          // clouds_rvb
				rrand(0.0, 1.0)           // clouds_mix
			]
		}
	});

	"[Griddlecake] FX LUT complete (%.2f MB)".format((65536 * 19 * 4) / 1048576).postln;

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
	// CREATE DRONE SYNTH
	// ========================================

	"[Griddlecake] Creating drone synth...".postln;
	~drone = Synth(\chaosDrone);
	s.sync;

	// ========================================
	// INITIALIZE STATE
	// ========================================

	~voiceIndex = 0;
	~fxIndex = 0;

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

	// Set slew time
	~setSlew = { |time|
		~drone.set(\slew_time, time);
		"[Griddlecake] Slew time: % sec".format(time).postln;
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

	// Current 16-bit DAC state for param grid
	~dacState = 0;

	// Connect to grid
	~connectGrid = {
		"[Griddlecake] Connecting to grid at %:%".format(~gridIP, ~gridPort).postln;
		~grid = GridInterface(~gridIP, ~gridPort, oscgrid: true);

		// Set up key handler
		~grid.key({ |x, y, state|
			var zone = ~grid.getZone(x, y);

			if (state == 1) {
				switch(zone,
					\navigation, {
						// Column 0: page select
						if (y == 0) { ~currentPage = 0; "[Grid] Page: Synth".postln };
						if (y == 1) { ~currentPage = 1; "[Grid] Page: FX".postln };
						~updateGridLEDs.();
					},
					\paramGrid, {
						// Cols 1-4, rows 0-3: 16-bit DAC toggle
						var bitPos = ((y * 4) + (x - 1));
						~dacState = ~dacState.bitXor(1 << (15 - bitPos));
						"[Grid] DAC state: % (bit % toggled)".format(~dacState, 15 - bitPos).postln;

						// Apply to current page's LUT
						if (~currentPage == 0) {
							~applyVoiceState.(~dacState);
						} {
							~applyFxState.(~dacState);
						};
						~updateGridLEDs.();
					},
					\slewGrid, {
						// Cols 5-8, rows 0-3: slew time select
						var slewIdx = ((y * 4) + (x - 5));
						var slewTime = slewIdx.linexp(0, 15, 0.01, 10.0);
						~setSlew.(slewTime);
					},
					\utilities, {
						// Cols 9-11, rows 0-3: row operations
						"[Grid] Utility: %, %".format(x, y).postln;
					},
					\gestures, {
						// Cols 12-15, rows 0-3: gesture slots
						var slot = ((y * 4) + (x - 12));
						"[Grid] Gesture slot: %".format(slot).postln;
					},
					\sequencer, {
						// Rows 4-7: sequencer
						var step = x;
						var row = y - 4;
						"[Grid] Seq step: %, row: %".format(step, row).postln;
					}
				);
			};
		});

		// LED update function
		~updateGridLEDs = {
			// Clear param grid
			4.do { |y| 4.do { |x|
				var bitPos = ((y * 4) + x);
				var isOn = (~dacState >> (15 - bitPos)) & 1;
				~grid.led(x + 1, y, isOn * GridInterface.ledFull);
			}};

			// Page indicator
			~grid.led(0, 0, if(~currentPage == 0) { GridInterface.ledFull } { GridInterface.ledDim });
			~grid.led(0, 1, if(~currentPage == 1) { GridInterface.ledFull } { GridInterface.ledDim });
		};

		// Initial LED state
		~updateGridLEDs.();

		"[Griddlecake] Grid connected".postln;
	};

	// Disconnect grid
	~disconnectGrid = {
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
	"[Griddlecake] LUT seed: %".format(~lutSeed).postln;
	"[Griddlecake] Voice index: %".format(~voiceIndex).postln;
	"[Griddlecake] FX index: %".format(~fxIndex).postln;
	"[Griddlecake] Drone synth: %".format(~drone).postln;
	"[Griddlecake] ========================================".postln;
	"[Griddlecake] Available functions:".postln;
	"[Griddlecake]   ~applyVoiceState.(index)       - Apply voice state".postln;
	"[Griddlecake]   ~applyFxState.(index)          - Apply FX state".postln;
	"[Griddlecake]   ~applyFullState.(voice, fx)    - Apply both".postln;
	"[Griddlecake]   ~setVoiceState.(index, time)   - Voice with slew".postln;
	"[Griddlecake]   ~setFxState.(index, time)      - FX with slew".postln;
	"[Griddlecake]   ~testVoice.()                  - Test voice states".postln;
	"[Griddlecake]   ~testFx.()                     - Test FX states".postln;
	"[Griddlecake]   ~randomize.()                  - Randomize both".postln;
	"[Griddlecake]   ~showSeed.()                   - Show LUT seed".postln;
	"[Griddlecake]   ~setSlew.(time)                - Set param slew time".postln;
	"[Griddlecake]   ~eq.(low, mid, high)           - Set EQ gains (dB)".postln;
	"[Griddlecake]   ~eqFreqs.(low, mid, high)      - Set EQ freqs (Hz)".postln;
	"[Griddlecake]   ~eqMidQ.(q)                    - Set mid Q".postln;
	"[Griddlecake]   ~eqBypass.()                   - Bypass EQ".postln;
	"[Griddlecake]   ~comp.(th, rat, atk, rel, mk)  - Set compressor".postln;
	"[Griddlecake]   ~compBypass.()                 - Bypass compressor".postln;
	"[Griddlecake] Grid:".postln;
	"[Griddlecake]   ~connectGrid.()               - Connect to oscgrid".postln;
	"[Griddlecake]   ~disconnectGrid.()            - Disconnect grid".postln;
	"[Griddlecake]   ~gridIP = \"x.x.x.x\"           - Set iPad IP".postln;
	"[Griddlecake] ========================================".postln;

	// Apply initial state
	~applyFullState.(0, 0);
});

)
