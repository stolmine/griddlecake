GridInterface {
	classvar <ledOff = 0;
	classvar <ledDim = 3;
	classvar <ledMedium = 8;
	classvar <ledBright = 12;
	classvar <ledFull = 15;

	var <addr;
	var <ledBuffer;
	var <dirty;
	var <refreshTask;
	var <keyAction;
	var <isOscgrid;
	var <prefix;
	var oscHandler;

	*new { |targetIP, targetPort, oscgrid=true, prefix="/monome"|
		^super.new.init(targetIP, targetPort, oscgrid, prefix);
	}

	init { |targetIP, targetPort, oscgridMode, oscPrefix|
		isOscgrid = oscgridMode;
		prefix = oscPrefix;
		addr = NetAddr(targetIP, targetPort);
		dirty = false;

		ledBuffer = 16.collect { 8.collect { 0 } };

		this.startRefresh;
		this.registerOSC;
	}

	led { |x, y, brightness|
		ledBuffer[x][y] = brightness.clip(0, 15);
		dirty = true;
	}

	ledRow { |y, levels|
		levels.do { |lvl, x| ledBuffer[x][y] = lvl.clip(0, 15) };
		dirty = true;
	}

	ledCol { |x, levels|
		levels.do { |lvl, y| ledBuffer[x][y] = lvl.clip(0, 15) };
		dirty = true;
	}

	ledAll { |brightness|
		var clipped = brightness.clip(0, 15);
		ledBuffer = 16.collect { 8.collect { clipped } };
		dirty = true;
	}

	clear {
		this.ledAll(0);
	}

	startRefresh {
		refreshTask = Routine({
			loop {
				if (dirty) {
					this.sendLEDs;
					dirty = false;
				};
				0.033.wait;
			}
		}).play;
	}

	sendLEDs {
		if (isOscgrid) {
			16.do { |x|
				8.do { |y|
					var ledPath = "/grid/led " ++ (x+1) ++ " " ++ (y+1);
					addr.sendMsg(ledPath, ledBuffer[x][y]);
				}
			};
		} {
			8.do { |y|
				var levels = 16.collect { |x| ledBuffer[x][y] };
				addr.sendMsg(prefix ++ "/grid/led/level/row", 0, y, *levels);
			};
		};
	}

	stopRefresh {
		refreshTask.stop;
	}

	registerOSC {
		oscHandler = { |msg, time, addr|
			var path = msg[0].asString;
			if (path.beginsWith("/grid/key")) {
				var parts = path.split($ );
				var x = parts[1].asInteger;
				var y = parts[2].asInteger;
				var state = msg[1];
				// oscgrid is 1-indexed, convert to 0-indexed
				if (isOscgrid) { x = x - 1; y = y - 1 };
				keyAction.value(x, y, state);
			};
		};
		thisProcess.addOSCRecvFunc(oscHandler);
	}

	key { |func|
		keyAction = func;
	}

	getZone { |x, y|
		^case
		{ x == 0 } { \navigation }
		{ (x >= 1) && (x <= 4) && (y <= 3) } { \paramGrid }
		{ (x >= 5) && (x <= 7) && (y <= 3) } { \utilities }
		{ (x >= 8) && (x <= 11) && (y <= 3) } { \slewGrid }
		{ (x >= 12) && (y <= 3) } { \gestures }
		{ y >= 4 } { \sequencer }
		{ \unknown };
	}

	free {
		this.stopRefresh;
		this.clear;
		this.sendLEDs;
		if (oscHandler.notNil) {
			thisProcess.removeOSCRecvFunc(oscHandler);
		};
	}
}
