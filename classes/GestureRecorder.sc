GestureRecorder {
	var <gestures;  // Can be preset or gesture type
	var <states;
	var <recordingStartTimes;
	var <playbackRoutines;

	*new {
		^super.new.init;
	}

	init {
		gestures = Array.newClear(16);
		states = Array.fill(16, { \empty });
		recordingStartTimes = Array.newClear(16);
		playbackRoutines = Array.newClear(16);
	}

	// ========================================
	// PRESET METHODS
	// ========================================

	savePreset { |slot, voiceState, fxState|
		if ((slot < 0) || (slot >= 16)) {
			Error("Slot index out of range: %".format(slot)).throw;
		};

		this.stop(slot);
		gestures[slot] = (
			type: \preset,
			voiceState: voiceState,
			fxState: fxState
		);
		states[slot] = \stopped;
	}

	isPreset { |slot|
		if ((slot < 0) || (slot >= 16)) {
			Error("Slot index out of range: %".format(slot)).throw;
		};
		if (gestures[slot].isNil) { ^false };
		^(gestures[slot][\type] == \preset);
	}

	getPreset { |slot|
		if ((slot < 0) || (slot >= 16)) {
			Error("Slot index out of range: %".format(slot)).throw;
		};
		if (this.isPreset(slot).not) { ^nil };
		^[gestures[slot][\voiceState], gestures[slot][\fxState]];
	}

	// ========================================
	// GESTURE RECORDING METHODS
	// ========================================

	startRecording { |slot|
		if ((slot < 0) || (slot >= 16)) {
			Error("Slot index out of range: %".format(slot)).throw;
		};

		this.stop(slot);
		gestures[slot] = (type: \gesture, steps: []);
		states[slot] = \recording;
		recordingStartTimes[slot] = Main.elapsedTime;
	}

	stopRecording { |slot|
		if ((slot < 0) || (slot >= 16)) {
			Error("Slot index out of range: %".format(slot)).throw;
		};

		if (states[slot] == \recording) {
			if (gestures[slot][\steps].size > 0) {
				states[slot] = \stopped;
			} {
				gestures[slot] = nil;
				states[slot] = \empty;
			};
			recordingStartTimes[slot] = nil;
		};
	}

	addStep { |slot, voiceState, fxState|
		if ((slot < 0) || (slot >= 16)) {
			Error("Slot index out of range: %".format(slot)).throw;
		};

		if (states[slot] == \recording) {
			var elapsedMs = ((Main.elapsedTime - recordingStartTimes[slot]) * 1000).asInteger;
			var step = (
				time: elapsedMs,
				voiceState: voiceState,
				fxState: fxState
			);
			gestures[slot][\steps] = gestures[slot][\steps].add(step);
		};
	}

	// ========================================
	// GESTURE PLAYBACK METHODS
	// ========================================

	play { |slot, onStep|
		var steps, totalDuration;

		if ((slot < 0) || (slot >= 16)) {
			Error("Slot index out of range: %".format(slot)).throw;
		};

		if (gestures[slot].isNil) { ^this };

		// Presets don't play - they apply instantly via getPreset
		if (this.isPreset(slot)) { ^this };

		steps = gestures[slot][\steps];
		if (steps.isNil || (steps.size == 0)) { ^this };

		this.stop(slot);
		states[slot] = \playing;

		totalDuration = steps.last[\time] / 1000.0;

		playbackRoutines[slot] = Routine({
			loop {
				var prevTime = 0;
				steps.do { |step|
					var waitTime = (step[\time] - prevTime) / 1000.0;
					if (waitTime > 0) {
						waitTime.wait;
					};
					onStep.value(step[\voiceState], step[\fxState]);
					prevTime = step[\time];
				};
				// Always wait before loop restart (prevents tight loop)
				max(0.01, totalDuration * 0.1).wait;
			};
		}).play;
	}

	pause { |slot|
		if ((slot < 0) || (slot >= 16)) {
			Error("Slot index out of range: %".format(slot)).throw;
		};

		if (states[slot] == \playing) {
			if (playbackRoutines[slot].notNil) {
				playbackRoutines[slot].stop;
				playbackRoutines[slot] = nil;
			};
			states[slot] = \paused;
		};
	}

	stop { |slot|
		if ((slot < 0) || (slot >= 16)) {
			Error("Slot index out of range: %".format(slot)).throw;
		};

		if (playbackRoutines[slot].notNil) {
			playbackRoutines[slot].stop;
			playbackRoutines[slot] = nil;
		};

		if (states[slot] == \recording) {
			this.stopRecording(slot);
		} {
			if ((states[slot] == \playing) || (states[slot] == \paused)) {
				if (gestures[slot].notNil) {
					states[slot] = \stopped;
				} {
					states[slot] = \empty;
				};
			};
		};
	}

	// ========================================
	// COMMON METHODS
	// ========================================

	clear { |slot|
		if ((slot < 0) || (slot >= 16)) {
			Error("Slot index out of range: %".format(slot)).throw;
		};

		this.stop(slot);
		gestures[slot] = nil;
		states[slot] = \empty;
	}

	getState { |slot|
		if ((slot < 0) || (slot >= 16)) {
			Error("Slot index out of range: %".format(slot)).throw;
		};
		^states[slot];
	}

	hasGesture { |slot|
		if ((slot < 0) || (slot >= 16)) {
			Error("Slot index out of range: %".format(slot)).throw;
		};
		^gestures[slot].notNil;
	}

	stepCount { |slot|
		if ((slot < 0) || (slot >= 16)) {
			Error("Slot index out of range: %".format(slot)).throw;
		};
		if (gestures[slot].isNil) { ^0 };
		if (this.isPreset(slot)) { ^1 };  // Presets count as 1 step
		^gestures[slot][\steps].size;
	}
}
