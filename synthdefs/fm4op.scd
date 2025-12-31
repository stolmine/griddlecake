// 4-Operator FM Engine for Griddlecake
// 8 algorithms, per-operator feedback, harmonic ratio weighting
//
// Voice params (20):
//   p0-p1:   Base (freq, algorithm)
//   p2-p5:   Ratios (op1-4)
//   p6-p9:   Levels (op1-4)
//   p10-p13: Feedback (op1-4)
//   p14-p15: Fine tune (op1, op3)
//   p16-p17: Global (fb, brightness)
//   p18-p19: Reserved
//
// FX params (20): wavefolder, chorus, filter, delay, clouds
// Note: fx_lib.scd is loaded by main.scd before engine loading

SynthDef(\fm4op, {
	arg gate = 1,
	// Voice params
	base_freq = 110, algorithm = 0,
	op1_ratio = 1, op2_ratio = 2, op3_ratio = 3, op4_ratio = 4,
	op1_level = 1, op2_level = 0.5, op3_level = 0.5, op4_level = 0.5,
	op1_fb = 0, op2_fb = 0, op3_fb = 0, op4_fb = 0,
	op1_fine = 0, op3_fine = 0,
	fb_global = 0, brightness = 1,
	reserved1 = 0, reserved2 = 0,
	// FX params
	fold_drive = 0.5, fold_sym = 0, fold_mix = 0,
	chorus_rate = 0.5, chorus_depth = 0.5, chorus_mix = 0,
	filt_freq = 8000, filt_res = 0, filt_mode = 0, filt_mix = 0,
	delay_time = 250, delay_fb = 0.3, delay_mix = 0,
	clouds_pos = 0.5, clouds_size = 0.5, clouds_dens = 0.5,
	clouds_tex = 0.5, clouds_mode = 0, clouds_rvb = 0, clouds_mix = 0,
	// Master
	eq_low = 0, eq_mid = 0, eq_high = 0,
	comp_thresh = 0.5, comp_ratio = 4,
	output_level = 0.5,
	// Slew control
	slew_time = 0.1, slew_curve = 0;

	var sig, env;
	var f1, f2, f3, f4;
	var op1, op2, op3, op4;
	var mod2, mod3, mod4;
	var fbGlobal;
	var alg;

	// Per-param slew with curve (VarLag: in, time, warp)
	base_freq = VarLag.kr(base_freq, slew_time, slew_curve);
	algorithm = VarLag.kr(algorithm, slew_time, slew_curve);
	op1_ratio = VarLag.kr(op1_ratio, slew_time, slew_curve);
	op2_ratio = VarLag.kr(op2_ratio, slew_time, slew_curve);
	op3_ratio = VarLag.kr(op3_ratio, slew_time, slew_curve);
	op4_ratio = VarLag.kr(op4_ratio, slew_time, slew_curve);
	op1_level = VarLag.kr(op1_level, slew_time, slew_curve);
	op2_level = VarLag.kr(op2_level, slew_time, slew_curve);
	op3_level = VarLag.kr(op3_level, slew_time, slew_curve);
	op4_level = VarLag.kr(op4_level, slew_time, slew_curve);
	op1_fb = VarLag.kr(op1_fb, slew_time, slew_curve);
	op2_fb = VarLag.kr(op2_fb, slew_time, slew_curve);
	op3_fb = VarLag.kr(op3_fb, slew_time, slew_curve);
	op4_fb = VarLag.kr(op4_fb, slew_time, slew_curve);
	op1_fine = VarLag.kr(op1_fine, slew_time, slew_curve);
	op3_fine = VarLag.kr(op3_fine, slew_time, slew_curve);
	fb_global = VarLag.kr(fb_global, slew_time, slew_curve);
	brightness = VarLag.kr(brightness, slew_time, slew_curve);
	// FX params
	fold_drive = VarLag.kr(fold_drive, slew_time, slew_curve);
	fold_sym = VarLag.kr(fold_sym, slew_time, slew_curve);
	fold_mix = VarLag.kr(fold_mix, slew_time, slew_curve);
	chorus_rate = VarLag.kr(chorus_rate, slew_time, slew_curve);
	chorus_depth = VarLag.kr(chorus_depth, slew_time, slew_curve);
	chorus_mix = VarLag.kr(chorus_mix, slew_time, slew_curve);
	filt_freq = VarLag.kr(filt_freq, slew_time, slew_curve);
	filt_res = VarLag.kr(filt_res, slew_time, slew_curve);
	filt_mode = VarLag.kr(filt_mode, slew_time, slew_curve);
	filt_mix = VarLag.kr(filt_mix, slew_time, slew_curve);
	delay_time = VarLag.kr(delay_time, slew_time, slew_curve);
	delay_fb = VarLag.kr(delay_fb, slew_time, slew_curve);
	delay_mix = VarLag.kr(delay_mix, slew_time, slew_curve);
	clouds_pos = VarLag.kr(clouds_pos, slew_time, slew_curve);
	clouds_size = VarLag.kr(clouds_size, slew_time, slew_curve);
	clouds_dens = VarLag.kr(clouds_dens, slew_time, slew_curve);
	clouds_tex = VarLag.kr(clouds_tex, slew_time, slew_curve);
	clouds_mode = VarLag.kr(clouds_mode, slew_time, slew_curve);
	clouds_rvb = VarLag.kr(clouds_rvb, slew_time, slew_curve);
	clouds_mix = VarLag.kr(clouds_mix, slew_time, slew_curve);
	output_level = VarLag.kr(output_level, slew_time, slew_curve);

	// Operator frequencies with fine tuning
	f1 = base_freq * op1_ratio * (1 + (op1_fine * 0.01));
	f2 = base_freq * op2_ratio;
	f3 = base_freq * op3_ratio * (1 + (op3_fine * 0.01));
	f4 = base_freq * op4_ratio;

	// Scale levels by brightness
	mod2 = op2_level * brightness;
	mod3 = op3_level * brightness;
	mod4 = op4_level * brightness;

	// Feedback signals (initialized to 0, updated via LocalIn)
	fbGlobal = LocalIn.ar(1) * fb_global;

	// Build operators based on algorithm
	alg = algorithm.round.clip(0, 7);

	// Algorithm implementations (all 8, select at audio rate)
	sig = Select.ar(alg, [
		// Alg 0: [4]→[3]→[2]→[1]→OUT (full series)
		{
			op4 = SinOsc.ar(f4, SinOsc.ar(f4, 0, op4_fb * 4)) * mod4;
			op3 = SinOsc.ar(f3, op4 + SinOsc.ar(f3, 0, op3_fb * 4)) * mod3;
			op2 = SinOsc.ar(f2, op3 + SinOsc.ar(f2, 0, op2_fb * 4)) * mod2;
			op1 = SinOsc.ar(f1, op2 + fbGlobal + SinOsc.ar(f1, 0, op1_fb * 4)) * op1_level;
			op1
		}.(),

		// Alg 1: [4]→[3]→[2]↘[1]→OUT (3-series into carrier)
		{
			op4 = SinOsc.ar(f4, SinOsc.ar(f4, 0, op4_fb * 4)) * mod4;
			op3 = SinOsc.ar(f3, op4 + SinOsc.ar(f3, 0, op3_fb * 4)) * mod3;
			op2 = SinOsc.ar(f2, op3 + SinOsc.ar(f2, 0, op2_fb * 4)) * mod2;
			op1 = SinOsc.ar(f1, op2 + op3 + fbGlobal + SinOsc.ar(f1, 0, op1_fb * 4)) * op1_level;
			op1
		}.(),

		// Alg 2: [4]→[3]↘[2]→[1]→OUT (branch at 3)
		{
			op4 = SinOsc.ar(f4, SinOsc.ar(f4, 0, op4_fb * 4)) * mod4;
			op3 = SinOsc.ar(f3, op4 + SinOsc.ar(f3, 0, op3_fb * 4)) * mod3;
			op2 = SinOsc.ar(f2, op3 + SinOsc.ar(f2, 0, op2_fb * 4)) * mod2;
			op1 = SinOsc.ar(f1, op2 + fbGlobal + SinOsc.ar(f1, 0, op1_fb * 4)) * op1_level;
			op1 + (op3 * 0.5)
		}.(),

		// Alg 3: [4]→[3]→OUT + [2]→[1]→OUT (dual 2-op stacks)
		{
			op4 = SinOsc.ar(f4, SinOsc.ar(f4, 0, op4_fb * 4)) * mod4;
			op3 = SinOsc.ar(f3, op4 + fbGlobal + SinOsc.ar(f3, 0, op3_fb * 4)) * op3_level;
			op2 = SinOsc.ar(f2, SinOsc.ar(f2, 0, op2_fb * 4)) * mod2;
			op1 = SinOsc.ar(f1, op2 + fbGlobal + SinOsc.ar(f1, 0, op1_fb * 4)) * op1_level;
			(op1 + op3) * 0.7
		}.(),

		// Alg 4: [4]→[3]→OUT, [2]→OUT, [1]→OUT (1 mod, 3 carriers)
		{
			op4 = SinOsc.ar(f4, SinOsc.ar(f4, 0, op4_fb * 4)) * mod4;
			op3 = SinOsc.ar(f3, op4 + fbGlobal + SinOsc.ar(f3, 0, op3_fb * 4)) * op3_level;
			op2 = SinOsc.ar(f2, fbGlobal + SinOsc.ar(f2, 0, op2_fb * 4)) * op2_level;
			op1 = SinOsc.ar(f1, fbGlobal + SinOsc.ar(f1, 0, op1_fb * 4)) * op1_level;
			(op1 + op2 + op3) * 0.5
		}.(),

		// Alg 5: [4]↘[3]→[2]→OUT, [1]→OUT (branch from 4)
		{
			op4 = SinOsc.ar(f4, SinOsc.ar(f4, 0, op4_fb * 4)) * mod4;
			op3 = SinOsc.ar(f3, op4 + SinOsc.ar(f3, 0, op3_fb * 4)) * mod3;
			op2 = SinOsc.ar(f2, op3 + op4 + fbGlobal + SinOsc.ar(f2, 0, op2_fb * 4)) * op2_level;
			op1 = SinOsc.ar(f1, fbGlobal + SinOsc.ar(f1, 0, op1_fb * 4)) * op1_level;
			(op1 + op2) * 0.7
		}.(),

		// Alg 6: [4]→[3],[2],[1]→OUT (1 mod to 3 carriers)
		{
			op4 = SinOsc.ar(f4, SinOsc.ar(f4, 0, op4_fb * 4)) * mod4;
			op3 = SinOsc.ar(f3, op4 + fbGlobal + SinOsc.ar(f3, 0, op3_fb * 4)) * op3_level;
			op2 = SinOsc.ar(f2, op4 + fbGlobal + SinOsc.ar(f2, 0, op2_fb * 4)) * op2_level;
			op1 = SinOsc.ar(f1, op4 + fbGlobal + SinOsc.ar(f1, 0, op1_fb * 4)) * op1_level;
			(op1 + op2 + op3) * 0.5
		}.(),

		// Alg 7: [4]+[3]+[2]+[1]→OUT (pure additive)
		{
			op4 = SinOsc.ar(f4, fbGlobal + SinOsc.ar(f4, 0, op4_fb * 4)) * op4_level;
			op3 = SinOsc.ar(f3, fbGlobal + SinOsc.ar(f3, 0, op3_fb * 4)) * op3_level;
			op2 = SinOsc.ar(f2, fbGlobal + SinOsc.ar(f2, 0, op2_fb * 4)) * op2_level;
			op1 = SinOsc.ar(f1, fbGlobal + SinOsc.ar(f1, 0, op1_fb * 4)) * op1_level;
			(op1 + op2 + op3 + op4) * 0.4
		}.()
	]);

	// Global feedback (delayed signal back into modulators)
	LocalOut.ar(DelayN.ar(sig, 0.01, 0.001));

	// === FX Chain B ===
	sig = ~fxWavefold.(sig, fold_drive, fold_sym, fold_mix);
	sig = ~fxChorus.(sig, chorus_rate, chorus_depth, chorus_mix);
	sig = ~fxFilter.(sig, filt_freq, filt_res, filt_mode, filt_mix);
	sig = ~fxDelay.(sig, delay_time, delay_fb, delay_mix);
	sig = ~fxClouds.(sig, clouds_pos, clouds_size, clouds_dens, clouds_tex, clouds_mode, clouds_rvb, clouds_mix);

	// EQ + Compression
	sig = ~fxEQ.(sig, 100, eq_low, 1000, eq_mid, 1, 5000, eq_high);
	sig = ~fxComp.(sig, comp_thresh, comp_ratio, 0.01, 0.1, 1);

	// Crossfade envelope for engine switching
	env = EnvGen.kr(Env.asr(0.1, 1, 0.5), gate, doneAction: 2);

	// Output
	sig = sig * output_level * env;
	sig = Limiter.ar(sig, 0.95);
	Out.ar(0, sig ! 2);
}).add;

