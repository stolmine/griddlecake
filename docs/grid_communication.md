# Grid Communication

OSC protocol implementation for oscgrid (iPad) and serialosc (hardware Grid).

---

## Overview

Griddlecake uses OSC over UDP for all grid communication. The same SuperCollider code handles both oscgrid (iPad emulation) and serialosc (hardware), with only connection setup differing.

**Key principle:** Timer-driven LED refresh with dirty flag pattern. Never update LEDs on every key event.

---

## oscgrid Setup (iPad)

### Prerequisites

1. oscgrid repo at `~/repos/oscgrid`
2. TouchOSC app on iPad
3. iPad and Mac on same WiFi network

### Configuration

**Find your Mac's IP:**
```bash
ipconfig getifaddr en0  # WiFi
# or
ipconfig getifaddr en1  # Ethernet
```

**Edit oscgrid config** (`~/repos/oscgrid/lib/oscgrid.lua` lines 6-7):
```lua
local oscsourceip = "YOUR_IPAD_IP"   -- iPad's IP address
local oscsourceport = 9000           -- TouchOSC incoming port
```

**TouchOSC settings on iPad:**
- Host: Your Mac's IP address
- Send Port: 57120 (SuperCollider default)
- Receive Port: 9000

### OSC Message Format (oscgrid)

**IMPORTANT:** oscgrid uses **1-indexed** coordinates (1-16, 1-8), not 0-indexed.

| Direction | Message | Args | Notes |
|-----------|---------|------|-------|
| In (key press) | `/grid/key x y` | `state` (int) | x: 1-16, y: 1-8, state: 1=down/0=up |
| Out (LED) | `/grid/led x y` | `brightness` (int) | brightness: 0-15 |

**No prefix** - oscgrid uses bare `/grid/...` paths.

---

## serialosc Setup (Hardware Grid)

### Prerequisites

1. serialosc daemon installed: https://monome.org/docs/serialosc/setup/
2. Hardware Grid connected via USB

### Device Discovery

serialosc runs on **port 12002**. Query for connected devices:

```supercollider
// Ask serialosc for device list
~serialosc = NetAddr("localhost", 12002);
~serialosc.sendMsg('/serialosc/list', "localhost", 57120);

// Response arrives as /serialosc/device with: id, type, port
OSCdef(\deviceList, { |msg|
    var id = msg[1], type = msg[2], port = msg[3];
    "Found device: % (%) on port %".format(id, type, port).postln;
}, '/serialosc/device');
```

### Device Configuration

Once you have the device port:

```supercollider
~gridPort = 12345;  // From discovery
~grid = NetAddr("localhost", ~gridPort);

// Set prefix (all messages will use this)
~grid.sendMsg('/sys/prefix', "/monome");

// Set destination for key messages
~grid.sendMsg('/sys/host', "localhost");
~grid.sendMsg('/sys/port', 57120);

// Query device info
~grid.sendMsg('/sys/info');
```

### OSC Message Format (serialosc)

**0-indexed** coordinates (0-15, 0-7). All messages prefixed (default `/monome`).

| Direction | Message | Args | Notes |
|-----------|---------|------|-------|
| In (key) | `/monome/grid/key` | `x y state` | 0-indexed |
| Out (LED single) | `/monome/grid/led/set` | `x y brightness` | 0-15 |
| Out (LED row) | `/monome/grid/led/level/row` | `x_off y *levels` | 8 brightness values |
| Out (LED map) | `/monome/grid/led/level/map` | `x_off y_off *levels` | 64 values (8x8 quad) |
| Out (LED all) | `/monome/grid/led/level/all` | `brightness` | Single value |

---

## SuperCollider Implementation

### GridInterface Class Design

