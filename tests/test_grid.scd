// Grid Connection Tests
// Tests for oscgrid (iPad) and serialosc (hardware Grid)
// All coordinates 0-indexed internally

// SETUP INSTRUCTIONS
// ==================
//
// oscgrid (iPad):
// 1. Edit ~/repos/oscgrid/lib/oscgrid.lua lines 6-7:
//    - oscsourceip = "YOUR_IPAD_IP"
//    - oscsourceport = 9000
// 2. TouchOSC on iPad:
//    - Host: Your Mac IP (run: ipconfig getifaddr en0)
//    - Send Port: 57120
//    - Receive Port: 9000
// 3. Update IP below in oscgrid section
//
// serialosc (hardware):
// 1. Install serialosc daemon from monome.org
// 2. Connect Grid via USB
// 3. Run discovery code below to find port

(
// CONNECTION CONFIG
~gridConfig = (
	// oscgrid (iPad)
	oscgridIP: "192.168.1.244",
	oscgridPort: 9000,

	// serialosc (hardware) - set after discovery
	serialoscPort: nil
);

// UTILITY: Grid interface wrapper
~makeGrid = { |ip, port, isOscgrid=true|
	(
		addr: NetAddr(ip, port),
		isOscgrid: isOscgrid,
		led: { |self, x, y, b|
			if (self.isOscgrid)
				{ self.addr.sendMsg("/grid/led", x+1, y+1, b.clip(0, 15)) }
				{ self.addr.sendMsg("/monome/grid/led/set", x, y, b.clip(0, 15)) };
		},
		clear: { |self|
			if (self.isOscgrid)
				{ 16.do { |x| 8.do { |y| self.led(x, y, 0) } } }
				{ self.addr.sendMsg("/monome/grid/led/level/all", 0) };
		},
		cleanup: { |self| OSCdef(\gridTest).free; self.clear; }
	)
};

// Parse incoming key message (handles both oscgrid and serialosc)
~parseKey = { |msg, isOscgrid|
	if (isOscgrid) {
		var parts = msg[0].asString.split($ );
		[parts[1].asInteger - 1, parts[2].asInteger - 1, msg[1]]
	} {
		[msg[1], msg[2], msg[3]]
	}
};

// TEST 1: Quick Connection Test
~testConnection = {
	"[1] CONNECTION TEST - Center 2x2 pattern + key listener".postln;
	~grid = ~makeGrid.(~gridConfig.oscgridIP, ~gridConfig.oscgridPort);
	~grid.led(7, 3, 15); ~grid.led(8, 3, 15);
	~grid.led(7, 4, 15); ~grid.led(8, 4, 15);
	OSCdef(\gridTest, { |msg|
		var parsed = ~parseKey.(msg, ~grid.isOscgrid);
		"Key: x=% y=% state=%".format(parsed[0], parsed[1], parsed[2]).postln;
	}, '/grid/key');
	"Press buttons to verify. Run ~grid.cleanup to stop.".postln;
};

// TEST 2: Echo Test
~testEcho = {
	"[2] ECHO TEST - Press any button, LED mirrors state".postln;
	~grid = ~makeGrid.(~gridConfig.oscgridIP, ~gridConfig.oscgridPort);
	~grid.clear;
	OSCdef(\gridTest, { |msg|
		var parsed = ~parseKey.(msg, ~grid.isOscgrid);
		~grid.led(parsed[0], parsed[1], parsed[2] * 15);
	}, '/grid/key');
	"Run ~grid.cleanup to stop.".postln;
};

// TEST 3: Zone Test
~testZones = {
	"[3] ZONE TEST - Light zones at different brightness".postln;
	~grid = ~makeGrid.(~gridConfig.oscgridIP, ~gridConfig.oscgridPort);
	~grid.clear;
	4.do { |y| ~grid.led(0, y, 12) };
	4.do { |x| 4.do { |y| ~grid.led(x+1, y, 15) } };
	4.do { |x| 4.do { |y| ~grid.led(x+5, y, 10) } };
	3.do { |x| 4.do { |y| ~grid.led(x+9, y, 8) } };
	4.do { |x| 4.do { |y| ~grid.led(x+12, y, 5) } };
	16.do { |x| 4.do { |y| ~grid.led(x, y+4, 3) } };
	"nav=12, param=15, slew=10, util=8, gesture=5, seq=3. Run ~grid.cleanup".postln;
};

// TEST 4: Sweep Test
~testSweep = {
	"[4] SWEEP TEST - Animate across grid at 20fps".postln;
	~grid = ~makeGrid.(~gridConfig.oscgridIP, ~gridConfig.oscgridPort);
	~grid.clear;
	~sweepTask = Routine({
		var x = 0, y = 0;
		loop {
			~grid.clear; ~grid.led(x, y, 15);
			x = (x + 1) % 16; if (x == 0) { y = (y + 1) % 8 };
			0.05.wait;
		}
	}).play;
	"Run ~sweepTask.stop; ~grid.cleanup to stop.".postln;
};

// TEST 5: Round-Trip Latency Test
~testLatency = {
	"[5] LATENCY TEST - Measure key->LED response time".postln;
	~grid = ~makeGrid.(~gridConfig.oscgridIP, ~gridConfig.oscgridPort);
	~grid.clear;
	~latencies = [];
	OSCdef(\gridTest, { |msg|
		var parsed = ~parseKey.(msg, ~grid.isOscgrid);
		var x = parsed[0], y = parsed[1], state = parsed[2];
		var t1, lat;
		if (state == 1) {
			t1 = Main.elapsedTime;
			~grid.led(x, y, 15);
			lat = (Main.elapsedTime - t1) * 1000;
			~latencies = ~latencies.add(lat);
			"Press (%,%): %.2f ms".format(x, y, lat).postln;
			if (~latencies.size >= 10) {
				"Stats: mean=%.2f min=%.2f max=%.2f ms".format(
					~latencies.mean, ~latencies.minItem, ~latencies.maxItem
				).postln;
			};
		} { ~grid.led(x, y, 0) };
	}, '/grid/key');
	"Run ~grid.cleanup to stop.".postln;
};

// HARDWARE GRID: Discovery helper
~discoverGrid = {
	"Querying serialosc for devices...".postln;
	~serialosc = NetAddr("localhost", 12002);
	~serialosc.sendMsg('/serialosc/list', "localhost", 57120);
	OSCdef(\deviceList, { |msg|
		"Found: % (%) on port %".format(msg[1], msg[2], msg[3]).postln;
		~gridConfig.serialoscPort = msg[3];
	}, '/serialosc/device');
};

"Grid tests loaded. Commands:".postln;
"  ~testConnection  ~testEcho  ~testZones  ~testSweep  ~testLatency".postln;
"  ~discoverGrid (for hardware Grid)".postln;
)
