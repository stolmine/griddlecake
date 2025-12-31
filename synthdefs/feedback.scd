// Feedback Network Engine
// 4 cross-feeding filter+delay paths with filtered exciter + slow LFO modulation
//
// Voice params (24):
//   p0-p3:   Path 1 (gain, filter_freq, filter_res, delay_time)
//   p4-p7:   Path 2
//   p8-p11:  Path 3
//   p12-p15: Path 4
//   p16-p23: Global (master_fb, exciter_type, exciter_level, exciter_freq, exciter_res, cross_feed, lfo_rate, lfo_depth)
//
// FX params (25): tape, filter bank, shimmer, freeze, clouds
// EQ + Comp hardcoded at end (not in LUT)

// Load shared FX library
(thisProcess.nowExecutingPath.dirname +/+ "fx_lib.scd").load;

SynthDef(\feedbackNetwork, {
	arg
	// Path 1
	p1_gain=0.5, p1_freq=400, p1_res=0.3, p1_delay=0.02,
	// Path 2
	p2_gain=0.5, p2_freq=600, p2_res=0.3, p2_delay=0.025,
	// Path 3
	p3_gain=0.5, p3_freq=800, p3_res=0.3, p3_delay=0.03,
	// Path 4
	p4_gain=0.5, p4_freq=1000, p4_res=0.3, p4_delay=0.035,
	// Global
	master_fb=0.7, exciter_type=0, exciter_level=0.3, exciter_freq=1000, exciter_res=0.3, cross_feed=0.2,
	lfo_rate=0.05, lfo_depth=0.3,
	// FX chain: tape, ffb, shimmer, freeze, clouds
	tape_drive=1.5, tape_mix=0,
	ffb_f1=200, ffb_f2=500, ffb_f3=1200, ffb_f4=3000,
	ffb_g1=0.8, ffb_g2=0.8, ffb_g3=0.8, ffb_g4=0.8,
	ffb_res=0.5, ffb_mix=0,
	shimmer_shift=12, shimmer_fb=0.3, shimmer_size=0.8, shimmer_mix=0,
	freeze_amt=0, freeze_mix=0,
	clouds_pos=0.5, clouds_size=0.5, clouds_dens=0.5,
	clouds_tex=0.5, clouds_mode=0, clouds_rvb=0, clouds_mix=0,
	output_level=0.5,
	t_clock=0,
	slew_time=0.1, slew_curve=0,
	// EQ (not in LUT - always at end)
	eq_low_freq=200, eq_low_gain=0,
	eq_mid_freq=1000, eq_mid_gain=0, eq_mid_q=0.5,
	eq_high_freq=4000, eq_high_gain=0,
	// Compressor (not in LUT - always at end)
	comp_thresh=0.5, comp_ratio=2, comp_attack=0.01, comp_release=0.1, comp_makeup=1,
	// Gate for crossfade
	gate=1;

	var exciter, fb, path1, path2, path3, path4, mix, sig;

	// Slew voice params
	p1_gain = VarLag.kr(p1_gain, slew_time, slew_curve);
	p1_freq = VarLag.kr(p1_freq, slew_time, slew_curve);
	p1_res = VarLag.kr(p1_res, slew_time, slew_curve);
	p1_delay = VarLag.kr(p1_delay, slew_time, slew_curve);
	p2_gain = VarLag.kr(p2_gain, slew_time, slew_curve);
	p2_freq = VarLag.kr(p2_freq, slew_time, slew_curve);
	p2_res = VarLag.kr(p2_res, slew_time, slew_curve);
	p2_delay = VarLag.kr(p2_delay, slew_time, slew_curve);
	p3_gain = VarLag.kr(p3_gain, slew_time, slew_curve);
	p3_freq = VarLag.kr(p3_freq, slew_time, slew_curve);
	p3_res = VarLag.kr(p3_res, slew_time, slew_curve);
	p3_delay = VarLag.kr(p3_delay, slew_time, slew_curve);
	p4_gain = VarLag.kr(p4_gain, slew_time, slew_curve);
	p4_freq = VarLag.kr(p4_freq, slew_time, slew_curve);
	p4_res = VarLag.kr(p4_res, slew_time, slew_curve);
	p4_delay = VarLag.kr(p4_delay, slew_time, slew_curve);
	master_fb = VarLag.kr(master_fb, slew_time, slew_curve);
	exciter_type = VarLag.kr(exciter_type, slew_time, slew_curve);
	exciter_level = VarLag.kr(exciter_level, slew_time, slew_curve);
	exciter_freq = VarLag.kr(exciter_freq, slew_time, slew_curve);
	exciter_res = VarLag.kr(exciter_res, slew_time, slew_curve);
	cross_feed = VarLag.kr(cross_feed, slew_time, slew_curve);
	lfo_rate = VarLag.kr(lfo_rate, slew_time, slew_curve);
	lfo_depth = VarLag.kr(lfo_depth, slew_time, slew_curve);

	// Slew FX params
	tape_drive = VarLag.kr(tape_drive, slew_time, slew_curve);
	tape_mix = VarLag.kr(tape_mix, slew_time, slew_curve);
	ffb_f1 = VarLag.kr(ffb_f1, slew_time, slew_curve);
	ffb_f2 = VarLag.kr(ffb_f2, slew_time, slew_curve);
	ffb_f3 = VarLag.kr(ffb_f3, slew_time, slew_curve);
	ffb_f4 = VarLag.kr(ffb_f4, slew_time, slew_curve);
	ffb_g1 = VarLag.kr(ffb_g1, slew_time, slew_curve);
	ffb_g2 = VarLag.kr(ffb_g2, slew_time, slew_curve);
	ffb_g3 = VarLag.kr(ffb_g3, slew_time, slew_curve);
	ffb_g4 = VarLag.kr(ffb_g4, slew_time, slew_curve);
	ffb_res = VarLag.kr(ffb_res, slew_time, slew_curve);
	ffb_mix = VarLag.kr(ffb_mix, slew_time, slew_curve);
	shimmer_shift = VarLag.kr(shimmer_shift, slew_time, slew_curve);
	shimmer_fb = VarLag.kr(shimmer_fb, slew_time, slew_curve);
	shimmer_size = VarLag.kr(shimmer_size, slew_time, slew_curve);
	shimmer_mix = VarLag.kr(shimmer_mix, slew_time, slew_curve);
	freeze_amt = VarLag.kr(freeze_amt, slew_time, slew_curve);
	freeze_mix = VarLag.kr(freeze_mix, slew_time, slew_curve);
	clouds_pos = VarLag.kr(clouds_pos, slew_time, slew_curve);
	clouds_size = VarLag.kr(clouds_size, slew_time, slew_curve);
	clouds_dens = VarLag.kr(clouds_dens, slew_time, slew_curve);
	clouds_tex = VarLag.kr(clouds_tex, slew_time, slew_curve);
	clouds_mode = VarLag.kr(clouds_mode, slew_time, slew_curve);
	clouds_rvb = VarLag.kr(clouds_rvb, slew_time, slew_curve);
	clouds_mix = VarLag.kr(clouds_mix, slew_time, slew_curve);
	output_level = VarLag.kr(output_level, slew_time, slew_curve);

	// === Slow LFO modulation for oceanic movement ===
	{
		var lfo1 = SinOsc.kr(lfo_rate * 1.0);
		var lfo2 = SinOsc.kr(lfo_rate * 1.618);
		var lfo3 = SinOsc.kr(lfo_rate * 0.618);
		var lfo4 = SinOsc.kr(lfo_rate * 1.272);
		var lfoX = SinOsc.kr(lfo_rate * 0.382);

		// Filter freq modulation: +/- 1 octave scaled by depth
		p1_freq = p1_freq * (2 ** (lfo1 * lfo_depth));
		p2_freq = p2_freq * (2 ** (lfo2 * lfo_depth));
		p3_freq = p3_freq * (2 ** (lfo3 * lfo_depth));
		p4_freq = p4_freq * (2 ** (lfo4 * lfo_depth));

		// Delay time modulation: +/- 20% for subtle pitch drift
		p1_delay = p1_delay * (1 + (lfo1 * lfo_depth * 0.2));
		p2_delay = p2_delay * (1 + (lfo2 * lfo_depth * 0.2));
		p3_delay = p3_delay * (1 + (lfo3 * lfo_depth * 0.2));
		p4_delay = p4_delay * (1 + (lfo4 * lfo_depth * 0.2));

		// Cross-feed and exciter modulation
		cross_feed = cross_feed * (1 + (lfoX * lfo_depth * 0.5)).clip(0, 0.8);
		exciter_freq = exciter_freq * (2 ** (lfoX.neg * lfo_depth * 0.5));
	}.value;

	// === Exciter ===
	exciter = Select.ar(exciter_type, [
		WhiteNoise.ar,
		Dust.ar(100),
		Impulse.ar(0.5),
		SinOsc.ar(55) * LFPulse.kr(0.2)
	]);
	exciter = SVF.ar(exciter, exciter_freq.clip(20, 16000), exciter_res.clip(0, 0.99), 1, 0, 0, 0, 0);
	exciter = exciter * exciter_level;

	// === Feedback Network ===
	fb = LocalIn.ar(4) * master_fb;

	path1 = exciter + fb[0] + (fb[3] * cross_feed);
	path1 = SVF.ar(path1, p1_freq.clip(20, 16000), p1_res.clip(0, 0.99), 1, 0, 0, 0, 0);
	path1 = DelayC.ar(path1, 0.5, p1_delay.clip(0.0001, 0.5));
	path1 = (path1 * p1_gain).tanh;

	path2 = exciter + fb[1] + (path1 * cross_feed);
	path2 = SVF.ar(path2, p2_freq.clip(20, 16000), p2_res.clip(0, 0.99), 1, 0, 0, 0, 0);
	path2 = DelayC.ar(path2, 0.5, p2_delay.clip(0.0001, 0.5));
	path2 = (path2 * p2_gain).tanh;

	path3 = exciter + fb[2] + (path2 * cross_feed);
	path3 = SVF.ar(path3, p3_freq.clip(20, 16000), p3_res.clip(0, 0.99), 1, 0, 0, 0, 0);
	path3 = DelayC.ar(path3, 0.5, p3_delay.clip(0.0001, 0.5));
	path3 = (path3 * p3_gain).tanh;

	path4 = exciter + fb[3] + (path3 * cross_feed);
	path4 = SVF.ar(path4, p4_freq.clip(20, 16000), p4_res.clip(0, 0.99), 1, 0, 0, 0, 0);
	path4 = DelayC.ar(path4, 0.5, p4_delay.clip(0.0001, 0.5));
	path4 = (path4 * p4_gain).tanh;

	LocalOut.ar([path1, path2, path3, path4]);

	mix = (path1 + path2 + path3 + path4) * 0.25;
	sig = mix;

	// === FX Chain: tape → ffb → shimmer → freeze → clouds ===
	sig = ~fxTape.(sig, tape_drive, tape_mix);
	sig = ~fxFilterBank4.(sig, ffb_f1, ffb_f2, ffb_f3, ffb_f4, ffb_g1, ffb_g2, ffb_g3, ffb_g4, ffb_res, ffb_mix);
	sig = ~fxShimmer.(sig, shimmer_shift, shimmer_fb, shimmer_mix, shimmer_size);
	sig = ~fxFreeze.(sig, freeze_amt, freeze_mix);
	sig = ~fxClouds.(sig, clouds_pos, clouds_size, clouds_dens, clouds_tex, clouds_mode, clouds_rvb, clouds_mix, t_clock);

	// === EQ + Comp (always at end, not in LUT) ===
	sig = ~fxEQ.(sig, eq_low_freq, eq_low_gain, eq_mid_freq, eq_mid_gain, eq_mid_q, eq_high_freq, eq_high_gain);
	sig = ~fxComp.(sig, comp_thresh, comp_ratio, comp_attack, comp_release, comp_makeup);

	// Output with gate envelope for crossfade
	sig = sig * EnvGen.kr(Env.asr(0.1, 1, 0.1), gate, doneAction: 2);
	sig = Limiter.ar(sig * output_level, 1.0, 0.01);

	Out.ar(0, sig ! 2);
}).add;

