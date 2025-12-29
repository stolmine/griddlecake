GestureRecorder {
	var <gestures;
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

	startRecording { |slot|
		if ((slot < 0) || (slot >= 16)) {
			Error("Slot index out of range: %".format(slot)).throw;
		};

		this.stop(slot);
		gestures[slot] = (steps: []);
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

	play { |slot, onStep|
		if ((slot < 0) || (slot >= 16)) {
			Error("Slot index out of range: %".format(slot)).throw;
		};

		if (gestures[slot].isNil) {
			^this;
		};

		this.stop(slot);

		states[slot] = \playing;

		playbackRoutines[slot] = Routine({
			var steps = gestures[slot][\steps];
			var totalDuration = steps.last[\time] / 1000.0;

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
				// Small gap before loop restart (or immediate if single-step)
				if (totalDuration > 0) { 0.01.wait };
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
		if (gestures[slot].isNil) {
			^0;
		};
		^gestures[slot][\steps].size;
	}
}
