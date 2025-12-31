// Feedback Network Engine
// 4 cross-feeding filter+delay paths with exciter
//
// Voice params (20):
//   p0-p3:   Path 1 (gain, filter_freq, filter_res, delay_time)
//   p4-p7:   Path 2
//   p8-p11:  Path 3
//   p12-p15: Path 4
//   p16-p19: Global (master_fb, exciter_type, exciter_level, cross_feed)
//
// FX params (19): Same as drone (lofi, ring, comb, delay, clouds)

SynthDef(\feedbackNetwork, {
	arg
	// Path 1
	p1_gain=0.5, p1_freq=400, p1_res=0.3, p1_delay=0.01,
	// Path 2
	p2_gain=0.5, p2_freq=600, p2_res=0.3, p2_delay=0.015,
	// Path 3
	p3_gain=0.5, p3_freq=800, p3_res=0.3, p3_delay=0.02,
	// Path 4
	p4_gain=0.5, p4_freq=1000, p4_res=0.3, p4_delay=0.025,
	// Global
	master_fb=0.7, exciter_type=0, exciter_level=0.3, cross_feed=0.2,
	// FX chain (same as drone)
	lofi_bits=16, lofi_rate=48000, lofi_mix=0,
	ring_freq=440, ring_wave=0, ring_mix=0,
	comb_freq=440, comb_decay=0.5, comb_mix=0,
	delay_time=250, delay_fb=0, delay_mix=0,
	clouds_pos=0.5, clouds_size=0.5, clouds_dens=0.5,
	clouds_tex=0.5, clouds_mode=0, clouds_rvb=0, clouds_mix=0,
	output_level=0.5,
	t_clock=0,
	slew_time=0.1, slew_curve=0,
	// EQ (not in LUT)
	eq_low_freq=200, eq_low_gain=0,
	eq_mid_freq=1000, eq_mid_gain=0, eq_mid_q=0.5,
	eq_high_freq=4000, eq_high_gain=0,
	// Compressor (not in LUT)
	comp_thresh=0.5, comp_ratio=2, comp_attack=0.01, comp_release=0.1, comp_makeup=1,
	// Gate for crossfade
	gate=1;

	var exciter, fb, path1, path2, path3, path4, mix, sig;
	var carrier, lofi, resonated, delayed;

	// Slew all params
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
	cross_feed = VarLag.kr(cross_feed, slew_time, slew_curve);
	// FX slew
	lofi_bits = VarLag.kr(lofi_bits, slew_time, slew_curve);
	lofi_rate = VarLag.kr(lofi_rate, slew_time, slew_curve);
	lofi_mix = VarLag.kr(lofi_mix, slew_time, slew_curve);
	ring_freq = VarLag.kr(ring_freq, slew_time, slew_curve);
	ring_wave = VarLag.kr(ring_wave, slew_time, slew_curve);
	ring_mix = VarLag.kr(ring_mix, slew_time, slew_curve);
	comb_freq = VarLag.kr(comb_freq, slew_time, slew_curve);
	comb_decay = VarLag.kr(comb_decay, slew_time, slew_curve);
	comb_mix = VarLag.kr(comb_mix, slew_time, slew_curve);
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

	// Exciter - kicks off and sustains the feedback
	exciter = Select.ar(exciter_type, [
		WhiteNoise.ar,                    // 0: continuous noise
		Dust.ar(100),                     // 1: sparse impulses
		Impulse.ar(0.5),                  // 2: slow pulse
		SinOsc.ar(55) * LFPulse.kr(0.2)   // 3: gated sine drone
	]) * exciter_level;

	// Get feedback from previous frame (4 channels)
	fb = LocalIn.ar(4) * master_fb;

	// Path 1: exciter + feedback + cross-feed from path 4
	path1 = exciter + fb[0] + (fb[3] * cross_feed);
	path1 = SVF.ar(path1, p1_freq.clip(20, 16000), p1_res.clip(0, 0.99), 1, 0, 0, 0, 0);
	path1 = DelayC.ar(path1, 0.5, p1_delay.clip(0.0001, 0.5));
	path1 = (path1 * p1_gain).tanh;  // soft clip

	// Path 2: exciter + feedback + cross-feed from path 1
	path2 = exciter + fb[1] + (path1 * cross_feed);
	path2 = SVF.ar(path2, p2_freq.clip(20, 16000), p2_res.clip(0, 0.99), 1, 0, 0, 0, 0);
	path2 = DelayC.ar(path2, 0.5, p2_delay.clip(0.0001, 0.5));
	path2 = (path2 * p2_gain).tanh;

	// Path 3: exciter + feedback + cross-feed from path 2
	path3 = exciter + fb[2] + (path2 * cross_feed);
	path3 = SVF.ar(path3, p3_freq.clip(20, 16000), p3_res.clip(0, 0.99), 1, 0, 0, 0, 0);
	path3 = DelayC.ar(path3, 0.5, p3_delay.clip(0.0001, 0.5));
	path3 = (path3 * p3_gain).tanh;

	// Path 4: exciter + feedback + cross-feed from path 3
	path4 = exciter + fb[3] + (path3 * cross_feed);
	path4 = SVF.ar(path4, p4_freq.clip(20, 16000), p4_res.clip(0, 0.99), 1, 0, 0, 0, 0);
	path4 = DelayC.ar(path4, 0.5, p4_delay.clip(0.0001, 0.5));
	path4 = (path4 * p4_gain).tanh;

	// Send back to feedback loop
	LocalOut.ar([path1, path2, path3, path4]);

	// Mix all paths
	mix = (path1 + path2 + path3 + path4) * 0.25;
	sig = mix;

	// === FX Chain (identical to drone) ===

	// Lo-Fi
	lofi = (sig * (2.pow(lofi_bits - 1))).round / (2.pow(lofi_bits - 1));
	lofi = Latch.ar(lofi, Impulse.ar(lofi_rate));
	sig = XFade2.ar(sig, lofi, lofi_mix * 2 - 1);

	// Ring Mod
	carrier = Select.ar(ring_wave, [
		SinOsc.ar(ring_freq),
		LFTri.ar(ring_freq),
		LFSaw.ar(ring_freq),
		LFPulse.ar(ring_freq, 0, 0.5, 2, -1)
	]);
	sig = XFade2.ar(sig, sig * carrier, ring_mix * 2 - 1);

	// Comb Resonator
	resonated = CombC.ar(sig, 0.05, (1/comb_freq).clip(0.0002, 0.05), comb_decay);
	sig = XFade2.ar(sig, resonated, comb_mix * 2 - 1);

	// Delay
	delayed = CombC.ar(sig, 2.0, (delay_time / 1000).clip(0.001, 2.0), delay_fb * 3);
	sig = XFade2.ar(sig, delayed, delay_mix * 2 - 1);

	// MiClouds
	sig = MiClouds.ar(
		[sig, sig],
		pit: 0.5,
		pos: clouds_pos,
		size: clouds_size,
		dens: clouds_dens,
		tex: clouds_tex,
		drywet: clouds_mix,
		in_gain: 1.0,
		spread: 0.0,
		rvb: clouds_rvb,
		fb: 0.0,
		freeze: 0,
		mode: clouds_mode,
		lofi: 0,
		trig: t_clock
	)[0];

	// 3-band EQ
	sig = BLowShelf.ar(sig, eq_low_freq.clip(20, 500), 1, eq_low_gain);
	sig = BPeakEQ.ar(sig, eq_mid_freq.clip(200, 8000), eq_mid_q.clip(0.1, 4), eq_mid_gain);
	sig = BHiShelf.ar(sig, eq_high_freq.clip(1000, 16000), 1, eq_high_gain);

	// Compressor
	sig = Compander.ar(sig, sig,
		thresh: comp_thresh.clip(0.01, 1),
		slopeBelow: 1,
		slopeAbove: (1 / comp_ratio.clip(1, 20)),
		clampTime: comp_attack.clip(0.001, 0.5),
		relaxTime: comp_release.clip(0.01, 2)
	) * comp_makeup;

	// Output with gate envelope for crossfade
	sig = sig * EnvGen.kr(Env.asr(0.1, 1, 0.1), gate, doneAction: 2);
	sig = Limiter.ar(sig * output_level, 1.0, 0.01);

	Out.ar(0, sig ! 2);
}).add;

