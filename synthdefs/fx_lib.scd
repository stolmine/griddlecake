// FX Library - Shared building blocks for engine FX chains
// Each function takes signal + params, returns processed signal
// Load this file before engine SynthDefs that use these blocks

// Lo-Fi (bit crush + sample rate reduction)
~fxLofi = { |sig, bits, rate, mix|
	var lofi = (sig * (2.pow(bits - 1))).round / (2.pow(bits - 1));
	lofi = Latch.ar(lofi, Impulse.ar(rate));
	XFade2.ar(sig, lofi, mix * 2 - 1)
};

// Ring Modulator
~fxRing = { |sig, freq, wave, mix|
	var carrier = Select.ar(wave, [
		SinOsc.ar(freq),
		LFTri.ar(freq),
		LFSaw.ar(freq),
		LFPulse.ar(freq, 0, 0.5, 2, -1)
	]);
	XFade2.ar(sig, sig * carrier, mix * 2 - 1)
};

// Comb Resonator
~fxComb = { |sig, freq, decay, mix|
	var resonated = CombC.ar(sig, 0.05, (1/freq).clip(0.0002, 0.05), decay);
	XFade2.ar(sig, resonated, mix * 2 - 1)
};

// Delay
~fxDelay = { |sig, time, fb, mix|
	var delayed = CombC.ar(sig, 2.0, (time / 1000).clip(0.001, 2.0), fb * 3);
	XFade2.ar(sig, delayed, mix * 2 - 1)
};

// MiClouds granular
~fxClouds = { |sig, pos, size, dens, tex, mode, rvb, mix, trig=0|
	MiClouds.ar(
		[sig, sig],
		pit: 0.5,
		pos: pos,
		size: size,
		dens: dens,
		tex: tex,
		drywet: mix,
		in_gain: 1.0,
		spread: 0.0,
		rvb: rvb,
		fb: 0.0,
		freeze: 0,
		mode: mode,
		lofi: 0,
		trig: trig
	)[0]
};

// 3-band EQ
~fxEQ = { |sig, lowFreq, lowGain, midFreq, midGain, midQ, highFreq, highGain|
	sig = BLowShelf.ar(sig, lowFreq.clip(20, 500), 1, lowGain);
	sig = BPeakEQ.ar(sig, midFreq.clip(200, 8000), midQ.clip(0.1, 4), midGain);
	sig = BHiShelf.ar(sig, highFreq.clip(1000, 16000), 1, highGain);
	sig
};

// Compressor
~fxComp = { |sig, thresh, ratio, attack, release, makeup|
	Compander.ar(sig, sig,
		thresh: thresh.clip(0.01, 1),
		slopeBelow: 1,
		slopeAbove: (1 / ratio.clip(1, 20)),
		clampTime: attack.clip(0.001, 0.5),
		relaxTime: release.clip(0.01, 2)
	) * makeup
};

// === Additional FX for other engines ===

// Shimmer (pitch-shifted reverb feedback)
~fxShimmer = { |sig, shift, fb, mix, size=0.8|
	var shimmer, local;
	local = LocalIn.ar(2) * fb;
	shimmer = sig + local;
	shimmer = PitchShift.ar(shimmer, 0.2, shift.midiratio, 0.01, 0.01);
	shimmer = FreeVerb2.ar(shimmer, shimmer, mix: 0.7, room: size, damp: 0.5);
	LocalOut.ar(shimmer);
	XFade2.ar(sig, shimmer[0], mix * 2 - 1)
};

// Spectral Freeze (FFT-based)
~fxFreeze = { |sig, freeze, mix|
	var chain, frozen;
	chain = FFT(LocalBuf(2048), sig);
	chain = PV_Freeze(chain, freeze > 0.5);
	frozen = IFFT(chain);
	XFade2.ar(sig, frozen, mix * 2 - 1)
};

// Tape Saturation
~fxTape = { |sig, drive, mix|
	var saturated = (sig * drive).tanh / drive.max(0.1);
	XFade2.ar(sig, saturated, mix * 2 - 1)
};

// Chorus
~fxChorus = { |sig, rate, depth, mix|
	var mod = SinOsc.kr(rate, [0, 0.5pi]) * depth * 0.01;
	var chorus = DelayC.ar(sig, 0.05, 0.02 + mod);
	XFade2.ar(sig, chorus.sum * 0.5, mix * 2 - 1)
};

