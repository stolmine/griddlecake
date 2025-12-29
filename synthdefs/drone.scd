SynthDef(\chaosDrone, {
	arg
	osc1_freq=220, osc1_wave=0, osc1_pw=0.5,
	osc2_freq=220, osc2_wave=0, osc2_pw=0.5,
	osc2_track=0, osc2_ratio=1,
	fm_amount=0, combo_mode=0, combo_mix=0,
	noise_type=0, noise_level=0, noise_to_osc1=0, noise_to_osc2=0,
	filter_freq=1000, filter_res=0, filter_type=0, filter_track=0,
	lofi_bits=16, lofi_rate=48000, lofi_mix=0,
	ring_freq=440, ring_wave=0, ring_mix=0,
	comb_freq=440, comb_decay=0.5, comb_mix=0,
	delay_time=250, delay_fb=0, delay_mix=0,
	clouds_pos=0.5, clouds_size=0.5, clouds_dens=0.5,
	clouds_tex=0.5, clouds_mode=0, clouds_rvb=0, clouds_mix=0,
	output_level=0.5,
	t_clock=0,
	slew_time=0.1,
	// EQ (not in LUT - SClang control only)
	eq_low_freq=200, eq_low_gain=0,
	eq_mid_freq=1000, eq_mid_gain=0, eq_mid_q=0.5,
	eq_high_freq=4000, eq_high_gain=0,
	// Compressor (not in LUT - SClang control only)
	comp_thresh=0.5, comp_ratio=2, comp_attack=0.01, comp_release=0.1, comp_makeup=1;

	var osc1, osc2, noise, combo, sig;
	var osc1FreqMod, osc2FreqMod;
	var carrier, lofi, resonated, delayed;
	var cutoff;

	// Per-param slew
	osc1_freq = Lag.kr(osc1_freq, slew_time);
	osc1_wave = Lag.kr(osc1_wave, slew_time);
	osc1_pw = Lag.kr(osc1_pw, slew_time);
	osc2_freq = Lag.kr(osc2_freq, slew_time);
	osc2_wave = Lag.kr(osc2_wave, slew_time);
	osc2_pw = Lag.kr(osc2_pw, slew_time);
	osc2_track = Lag.kr(osc2_track, slew_time);
	osc2_ratio = Lag.kr(osc2_ratio, slew_time);
	fm_amount = Lag.kr(fm_amount, slew_time);
	combo_mode = Lag.kr(combo_mode, slew_time);
	combo_mix = Lag.kr(combo_mix, slew_time);
	noise_type = Lag.kr(noise_type, slew_time);
	noise_level = Lag.kr(noise_level, slew_time);
	noise_to_osc1 = Lag.kr(noise_to_osc1, slew_time);
	noise_to_osc2 = Lag.kr(noise_to_osc2, slew_time);
	filter_freq = Lag.kr(filter_freq, slew_time);
	filter_res = Lag.kr(filter_res, slew_time);
	filter_type = Lag.kr(filter_type, slew_time);
	filter_track = Lag.kr(filter_track, slew_time);
	lofi_bits = Lag.kr(lofi_bits, slew_time);
	lofi_rate = Lag.kr(lofi_rate, slew_time);
	lofi_mix = Lag.kr(lofi_mix, slew_time);
	ring_freq = Lag.kr(ring_freq, slew_time);
	ring_wave = Lag.kr(ring_wave, slew_time);
	ring_mix = Lag.kr(ring_mix, slew_time);
	comb_freq = Lag.kr(comb_freq, slew_time);
	comb_decay = Lag.kr(comb_decay, slew_time);
	comb_mix = Lag.kr(comb_mix, slew_time);
	delay_time = Lag.kr(delay_time, slew_time);
	delay_fb = Lag.kr(delay_fb, slew_time);
	delay_mix = Lag.kr(delay_mix, slew_time);
	clouds_pos = Lag.kr(clouds_pos, slew_time);
	clouds_size = Lag.kr(clouds_size, slew_time);
	clouds_dens = Lag.kr(clouds_dens, slew_time);
	clouds_tex = Lag.kr(clouds_tex, slew_time);
	clouds_mode = Lag.kr(clouds_mode, slew_time);
	clouds_rvb = Lag.kr(clouds_rvb, slew_time);
	clouds_mix = Lag.kr(clouds_mix, slew_time);
	output_level = Lag.kr(output_level, slew_time);
	t_clock = Lag.kr(t_clock, slew_time);

	// Signal flow
	noise = Select.ar(noise_type, [
		WhiteNoise.ar,
		PinkNoise.ar,
		BrownNoise.ar
	]);

	osc2FreqMod = Select.kr(osc2_track, [
		osc2_freq,
		osc1_freq * osc2_ratio
	]) * (1 + (noise * noise_to_osc2 * 0.5));

	osc2 = Select.ar(osc2_wave, [
		SinOsc.ar(osc2FreqMod),
		LFTri.ar(osc2FreqMod),
		LFSaw.ar(osc2FreqMod),
		LFPulse.ar(osc2FreqMod, 0, osc2_pw, 2, -1)
	]);

	osc1FreqMod = osc1_freq * (1 + (noise * noise_to_osc1 * 0.5)) + (osc2 * fm_amount * osc1_freq);

	osc1 = Select.ar(osc1_wave, [
		SinOsc.ar(osc1FreqMod),
		LFTri.ar(osc1FreqMod),
		LFSaw.ar(osc1FreqMod),
		LFPulse.ar(osc1FreqMod, 0, osc1_pw, 2, -1)
	]);

	// Combo modes - bitwise ops approximated with audio-rate logic
	combo = Select.ar(combo_mode, [
		osc1,                                    // 0: OSC1
		osc2,                                    // 1: OSC2
		osc1 * osc2,                             // 2: RING
		min(osc1, osc2),                         // 3: MIN
		max(osc1, osc2),                         // 4: MAX (was PONG)
		(osc1 + osc2).clip(-1, 1),               // 5: ADD/clip (was AND)
		(osc1 - osc2).clip(-1, 1),               // 6: SUB/clip (was OR)
		(osc1 * osc2.sign),                      // 7: SIGN (was XOR)
		((osc1 + osc2) * (osc1 - osc2))          // 8: GLITCH
	]);

	sig = XFade2.ar(osc1, combo, combo_mix * 2 - 1);

	sig = sig + (noise * noise_level);

	// SVF filter - args: signal, cutoff, res, low, band, high, notch, peak
	cutoff = filter_freq + (filter_track * osc1_freq);
	sig = SVF.ar(sig, cutoff.clip(20, 20000), filter_res, 1, 0, 0, 0, 0);

	lofi = (sig * (2.pow(lofi_bits - 1))).round / (2.pow(lofi_bits - 1));
	lofi = Latch.ar(lofi, Impulse.ar(lofi_rate));
	sig = XFade2.ar(sig, lofi, lofi_mix * 2 - 1);

	carrier = Select.ar(ring_wave, [
		SinOsc.ar(ring_freq),
		LFTri.ar(ring_freq),
		LFSaw.ar(ring_freq),
		LFPulse.ar(ring_freq, 0, 0.5, 2, -1)
	]);
	sig = XFade2.ar(sig, sig * carrier, ring_mix * 2 - 1);

	resonated = CombC.ar(sig, 0.05, (1/comb_freq).clip(0.0002, 0.05), comb_decay);
	sig = XFade2.ar(sig, resonated, comb_mix * 2 - 1);

	delayed = CombC.ar(sig, 2.0, (delay_time / 1000).clip(0.001, 2.0), delay_fb * 3);
	sig = XFade2.ar(sig, delayed, delay_mix * 2 - 1);

	// MiClouds granular processor
	sig = MiClouds.ar(
		[sig, sig],  // inputArray (stereo)
		pit: 0.5,    // no pitch shift
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

	// 3-band EQ (low shelf, mid peak, high shelf)
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

	sig = Limiter.ar(sig * output_level, 1.0, 0.01);

	Out.ar(0, sig ! 2);
}).add;