// === Engine Specification ===
// Returns engine spec dictionary for registry

(
	key: \feedback,
	name: "Feedback Network",
	synthDef: \feedbackNetwork,
	implemented: true,

	// Voice params (20) - mapped to p0-p19
	voiceParams: [
		// Path 1
		(idx: 0,  name: \p1_gain,  min: 0.1, max: 2.0,   curve: \lin, default: 0.5),
		(idx: 1,  name: \p1_freq,  min: 20,  max: 8000,  curve: \exp, default: 400),
		(idx: 2,  name: \p1_res,   min: 0,   max: 0.99,  curve: \lin, default: 0.3),
		(idx: 3,  name: \p1_delay, min: 0.0001, max: 0.5, curve: \exp, default: 0.01),
		// Path 2
		(idx: 4,  name: \p2_gain,  min: 0.1, max: 2.0,   curve: \lin, default: 0.5),
		(idx: 5,  name: \p2_freq,  min: 20,  max: 8000,  curve: \exp, default: 600),
		(idx: 6,  name: \p2_res,   min: 0,   max: 0.99,  curve: \lin, default: 0.3),
		(idx: 7,  name: \p2_delay, min: 0.0001, max: 0.5, curve: \exp, default: 0.015),
		// Path 3
		(idx: 8,  name: \p3_gain,  min: 0.1, max: 2.0,   curve: \lin, default: 0.5),
		(idx: 9,  name: \p3_freq,  min: 20,  max: 8000,  curve: \exp, default: 800),
		(idx: 10, name: \p3_res,   min: 0,   max: 0.99,  curve: \lin, default: 0.3),
		(idx: 11, name: \p3_delay, min: 0.0001, max: 0.5, curve: \exp, default: 0.02),
		// Path 4
		(idx: 12, name: \p4_gain,  min: 0.1, max: 2.0,   curve: \lin, default: 0.5),
		(idx: 13, name: \p4_freq,  min: 20,  max: 8000,  curve: \exp, default: 1000),
		(idx: 14, name: \p4_res,   min: 0,   max: 0.99,  curve: \lin, default: 0.3),
		(idx: 15, name: \p4_delay, min: 0.0001, max: 0.5, curve: \exp, default: 0.025),
		// Global
		(idx: 16, name: \master_fb,     min: 0,   max: 0.99, curve: \lin, default: 0.7),
		(idx: 17, name: \exciter_type,  min: 0,   max: 3,    curve: \lin, default: 0),
		(idx: 18, name: \exciter_level, min: 0,   max: 1,    curve: \lin, default: 0.3),
		(idx: 19, name: \cross_feed,    min: 0,   max: 0.8,  curve: \lin, default: 0.2),
	],

	// FX params (19) - same as drone, mapped to p20-p38
	fxParams: [
		(idx: 20, name: \lofi_bits,    min: 4,     max: 16,    curve: \lin, default: 16),
		(idx: 21, name: \lofi_rate,    min: 1000,  max: 48000, curve: \exp, default: 48000),
		(idx: 22, name: \lofi_mix,     min: 0,     max: 1,     curve: \lin, default: 0),
		(idx: 23, name: \ring_freq,    min: 20,    max: 2000,  curve: \exp, default: 440),
		(idx: 24, name: \ring_wave,    min: 0,     max: 3,     curve: \lin, default: 0),
		(idx: 25, name: \ring_mix,     min: 0,     max: 1,     curve: \lin, default: 0),
		(idx: 26, name: \comb_freq,    min: 20,    max: 2000,  curve: \exp, default: 440),
		(idx: 27, name: \comb_decay,   min: 0.1,   max: 10,    curve: \exp, default: 0.5),
		(idx: 28, name: \comb_mix,     min: 0,     max: 1,     curve: \lin, default: 0),
		(idx: 29, name: \delay_time,   min: 1,     max: 2000,  curve: \exp, default: 250),
		(idx: 30, name: \delay_fb,     min: 0,     max: 0.95,  curve: \lin, default: 0),
		(idx: 31, name: \delay_mix,    min: 0,     max: 1,     curve: \lin, default: 0),
		(idx: 32, name: \clouds_pos,   min: 0,     max: 1,     curve: \lin, default: 0.5),
		(idx: 33, name: \clouds_size,  min: 0,     max: 1,     curve: \lin, default: 0.5),
		(idx: 34, name: \clouds_dens,  min: 0,     max: 1,     curve: \lin, default: 0.5),
		(idx: 35, name: \clouds_tex,   min: 0,     max: 1,     curve: \lin, default: 0.5),
		(idx: 36, name: \clouds_mode,  min: 0,     max: 3,     curve: \lin, default: 0),
		(idx: 37, name: \clouds_rvb,   min: 0,     max: 1,     curve: \lin, default: 0),
		(idx: 38, name: \clouds_mix,   min: 0,     max: 1,     curve: \lin, default: 0),
	],

	// LUT generator with feedback-appropriate weighting
	lutGenerator: { |seed|
		var voiceLut, fxLut;
		thisThread.randSeed = seed;

		voiceLut = 65536.collect { |i|
			if(i == 0) {
				// State 0 = safe home: gentle feedback, low freqs, moderate delays
				Float32Array[
					0.5, 200, 0.2, 0.02,    // path 1: gentle
					0.5, 300, 0.2, 0.025,   // path 2
					0.5, 400, 0.2, 0.03,    // path 3
					0.5, 500, 0.2, 0.035,   // path 4
					0.5, 0, 0.2, 0.15       // master_fb, exciter(noise), level, cross
				]
			} {
				Float32Array[
					// Path 1
					rrand(0.1, 2.0),                                    // gain
					exprand(20, 8000).pow(0.6).linexp(0, 1, 20, 8000), // freq (bias low)
					rrand(0.0, 0.99).pow(0.7),                         // res (bias lower)
					exprand(0.0001, 0.5),                               // delay
					// Path 2
					rrand(0.1, 2.0),
					exprand(20, 8000).pow(0.6).linexp(0, 1, 20, 8000),
					rrand(0.0, 0.99).pow(0.7),
					exprand(0.0001, 0.5),
					// Path 3
					rrand(0.1, 2.0),
					exprand(20, 8000).pow(0.6).linexp(0, 1, 20, 8000),
					rrand(0.0, 0.99).pow(0.7),
					exprand(0.0001, 0.5),
					// Path 4
					rrand(0.1, 2.0),
					exprand(20, 8000).pow(0.6).linexp(0, 1, 20, 8000),
					rrand(0.0, 0.99).pow(0.7),
					exprand(0.0001, 0.5),
					// Global
					rrand(0.3, 0.95),  // master_fb (bias toward sustain)
					4.rand,            // exciter_type
					rrand(0.05, 0.5),  // exciter_level
					rrand(0.0, 0.6),   // cross_feed
				]
			}
		};

		fxLut = 65536.collect { |i|
			if(i == 0) {
				// State 0 = dry FX
				Float32Array[16, 48000, 0, 440, 0, 0, 440, 0.5, 0, 250, 0, 0, 0.5, 0.5, 0.5, 0.5, 0, 0, 0]
			} {
				Float32Array[
					rrand(4, 16),              // lofi_bits
					exprand(1000, 48000),      // lofi_rate
					rrand(0.0, 0.5),           // lofi_mix (bias subtle)
					exprand(20, 2000).pow(0.6).linexp(0, 1, 20, 2000),  // ring_freq
					4.rand,                    // ring_wave
					rrand(0.0, 0.4),           // ring_mix
					exprand(20, 2000).pow(0.6).linexp(0, 1, 20, 2000),  // comb_freq
					exprand(0.1, 10),          // comb_decay
					rrand(0.0, 0.5),           // comb_mix
					exprand(1, 2000),          // delay_time
					rrand(0.0, 0.8),           // delay_fb
					rrand(0.0, 0.5),           // delay_mix
					rrand(0.0, 1.0),           // clouds_pos
					rrand(0.0, 1.0),           // clouds_size
					rrand(0.0, 1.0),           // clouds_dens
					rrand(0.0, 1.0),           // clouds_tex
					4.rand,                    // clouds_mode
					rrand(0.0, 0.7),           // clouds_rvb
					rrand(0.0, 0.6),           // clouds_mix
				]
			}
		};

		(voice: voiceLut, fx: fxLut)
	},
)
