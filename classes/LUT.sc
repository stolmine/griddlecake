LUT {
	var <seed;
	var <table;
	var <specs;

	*new { |argSeed|
		^super.new.init(argSeed);
	}

	init { |argSeed|
		seed = argSeed ?? { Date.seed };
		this.buildSpecs();
		this.generateTable();
	}

	buildSpecs {
		specs = [
			[\osc1_freq, 20, 2000, \exp],
			[\osc1_wave, 0, 3, \lin],
			[\osc1_pw, 0, 1, \lin],
			[\osc2_freq, 20, 2000, \exp],
			[\osc2_wave, 0, 3, \lin],
			[\osc2_pw, 0, 1, \lin],
			[\osc2_track, 0, 1, \lin],
			[\osc2_ratio, 0.25, 4.0, \lin],
			[\fm_amount, 0, 1, \lin],
			[\combo_mode, 0, 8, \lin],
			[\combo_mix, 0, 1, \lin],
			[\noise_type, 0, 2, \lin],
			[\noise_level, 0, 1, \lin],
			[\noise_to_osc1, 0, 1, \lin],
			[\noise_to_osc2, 0, 1, \lin],
			[\filter_freq, 20, 20000, \exp],
			[\filter_res, 0, 0.99, \lin],
			[\filter_type, 0, 3, \lin],
			[\filter_track, 0, 1, \lin],
			[\output_level, 0, 1, \lin],
			[\lofi_bits, 1, 16, \lin],
			[\lofi_rate, 100, 48000, \exp],
			[\lofi_mix, 0, 1, \lin],
			[\ring_freq, 20, 2000, \exp],
			[\ring_wave, 0, 3, \lin],
			[\ring_mix, 0, 1, \lin],
			[\comb_freq, 20, 5000, \exp],
			[\comb_decay, 0.01, 5.0, \lin],
			[\comb_mix, 0, 1, \lin],
			[\delay_time, 1, 2000, \lin],
			[\delay_fb, 0, 0.99, \lin],
			[\delay_mix, 0, 1, \lin],
			[\clouds_pos, 0, 1, \lin],
			[\clouds_size, 0, 1, \lin],
			[\clouds_dens, 0, 1, \lin],
			[\clouds_tex, 0, 1, \lin],
			[\clouds_mode, 0, 3, \lin],
			[\clouds_rvb, 0, 1, \lin],
			[\clouds_mix, 0, 1, \lin]
		];
	}

	generateTable {
		table = Array.fill(65536, { |i|
			thisThread.randSeed = seed + i;
			Array.fill(39, { 1.0.rand });
		});
	}

	at { |index|
		^table[index];
	}

	scaledAt { |index|
		var rawValues = table[index];
		var event = ();

		specs.do { |spec, i|
			var name = spec[0];
			var min = spec[1];
			var max = spec[2];
			var curve = spec[3];
			var rawValue = rawValues[i];
			var scaledValue;

			if (curve == \exp) {
				scaledValue = rawValue.linexp(0, 1, min, max);
			} {
				scaledValue = rawValue.linlin(0, 1, min, max);
			};

			event[name] = scaledValue;
		};

		^event;
	}
}
