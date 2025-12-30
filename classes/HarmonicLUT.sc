HarmonicLUT {
	classvar <scales, <scaleNames, <justRatios;
	var <lut, <seed;

	*initClass {
		// 16 scales as semitone offsets from root
		scales = [
			[0, 2, 4, 5, 7, 9, 11],      // 0: Major (Ionian)
			[0, 2, 3, 5, 7, 8, 10],      // 1: Natural Minor (Aeolian)
			[0, 2, 3, 5, 7, 8, 11],      // 2: Harmonic Minor
			[0, 2, 3, 5, 7, 9, 11],      // 3: Melodic Minor
			[0, 2, 3, 5, 7, 9, 10],      // 4: Dorian
			[0, 1, 3, 5, 7, 8, 10],      // 5: Phrygian
			[0, 2, 4, 6, 7, 9, 11],      // 6: Lydian
			[0, 2, 4, 5, 7, 9, 10],      // 7: Mixolydian
			[0, 1, 3, 5, 6, 8, 10],      // 8: Locrian
			[0, 2, 4, 7, 9],             // 9: Pentatonic Major
			[0, 3, 5, 7, 10],            // 10: Pentatonic Minor
			[0, 3, 5, 6, 7, 10],         // 11: Blues
			[0, 2, 4, 6, 8, 10],         // 12: Whole Tone
			[0, 1, 3, 4, 6, 7, 9, 10],   // 13: Diminished (half-whole)
			[0, 3, 4, 7, 8, 11],         // 14: Augmented
			[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]  // 15: Chromatic
		];

		scaleNames = [
			"Major", "Natural Minor", "Harmonic Minor", "Melodic Minor",
			"Dorian", "Phrygian", "Lydian", "Mixolydian",
			"Locrian", "Pentatonic Maj", "Pentatonic Min", "Blues",
			"Whole Tone", "Diminished", "Augmented", "Chromatic"
		];

		// 5-limit Just Intonation ratios for 12 semitones
		justRatios = [
			1,         // 0: Unison
			16/15,     // 1: Minor 2nd
			9/8,       // 2: Major 2nd
			6/5,       // 3: Minor 3rd
			5/4,       // 4: Major 3rd
			4/3,       // 5: Perfect 4th
			45/32,     // 6: Tritone
			3/2,       // 7: Perfect 5th
			8/5,       // 8: Minor 6th
			5/3,       // 9: Major 6th
			9/5,       // 10: Minor 7th
			15/8       // 11: Major 7th
		];
	}

	*new { |seed|
		^super.new.init(seed);
	}

	init { |argSeed|
		seed = argSeed ?? { Date.seed };
		this.generate;
	}

	generate {
		lut = Array.fill(65536, { |i|
			if (i == 0) {
				// State 0: Home base - all on root, no detune
				(
					osc1Degree: 0,
					osc2Degree: 0,
					osc3Degree: 0,
					osc1Octave: 0,
					osc2Octave: 0,
					osc3Octave: 0,
					voicingSpread: 0,
					detune: 0
				)
			} {
				// Chord-aware degree generation for consonant intervals
				var chordTemplates = [
					[0, 2, 4],  // Root triad (1-3-5)
					[0, 2, 4],  // Root triad (doubled weight)
					[0, 4, 4],  // Power chord (1-5-5)
					[0, 0, 4],  // Root + fifth (1-1-5)
					[0, 2, 6],  // 7th chord (1-3-7)
					[0, 3, 4],  // Sus4 (1-4-5)
					[0, 1, 4],  // Sus2/add2 (1-2-5)
					[0, 2, 5],  // Add6 (1-3-6)
					[0, 0, 0],  // Unison/octaves
					[0, 4, 7],  // Root + 5th + octave above 3rd
				];
				var chord = chordTemplates.choose;
				var octaveSpread;

				thisThread.randSeed = seed + i;

				// Octave spread patterns for variety
				octaveSpread = [
					[0, 0, 0],   // Close voicing
					[0, 0, 1],   // Third voice up
					[0, 1, 1],   // Upper voices up
					[-1, 0, 0],  // Bass down
					[-1, 0, 1],  // Wide spread
					[0, 0, 0],   // Close (doubled weight)
				].choose;

				(
					osc1Degree: chord[0],
					osc2Degree: chord[1],
					osc3Degree: chord[2],
					osc1Octave: octaveSpread[0] + [-1, 0, 0, 0].choose,
					osc2Octave: octaveSpread[1] + [0, 0, 1].choose,
					osc3Octave: octaveSpread[2] + [0, 0, 1].choose,
					voicingSpread: rrand(0.0, 1.0),
					detune: rrand(0.0, 0.3).pow(1.5)  // Very subtle
				)
			};
		});
	}

	// Get entry at index
	at { |index|
		^lut[index.asInteger.clip(0, 65535)]
	}

	// Calculate frequency for a degree within a scale
	*degreeToSemitone { |degree, scaleIndex|
		var scale = scales[scaleIndex.asInteger.clip(0, 15)];
		var octaveOffset = (degree / scale.size).floor.asInteger;
		var degreeInScale = degree % scale.size;
		^scale[degreeInScale] + (octaveOffset * 12)
	}

	// Calculate frequency from degree, root, scale, octave, and tuning
	*calcFreq { |degree, root, scaleIndex, octaveOffset, tuning = \tet, baseFreq = 55|
		var semitone = this.degreeToSemitone(degree, scaleIndex) + root;
		var totalSemitone = semitone + (octaveOffset * 12);

		^if (tuning == \just) {
			var octaves = (totalSemitone / 12).floor;
			var semitoneInOctave = totalSemitone % 12;
			baseFreq * (2 ** octaves) * justRatios[semitoneInOctave]
		} {
			// 12TET
			baseFreq * (2 ** (totalSemitone / 12))
		}
	}

	// Get frequencies for all 3 oscillators from a LUT entry
	getFreqs { |index, root = 0, scaleIndex = 0, tuning = \tet, baseFreq = 55|
		var entry = this.at(index);
		^[
			HarmonicLUT.calcFreq(entry.osc1Degree, root, scaleIndex, entry.osc1Octave, tuning, baseFreq),
			HarmonicLUT.calcFreq(entry.osc2Degree, root, scaleIndex, entry.osc2Octave, tuning, baseFreq),
			HarmonicLUT.calcFreq(entry.osc3Degree, root, scaleIndex, entry.osc3Octave, tuning, baseFreq)
		]
	}

	// Get detune amount from entry
	getDetune { |index|
		^this.at(index).detune
	}

	// Get voicing spread from entry
	getVoicingSpread { |index|
		^this.at(index).voicingSpread
	}

	// Utility: Print entry info
	printEntry { |index, root = 0, scaleIndex = 0|
		var entry = this.at(index);
		var freqs = this.getFreqs(index, root, scaleIndex);
		"HarmonicLUT entry %:".format(index).postln;
		"  Degrees: %, %, %".format(entry.osc1Degree, entry.osc2Degree, entry.osc3Degree).postln;
		"  Octaves: %, %, %".format(entry.osc1Octave, entry.osc2Octave, entry.osc3Octave).postln;
		"  Freqs (root=%, scale=%): %, %, %".format(
			root, HarmonicLUT.scaleNames[scaleIndex],
			freqs[0].round(0.1), freqs[1].round(0.1), freqs[2].round(0.1)
		).postln;
		"  Detune: %, Spread: %".format(entry.detune.round(0.01), entry.voicingSpread.round(0.01)).postln;
	}

	// Regenerate with new seed
	reseed { |newSeed|
		seed = newSeed ?? { Date.seed };
		this.generate;
	}
}
