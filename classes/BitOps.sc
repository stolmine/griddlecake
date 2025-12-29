// BitOps - True audio-rate bitwise operations for SynthDefs
// Builds UGen graphs that perform bitwise ops at audio rate
// Uses 8 bits by default (16 bits = 2x CPU cost)

BitOps {
	classvar <defaultBits = 8;

	// Convert audio (-1 to 1) to unsigned integer signal
	*toInt { |sig, bits|
		var maxVal = (2 ** (bits ?? defaultBits)) - 1;
		^((sig + 1) * 0.5 * maxVal).floor.clip(0, maxVal);
	}

	// Convert integer signal back to audio (-1 to 1)
	*toAudio { |intSig, bits|
		var maxVal = (2 ** (bits ?? defaultBits)) - 1;
		^(intSig / maxVal * 2) - 1;
	}

	// Extract bit at position (builds UGen graph)
	*getBit { |intSig, bitPos|
		^((intSig / (2 ** bitPos)).floor % 2);
	}

	// Bitwise AND - unrolled for UGen graph
	*and { |sigA, sigB, bits|
		var numBits = bits ?? defaultBits;
		var intA = this.toInt(sigA, numBits);
		var intB = this.toInt(sigB, numBits);
		var result;

		// Unrolled bit-by-bit AND
		result = (0..numBits-1).collect({ |i|
			var bitA = this.getBit(intA, i);
			var bitB = this.getBit(intB, i);
			(bitA * bitB) * (2 ** i);  // AND: both must be 1
		}).sum;

		^this.toAudio(result, numBits);
	}

	// Bitwise OR - unrolled for UGen graph
	*or { |sigA, sigB, bits|
		var numBits = bits ?? defaultBits;
		var intA = this.toInt(sigA, numBits);
		var intB = this.toInt(sigB, numBits);
		var result;

		result = (0..numBits-1).collect({ |i|
			var bitA = this.getBit(intA, i);
			var bitB = this.getBit(intB, i);
			// OR: 1 if either is 1 = a + b - a*b
			(bitA + bitB - (bitA * bitB)) * (2 ** i);
		}).sum;

		^this.toAudio(result, numBits);
	}

	// Bitwise XOR - unrolled for UGen graph
	*xor { |sigA, sigB, bits|
		var numBits = bits ?? defaultBits;
		var intA = this.toInt(sigA, numBits);
		var intB = this.toInt(sigB, numBits);
		var result;

		result = (0..numBits-1).collect({ |i|
			var bitA = this.getBit(intA, i);
			var bitB = this.getBit(intB, i);
			// XOR: 1 if different = (a + b) mod 2
			((bitA + bitB) % 2) * (2 ** i);
		}).sum;

		^this.toAudio(result, numBits);
	}

	// Bitwise NOT
	*not { |sig, bits|
		var numBits = bits ?? defaultBits;
		var intSig = this.toInt(sig, numBits);
		var maxVal = (2 ** numBits) - 1;
		^this.toAudio(maxVal - intSig, numBits);
	}

	// NAND = NOT(AND)
	*nand { |sigA, sigB, bits|
		^this.not(this.and(sigA, sigB, bits), bits);
	}

	// NOR = NOT(OR)
	*nor { |sigA, sigB, bits|
		^this.not(this.or(sigA, sigB, bits), bits);
	}

	// XNOR = NOT(XOR)
	*xnor { |sigA, sigB, bits|
		^this.not(this.xor(sigA, sigB, bits), bits);
	}

	// Crush to N bits (like bitcrusher)
	*crush { |sig, bits|
		var numBits = bits ?? defaultBits;
		^this.toAudio(this.toInt(sig, numBits), numBits);
	}
}
