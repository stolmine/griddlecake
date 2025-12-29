# Monome serialosc Protocol Reference

Complete technical specification for Monome Grid hardware integration via serialosc and OSC.

## Table of Contents

1. [Overview](#overview)
2. [Device Discovery Protocol](#device-discovery-protocol)
3. [System Configuration](#system-configuration)
4. [Grid LED Control](#grid-led-control)
5. [Grid Input Events](#grid-input-events)
6. [Varibright Levels](#varibright-levels)
7. [Timing and Best Practices](#timing-and-best-practices)
8. [SuperCollider Integration](#supercollider-integration)
9. [Complete OSC Message Reference](#complete-osc-message-reference)

---

## Overview

**serialosc** is a daemon that runs in the background, converting serial communication (over USB) into OSC messages. It listens on port 12002 and spawns dedicated server processes for each connected device.

- **Protocol**: OSC (Open Sound Control) over UDP
- **Server Port**: 12002
- **Device Discovery**: Zeroconf/Bonjour (`_monome-osc._udp`)
- **Per-Device Ports**: Dynamically assigned when device connects

---

## Device Discovery Protocol

### Initial Setup

1. Send discovery query to serialosc server (port 12002)
2. Register for device connection/disconnection notifications
3. Receive device information (ID, type, assigned port)
4. Connect directly to device port for LED/input communication

### Discovery Messages (to serialosc server on port 12002)

```
/serialosc/list si <host> <port>
```
Request list of currently connected devices. Server responds with `/serialosc/device` messages.

```
/serialosc/notify si <host> <port>
```
Register to receive device connect/disconnect notifications at specified host:port.

**Important**: After receiving an add/remove notification, you must re-register with `/serialosc/notify` to continue receiving updates.

### Server Response Messages

```
/serialosc/device ssi <id> <type> <port>
```
Device information response.
- `id`: Device serial number (string)
- `type`: Device type (e.g., "monome 128", "monome 64")
- `port`: OSC port assigned to this device (integer)

```
/serialosc/add s <id>
```
Notification that device was connected.

```
/serialosc/remove s <id>
```
Notification that device was disconnected.

---

## System Configuration

Send to device port (not server port 12002).

### Configuration Messages (to device)

```
/sys/port i <port>
```
Set destination port for messages from device (key presses, tilt, etc).

```
/sys/host s <host>
```
Set destination host for messages from device (e.g., "localhost", "127.0.0.1").

```
/sys/prefix s <prefix>
```
Set OSC message prefix (default: "/monome"). All subsequent messages use this prefix.

```
/sys/rotation i <degrees>
```
Rotate grid display. Valid values: 0, 90, 180, 270.

```
/sys/info [si <host> <port>]
```
Request device information. Optional parameters specify where to send response.
If omitted, responds to current sys/host and sys/port.

### Information Responses (from device)

```
/sys/id s <id>
```
Device identifier (serial number).

```
/sys/size ii <x> <y>
```
Grid dimensions (columns, rows).
- 64: 8x8
- 128: 16x8
- 256: 16x16

```
/sys/host s <host>
```
Current destination host.

```
/sys/port i <port>
```
Current destination port.

```
/sys/prefix s <prefix>
```
Current message prefix.

```
/sys/rotation i <degrees>
```
Current rotation setting.

---

## Grid LED Control

All LED messages are sent to device port with configured prefix (default `/monome`).

### Binary LED Control (On/Off)

```
<prefix>/grid/led/set iii <x> <y> <s>
```
Set single LED on (1) or off (0).
- `x`: Column (0-indexed)
- `y`: Row (0-indexed)
- `s`: State (0 = off, 1 = on)

```
<prefix>/grid/led/all i <s>
```
Set all LEDs to same state.
- `s`: State (0 = off, 1 = on)

```
<prefix>/grid/led/map iiiiiiiiii <x_offset> <y_offset> <s[8]>
```
Set 8x8 quadrant using bitmask encoding.
- `x_offset`: Starting column (0 or 8 for 128/256)
- `y_offset`: Starting row (always 0 for 8-row grids)
- `s[8]`: 8 integers, each representing one row as bitmask

**Bitmask encoding**: Each integer represents 8 LEDs in a row.
- Bit 0 (LSB) = leftmost LED
- Bit 7 (MSB) = rightmost LED
- Example: `255` (0b11111111) = all 8 LEDs on

```
<prefix>/grid/led/row iii[..] <x_offset> <y> <s[..]>
```
Set row using bitmask(s).
- `x_offset`: Starting column
- `y`: Row number
- `s[..]`: One or more bitmask integers (each covers 8 LEDs)

```
<prefix>/grid/led/col iii[..] <x> <y_offset> <s[..]>
```
Set column using bitmask(s).
- `x`: Column number
- `y_offset`: Starting row
- `s[..]`: One or more bitmask integers (each covers 8 LEDs)

### Varibright LED Control (0-15 intensity)

```
<prefix>/grid/led/level/set iii <x> <y> <l>
```
Set single LED brightness level.
- `x`: Column (0-indexed)
- `y`: Row (0-indexed)
- `l`: Level (0-15, where 0 = off, 15 = maximum brightness)

```
<prefix>/grid/led/level/all i <l>
```
Set all LEDs to same brightness level.
- `l`: Level (0-15)

```
<prefix>/grid/led/level/map iii[64] <x_offset> <y_offset> <l[64]>
```
Set 8x8 quadrant with individual brightness values.
- `x_offset`: Starting column (0 or 8)
- `y_offset`: Starting row (0)
- `l[64]`: 64 integers (0-15), row-major order

**Order**: Left-to-right, top-to-bottom.
- l[0-7]: First row
- l[8-15]: Second row
- ...
- l[56-63]: Eighth row

```
<prefix>/grid/led/level/row iii[..] <x_offset> <y> <l[..]>
```
Set row with individual brightness values.
- `x_offset`: Starting column
- `y`: Row number
- `l[..]`: Brightness levels (0-15) for each LED

```
<prefix>/grid/led/level/col iii[..] <x> <y_offset> <l[..]>
```
Set column with individual brightness values.
- `x`: Column number
- `y_offset`: Starting row
- `l[..]`: Brightness levels (0-15) for each LED

```
<prefix>/grid/led/intensity i <l>
```
Set global intensity multiplier.
- `l`: Level (0-15)
- Affects all LEDs uniformly (like a master brightness control)

---

## Grid Input Events

Messages sent from device to configured host:port.

### Key Press

```
<prefix>/grid/key iii <x> <y> <s>
```
Button state change.
- `x`: Column (0-indexed)
- `y`: Row (0-indexed)
- `s`: State (1 = key down, 0 = key up)

### Tilt Sensor (if available)

```
<prefix>/tilt iiii <n> <x> <y> <z>
```
3-axis accelerometer data.
- `n`: Sensor number (0-3, grids typically have 1)
- `x`, `y`, `z`: 8-bit acceleration values

```
<prefix>/tilt/set ii <n> <s>
```
Enable (1) or disable (0) tilt sensor.
- `n`: Sensor number
- `s`: State (0 = disabled, 1 = enabled)

---

## Varibright Levels

### Hardware Capabilities by Generation

| Period | Brightness Levels | Notes |
|--------|------------------|-------|
| 2007-2010 | Mono-bright (2 levels) | On or off only |
| 2011 | 4 levels | Off + 3 brightness steps |
| 2012+ | 16 levels | Full varibright (0-15) |
| 2023+ | 16 levels | RP2040-based, USB-C, warm white LEDs |

### Level Quantization

- **16-level devices**: Use full 0-15 range
- **4-level devices**: Firmware quantizes 16 levels to 4 (brightness >> 2)
- **Mono-bright devices**: Any level > 0 = on, 0 = off

### Compatibility

Most modern applications assume 16-level varibright. Older grids will still function but may lose subtle visual indicators that require full brightness range.

---

## Timing and Best Practices

### Refresh Rate Recommendations

**DO:**
- Use timer-driven refresh (not event-driven)
- Target ~30ms interval (approximately 33 fps)
- Implement dirty flag pattern to avoid unnecessary updates

**DON'T:**
- Refresh on every key event
- Send LED updates faster than ~30-33 fps
- Flood serialosc with individual LED messages

### Dirty Flag Pattern

```
// Pseudocode
var dirty = false;
var refreshTimer = 30ms;

onKeyPress(x, y, s) {
    // Update internal state
    gridState[x][y] = s;
    dirty = true;  // Mark for refresh
}

every refreshTimer {
    if (dirty) {
        updateGridDisplay();
        dirty = false;
    }
}
```

### Performance Issues

**Symptoms of over-messaging:**
- Grid LEDs black out or freeze
- Requires physical reconnection to recover
- serialosc becomes unresponsive

**Solutions:**
1. Use batch update methods (`/map`, `/row`, `/col`) instead of individual `/set`
2. Rebuild full frame and send once per refresh cycle
3. Limit refresh rate to 30-33 fps maximum
4. Implement dirty flag to skip redundant updates

### USB Power Considerations

- 256 grids require more USB power than smaller models
- Some USB cables work better than others
- When using with norns on battery: boot with grid already plugged in
- Use quality USB cables for reliable power delivery

---

## SuperCollider Integration

### Official Library: monomeSC

Repository: https://github.com/monome/monomeSC

### Basic Setup

```supercollider
(
// Initialize grid
~m = MonomeGrid.new();

// Connect after server boots (allow slight delay)
s.waitForBoot({
    ~m.connect(0);  // Connect to first device
});
)
```

### Key Input Handling

```supercollider
// Register key callback
~m.key({ arg x, y, z;
    // x: column (0-indexed)
    // y: row (0-indexed)
    // z: state (1 = down, 0 = up)
    [x, y, z].postln;
});
```

### LED Control Methods

```supercollider
// Binary LED control
~m.ledset(x, y, state);  // state: 0 or 1

// Varibright control
~m.led(x, y, level);     // level: 0-15

// Coupled interaction (immediate visual feedback)
~m.key({ arg x, y, z;
    ~m.led(x, y, z * 15);  // Echo key state to LED
});
```

### Device Properties

```supercollider
~m.rows;    // Number of rows
~m.cols;    // Number of columns
~m.serial;  // Device serial number
~m.port;    // OSC port
```

### Full Frame Refresh Pattern

```supercollider
(
// State storage
~gridState = Array.fill(8, { Array.fill(16, 0) });

// Refresh function
~refreshGrid = {
    ~gridState.do({ arg row, y;
        row.do({ arg level, x;
            ~m.led(x, y, level);
        });
    });
};

// Timer-driven refresh with dirty flag
~dirty = false;
~refreshTask = Task({
    loop {
        if (~dirty) {
            ~refreshGrid.value;
            ~dirty = false;
        };
        0.03.wait;  // 30ms = ~33fps
    };
}).play;
)
```

### Alternative Library: sc-monome

Repository: https://github.com/ideoforms/sc-monome

Simplified interface with methods like `.led`, `.led_row`, `.led_col` and `.action` callback.

---

## Complete OSC Message Reference

### To serialosc Server (port 12002)

| Message | Type | Description |
|---------|------|-------------|
| `/serialosc/list` | si | Request device list |
| `/serialosc/notify` | si | Register for notifications |

### From serialosc Server

| Message | Type | Description |
|---------|------|-------------|
| `/serialosc/device` | ssi | Device info (id, type, port) |
| `/serialosc/add` | s | Device connected |
| `/serialosc/remove` | s | Device disconnected |

### To Device (system messages)

| Message | Type | Description |
|---------|------|-------------|
| `/sys/port` | i | Set destination port |
| `/sys/host` | s | Set destination host |
| `/sys/prefix` | s | Set message prefix |
| `/sys/rotation` | i | Set rotation (0/90/180/270) |
| `/sys/info` | [si] | Request device info |

### From Device (system responses)

| Message | Type | Description |
|---------|------|-------------|
| `/sys/id` | s | Device ID |
| `/sys/size` | ii | Grid dimensions |
| `/sys/host` | s | Current host |
| `/sys/port` | i | Current port |
| `/sys/prefix` | s | Current prefix |
| `/sys/rotation` | i | Current rotation |

### To Device (LED control - binary)

| Message | Type | Description |
|---------|------|-------------|
| `<prefix>/grid/led/set` | iii | Single LED on/off |
| `<prefix>/grid/led/all` | i | All LEDs on/off |
| `<prefix>/grid/led/map` | ii + 8i | 8x8 quad (bitmask) |
| `<prefix>/grid/led/row` | iii[..] | Row (bitmask) |
| `<prefix>/grid/led/col` | iii[..] | Column (bitmask) |

### To Device (LED control - varibright)

| Message | Type | Description |
|---------|------|-------------|
| `<prefix>/grid/led/level/set` | iii | Single LED level (0-15) |
| `<prefix>/grid/led/level/all` | i | All LEDs level |
| `<prefix>/grid/led/level/map` | ii + 64i | 8x8 quad levels |
| `<prefix>/grid/led/level/row` | iii[..] | Row levels |
| `<prefix>/grid/led/level/col` | iii[..] | Column levels |
| `<prefix>/grid/led/intensity` | i | Global intensity |

### From Device (input events)

| Message | Type | Description |
|---------|------|-------------|
| `<prefix>/grid/key` | iii | Key press (x, y, state) |
| `<prefix>/tilt` | iiii | Tilt sensor (n, x, y, z) |

### Argument Type Notation

- `s`: String
- `i`: Integer (32-bit)
- `ii`: Two integers
- `iii`: Three integers
- `i[64]`: Array of 64 integers
- `[si]`: Optional string and integer

**Note**: High-level environments (Max/MSP, SuperCollider, Processing) typically don't require explicit type tags.

---

## References and Resources

### Official Documentation
- [serialosc OSC Reference](https://monome.org/docs/serialosc/osc/)
- [serialosc Overview](https://monome.org/docs/serialosc/)
- [Grid Studies: SuperCollider](https://monome.org/docs/grid/studies/sc/)
- [Grid Editions](https://monome.org/docs/grid/editions/)

### GitHub Repositories
- [serialosc Source](https://github.com/monome/serialosc)
- [monomeSC Library](https://github.com/monome/monomeSC)
- [sc-monome Library](https://github.com/ideoforms/sc-monome)
- [Official Documentation Source](https://github.com/monome/docs/blob/gh-pages/serialosc/osc.md)

### Community Resources
- [lines Forum](https://llllllll.co/) - Monome community discussion
- [Getting Started with serialosc Protocol](https://llllllll.co/t/getting-started-with-the-serialosc-protocol/16834)
- [Rate-limiting LED Messages](https://llllllll.co/t/rate-limiting-led-messages/4137)

---

## Technical Notes

### Zeroconf/Bonjour Discovery

In addition to OSC queries, all device ports are discoverable via zeroconf as `_monome-osc._udp` services. This allows automatic discovery on local networks.

### Message Prefix

The default prefix is `/monome`. You can change it to avoid conflicts when multiple applications control the same device, or to namespace different functional areas.

### Grid Coordinate System

- **Origin**: Top-left corner (0, 0)
- **X-axis**: Increases left to right (columns)
- **Y-axis**: Increases top to bottom (rows)
- **Rotation**: Applied before coordinate mapping

### Bitmask Encoding Details

For row/column bitmask messages:
- LSB (bit 0) = first LED in sequence
- MSB (bit 7) = eighth LED
- Multiple integers extend sequence (16 LEDs = 2 integers, etc.)

Example row bitmask:
```
/monome/grid/led/row 0 0 170 85
// x_offset=0, y=0
// 170 = 0b10101010 = alternating pattern for LEDs 0-7
// 85  = 0b01010101 = alternating pattern for LEDs 8-15
```

### Historical Context

The serialosc protocol has remained remarkably stable since 2012. Modern applications should target 16-level varibright but gracefully degrade for older hardware. The 2023 hardware refresh maintains full protocol compatibility while upgrading internals (RP2040, USB-C).

---

**Document Version**: 1.0
**Date**: 2025-12-28
**Protocol Version**: serialosc (2012-present)
