// Test BitOps class - audio-rate bitwise operations
// Run after recompiling class library

(
// Test 1: Visual verification of bit operations
"Testing BitOps class...".postln;

// Simple test synth
SynthDef(\testBitOps, {
	arg mode=0;
	var osc1 = SinOsc.ar(100);
	var osc2 = SinOsc.ar(150);
	var sig;

	sig = Select.ar(mode, [
		osc1,                         // 0: OSC1
		osc2,                         // 1: OSC2
		BitOps.and(osc1, osc2),       // 2: AND
		BitOps.or(osc1, osc2),        // 3: OR
		BitOps.xor(osc1, osc2),       // 4: XOR
		BitOps.not(osc1),             // 5: NOT
		BitOps.crush(osc1, 4),        // 6: 4-bit crush
		BitOps.crush(osc1, 2),        // 7: 2-bit crush
	]);

	Out.ar(0, sig * 0.3 ! 2);
}).add;

s.sync;

// Play test
~test = Synth(\testBitOps);
"BitOps test synth created. Use ~test.set(\\mode, n) where n = 0-7".postln;
"0=osc1, 1=osc2, 2=AND, 3=OR, 4=XOR, 5=NOT, 6=4bit, 7=2bit".postln;
)

// Test each mode
~test.set(\mode, 0);  // OSC1
~test.set(\mode, 2);  // AND - should sound "thinner"
~test.set(\mode, 3);  // OR - should sound "fuller"
~test.set(\mode, 4);  // XOR - should sound "hollow/different"
~test.set(\mode, 5);  // NOT - inverted
~test.set(\mode, 6);  // 4-bit crush
~test.set(\mode, 7);  // 2-bit crush - very crunchy

// Cleanup
~test.free;