// Freeverb wrapper
~fxReverb = { |sig, room, damp, mix|
	var verb = FreeVerb.ar(sig, mix: 1, room: room, damp: damp);
	XFade2.ar(sig, verb, mix * 2 - 1)
};

// Fixed Filter Bank (8 parallel resonant bandpass filters)
// freqs: array of 8 frequencies, gains: array of 8 gains (0-1), res: shared resonance
~fxFilterBank = { |sig, f1, f2, f3, f4, f5, f6, f7, f8, g1, g2, g3, g4, g5, g6, g7, g8, res, mix|
	var bands, filtered;
	var freqs = [f1, f2, f3, f4, f5, f6, f7, f8];
	var gains = [g1, g2, g3, g4, g5, g6, g7, g8];
	var q = res.linexp(0, 1, 2, 50);  // resonance -> Q factor

	bands = freqs.collect { |freq, i|
		BPF.ar(sig, freq.clip(20, 16000), 1/q) * gains[i]
	};
	filtered = bands.sum * 2;  // sum and boost (bandpass attenuates)
	XFade2.ar(sig, filtered, mix * 2 - 1)
};

// Simpler 4-band fixed filter bank
~fxFilterBank4 = { |sig, f1, f2, f3, f4, g1, g2, g3, g4, res, mix|
	var bands, filtered;
	var q = res.linexp(0, 1, 1, 30);

	bands = [
		BPF.ar(sig, f1.clip(20, 16000), 1/q) * g1,
		BPF.ar(sig, f2.clip(20, 16000), 1/q) * g2,
		BPF.ar(sig, f3.clip(20, 16000), 1/q) * g3,
		BPF.ar(sig, f4.clip(20, 16000), 1/q) * g4,
	];
	filtered = bands.sum * 2.5;
	XFade2.ar(sig, filtered, mix * 2 - 1)
};

// Pitch Shifter (granular-based)
~fxPitchShift = { |sig, shift, windowSize=0.2, pitchDisp=0.01, timeDisp=0.01, mix|
	var shifted = PitchShift.ar(sig, windowSize, shift.midiratio, pitchDisp, timeDisp);
	XFade2.ar(sig, shifted, mix * 2 - 1)
};

// Dual Pitch Shifter (harmony - two voices)
~fxDualPitch = { |sig, shift1, shift2, mix|
	var p1 = PitchShift.ar(sig, 0.2, shift1.midiratio, 0.01, 0.01);
	var p2 = PitchShift.ar(sig, 0.2, shift2.midiratio, 0.01, 0.01);
	var shifted = (p1 + p2) * 0.5;
	XFade2.ar(sig, shifted, mix * 2 - 1)
};

// Frequency Shifter (Bode-style, not pitch - creates inharmonic sidebands)
~fxFreqShift = { |sig, shift, mix|
	var shifted = FreqShift.ar(sig, shift);
	XFade2.ar(sig, shifted, mix * 2 - 1)
};

// Wavefolder (adds harmonics via folding)
~fxWavefold = { |sig, drive, sym, mix|
	var folded, shaped;
	shaped = sig * drive.linexp(0, 1, 1, 10);
	// Asymmetric folding based on sym param
	folded = (shaped + (sym * 0.5)).fold2(1) * (1 + (sym * 0.3));
	folded = LeakDC.ar(folded);
	XFade2.ar(sig, folded, mix * 2 - 1)
};

// Multimode Filter (SVF-style: LP, BP, HP, Notch)
~fxFilter = { |sig, freq, res, mode, mix|
	var filtered;
	filtered = Select.ar(mode, [
		RLPF.ar(sig, freq.clip(20, 18000), res.linexp(0, 1, 1, 0.01)),  // LP
		BPF.ar(sig, freq.clip(20, 18000), res.linexp(0, 1, 2, 0.1)),    // BP
		RHPF.ar(sig, freq.clip(20, 18000), res.linexp(0, 1, 1, 0.01)), // HP
		BRF.ar(sig, freq.clip(20, 18000), res.linexp(0, 1, 2, 0.1))    // Notch
	]);
	XFade2.ar(sig, filtered, mix * 2 - 1)
};

"[FX Lib] Loaded FX building blocks".postln;
