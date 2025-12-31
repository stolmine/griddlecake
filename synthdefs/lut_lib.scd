// LUT Generator Library
// Shared random generators with musical weighting for LUT creation
// Load before engine files: ~lutLib = "/path/to/lut_lib.scd".load;

(
	// ========================================
	// BIASED RANDOM GENERATORS
	// ========================================

	// Frequency with low-bias weighting
	// bias > 1 = favor low frequencies, < 1 = favor high
	freq: { |min=20, max=2000, bias=1.8|
		rrand(0.0, 1.0).pow(bias).linexp(0, 1, min, max)
	},

	// Time/delay with short-bias weighting
	// bias > 1 = favor short times, < 1 = favor long
	time: { |min=0.005, max=0.5, bias=0.4|
		rrand(0.0, 1.0).pow(bias).linexp(0, 1, min, max)
	},

	// Curved 0-max range (resonance, mix, feedback, etc)
	// bias > 1 = favor low values, < 1 = favor high
	curved: { |max=1.0, bias=1.0|
		rrand(0.0, 1.0).pow(bias) * max
	},

	// Linear range (no bias)
	linear: { |min=0.0, max=1.0|
		rrand(min, max)
	},

	// Exponential range (natural for frequencies, times)
	exp: { |min=20, max=2000|
		exprand(min, max)
	},

	// Integer range
	int: { |max=4|
		max.rand
	},

	// Choose from array (equal probability)
	choose: { |array|
		array.choose
	},

	// Choose from array with weighted probability toward first items
	// bias > 1 = favor early items
	chooseWeighted: { |array, bias=1.0|
		var idx = (rrand(0.0, 1.0).pow(bias) * array.size).floor.asInteger;
		array[idx.min(array.size - 1)]
	},

	// ========================================
	// COMMON PARAM GROUP GENERATORS
	// ========================================

	// MiClouds params: [pos, size, dens, tex, mode, rvb, mix]
	clouds: { |posR, sizeR, densR, texR, modeN=4, rvbMax=0.7, mixMax=0.6|
		posR = posR ? [0.0, 1.0];
		sizeR = sizeR ? [0.0, 1.0];
		densR = densR ? [0.0, 1.0];
		texR = texR ? [0.0, 1.0];
		[
			rrand(posR[0], posR[1]),
			rrand(sizeR[0], sizeR[1]),
			rrand(densR[0], densR[1]),
			rrand(texR[0], texR[1]),
			modeN.rand,
			rrand(0.0, rvbMax),
			rrand(0.0, mixMax)
		]
	},

	// Lo-Fi params: [bits, rate, mix]
	lofi: { |bitsR, rateR, mixMax=0.5|
		bitsR = bitsR ? [4, 16];
		rateR = rateR ? [1000, 48000];
		[
			rrand(bitsR[0], bitsR[1]),
			exprand(rateR[0], rateR[1]),
			rrand(0.0, mixMax)
		]
	},

	// Ring mod params: [freq, wave, mix]
	ring: { |freqMin=20, freqMax=2000, freqBias=1.8, waveN=4, mixMax=0.4|
		[
			rrand(0.0, 1.0).pow(freqBias).linexp(0, 1, freqMin, freqMax),
			waveN.rand,
			rrand(0.0, mixMax)
		]
	},

	// Comb resonator params: [freq, decay, mix]
	comb: { |freqMin=20, freqMax=2000, freqBias=1.8, decayR, mixMax=0.5|
		decayR = decayR ? [0.1, 10];
		[
			rrand(0.0, 1.0).pow(freqBias).linexp(0, 1, freqMin, freqMax),
			exprand(decayR[0], decayR[1]),
			rrand(0.0, mixMax)
		]
	},

	// Delay params: [time, feedback, mix]
	delay: { |timeR, fbMax=0.8, mixMax=0.5|
		timeR = timeR ? [1, 2000];  // ms
		[
			exprand(timeR[0], timeR[1]),
			rrand(0.0, fbMax),
			rrand(0.0, mixMax)
		]
	},

	// ========================================
	// LUT BUILDER
	// ========================================

	// Build a LUT with home state at index 0
	// seed: random seed for reproducibility
	// size: number of entries (default 65536 = 16-bit)
	// homeState: array for index 0 (safe defaults)
	// randomGen: function that returns random param array
	build: { |seed, size=65536, homeState, randomGen|
		thisThread.randSeed = seed;
		size.collect { |i|
			if(i == 0) { homeState } { randomGen.() }
		}
	},

	// Build voice + fx LUT pair
	buildPair: { |seed, voiceHome, voiceGen, fxHome, fxGen, size=65536|
		thisThread.randSeed = seed;
		(
			voice: size.collect { |i| if(i == 0) { voiceHome } { voiceGen.() } },
			fx: size.collect { |i| if(i == 0) { fxHome } { fxGen.() } }
		)
	}
)