```supercollider
GridInterface {
    var <addr;           // NetAddr for sending
    var <ledBuffer;      // 16x8 array of brightness values (0-15)
    var <dirty;          // Boolean - needs refresh
    var <refreshTask;    // Routine for timer-driven refresh
    var <keyAction;      // User callback for key presses
    var <isOscgrid;      // true = oscgrid (1-indexed), false = serialosc (0-indexed)
    var <prefix;         // OSC prefix (serialosc only)

    *new { |targetIP, targetPort, oscgrid=true, prefix="/monome"|
        ^super.new.init(targetIP, targetPort, oscgrid, prefix);
    }

    init { |targetIP, targetPort, oscgridMode, oscPrefix|
        isOscgrid = oscgridMode;
        prefix = oscPrefix;
        addr = NetAddr(targetIP, targetPort);
        dirty = false;

        // Initialize LED buffer (all off)
        ledBuffer = 16.collect { 8.collect { 0 } };

        // Start refresh loop
        this.startRefresh;

        // Register OSC receiver
        this.registerOSC;
    }

    // --- LED Control ---

    led { |x, y, brightness|
        // Store in buffer, mark dirty
        ledBuffer[x][y] = brightness.clip(0, 15);
        dirty = true;
    }

    ledRow { |y, levels|
        // Set entire row
        levels.do { |lvl, x| ledBuffer[x][y] = lvl.clip(0, 15) };
        dirty = true;
    }

    ledAll { |brightness|
        ledBuffer = 16.collect { 8.collect { brightness.clip(0, 15) } };
        dirty = true;
    }

    clear { this.ledAll(0) }

    // --- Refresh Loop ---

    startRefresh {
        refreshTask = Routine({
            loop {
                if (dirty) { this.sendLEDs; dirty = false };
                0.033.wait;  // ~30fps
            }
        }).play;
    }

    sendLEDs {
        if (isOscgrid) {
            // oscgrid: individual LED messages (1-indexed)
            16.do { |x|
                8.do { |y|
                    addr.sendMsg("/grid/led", x+1, y+1, ledBuffer[x][y]);
                }
            };
        } {
            // serialosc: use row messages for efficiency (0-indexed)
            8.do { |y|
                var levels = 16.collect { |x| ledBuffer[x][y] };
                addr.sendMsg(prefix ++ "/grid/led/level/row", 0, y, *levels);
            };
        };
    }

    stopRefresh {
        refreshTask.stop;
    }

    // --- Key Input ---

    registerOSC {
        if (isOscgrid) {
            // oscgrid: /grid/key with space-separated x y in path
            OSCdef(\gridKey, { |msg, time, replyAddr|
                var path = msg[0].asString;
                var parts = path.split($ );
                var x = parts[1].asInteger - 1;  // Convert to 0-indexed
                var y = parts[2].asInteger - 1;
                var state = msg[1];
                keyAction.value(x, y, state);
            }, '/grid/key', recvPort: 57120);
        } {
            // serialosc: standard /prefix/grid/key x y state
            OSCdef(\gridKey, { |msg|
                var x = msg[1], y = msg[2], state = msg[3];
                keyAction.value(x, y, state);
            }, (prefix ++ "/grid/key").asSymbol);
        };
    }

    key { |func|
        keyAction = func;
    }

    // --- Cleanup ---

    free {
        this.stopRefresh;
        this.clear;
        this.sendLEDs;
        OSCdef(\gridKey).free;
    }
}
```

### Usage Example

```supercollider
// oscgrid (iPad)
~grid = GridInterface("10.0.1.11", 9000, oscgrid: true);

// serialosc (hardware) - after discovery
~grid = GridInterface("localhost", 14235, oscgrid: false, prefix: "/monome");

// Set key handler
~grid.key({ |x, y, state|
    if (state == 1) {
        "Key down: %, %".format(x, y).postln;
        ~grid.led(x, y, 15);  // Light up on press
    } {
        ~grid.led(x, y, 0);   // Off on release
    };
});

// Cleanup
~grid.free;
```

---

## Critical Timing Considerations

### The Blackout Problem

Sending too many LED messages can cause the Grid to **black out completely**, requiring physical reconnection. This happens when:
- Updating LEDs on every key event
- Sending individual LED messages for full-grid updates
- Refresh rate too high (>60fps)

### Solution: Timer-Driven Refresh

```
┌─────────────────────────────────────────┐
│  Key Event                              │
│    └─▶ Update ledBuffer[x][y]           │
│    └─▶ Set dirty = true                 │
│                                         │
│  Timer (every 33ms)                     │
│    └─▶ if (dirty) sendLEDs()            │
│    └─▶ dirty = false                    │
└─────────────────────────────────────────┘
```

### Recommended Settings

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Refresh interval | 30-33ms | 30fps, safe for all devices |
| Batch method | Row-based | 8 messages vs 128 for full update |
| Key debounce | None needed | OSC handles this |

