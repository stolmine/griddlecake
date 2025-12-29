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
	slew_time=0.1, slew_curve=0,
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

	// Per-param slew with curve (VarLag: in, time, warp)
	osc1_freq = VarLag.kr(osc1_freq, slew_time, slew_curve);
	osc1_wave = VarLag.kr(osc1_wave, slew_time, slew_curve);
	osc1_pw = VarLag.kr(osc1_pw, slew_time, slew_curve);
	osc2_freq = VarLag.kr(osc2_freq, slew_time, slew_curve);
	osc2_wave = VarLag.kr(osc2_wave, slew_time, slew_curve);
	osc2_pw = VarLag.kr(osc2_pw, slew_time, slew_curve);
	osc2_track = VarLag.kr(osc2_track, slew_time, slew_curve);
	osc2_ratio = VarLag.kr(osc2_ratio, slew_time, slew_curve);
	fm_amount = VarLag.kr(fm_amount, slew_time, slew_curve);
	combo_mode = VarLag.kr(combo_mode, slew_time, slew_curve);
	combo_mix = VarLag.kr(combo_mix, slew_time, slew_curve);
	noise_type = VarLag.kr(noise_type, slew_time, slew_curve);
	noise_level = VarLag.kr(noise_level, slew_time, slew_curve);
	noise_to_osc1 = VarLag.kr(noise_to_osc1, slew_time, slew_curve);
	noise_to_osc2 = VarLag.kr(noise_to_osc2, slew_time, slew_curve);
	filter_freq = VarLag.kr(filter_freq, slew_time, slew_curve);
	filter_res = VarLag.kr(filter_res, slew_time, slew_curve);
	filter_type = VarLag.kr(filter_type, slew_time, slew_curve);
	filter_track = VarLag.kr(filter_track, slew_time, slew_curve);
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
	t_clock = VarLag.kr(t_clock, slew_time, slew_curve);

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

	// Combo modes - true 8-bit audio-rate bitwise ops (inlined)
	combo = {
		var bits = 8;
		var maxVal = (2 ** bits) - 1;
		// Convert to unsigned int
		var intA = ((osc1 + 1) * 0.5 * maxVal).floor.clip(0, maxVal);
		var intB = ((osc2 + 1) * 0.5 * maxVal).floor.clip(0, maxVal);
		// Extract bits and compute ops
		var andBits = (0..bits-1).collect({ |i|
			var bitA = ((intA / (2 ** i)).floor % 2);
			var bitB = ((intB / (2 ** i)).floor % 2);
			(bitA * bitB) * (2 ** i);
		}).sum;
		var orBits = (0..bits-1).collect({ |i|
			var bitA = ((intA / (2 ** i)).floor % 2);
			var bitB = ((intB / (2 ** i)).floor % 2);
			(bitA + bitB - (bitA * bitB)) * (2 ** i);
		}).sum;
		var xorBits = (0..bits-1).collect({ |i|
			var bitA = ((intA / (2 ** i)).floor % 2);
			var bitB = ((intB / (2 ** i)).floor % 2);
			((bitA + bitB) % 2) * (2 ** i);
		}).sum;
		var notB = maxVal - intB;
		var glitchBits = (0..bits-1).collect({ |i|
			var bitA = ((intA / (2 ** i)).floor % 2);
			var bitNotB = ((notB / (2 ** i)).floor % 2);
			((bitA + bitNotB) % 2) * (2 ** i);
		}).sum;
		// Convert back to audio
		var andSig = (andBits / maxVal * 2) - 1;
		var orSig = (orBits / maxVal * 2) - 1;
		var xorSig = (xorBits / maxVal * 2) - 1;
		var glitchSig = (glitchBits / maxVal * 2) - 1;

		Select.ar(combo_mode, [
			osc1,              // 0: OSC1
			osc2,              // 1: OSC2
			osc1 * osc2,       // 2: RING
			min(osc1, osc2),   // 3: MIN
			max(osc1, osc2),   // 4: MAX
			andSig,            // 5: AND
			orSig,             // 6: OR
			xorSig,            // 7: XOR
			glitchSig          // 8: GLITCH
		]);
	}.value;

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