// === Engine Specification ===

(
	key: \fm4op,
	name: "4-Op FM",
	synthDef: \fm4op,
	implemented: true,

	// Voice params (20)
	voiceParams: [
		(idx: 0,  name: \base_freq,   min: 20,   max: 500,  curve: \exp, default: 110),
		(idx: 1,  name: \algorithm,   min: 0,    max: 7,    curve: \lin, default: 0),
		(idx: 2,  name: \op1_ratio,   min: 0.5,  max: 16,   curve: \exp, default: 1),
		(idx: 3,  name: \op2_ratio,   min: 0.5,  max: 16,   curve: \exp, default: 2),
		(idx: 4,  name: \op3_ratio,   min: 0.5,  max: 16,   curve: \exp, default: 3),
		(idx: 5,  name: \op4_ratio,   min: 0.5,  max: 16,   curve: \exp, default: 4),
		(idx: 6,  name: \op1_level,   min: 0,    max: 1,    curve: \lin, default: 1),
		(idx: 7,  name: \op2_level,   min: 0,    max: 1,    curve: \lin, default: 0.5),
		(idx: 8,  name: \op3_level,   min: 0,    max: 1,    curve: \lin, default: 0.5),
		(idx: 9,  name: \op4_level,   min: 0,    max: 1,    curve: \lin, default: 0.5),
		(idx: 10, name: \op1_fb,      min: 0,    max: 1,    curve: \lin, default: 0),
		(idx: 11, name: \op2_fb,      min: 0,    max: 1,    curve: \lin, default: 0),
		(idx: 12, name: \op3_fb,      min: 0,    max: 1,    curve: \lin, default: 0),
		(idx: 13, name: \op4_fb,      min: 0,    max: 1,    curve: \lin, default: 0),
		(idx: 14, name: \op1_fine,    min: -1,   max: 1,    curve: \lin, default: 0),
		(idx: 15, name: \op3_fine,    min: -1,   max: 1,    curve: \lin, default: 0),
		(idx: 16, name: \fb_global,   min: 0,    max: 1,    curve: \lin, default: 0),
		(idx: 17, name: \brightness,  min: 0,    max: 1,    curve: \lin, default: 1),
		(idx: 18, name: \reserved1,   min: 0,    max: 1,    curve: \lin, default: 0),
		(idx: 19, name: \reserved2,   min: 0,    max: 1,    curve: \lin, default: 0),
	],

	// FX params (20)
	fxParams: [
		(idx: 0,  name: \fold_drive,   min: 0,    max: 1,     curve: \lin, default: 0.5),
		(idx: 1,  name: \fold_sym,     min: 0,    max: 1,     curve: \lin, default: 0),
		(idx: 2,  name: \fold_mix,     min: 0,    max: 1,     curve: \lin, default: 0),
		(idx: 3,  name: \chorus_rate,  min: 0.1,  max: 5,     curve: \exp, default: 0.5),
		(idx: 4,  name: \chorus_depth, min: 0,    max: 1,     curve: \lin, default: 0.5),
		(idx: 5,  name: \chorus_mix,   min: 0,    max: 1,     curve: \lin, default: 0),
		(idx: 6,  name: \filt_freq,    min: 100,  max: 16000, curve: \exp, default: 8000),
		(idx: 7,  name: \filt_res,     min: 0,    max: 1,     curve: \lin, default: 0),
		(idx: 8,  name: \filt_mode,    min: 0,    max: 3,     curve: \lin, default: 0),
		(idx: 9,  name: \filt_mix,     min: 0,    max: 1,     curve: \lin, default: 0),
		(idx: 10, name: \delay_time,   min: 1,    max: 2000,  curve: \exp, default: 250),
		(idx: 11, name: \delay_fb,     min: 0,    max: 0.95,  curve: \lin, default: 0.3),
		(idx: 12, name: \delay_mix,    min: 0,    max: 1,     curve: \lin, default: 0),
		(idx: 13, name: \clouds_pos,   min: 0,    max: 1,     curve: \lin, default: 0.5),
		(idx: 14, name: \clouds_size,  min: 0,    max: 1,     curve: \lin, default: 0.5),
		(idx: 15, name: \clouds_dens,  min: 0,    max: 1,     curve: \lin, default: 0.5),
		(idx: 16, name: \clouds_tex,   min: 0,    max: 1,     curve: \lin, default: 0.5),
		(idx: 17, name: \clouds_mode,  min: 0,    max: 3,     curve: \lin, default: 0),
		(idx: 18, name: \clouds_rvb,   min: 0,    max: 1,     curve: \lin, default: 0),
		(idx: 19, name: \clouds_mix,   min: 0,    max: 1,     curve: \lin, default: 0),
	],

	// LUT generator using shared lutLib
	lutGenerator: { |seed|
		var lib = ~lutLib;

		// Harmonic ratios weighted toward simple intervals
		var ratios = [1, 2, 3, 4, 0.5, 1.5, 2.5, 3.5, 5, 6, 7, 8, 0.25, 0.75, 1.25, 2.25];

		var voiceHome = [
			110, 0,           // base_freq, algorithm
			1, 2, 3, 4,       // ratios (1:2:3:4 = classic)
			1, 0.5, 0.5, 0.5, // levels
			0, 0, 0, 0,       // no feedback
			0, 0,             // no detune
			0, 1,             // no global fb, full brightness
			0, 0              // reserved
		];

		var fxHome = [
			0.5, 0, 0,        // wavefold: half drive, no sym, dry
			0.5, 0.5, 0,      // chorus: moderate rate/depth, dry
			8000, 0, 0, 0,    // filter: open, no res, LP, dry
			250, 0.3, 0,      // delay: 250ms, 30% fb, dry
			0.5, 0.5, 0.5, 0.5, 0, 0, 0  // clouds: centered, mode 0, dry
		];

		var voiceGen = {
			[
				// Base frequency - strong low bias for drones
				lib[\freq].(20, 500, 2.0),
				// Algorithm - equal distribution
				lib[\int].(8),
				// Operator ratios - weighted toward simple harmonics
				lib[\choose].(ratios),
				lib[\choose].(ratios),
				lib[\choose].(ratios),
				lib[\choose].(ratios),
				// Operator levels - carrier louder, mods varied
				lib[\linear].(0.5, 1.0),
				lib[\curved].(1.0, 0.8),
				lib[\curved].(1.0, 0.8),
				lib[\curved].(1.0, 0.8),
				// Feedback - mostly subtle
				lib[\curved].(0.6, 1.5),
				lib[\curved].(0.6, 1.5),
				lib[\curved].(0.6, 1.5),
				lib[\curved].(0.6, 1.5),
				// Fine tuning - small deviations
				lib[\linear].(-0.3, 0.3),
				lib[\linear].(-0.3, 0.3),
				// Global feedback - subtle
				lib[\curved].(0.5, 1.2),
				// Brightness - mostly bright
				lib[\linear].(0.5, 1.0),
				// Reserved
				0, 0
			]
		};

		var fxGen = {
			[
				// Wavefolder
				lib[\linear].(0.3, 1.0),
				lib[\linear].(0.0, 0.5),
				lib[\curved].(0.6, 1.2),
				// Chorus
				lib[\exp].(0.1, 3),
				lib[\linear].(0.2, 0.8),
				lib[\curved].(0.5, 1.0),
				// Filter
				lib[\freq].(200, 12000, 0.7),
				lib[\curved].(0.7, 1.0),
				lib[\int].(4),
				lib[\curved].(0.8, 1.0),
				// Delay
				lib[\exp].(50, 1500),
				lib[\linear].(0.1, 0.7),
				lib[\curved].(0.5, 1.0),
			] ++ lib[\clouds].()
		};

		lib[\buildPair].(seed, voiceHome, voiceGen, fxHome, fxGen)
	},
)