---

## Coordinate Systems

### Grid Layout (0-indexed internal)

```
       0   1   2   3   4   5   6   7   8   9  10  11  12  13  14  15
     ┌───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┬───┐
  0  │   │   │   │   │   │   │   │   │   │   │   │   │   │   │   │   │
     ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  1  │   │   │   │   │   │   │   │   │   │   │   │   │   │   │   │   │
     ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  2  │   │   │   │   │   │   │   │   │   │   │   │   │   │   │   │   │
     ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  3  │   │   │   │   │   │   │   │   │   │   │   │   │   │   │   │   │
     ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  4  │   │   │   │   │   │   │   │   │   │   │   │   │   │   │   │   │
     ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  5  │   │   │   │   │   │   │   │   │   │   │   │   │   │   │   │   │
     ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  6  │   │   │   │   │   │   │   │   │   │   │   │   │   │   │   │   │
     ├───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┼───┤
  7  │   │   │   │   │   │   │   │   │   │   │   │   │   │   │   │   │
     └───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┴───┘
```

### Index Conversion

```supercollider
// oscgrid → internal (1-indexed to 0-indexed)
~fromOscgrid = { |x, y| [x - 1, y - 1] };

// internal → oscgrid
~toOscgrid = { |x, y| [x + 1, y + 1] };

// serialosc uses 0-indexed (no conversion needed)
```

---

## Button Routing

All coordinates below are 0-indexed (internal representation).

### Zone Detection

```supercollider
~getZone = { |x, y|
    case
    { x == 0 } { \navigation }              // Column 0
    { x <= 4 && y <= 3 } { \paramGrid }     // Cols 1-4, rows 0-3
    { x <= 8 && y <= 3 } { \slewGrid }      // Cols 5-8, rows 0-3
    { x <= 11 && y <= 3 } { \utilities }    // Cols 9-11, rows 0-3
    { x >= 12 && y <= 3 } { \gestures }     // Cols 12-15, rows 0-3
    { y >= 4 } { \sequencer }               // Rows 4-7
    { \unknown }
};
```

### Action Dispatch

```supercollider
~handleKey = { |x, y, state|
    var zone = ~getZone.(x, y);

    if (state == 1) {  // Key down only
        switch(zone,
            \navigation, { ~handleNav.(x, y) },
            \paramGrid,  { ~handleParam.(x - 1, y) },  // Offset for zone
            \slewGrid,   { ~handleSlew.(x - 5, y) },
            \utilities,  { ~handleUtil.(x - 9, y) },
            \gestures,   { ~handleGesture.(x - 12, y) },
            \sequencer,  { ~handleSeq.(x, y - 4) }
        );
    };
};
```

---

## LED Feedback Patterns

### Brightness Levels

| Level | Use Case |
|-------|----------|
| 0 | Off |
| 3 | Empty/inactive slot |
| 8 | Has content but not current |
| 12 | Highlighted/hover |
| 15 | Active/on/current |

### Blinking

```supercollider
// Blink pattern for recording
~blinkLED = { |x, y, onTime=0.1, offTime=0.1|
    Routine({
        loop {
            ~grid.led(x, y, 15);
            onTime.wait;
            ~grid.led(x, y, 0);
            offTime.wait;
        }
    }).play;
};
```

---

## Connection Testing

### Quick Test (oscgrid)

```supercollider
// 1. Start SC, boot server
s.boot;

// 2. Create grid connection
~grid = NetAddr("10.0.1.11", 9000);  // Your iPad IP

// 3. Listen for keys
OSCdef(\test, { |msg| msg.postln }, '/grid/key');

// 4. Send test LED (center of grid)
~grid.sendMsg("/grid/led", 8, 4, 15);

// Press buttons on TouchOSC - should see messages in post window
```

### Verify Round-Trip

```supercollider
// Light up whatever button is pressed
OSCdef(\echo, { |msg|
    var parts = msg[0].asString.split($ );
    var x = parts[1].asInteger;
    var y = parts[2].asInteger;
    var state = msg[1];
    ~grid.sendMsg("/grid/led", x, y, state * 15);
}, '/grid/key');
```

---

## Related Documents

- [Grid Layout](grid_layout.md) - Button zones and functions
- [Technical Notes](technical_notes.md) - SC architecture
- [Implementation](implementation.md) - Build phases
