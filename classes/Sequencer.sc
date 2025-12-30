Sequencer {
	var <rowVoiceParams;  // 4 rows × 20 voice params
	var <rowFxParams;     // 4 rows × 19 FX params
	var <currentStep;
	var <loopLengths;
	var <stepGestures;
	var <rowIsActive;

	*new {
		^super.new.init;
	}

	init {
		// Store actual param values per row (not LUT indices)
		rowVoiceParams = Array.fill(4, { Array.fill(20, { 0 }) });
		rowFxParams = Array.fill(4, { Array.fill(19, { 0 }) });
		currentStep = Array.fill(4, { 0 });
		loopLengths = Array.fill(4, { 16 });
		stepGestures = Array.fill(4, { Array.newClear(16) });
		rowIsActive = Array.fill(4, { true });
	}

	setLoopLength { |row, length|
		if ((row < 0) || (row >= 4)) {
			Error("Row index out of range: %".format(row)).throw;
		};
		if ((length < 1) || (length > 16)) {
			Error("Loop length out of range: %".format(length)).throw;
		};
		loopLengths[row] = length;
	}

	assignGesture { |row, step, slotOrNil|
		if ((row < 0) || (row >= 4)) {
			Error("Row index out of range: %".format(row)).throw;
		};
		if ((step < 0) || (step >= 16)) {
			Error("Step index out of range: %".format(step)).throw;
		};
		if (slotOrNil.notNil) {
			if ((slotOrNil < 0) || (slotOrNil >= 16)) {
				Error("Gesture slot out of range: %".format(slotOrNil)).throw;
			};
		};
		stepGestures[row][step] = slotOrNil;
	}

	getGesture { |row, step|
		if ((row < 0) || (row >= 4)) {
			Error("Row index out of range: %".format(row)).throw;
		};
		if ((step < 0) || (step >= 16)) {
			Error("Step index out of range: %".format(step)).throw;
		};
		^stepGestures[row][step];
	}

	advanceStep { |row|
		if ((row < 0) || (row >= 4)) {
			Error("Row index out of range: %".format(row)).throw;
		};
		currentStep[row] = (currentStep[row] + 1) % loopLengths[row];
	}

	advanceAll {
		4.do { |row|
			this.advanceStep(row);
		};
	}

	setRowParams { |row, voiceParams, fxParams|
		if ((row < 0) || (row >= 4)) {
			Error("Row index out of range: %".format(row)).throw;
		};
		rowVoiceParams[row] = voiceParams;
		rowFxParams[row] = fxParams;
	}

	getRowParams { |row|
		if ((row < 0) || (row >= 4)) {
			Error("Row index out of range: %".format(row)).throw;
		};
		^[rowVoiceParams[row], rowFxParams[row]];
	}

	calculateBlendedParams {
		var activeCount = 0;
		var voiceBlend = Array.fill(20, { 0 });
		var fxBlend = Array.fill(19, { 0 });

		// Sum params from active rows
		4.do { |row|
			if (rowIsActive[row]) {
				20.do { |i| voiceBlend[i] = voiceBlend[i] + rowVoiceParams[row][i] };
				19.do { |i| fxBlend[i] = fxBlend[i] + rowFxParams[row][i] };
				activeCount = activeCount + 1;
			};
		};

		// Calculate mean
		if (activeCount == 0) {
			^[voiceBlend, fxBlend];  // All zeros
		};

		voiceBlend = voiceBlend.collect { |v| v / activeCount };
		fxBlend = fxBlend.collect { |v| v / activeCount };

		^[voiceBlend, fxBlend];
	}

	reset {
		4.do { |row|
			currentStep[row] = 0;
		};
	}

	getStepForRow { |row|
		if ((row < 0) || (row >= 4)) {
			Error("Row index out of range: %".format(row)).throw;
		};
		^currentStep[row];
	}

	hasGestureAt { |row, step|
		if ((row < 0) || (row >= 4)) {
			Error("Row index out of range: %".format(row)).throw;
		};
		if ((step < 0) || (step >= 16)) {
			Error("Step index out of range: %".format(step)).throw;
		};
		^stepGestures[row][step].notNil;
	}

	setRowActive { |row, active|
		if ((row < 0) || (row >= 4)) {
			Error("Row index out of range: %".format(row)).throw;
		};
		rowIsActive[row] = active;
	}

	getRowActive { |row|
		if ((row < 0) || (row >= 4)) {
			Error("Row index out of range: %".format(row)).throw;
		};
		^rowIsActive[row];
	}
}
