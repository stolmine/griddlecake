// Clock & Sequencer Module for Griddlecake
// Handles: transport, tap tempo, sequencer, gesture triggering
// Loaded by main.scd after core state is initialized

// ========================================
// GESTURE RECORDER
// ========================================

~gestures = GestureRecorder.new;

// ========================================
// SEQUENCER & CLOCK
// ========================================

~sequencer = Sequencer.new;
~transport = \stopped;
~bpm = 120;
~clock = TempoClock(~bpm / 60);
~tapTimes = [];

// Tap tempo calculation
~tapTimeout = 3.0;  // Reset if gap > 3s (allows ~20 BPM minimum)
~tapTempo = {
	var now = Main.elapsedTime;
	var interval, intervals, avgInterval;

	// Reset if too long since last tap
	if (~tapTimes.size > 0) {
		interval = now - ~tapTimes.last;
		if (interval > ~tapTimeout) {
			~tapTimes = [];
			"[Clock] Tap tempo reset (timeout)".postln;
		};
	};

	~tapTimes = ~tapTimes.add(now);

	// Keep only last 4 taps
	if (~tapTimes.size > 4) { ~tapTimes = ~tapTimes.keep(-4) };

	if (~tapTimes.size >= 2) {
		// Calculate intervals between consecutive taps
		intervals = [];
		(~tapTimes.size - 1).do { |i|
			intervals = intervals.add(~tapTimes[i + 1] - ~tapTimes[i]);
		};

		avgInterval = intervals.sum / intervals.size;
		~bpm = (60 / avgInterval).clip(20, 300);
		~clock.tempo = ~bpm / 60;
		"[Clock] Tap tempo: % BPM (interval: %s)".format(
			~bpm.round(0.1),
			avgInterval.round(0.001)
		).postln;
	} {
		"[Clock] Tap % - need 1 more".format(~tapTimes.size).postln;
	};
};

// Start transport
~startTransport = {
	if (~transport == \stopped) {
		~transport = \running;
		~clockRoutine = Routine({
			loop {
				if (~transport == \running) {
					// Process all sequencer rows
					4.do { |row|
						var step = ~sequencer.getStepForRow(row);
						var gestureSlot = ~sequencer.getGesture(row, step);

						// If step has gesture, trigger it (updates row params)
						if (gestureSlot.notNil) {
							~triggerGestureOnRow.(row, gestureSlot);
						};

						~sequencer.advanceStep(row);
					};

					// Always apply blended params (even if no gesture triggered)
					~applyBlendedParams.();

					// Trigger MiClouds on clock
					~synth.set(\t_clock, 1);

					// Update LEDs
					~updateGridLEDs.();
				};
				~clock.beatDur.wait;
			};
		}).play;
		"[Clock] Transport started".postln;
	};
};

// Stop transport
~stopTransport = {
	if (~transport == \running) {
		~transport = \stopped;
		if (~clockRoutine.notNil) {
			~clockRoutine.stop;
			~clockRoutine = nil;
		};
		// Stop all row playback routines
		4.do { |row|
			if (~rowPlaybackRoutines[row].notNil) {
				~rowPlaybackRoutines[row].stop;
				~rowPlaybackRoutines[row] = nil;
			};
		};
		"[Clock] Transport stopped".postln;
	};
};

// Toggle transport
~toggleTransport = {
	if (~transport == \stopped) {
		~startTransport.();
	} {
		~stopTransport.();
	};
};

// Apply blended params from sequencer (actual param values, not indices)
~applyBlendedParams = {
	var blend = ~sequencer.calculateBlendedParams;
	var voiceParams = blend[0];
	var fxParams = blend[1];

	// Apply voice params directly
	~voiceParamNames.do { |name, i|
		~synth.set(name, voiceParams[i]);
	};

	// Apply FX params directly
	~fxParamNames.do { |name, i|
		~synth.set(name, fxParams[i]);
	};
};

// Per-row gesture playback routines (for interrupt behavior)
~rowPlaybackRoutines = Array.newClear(4);

// Trigger gesture/preset on a row (interrupts any existing playback)
~triggerGestureOnRow = { |row, gestureSlot|
	var gesture, stepsCopy, preset, voiceParams, fxParams;

	// Stop existing playback on this row
	if (~rowPlaybackRoutines[row].notNil) {
		~rowPlaybackRoutines[row].stop;
		~rowPlaybackRoutines[row] = nil;
	};

	if (~gestures.hasGesture(gestureSlot)) {
		if (~gestures.isPreset(gestureSlot)) {
			// Handle preset: apply immediately, no routine needed
			preset = ~gestures.getPreset(gestureSlot);
			if (preset.notNil) {
				voiceParams = ~voiceLut[preset[0].clip(0, 65535)];
				fxParams = ~fxLut[preset[1].clip(0, 65535)];
				~sequencer.setRowParams(row, voiceParams, fxParams);
				~applyBlendedParams.();
				// Update DAC state for LED display
				~voiceDacState = preset[0];
				~fxDacState = preset[1];
				// Flash preset slot
				~flashGestureSlot.(gestureSlot);
			};
		} {
			// Handle gesture: play full sequence
			gesture = ~gestures.gestures[gestureSlot];
			if (gesture.notNil && gesture[\steps].notNil && (gesture[\steps].size > 0)) {
				// Deep copy steps at trigger time (immune to later clearing)
				stepsCopy = gesture[\steps].collect { |step|
					(time: step[\time], voiceState: step[\voiceState], fxState: step[\fxState])
				};

				// Start playback routine for this row
				~rowPlaybackRoutines[row] = Routine({
					var prevTime = 0;

					stepsCopy.do { |step|
						var waitTime = (step[\time] - prevTime) / 1000.0;
						var vParams = ~voiceLut[step[\voiceState].clip(0, 65535)];
						var fParams = ~fxLut[step[\fxState].clip(0, 65535)];

						if (waitTime > 0) { waitTime.wait };

						// Update row's params
						~sequencer.setRowParams(row, vParams, fParams);

						// Recalculate and apply blend
						~applyBlendedParams.();

						prevTime = step[\time];
					};

					// Gesture complete - row latches at final state
					~rowPlaybackRoutines[row] = nil;
				}).play;
			};
		};
	};
};

// Initialize sequencer rows with default params (must be called after LUT init)
~initSequencerRows = {
	4.do { |row|
		~sequencer.setRowParams(row, ~voiceLut[0], ~fxLut[0]);
	};
};

"[Griddlecake] Clock & Sequencer module loaded".postln;
