// Grid Handler Module for Griddlecake
// Handles: grid connection, key handling, LED updates
// Loaded by main.scd after clock_sequencer.scd

// ========================================
// GRID STATE
// ========================================

// Grid config - UPDATE THESE for your setup
~gridIP = "192.168.1.244";  // iPad IP for oscgrid
~gridPort = 9000;           // TouchOSC receive port

// Current page (0 = synth/voice, 1 = FX)
~currentPage = 0;

// Separate 16-bit DAC states for each page
~voiceDacState = 0;
~fxDacState = 0;

// Modifier state: track pressed sequencer step for hold+tap gestures
~pressedSeqStep = nil;  // [row, step] or nil

// Modifier state: track pressed page button for preset saving
~pressedPageButton = nil;  // 0 = synth, 1 = FX, nil = none

// Slew grid state (4-bit each, 0-15)
~slewTimeBits = 0;    // Row 0: time (10ms-10s)
~slewCurveBits = 0;   // Row 1: curve (-8 to +8)

// Convert slew bits to actual values
~getSlewTime = { ~slewTimeBits.linexp(0, 15, 0.01, 10.0) };
~getSlewCurve = { ~slewCurveBits.linlin(0, 15, -8, 8) };

// Apply current slew settings to synth
~applySlew = {
	var time = ~getSlewTime.();
	var curve = ~getSlewCurve.();
	~synth.set(\slew_time, time, \slew_curve, curve);
	"[Grid] Slew: %s, curve %".format(time.round(0.001), curve.round(0.1)).postln;
};

// Track flashing slots (so updateGridLEDs doesn't overwrite)
~flashingSlots = Set.new;

// Track active preset for mutual exclusion (manual taps only)
~activePreset = nil;

// Flash a gesture slot LED (for preset feedback)
~flashGestureSlot = { |slot|
	var col = slot % 4;
	var row = (slot / 4).floor.asInteger;
	if (~grid.notNil) {
		~flashingSlots.add(slot);
		~grid.led(col + 12, row, GridInterface.ledFull);
		AppClock.sched(0.15, {
			~flashingSlots.remove(slot);
			~updateGridLEDs.();
			nil;
		});
	};
};

// Play gesture or apply preset (manual tap version)
~playGesture = { |slot|
	if (~gestures.isPreset(slot)) {
		// Preset: apply instantly, no loop
		var preset = ~gestures.getPreset(slot);
		if (preset.notNil) {
			~voiceDacState = preset[0];
			~fxDacState = preset[1];
			~applyVoiceState.(~voiceDacState);
			~applyFxState.(~fxDacState);
			~activePreset = slot;  // Mutual exclusion: only this preset active
			~updateGridLEDs.();  // Update LEDs to dim other presets
			~flashGestureSlot.(slot);  // Flash feedback (overrides for this slot)
			"[Grid] Applied preset % (activePreset now %)".format(slot, ~activePreset).postln;
		};
	} {
		// Gesture: play with looping (clears active preset)
		~activePreset = nil;
		~updateGridLEDs.();
		~gestures.play(slot, { |voiceState, fxState|
			~voiceDacState = voiceState;
			~fxDacState = fxState;
			~applyVoiceState.(voiceState);
			~applyFxState.(fxState);
			~updateGridLEDs.();
		});
	};
};

// ========================================
// GRID CONNECTION
// ========================================

