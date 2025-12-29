(
var lut, rawValues, scaledValues;

lut = LUT.new(12345);

rawValues = lut.at(23456);
"Raw values at index 23456:".postln;
rawValues.postln;

scaledValues = lut.scaledAt(23456);
"\nScaled values at index 23456:".postln;
scaledValues.postln;

"\nVerifying determinism (same seed = same LUT):".postln;
var lut2 = LUT.new(12345);
var match = lut.at(23456) == lut2.at(23456);
"Deterministic: %".format(match).postln;

"\nSeed getter:".postln;
"Seed: %".format(lut.seed).postln;

"\nParameter count verification:".postln;
"Expected: 39, Actual: %".format(rawValues.size).postln;

"\nSample scaled parameters:".postln;
"osc1_freq: %".format(scaledValues[\osc1_freq]).postln;
"osc1_wave: %".format(scaledValues[\osc1_wave]).postln;
"filter_freq: %".format(scaledValues[\filter_freq]).postln;
"clouds_pos: %".format(scaledValues[\clouds_pos]).postln;

"Test complete!".postln;
)
