// Griddlecake - Main Boot File
// Modular structure: main.scd loads clock_sequencer.scd and grid_handler.scd
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

	// Load shared libraries (used by all engines)
	~synthdefs_dir = thisProcess.nowExecutingPath.dirname +/+ "synthdefs";
	~lutLib = (~synthdefs_dir +/+ "lut_lib.scd").load;
	"[Griddlecake] Loaded LUT library".postln;
	(~synthdefs_dir +/+ "fx_lib.scd").load;
	"[Griddlecake] Loaded FX library".postln;

	// Load engine files - each returns a spec dictionary
	~loadEngine = { |filename|
		var path = ~synthdefs_dir +/+ filename;
		var spec = path.load;
		if (spec.notNil && spec[\key].notNil) {
			// Validate required keys
			if (spec[\synthDef].isNil) {
				"[Griddlecake]   WARNING: Engine % missing synthDef".format(spec[\key]).warn;
			};
			if (spec[\voiceParams].isNil || spec[\fxParams].isNil) {
				"[Griddlecake]   WARNING: Engine % missing param specs".format(spec[\key]).warn;
			};
			if (spec[\lutGenerator].isNil) {
				"[Griddlecake]   WARNING: Engine % missing lutGenerator".format(spec[\key]).warn;
			};
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
	~loadEngine.("fm4op.scd");
	~loadEngine.("wavetable.scd");
	s.sync;

	// ========================================
	// WAVETABLE BUFFER MANAGEMENT
	// ========================================

	~wtBufs = nil;
	~wtBufBase = nil;

	~allocWavetables = {
		var size = 2048;
		"[Griddlecake] Allocating wavetable buffers...".postln;

		~wtBufs = Buffer.allocConsecutive(64, s, size);
		s.sync;
		~wtBufBase = ~wtBufs[0].bufnum;

		// Bank 0: Harmonic (sine → saw)
		8.do { |i|
			var numHarmonics = (i + 1) * 2;
			~wtBufs[0 * 8 + i].sine1((1..numHarmonics).collect { |h| 1.0 / h }, asWavetable: true);
		};

		// Bank 1: Odd harmonics (sine → square)
		8.do { |i|
			var numHarmonics = (i + 1) * 2;
			~wtBufs[1 * 8 + i].sine1((1, 3..numHarmonics * 2).collect { |h| 1.0 / h }, asWavetable: true);
		};

		// Bank 2: Formant (vocal-like)
		[[1, 0.3, 0, 0.2], [1, 0.5, 0.3, 0], [1, 0, 0.5, 0.2, 0], [1, 0.2, 0, 0.4, 0.1],
		 [1, 0, 0, 0.3, 0, 0.2], [1, 0.4, 0.2, 0.3, 0.1], [1, 0.1, 0.5, 0.1, 0.3], [1, 0.3, 0.3, 0.3, 0.1]
		].do { |amps, i| ~wtBufs[2 * 8 + i].sine1(amps, asWavetable: true) };

		// Bank 3: PWM-like
		8.do { |i|
			var duty = (i + 1) / 9;
			~wtBufs[3 * 8 + i].sine1((1..16).collect { |h| (2 / (h * pi)) * sin(h * pi * duty) }, asWavetable: true);
		};

		// Bank 4: Metallic
		8.do { |i|
			var detune = 1 + (i * 0.03);
			~wtBufs[4 * 8 + i].sine1(Array.fill(12, { |h| if ((h + 1) * (detune ** h) < 16) { 1.0 / (h + 1) } { 0 } }), asWavetable: true);
		};

		// Bank 5: Organ
		[[1], [1, 1], [1, 0, 1], [1, 1, 1], [1, 1, 1, 1], [1, 0.5, 1, 0.5, 1], [1, 0.8, 0.6, 0.8, 0.6, 0.4], [0.5, 1, 0.5, 1, 0.5, 1, 0.3]
		].do { |amps, i| ~wtBufs[5 * 8 + i].sine1(amps, asWavetable: true) };

		// Bank 6: Bright
		8.do { |i|
			var boost = i + 1;
			~wtBufs[6 * 8 + i].sine1((1..20).collect { |h| if (h > 4) { boost / h } { 1.0 / h } }, asWavetable: true);
		};

		// Bank 7: Soft
		8.do { |i|
			var rolloff = 1.5 + (i * 0.3);
			~wtBufs[7 * 8 + i].sine1((1..12).collect { |h| 1.0 / (h ** rolloff) }, asWavetable: true);
		};

		s.sync;
		"[Griddlecake] Wavetable buffers allocated (base: %)".format(~wtBufBase).postln;
	};

	~freeWavetables = {
		if (~wtBufs.notNil) {
			"[Griddlecake] Freeing wavetable buffers...".postln;
			~wtBufs.do { |buf| buf.free };
			~wtBufs = nil;
			~wtBufBase = nil;
		};
	};

	// Set initial engine
	~currentEngine = \drone;
	"[Griddlecake] Active engine: %".format(~engines[~currentEngine][\name]).postln;

	// ========================================
	// INITIALIZE LUT
	// ========================================

	if (~useSeed.notNil) {
		~lutSeed = ~useSeed;
		~useSeed = nil;
		"[Griddlecake] Using provided seed: %".format(~lutSeed).postln;
	} {
		~lutSeed = Date.seed;
		"[Griddlecake] Generated new seed: %".format(~lutSeed).postln;
	};

	~lutCache = Dictionary.new;

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

	~clearLutCache = { ~lutCache.clear; "[Griddlecake] LUT cache cleared".postln; };

	~luts = ~getLuts.(~currentEngine);
	~voiceLut = ~luts[\voice];
	~fxLut = ~luts[\fx];

	"[Griddlecake] Voice LUT: % entries".format(~voiceLut.size).postln;
	"[Griddlecake] FX LUT: % entries".format(~fxLut.size).postln;

	// ========================================
	// PARAMETER NAMES (derived from engine)
	// ========================================

	~getEngineParamNames = {
		var engine = ~engines[~currentEngine];
		~voiceParamNames = engine[\voiceParams].collect({ |p| p[\name] });
		~fxParamNames = engine[\fxParams].collect({ |p| p[\name] });
	};

	~getEngineParamNames.();

	// ========================================
	// CREATE SYNTH
	// ========================================

	"[Griddlecake] Creating synth (%)...".format(~currentEngine).postln;
	~synth = Synth(~engines[~currentEngine][\synthDef]);
	s.sync;
	~drone = ~synth;

	// ========================================
	// ENGINE SWITCHING
	// ========================================

	~engineModalActive = false;

	~switchEngine = { |newEngineKey|
		var engine = ~engines[newEngineKey];

		if (engine.isNil) {
			"[Griddlecake] Unknown engine: %".format(newEngineKey).warn;
		} {
			if ((engine[\implemented] ? false).not) {
				"[Griddlecake] Engine not implemented: %".format(newEngineKey).warn;
			} {
				var oldSynth = ~synth;
				var oldEngine = ~currentEngine;
				var luts;

				"[Griddlecake] Switching to engine: %".format(engine[\name]).postln;

				luts = ~getLuts.(newEngineKey);
				~voiceLut = luts[\voice];
				~fxLut = luts[\fx];

				~currentEngine = newEngineKey;
				~getEngineParamNames.();
				oldSynth.set(\gate, 0);

				fork {
					0.12.wait;

					if ((oldEngine == \wavetable) && (newEngineKey != \wavetable)) {
						~freeWavetables.();
					};

					if ((newEngineKey == \wavetable) && ~wtBufs.isNil) {
						~allocWavetables.();
					};

					if (newEngineKey == \wavetable) {
						~synth = Synth(engine[\synthDef], [
							\wt_buf_base, ~wtBufBase,
							\output_level, 0.5,
							\slew_time, ~getSlewTime.(),
							\slew_curve, ~getSlewCurve.(),
							\gate, 1
						]);
					} {
						~synth = Synth(engine[\synthDef], [
							\output_level, 0.5,
							\slew_time, ~getSlewTime.(),
							\slew_curve, ~getSlewCurve.(),
							\gate, 1
						]);
					};
					~drone = ~synth;

					s.sync;

					~applyVoiceState.(~voiceDacState);
					~applyFxState.(~fxDacState);

					"[Griddlecake] Engine switch complete: %".format(engine[\name]).postln;
				};
			};
		};
	};

	// ========================================
	// STATE MANAGEMENT
	// ========================================

	~voiceIndex = 0;
	~fxIndex = 0;
	~recordingSlot = nil;

	~applyVoiceState = { |index|
		var params = ~voiceLut[index.asInteger.clip(0, 65535)];
		~voiceParamNames.do({ |name, i| ~synth.set(name, params[i]); });
		~voiceIndex = index.asInteger;
	};

	~applyFxState = { |index|
		var params = ~fxLut[index.asInteger.clip(0, 65535)];
		~fxParamNames.do({ |name, i| ~synth.set(name, params[i]); });
		~fxIndex = index.asInteger;
	};

	~applyFullState = { |voiceIdx, fxIdx|
		~applyVoiceState.(voiceIdx);
		~applyFxState.(fxIdx);
		"[Griddlecake] Applied state: voice % / fx %".format(~voiceIndex, ~fxIndex).postln;
	};

	~setVoiceState = { |targetIndex, slewTime = 1.0|
		var startParams = ~voiceLut[~voiceIndex.clip(0, 65535)];
		var endIndex = targetIndex.asInteger.clip(0, 65535);
		var endParams = ~voiceLut[endIndex];
		var startTime = Main.elapsedTime;
		var duration = slewTime;

		if (~voiceSlewRoutine.notNil) { ~voiceSlewRoutine.stop; };

		~voiceSlewRoutine = Routine({
			var elapsed, progress, interpParams;
			loop {
				elapsed = Main.elapsedTime - startTime;
				progress = (elapsed / duration).clip(0, 1);
				interpParams = startParams.collect({ |startVal, i| startVal + ((endParams[i] - startVal) * progress); });
				~voiceParamNames.do({ |name, i| ~synth.set(name, interpParams[i]); });
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

	~setFxState = { |targetIndex, slewTime = 1.0|
		var startParams = ~fxLut[~fxIndex.clip(0, 65535)];
		var endIndex = targetIndex.asInteger.clip(0, 65535);
		var endParams = ~fxLut[endIndex];
		var startTime = Main.elapsedTime;
		var duration = slewTime;

		if (~fxSlewRoutine.notNil) { ~fxSlewRoutine.stop; };

		~fxSlewRoutine = Routine({
			var elapsed, progress, interpParams;
			loop {
				elapsed = Main.elapsedTime - startTime;
				progress = (elapsed / duration).clip(0, 1);
				interpParams = startParams.collect({ |startVal, i| startVal + ((endParams[i] - startVal) * progress); });
				~fxParamNames.do({ |name, i| ~synth.set(name, interpParams[i]); });
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

	~testVoice = {
		var testIndices = [0, 10000, 30000, 50000, 65535];
		"[Griddlecake] Testing voice states...".postln;
		fork { testIndices.do({ |idx| ~applyVoiceState.(idx); "[Griddlecake] Voice test: %".format(idx).postln; 2.wait; }); "[Griddlecake] Voice test complete".postln; };
	};

	~testFx = {
		var testIndices = [0, 10000, 30000, 50000, 65535];
		"[Griddlecake] Testing FX states...".postln;
		fork { testIndices.do({ |idx| ~applyFxState.(idx); "[Griddlecake] FX test: %".format(idx).postln; 2.wait; }); "[Griddlecake] FX test complete".postln; };
	};

	~randomize = {
		var voiceIdx = 65535.rand;
		var fxIdx = 65535.rand;
		~applyFullState.(voiceIdx, fxIdx);
		"[Griddlecake] Randomized: voice % / fx %".format(voiceIdx, fxIdx).postln;
	};

	~showSeed = {
		"[Griddlecake] ========================================".postln;
		"[Griddlecake] LUT Seed: %".format(~lutSeed).postln;
		"[Griddlecake] Voice Index: %".format(~voiceIndex).postln;
		"[Griddlecake] FX Index: %".format(~fxIndex).postln;
		"[Griddlecake] ========================================".postln;
		~lutSeed;
	};

	~setSlew = { |time, curve|
		var timeBits = time.explin(0.01, 10.0, 0, 15).round.asInteger.clip(0, 15);
		~slewTimeBits = timeBits;
		if (curve.notNil) {
			var curveBits = curve.linlin(-8, 8, 0, 15).round.asInteger.clip(0, 15);
			~slewCurveBits = curveBits;
		};
		~applySlew.();
	};

	~setCurve = { |curve|
		var curveBits = curve.linlin(-8, 8, 0, 15).round.asInteger.clip(0, 15);
		~slewCurveBits = curveBits;
		~applySlew.();
	};

	// ========================================
	// EQ & COMPRESSOR
	// ========================================

	~eq = { |low=0, mid=0, high=0|
		~synth.set(\eq_low_gain, low, \eq_mid_gain, mid, \eq_high_gain, high);
		"[Griddlecake] EQ: low %dB, mid %dB, high %dB".format(low, mid, high).postln;
	};

	~eqFreqs = { |low=200, mid=1000, high=4000|
		~synth.set(\eq_low_freq, low, \eq_mid_freq, mid, \eq_high_freq, high);
		"[Griddlecake] EQ freqs: low %Hz, mid %Hz, high %Hz".format(low, mid, high).postln;
	};

	~eqMidQ = { |q=0.5| ~synth.set(\eq_mid_q, q); "[Griddlecake] EQ mid Q: %".format(q).postln; };

	~comp = { |thresh=0.5, ratio=2, attack=0.01, release=0.1, makeup=1|
		~synth.set(\comp_thresh, thresh, \comp_ratio, ratio, \comp_attack, attack, \comp_release, release, \comp_makeup, makeup);
		"[Griddlecake] Comp: thresh %, ratio %:1, atk %s, rel %s, makeup %".format(thresh, ratio, attack, release, makeup).postln;
	};

	~eqBypass = { ~synth.set(\eq_low_gain, 0, \eq_mid_gain, 0, \eq_high_gain, 0); "[Griddlecake] EQ bypassed".postln; };
	~compBypass = { ~synth.set(\comp_ratio, 1, \comp_makeup, 1); "[Griddlecake] Compressor bypassed".postln; };

	// ========================================
	// LOAD MODULES
	// ========================================

	"[Griddlecake] Loading modules...".postln;

	// Load clock & sequencer module
	(thisProcess.nowExecutingPath.dirname +/+ "clock_sequencer.scd").load;

	// Load grid handler module
	(thisProcess.nowExecutingPath.dirname +/+ "grid_handler.scd").load;

	// Initialize sequencer rows with LUT[0] params
	~initSequencerRows.();

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
	"[Griddlecake]   Hold page button              - Engine select modal".postln;
	"[Griddlecake] Clock/Transport:".postln;
	"[Griddlecake]   ~tapTempo.()                  - Register tap for tempo".postln;
	"[Griddlecake]   ~startTransport.()            - Start sequencer".postln;
	"[Griddlecake]   ~bpm                          - Current BPM (%)".format(~bpm).postln;
	"[Griddlecake] ========================================".postln;

	~applyFullState.(0, 0);
});

)