~connectGrid = {
	// Disconnect existing grid first to prevent duplicate handlers
	if (~gestureBreathTask.notNil) {
		~gestureBreathTask.stop;
		~gestureBreathTask = nil;
	};
	if (~grid.notNil) {
		"[Griddlecake] Disconnecting existing grid...".postln;
		~grid.free;
		~grid = nil;
	};

	"[Griddlecake] Connecting to grid at %:%".format(~gridIP, ~gridPort).postln;
	~grid = GridInterface(~gridIP, ~gridPort, oscgrid: true);

	// Set up key handler
	~grid.key({ |x, y, state|
		var zone = ~grid.getZone(x, y);

		// Normal UI handling (modal overlay is just visual)
		if (state == 1) {
			switch(zone,
				\navigation, {
					// Column 0: page select + clock controls
					if (y == 0) {
						if (~engineModalActive) {
							~engineModalActive = false;
							"[Grid] Engine modal closed".postln;
						} {
							~currentPage = 0;
							~pressedPageButton = 0;
							"[Grid] Page: Synth".postln;
						};
					};
					if (y == 1) {
						if (~engineModalActive) {
							~engineModalActive = false;
							"[Grid] Engine modal closed".postln;
						} {
							~currentPage = 1;
							~pressedPageButton = 1;
							"[Grid] Page: FX".postln;
						};
					};
					if (y == 2) {
						// Tap tempo - OR set loop length if seq step held
						if (~pressedSeqStep.notNil) {
							var row = ~pressedSeqStep[0];
							var step = ~pressedSeqStep[1];
							~sequencer.setLoopLength(row, step + 1);
							"[Grid] Seq row % loop length: %".format(row, step + 1).postln;
						} {
							~tapTempo.();
						};
					};
					if (y == 3) { ~toggleTransport.() };
					~updateGridLEDs.();
				},
				\paramGrid, {
					if (~engineModalActive) {
						// Engine selection mode (row 0 only)
						if (y == 0) {
							var engineIdx = x - 1;
							if (engineIdx < ~engineOrder.size) {
								var engineKey = ~engineOrder[engineIdx];
								var engine = ~engines[engineKey];
								if (engine[\implemented] ? false) {
									~switchEngine.(engineKey);
								} {
									"[Grid] Engine % not implemented".format(engineKey).postln;
								};
							};
						};
						~engineModalActive = false;
					} {
						// Normal: 16-bit DAC toggle
						var bitPos = ((y * 4) + (x - 1));

						if (~currentPage == 0) {
							~voiceDacState = ~voiceDacState.bitXor(1 << (15 - bitPos));
							~applyVoiceState.(~voiceDacState);
							"[Grid] Voice DAC: % (bit % toggled)".format(~voiceDacState, 15 - bitPos).postln;
						} {
							~fxDacState = ~fxDacState.bitXor(1 << (15 - bitPos));
							~applyFxState.(~fxDacState);
							"[Grid] FX DAC: % (bit % toggled)".format(~fxDacState, 15 - bitPos).postln;
						};

						// Record step if recording
						if (~recordingSlot.notNil) {
							~gestures.addStep(~recordingSlot, ~voiceDacState, ~fxDacState);
						};
					};
					~updateGridLEDs.();
				},
				\slewGrid, {
					var col = x - 8;
					var bitPos = 3 - col;
					var bitMask = 1 << bitPos;

					if (y == 0) {
						~slewTimeBits = ~slewTimeBits.bitXor(bitMask);
						~applySlew.();
					};
					if (y == 1) {
						~slewCurveBits = ~slewCurveBits.bitXor(bitMask);
						~applySlew.();
					};
					~updateGridLEDs.();
				},
				\utilities, {
					var rowShift = (3 - y) * 4;
					var rowMask = 0xF << rowShift;
					var dacState = if(~currentPage == 0) { ~voiceDacState } { ~fxDacState };
					var rowBits = (dacState & rowMask) >> rowShift;
					var newRowBits, newDacState;

					~grid.led(x, y, GridInterface.ledMedium);

					if (x == 5) { newRowBits = 0; "[Grid] Clear row %".format(y).postln; };
					if (x == 6) { newRowBits = rowBits.bitXor(0xF); "[Grid] Invert row %".format(y).postln; };
					if (x == 7) { newRowBits = ((rowBits >> 1) | ((rowBits & 1) << 3)) & 0xF; "[Grid] Shift row %".format(y).postln; };

					newDacState = (dacState & rowMask.bitNot) | (newRowBits << rowShift);

					if (~currentPage == 0) {
						~voiceDacState = newDacState;
						~applyVoiceState.(~voiceDacState);
					} {
						~fxDacState = newDacState;
						~applyFxState.(~fxDacState);
					};

					if (~recordingSlot.notNil) {
						~gestures.addStep(~recordingSlot, ~voiceDacState, ~fxDacState);
					};
					~updateGridLEDs.();
				},
				\gestures, {
					var slot = ((y * 4) + (x - 12));

					if (~pressedSeqStep.notNil) {
						var row = ~pressedSeqStep[0];
						var step = ~pressedSeqStep[1];
						~sequencer.assignGesture(row, step, slot);
						"[Grid] Seq row % step %: assigned gesture %".format(row, step, slot).postln;
					} {
						if (~pressedPageButton.notNil) {
							~gestures.savePreset(slot, ~voiceDacState, ~fxDacState);
							"[Grid] Saved preset to slot % (voice: %, fx: %)".format(slot, ~voiceDacState, ~fxDacState).postln;
						} {
							var state = ~gestures.getState(slot);
							switch(state,
								\empty, {
									~gestures.startRecording(slot);
									~recordingSlot = slot;
									"[Grid] Recording gesture %".format(slot).postln;
								},
								\recording, {
									~gestures.stopRecording(slot);
									~recordingSlot = nil;
									"[Grid] Stopped recording gesture %".format(slot).postln;
									~playGesture.(slot);
								},
								\stopped, { ~playGesture.(slot); "[Grid] Playing gesture %".format(slot).postln; },
								\paused, { ~playGesture.(slot); "[Grid] Resumed gesture %".format(slot).postln; },
								\playing, { }
							);
						};
					};
					~updateGridLEDs.();
				},
				\sequencer, {
					var step = x;
					var row = y - 4;
					~pressedSeqStep = [row, step];
					"[Grid] Seq step pressed: row %, step %".format(row, step).postln;
					~updateGridLEDs.();
				}
			);
		} {
			// Key release
			var zone = ~grid.getZone(x, y);
			if (zone == \sequencer) { ~pressedSeqStep = nil; };
			if (zone == \navigation) { if (y < 2) { ~pressedPageButton = nil; }; };
		};
	});

	// Hold callback
	~grid.hold({ |x, y|
		var zone = ~grid.getZone(x, y);
		if (zone == \gestures) {
			var slot = ((y * 4) + (x - 12));
			~gestures.clear(slot);
			"[Grid] Gesture % cleared".format(slot).postln;
			~updateGridLEDs.();
		};
		if (zone == \navigation) {
			if (y < 2) {
				~engineModalActive = true;
				"[Grid] Engine select modal opened".postln;
				~updateGridLEDs.();
			};
			if (y == 3) {
				~stopTransport.();
				~sequencer.reset;
				"[Clock] Transport reset to beginning".postln;
				~updateGridLEDs.();
			};
		};
	});

	// Double-tap callback
	~grid.doubleTap({ |x, y|
		var zone = ~grid.getZone(x, y);
		if (zone == \gestures) {
			var slot = ((y * 4) + (x - 12));
			~gestures.pause(slot);
			"[Grid] Gesture % paused".format(slot).postln;
			~updateGridLEDs.();
		};
		if (zone == \sequencer) {
			var step = x;
			var row = y - 4;
			~sequencer.assignGesture(row, step, nil);
			"[Grid] Seq row % step %: cleared".format(row, step).postln;
			~updateGridLEDs.();
		};
	});

	// LED update function
	~updateGridLEDs = {
		var dacState = if(~currentPage == 0) { ~voiceDacState } { ~fxDacState };

		// Param grid (cols 1-4)
		4.do { |y| 4.do { |x|
			var bitPos = ((y * 4) + x);
			var isOn = (dacState >> (15 - bitPos)) & 1;
			~grid.led(x + 1, y, isOn * GridInterface.ledFull);
		}};

		// Engine modal overlay
		if (~engineModalActive) {
			~engineOrder.do { |key, i|
				var x = i + 1;
				var engine = ~engines[key];
				var brightness = case
					{ key == ~currentEngine } { GridInterface.ledFull }
					{ engine[\implemented] ? false } { GridInterface.ledMedium }
					{ true } { GridInterface.ledDim };
				~grid.led(x, 0, brightness);
			};
		};

		// Utilities (cols 5-7)
		4.do { |row|
			~grid.led(5, row, GridInterface.ledDim);
			~grid.led(6, row, GridInterface.ledDim);
			~grid.led(7, row, GridInterface.ledDim);
		};

		// Slew grid (cols 8-11)
		4.do { |col|
			var bitPos = 3 - col;
			~grid.led(col + 8, 0, ((~slewTimeBits >> bitPos) & 1) * GridInterface.ledFull);
			~grid.led(col + 8, 1, ((~slewCurveBits >> bitPos) & 1) * GridInterface.ledFull);
			~grid.led(col + 8, 2, GridInterface.ledDim);
			~grid.led(col + 8, 3, GridInterface.ledDim);
		};

		// Gesture slots (cols 12-15)
		4.do { |row|
			4.do { |col|
				var slot = (row * 4) + col;
				if (~flashingSlots.includes(slot).not) {
					var state = ~gestures.getState(slot);
					if (state != \playing) {
						var brightness;
						var isPreset = ~gestures.isPreset(slot);

						if (isPreset && ~activePreset.notNil && (~activePreset == slot)) {
							brightness = GridInterface.ledFull;
						} {
							brightness = switch(state,
								\empty, { GridInterface.ledOff },
								\recording, { GridInterface.ledFull },
								\stopped, { if (isPreset) { GridInterface.ledDim } { GridInterface.ledMedium } },
								\paused, { GridInterface.ledBright },
								{ GridInterface.ledDim }
							);
						};
						~grid.led(col + 12, row, brightness);
					};
				};
			};
		};

		// Navigation (col 0)
		if (~engineModalActive) {
			~grid.led(0, 0, GridInterface.ledFull);
			~grid.led(0, 1, GridInterface.ledFull);
		} {
			~grid.led(0, 0, if(~currentPage == 0) { GridInterface.ledFull } { GridInterface.ledDim });
			~grid.led(0, 1, if(~currentPage == 1) { GridInterface.ledFull } { GridInterface.ledDim });
		};
		~grid.led(0, 2, GridInterface.ledDim);
		~grid.led(0, 3, if(~transport == \running) { GridInterface.ledFull } { GridInterface.ledDim });

		// Sequencer (rows 4-7)
		4.do { |row|
			var currentStep = ~sequencer.getStepForRow(row);
			var loopLen = ~sequencer.loopLengths[row];

			16.do { |step|
				var brightness;
				if (step >= loopLen) {
					brightness = GridInterface.ledOff;
				} {
					if (step == currentStep) {
						brightness = GridInterface.ledFull;
					} {
						if (~sequencer.hasGestureAt(row, step)) {
							brightness = GridInterface.ledMedium;
						} {
							brightness = GridInterface.ledDim;
						};
					};
				};
				~grid.led(step, row + 4, brightness);
			};
		};
	};

	// Gesture LED breathing task
	~gestureBreathTask = Routine({
		var phase = 0;
		loop {
			4.do { |row|
				4.do { |col|
					var slot = (row * 4) + col;
					if (~gestures.getState(slot) == \playing) {
						var breath = (phase.sin + 1) / 2;
						var brightness = (GridInterface.ledMedium + (breath * 7)).asInteger;
						~grid.led(col + 12, row, brightness);
					};
				};
			};
			phase = phase + 0.15;
			0.033.wait;
		};
	}).play;

	~updateGridLEDs.();
	"[Griddlecake] Grid connected".postln;
};

// Disconnect grid
~disconnectGrid = {
	if (~gestureBreathTask.notNil) {
		~gestureBreathTask.stop;
		~gestureBreathTask = nil;
	};
	if (~clockRoutine.notNil) {
		~clockRoutine.stop;
		~clockRoutine = nil;
	};
	4.do { |row|
		if (~rowPlaybackRoutines[row].notNil) {
			~rowPlaybackRoutines[row].stop;
			~rowPlaybackRoutines[row] = nil;
		};
	};
	~transport = \stopped;
	if (~grid.notNil) {
		~grid.free;
		~grid = nil;
		"[Griddlecake] Grid disconnected".postln;
	};
};

"[Griddlecake] Grid Handler module loaded".postln;
