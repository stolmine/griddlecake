// Wavetable Engine for Griddlecake
// 2 morphable wavetable oscillators with 8 banks × 8 tables
//
// Voice params (20):
//   p0:      Base frequency
//   p1-p4:   Osc1 (bank, morph, level, detune)
//   p5-p9:   Osc2 (bank, morph, level, detune, ratio)
//   p10-p11: Morph LFO (rate, depth)
//   p12:     Cross-modulation amount
//   p13-p14: Sub + noise levels
//   p15-p17: Pre-FX filter (freq, res, env amount)
//   p18-p19: Reserved
//
// FX params (20): chorus, phaser, filter, reverb, clouds
// Note: fx_lib.scd is loaded by main.scd before engine loading
//
// Wavetable Banks:
//   0: Harmonic (sine → saw morph)
//   1: Odd harmonics (sine → square morph)
//   2: Formant (vocal-like)
//   3: PWM-like
//   4: Metallic (inharmonic)
//   5: Organ (drawbar combinations)
//   6: Bright (high harmonic content)
//   7: Soft (rounded, filtered)

SynthDef(\wavetable, {
	arg gate = 1,
	// Wavetable buffer base (set by main.scd)
	wt_buf_base = 0,
	// Voice params
	base_freq = 110,
	osc1_bank = 0, osc1_morph = 0, osc1_level = 1, osc1_detune = 0,
	osc2_bank = 0, osc2_morph = 0, osc2_level = 0, osc2_detune = 0, osc2_ratio = 1,
	morph_lfo_rate = 0.5, morph_lfo_depth = 0,
	xmod_amount = 0,
	sub_level = 0, noise_level = 0,
	filter_freq = 8000, filter_res = 0, filter_env = 0,
	reserved1 = 0, reserved2 = 0,
	// FX params
	chorus_rate = 0.5, chorus_depth = 0.5, chorus_mix = 0,
	phaser_rate = 0.3, phaser_depth = 0.5, phaser_mix = 0,
	filt_freq = 8000, filt_res = 0, filt_mode = 0, filt_mix = 0,
	reverb_room = 0.5, reverb_damp = 0.5, reverb_mix = 0,
	clouds_pos = 0.5, clouds_size = 0.5, clouds_dens = 0.5,
	clouds_tex = 0.5, clouds_mode = 0, clouds_rvb = 0, clouds_mix = 0,
	// Master
	eq_low = 0, eq_mid = 0, eq_high = 0,
	comp_thresh = 0.5, comp_ratio = 4,
	output_level = 0.5,
	// Slew control
	slew_time = 0.1, slew_curve = 0;

	var sig, osc1, osc2, sub, noise, env;
	var f1, f2, morph_mod;
	var buf1_base, buf2_base, buf1_pos, buf2_pos;

	// Per-param slew with curve (VarLag: in, time, warp)
	base_freq = VarLag.kr(base_freq, slew_time, slew_curve);
	osc1_bank = VarLag.kr(osc1_bank, slew_time, slew_curve);
	osc1_morph = VarLag.kr(osc1_morph, slew_time, slew_curve);
	osc1_level = VarLag.kr(osc1_level, slew_time, slew_curve);
	osc1_detune = VarLag.kr(osc1_detune, slew_time, slew_curve);
	osc2_bank = VarLag.kr(osc2_bank, slew_time, slew_curve);
	osc2_morph = VarLag.kr(osc2_morph, slew_time, slew_curve);
	osc2_level = VarLag.kr(osc2_level, slew_time, slew_curve);
	osc2_detune = VarLag.kr(osc2_detune, slew_time, slew_curve);
	osc2_ratio = VarLag.kr(osc2_ratio, slew_time, slew_curve);
	morph_lfo_rate = VarLag.kr(morph_lfo_rate, slew_time, slew_curve);
	morph_lfo_depth = VarLag.kr(morph_lfo_depth, slew_time, slew_curve);
	xmod_amount = VarLag.kr(xmod_amount, slew_time, slew_curve);
	sub_level = VarLag.kr(sub_level, slew_time, slew_curve);
	noise_level = VarLag.kr(noise_level, slew_time, slew_curve);
	filter_freq = VarLag.kr(filter_freq, slew_time, slew_curve);
	filter_res = VarLag.kr(filter_res, slew_time, slew_curve);
	filter_env = VarLag.kr(filter_env, slew_time, slew_curve);
	// FX params
	chorus_rate = VarLag.kr(chorus_rate, slew_time, slew_curve);
	chorus_depth = VarLag.kr(chorus_depth, slew_time, slew_curve);
	chorus_mix = VarLag.kr(chorus_mix, slew_time, slew_curve);
	phaser_rate = VarLag.kr(phaser_rate, slew_time, slew_curve);
	phaser_depth = VarLag.kr(phaser_depth, slew_time, slew_curve);
	phaser_mix = VarLag.kr(phaser_mix, slew_time, slew_curve);
	filt_freq = VarLag.kr(filt_freq, slew_time, slew_curve);
	filt_res = VarLag.kr(filt_res, slew_time, slew_curve);
	filt_mode = VarLag.kr(filt_mode, slew_time, slew_curve);
	filt_mix = VarLag.kr(filt_mix, slew_time, slew_curve);
	reverb_room = VarLag.kr(reverb_room, slew_time, slew_curve);
	reverb_damp = VarLag.kr(reverb_damp, slew_time, slew_curve);
	reverb_mix = VarLag.kr(reverb_mix, slew_time, slew_curve);
	clouds_pos = VarLag.kr(clouds_pos, slew_time, slew_curve);
	clouds_size = VarLag.kr(clouds_size, slew_time, slew_curve);
	clouds_dens = VarLag.kr(clouds_dens, slew_time, slew_curve);
	clouds_tex = VarLag.kr(clouds_tex, slew_time, slew_curve);
	clouds_mode = VarLag.kr(clouds_mode, slew_time, slew_curve);
	clouds_rvb = VarLag.kr(clouds_rvb, slew_time, slew_curve);
	clouds_mix = VarLag.kr(clouds_mix, slew_time, slew_curve);
	output_level = VarLag.kr(output_level, slew_time, slew_curve);

	// Morph LFO modulates both oscillators
	morph_mod = SinOsc.kr(morph_lfo_rate) * morph_lfo_depth;

	// Oscillator frequencies with detune (semitones)
	f1 = base_freq * (2 ** (osc1_detune / 12));
	f2 = base_freq * osc2_ratio * (2 ** (osc2_detune / 12));

	// Buffer positions for VOsc
	// Each bank is 8 consecutive buffers, bank 0 starts at wt_buf_base
	buf1_base = wt_buf_base + (osc1_bank.round.clip(0, 7) * 8);
	buf2_base = wt_buf_base + (osc2_bank.round.clip(0, 7) * 8);

	// Morph position: 0-1 maps to 0-6.99 (for 8 tables with interpolation)
	buf1_pos = buf1_base + ((osc1_morph + morph_mod).clip(0, 1) * 6.99);
	buf2_pos = buf2_base + ((osc2_morph + morph_mod).clip(0, 1) * 6.99);

	// Wavetable oscillators with cross-modulation
	osc2 = VOsc.ar(buf2_pos, f2);
	osc1 = VOsc.ar(buf1_pos, f1 * (1 + (osc2 * xmod_amount)));

	// Mix oscillators
	sig = (osc1 * osc1_level) + (osc2 * osc2_level);

	// Sub oscillator (sine, one octave down)
	sub = SinOsc.ar(base_freq * 0.5) * sub_level;
	sig = sig + sub;

	// Noise layer
	noise = PinkNoise.ar * noise_level * 0.3;
	sig = sig + noise;

	// Pre-FX filter with envelope follower modulation
	// filter_env: positive = morph opens filter, negative = closes
	filter_freq = filter_freq * (1 + (filter_env * ((osc1_morph + osc2_morph) - 1)));
	sig = RLPF.ar(sig, filter_freq.clip(20, 16000), filter_res.linexp(0, 1, 1, 0.05));

	// === FX Chain C ===
	sig = ~fxChorus.(sig, chorus_rate, chorus_depth, chorus_mix);
	sig = ~fxPhaser.(sig, phaser_rate, phaser_depth, phaser_mix);
	sig = ~fxFilter.(sig, filt_freq, filt_res, filt_mode, filt_mix);
	sig = ~fxReverb.(sig, reverb_room, reverb_damp, reverb_mix);
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
	key: \wavetable,
	name: "Wavetable",
	synthDef: \wavetable,
	implemented: true,

	// Voice params (20)
	voiceParams: [
		(idx: 0,  name: \base_freq,      min: 20,    max: 500,   curve: \exp, default: 110),
		(idx: 1,  name: \osc1_bank,      min: 0,     max: 7,     curve: \lin, default: 0),
		(idx: 2,  name: \osc1_morph,     min: 0,     max: 1,     curve: \lin, default: 0),
		(idx: 3,  name: \osc1_level,     min: 0,     max: 1,     curve: \lin, default: 1),
		(idx: 4,  name: \osc1_detune,    min: -1,    max: 1,     curve: \lin, default: 0),
		(idx: 5,  name: \osc2_bank,      min: 0,     max: 7,     curve: \lin, default: 0),
		(idx: 6,  name: \osc2_morph,     min: 0,     max: 1,     curve: \lin, default: 0),
		(idx: 7,  name: \osc2_level,     min: 0,     max: 1,     curve: \lin, default: 0),
		(idx: 8,  name: \osc2_detune,    min: -1,    max: 1,     curve: \lin, default: 0),
		(idx: 9,  name: \osc2_ratio,     min: 0.5,   max: 4,     curve: \exp, default: 1),
		(idx: 10, name: \morph_lfo_rate, min: 0.01,  max: 10,    curve: \exp, default: 0.5),
		(idx: 11, name: \morph_lfo_depth, min: 0,    max: 1,     curve: \lin, default: 0),
		(idx: 12, name: \xmod_amount,    min: 0,     max: 1,     curve: \lin, default: 0),
		(idx: 13, name: \sub_level,      min: 0,     max: 1,     curve: \lin, default: 0),
		(idx: 14, name: \noise_level,    min: 0,     max: 1,     curve: \lin, default: 0),
		(idx: 15, name: \filter_freq,    min: 20,    max: 16000, curve: \exp, default: 8000),
		(idx: 16, name: \filter_res,     min: 0,     max: 0.99,  curve: \lin, default: 0),
		(idx: 17, name: \filter_env,     min: -1,    max: 1,     curve: \lin, default: 0),
		(idx: 18, name: \reserved1,      min: 0,     max: 1,     curve: \lin, default: 0),
		(idx: 19, name: \reserved2,      min: 0,     max: 1,     curve: \lin, default: 0),
	],

	// FX params (20)
	fxParams: [
		(idx: 0,  name: \chorus_rate,    min: 0.1,   max: 5,     curve: \exp, default: 0.5),
		(idx: 1,  name: \chorus_depth,   min: 0,     max: 1,     curve: \lin, default: 0.5),
		(idx: 2,  name: \chorus_mix,     min: 0,     max: 1,     curve: \lin, default: 0),
		(idx: 3,  name: \phaser_rate,    min: 0.05,  max: 5,     curve: \exp, default: 0.3),
		(idx: 4,  name: \phaser_depth,   min: 0,     max: 1,     curve: \lin, default: 0.5),
		(idx: 5,  name: \phaser_mix,     min: 0,     max: 1,     curve: \lin, default: 0),
		(idx: 6,  name: \filt_freq,      min: 100,   max: 16000, curve: \exp, default: 8000),
		(idx: 7,  name: \filt_res,       min: 0,     max: 1,     curve: \lin, default: 0),
		(idx: 8,  name: \filt_mode,      min: 0,     max: 3,     curve: \lin, default: 0),
		(idx: 9,  name: \filt_mix,       min: 0,     max: 1,     curve: \lin, default: 0),
		(idx: 10, name: \reverb_room,    min: 0,     max: 1,     curve: \lin, default: 0.5),
		(idx: 11, name: \reverb_damp,    min: 0,     max: 1,     curve: \lin, default: 0.5),
		(idx: 12, name: \reverb_mix,     min: 0,     max: 1,     curve: \lin, default: 0),
		(idx: 13, name: \clouds_pos,     min: 0,     max: 1,     curve: \lin, default: 0.5),
		(idx: 14, name: \clouds_size,    min: 0,     max: 1,     curve: \lin, default: 0.5),
		(idx: 15, name: \clouds_dens,    min: 0,     max: 1,     curve: \lin, default: 0.5),
		(idx: 16, name: \clouds_tex,     min: 0,     max: 1,     curve: \lin, default: 0.5),
		(idx: 17, name: \clouds_mode,    min: 0,     max: 3,     curve: \lin, default: 0),
		(idx: 18, name: \clouds_rvb,     min: 0,     max: 1,     curve: \lin, default: 0),
		(idx: 19, name: \clouds_mix,     min: 0,     max: 1,     curve: \lin, default: 0),
	],

	// LUT generator using shared lutLib
	lutGenerator: { |seed|
		var lib = ~lutLib;

		var voiceHome = [
			110, 0, 0, 1, 0,      // base_freq, osc1: bank 0, morph 0, full level, no detune
			0, 0, 0, 0, 1,        // osc2: off (level 0)
			0.5, 0, 0,            // no morph LFO, no xmod
			0, 0,                 // no sub, no noise
			8000, 0, 0,           // filter open
			0, 0                  // reserved
		];

		var fxHome = [
			0.5, 0.5, 0,          // chorus: moderate, dry
			0.3, 0.5, 0,          // phaser: slow, dry
			8000, 0, 0, 0,        // filter: open, LP, dry
			0.5, 0.5, 0,          // reverb: medium room, dry
			0.5, 0.5, 0.5, 0.5, 0, 0, 0  // clouds: centered, dry
		];

		var voiceGen = {
			[
				// Base frequency - strong low bias for drones
				lib[\freq].(20, 500, 2.0),
				// Osc1
				lib[\int].(8),               // bank
				lib[\linear].(0.0, 1.0),     // morph
				lib[\linear].(0.5, 1.0),     // level (always some presence)
				lib[\linear].(-0.3, 0.3),    // detune (subtle)
				// Osc2
				lib[\int].(8),               // bank
				lib[\linear].(0.0, 1.0),     // morph
				lib[\curved].(1.0, 1.0),     // level (often off or quiet)
				lib[\linear].(-0.5, 0.5),    // detune
				lib[\choose].([0.5, 1, 1.5, 2, 3, 4]),  // ratio
				// Morph LFO
				lib[\exp].(0.01, 5),          // rate
				lib[\curved].(0.5, 1.2),      // depth (often subtle)
				// Cross-mod
				lib[\curved].(0.3, 1.5),      // amount (subtle)
				// Sub + noise
				lib[\curved].(0.5, 1.0),      // sub level
				lib[\curved].(0.2, 1.5),      // noise level (subtle)
				// Pre-FX filter
				lib[\freq].(100, 12000, 1.2), // freq
				lib[\curved].(0.7, 1.0),      // res
				lib[\linear].(-0.5, 0.5),     // env amount
				// Reserved
				0, 0
			]
		};

		var fxGen = {
			[
				// Chorus
				lib[\exp].(0.1, 3),
				lib[\linear].(0.2, 0.8),
				lib[\curved].(0.5, 1.0),
				// Phaser
				lib[\exp].(0.05, 2),
				lib[\linear].(0.3, 1.0),
				lib[\curved].(0.5, 1.0),
				// Filter
				lib[\freq].(200, 12000, 0.8),
				lib[\curved].(0.7, 1.0),
				lib[\int].(4),
				lib[\curved].(0.6, 1.0),
				// Reverb
				lib[\linear].(0.2, 0.9),
				lib[\linear].(0.2, 0.8),
				lib[\curved].(0.5, 0.8),
			] ++ lib[\clouds].()
		};

		lib[\buildPair].(seed, voiceHome, voiceGen, fxHome, fxGen)
	},
)