// === Engine Specification ===

(
	key: \feedback,
	name: "Feedback Network",
	synthDef: \feedbackNetwork,
	implemented: true,

	// Voice params (24)
	voiceParams: [
		// Path 1
		(idx: 0,  name: \p1_gain,  min: 0.1, max: 2.0,   curve: \lin, default: 0.5),
		(idx: 1,  name: \p1_freq,  min: 20,  max: 8000,  curve: \exp, default: 400),
		(idx: 2,  name: \p1_res,   min: 0,   max: 0.99,  curve: \lin, default: 0.3),
		(idx: 3,  name: \p1_delay, min: 0.005, max: 0.5, curve: \exp, default: 0.02),
		// Path 2
		(idx: 4,  name: \p2_gain,  min: 0.1, max: 2.0,   curve: \lin, default: 0.5),
		(idx: 5,  name: \p2_freq,  min: 20,  max: 8000,  curve: \exp, default: 600),
		(idx: 6,  name: \p2_res,   min: 0,   max: 0.99,  curve: \lin, default: 0.3),
		(idx: 7,  name: \p2_delay, min: 0.005, max: 0.5, curve: \exp, default: 0.025),
		// Path 3
		(idx: 8,  name: \p3_gain,  min: 0.1, max: 2.0,   curve: \lin, default: 0.5),
		(idx: 9,  name: \p3_freq,  min: 20,  max: 8000,  curve: \exp, default: 800),
		(idx: 10, name: \p3_res,   min: 0,   max: 0.99,  curve: \lin, default: 0.3),
		(idx: 11, name: \p3_delay, min: 0.005, max: 0.5, curve: \exp, default: 0.03),
		// Path 4
		(idx: 12, name: \p4_gain,  min: 0.1, max: 2.0,   curve: \lin, default: 0.5),
		(idx: 13, name: \p4_freq,  min: 20,  max: 8000,  curve: \exp, default: 1000),
		(idx: 14, name: \p4_res,   min: 0,   max: 0.99,  curve: \lin, default: 0.3),
		(idx: 15, name: \p4_delay, min: 0.005, max: 0.5, curve: \exp, default: 0.035),
		// Global
		(idx: 16, name: \master_fb,     min: 0,    max: 0.99, curve: \lin, default: 0.7),
		(idx: 17, name: \exciter_type,  min: 0,    max: 3,    curve: \lin, default: 0),
		(idx: 18, name: \exciter_level, min: 0,    max: 1,    curve: \lin, default: 0.3),
		(idx: 19, name: \exciter_freq,  min: 20,   max: 8000, curve: \exp, default: 1000),
		(idx: 20, name: \exciter_res,   min: 0,    max: 0.99, curve: \lin, default: 0.3),
		(idx: 21, name: \cross_feed,    min: 0,    max: 0.8,  curve: \lin, default: 0.2),
		(idx: 22, name: \lfo_rate,      min: 0.01, max: 0.2,  curve: \exp, default: 0.05),
		(idx: 23, name: \lfo_depth,     min: 0,    max: 1.0,  curve: \lin, default: 0.3),
	],

	// FX params (25): tape, ffb, shimmer, freeze, clouds
	fxParams: [
		// Tape
		(idx: 0,  name: \tape_drive,    min: 0.5,  max: 5,    curve: \exp, default: 1.5),
		(idx: 1,  name: \tape_mix,      min: 0,    max: 1,    curve: \lin, default: 0),
		// Filter Bank
		(idx: 2,  name: \ffb_f1,        min: 50,   max: 500,  curve: \exp, default: 200),
		(idx: 3,  name: \ffb_f2,        min: 200,  max: 1500, curve: \exp, default: 500),
		(idx: 4,  name: \ffb_f3,        min: 500,  max: 4000, curve: \exp, default: 1200),
		(idx: 5,  name: \ffb_f4,        min: 1500, max: 10000,curve: \exp, default: 3000),
		(idx: 6,  name: \ffb_g1,        min: 0,    max: 1,    curve: \lin, default: 0.8),
		(idx: 7,  name: \ffb_g2,        min: 0,    max: 1,    curve: \lin, default: 0.8),
		(idx: 8,  name: \ffb_g3,        min: 0,    max: 1,    curve: \lin, default: 0.8),
		(idx: 9,  name: \ffb_g4,        min: 0,    max: 1,    curve: \lin, default: 0.8),
		(idx: 10, name: \ffb_res,       min: 0,    max: 1,    curve: \lin, default: 0.5),
		(idx: 11, name: \ffb_mix,       min: 0,    max: 1,    curve: \lin, default: 0),
		// Shimmer
		(idx: 12, name: \shimmer_shift, min: -24,  max: 24,   curve: \lin, default: 12),
		(idx: 13, name: \shimmer_fb,    min: 0,    max: 0.9,  curve: \lin, default: 0.3),
		(idx: 14, name: \shimmer_size,  min: 0.1,  max: 1,    curve: \lin, default: 0.8),
		(idx: 15, name: \shimmer_mix,   min: 0,    max: 1,    curve: \lin, default: 0),
		// Freeze
		(idx: 16, name: \freeze_amt,    min: 0,    max: 1,    curve: \lin, default: 0),
		(idx: 17, name: \freeze_mix,    min: 0,    max: 1,    curve: \lin, default: 0),
		// Clouds
		(idx: 18, name: \clouds_pos,    min: 0,    max: 1,    curve: \lin, default: 0.5),
		(idx: 19, name: \clouds_size,   min: 0,    max: 1,    curve: \lin, default: 0.5),
		(idx: 20, name: \clouds_dens,   min: 0,    max: 1,    curve: \lin, default: 0.5),
		(idx: 21, name: \clouds_tex,    min: 0,    max: 1,    curve: \lin, default: 0.5),
		(idx: 22, name: \clouds_mode,   min: 0,    max: 3,    curve: \lin, default: 0),
		(idx: 23, name: \clouds_rvb,    min: 0,    max: 1,    curve: \lin, default: 0),
		(idx: 24, name: \clouds_mix,    min: 0,    max: 1,    curve: \lin, default: 0),
	],

	// LUT generator
	lutGenerator: { |seed|
		var voiceLut, fxLut;
		thisThread.randSeed = seed;

		voiceLut = 65536.collect { |i|
			if(i == 0) {
				// State 0 = safe home
				[
					0.5, 200, 0.2, 0.05,
					0.5, 300, 0.2, 0.06,
					0.5, 400, 0.2, 0.07,
					0.5, 500, 0.2, 0.08,
					0.5, 0, 0.2, 400, 0.3, 0.15, 0.03, 0.2
				]
			} {
				[
					// Path 1-4
					rrand(0.1, 2.0), exprand(20, 4000).pow(0.5).linexp(0, 1, 20, 4000), rrand(0.0, 0.8).pow(0.6), exprand(0.005, 0.5).pow(0.4).linexp(0, 1, 0.005, 0.5),
					rrand(0.1, 2.0), exprand(20, 4000).pow(0.5).linexp(0, 1, 20, 4000), rrand(0.0, 0.8).pow(0.6), exprand(0.005, 0.5).pow(0.4).linexp(0, 1, 0.005, 0.5),
					rrand(0.1, 2.0), exprand(20, 4000).pow(0.5).linexp(0, 1, 20, 4000), rrand(0.0, 0.8).pow(0.6), exprand(0.005, 0.5).pow(0.4).linexp(0, 1, 0.005, 0.5),
					rrand(0.1, 2.0), exprand(20, 4000).pow(0.5).linexp(0, 1, 20, 4000), rrand(0.0, 0.8).pow(0.6), exprand(0.005, 0.5).pow(0.4).linexp(0, 1, 0.005, 0.5),
					// Global
					rrand(0.2, 0.85), 4.rand, rrand(0.1, 0.6),
					exprand(20, 4000).pow(0.5).linexp(0, 1, 20, 4000), rrand(0.0, 0.8).pow(0.6),
					rrand(0.0, 0.5), exprand(0.01, 0.2), rrand(0.1, 0.8),
				]
			}
		};

		fxLut = 65536.collect { |i|
			if(i == 0) {
				// State 0 = mostly dry
				[
					1.5, 0,  // tape
					200, 500, 1200, 3000, 0.8, 0.8, 0.8, 0.8, 0.5, 0,  // ffb
					12, 0.3, 0.8, 0,  // shimmer
					0, 0,  // freeze
					0.5, 0.5, 0.5, 0.5, 0, 0, 0  // clouds
				]
			} {
				[
					// Tape
					exprand(0.5, 5),
					rrand(0.0, 0.6),
					// Filter Bank - formant-like frequencies
					exprand(50, 500),
					exprand(200, 1500),
					exprand(500, 4000),
					exprand(1500, 10000),
					rrand(0.2, 1.0),
					rrand(0.2, 1.0),
					rrand(0.2, 1.0),
					rrand(0.2, 1.0),
					rrand(0.2, 0.9),
					rrand(0.0, 0.7),
					// Shimmer
					rrand(-24, 24).round(1),  // semitones
					rrand(0.1, 0.7),
					rrand(0.3, 1.0),
					rrand(0.0, 0.5),
					// Freeze (mostly off, occasional freeze)
					[0, 0, 0, 0, 1].choose,  // 20% chance of freeze
					rrand(0.0, 0.5),
					// Clouds
					rrand(0.0, 1.0),
					rrand(0.0, 1.0),
					rrand(0.0, 1.0),
					rrand(0.0, 1.0),
					4.rand,
					rrand(0.0, 0.7),
					rrand(0.0, 0.6),
				]
			}
		};

		(voice: voiceLut, fx: fxLut)
	},
)
