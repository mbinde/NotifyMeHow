# NotifyMeHow

A macOS utility to customize notification position and appearance.

## Features

- **Move notifications** to any corner or center of the screen
- **Custom duplicate notifications** with full control over:
  - Position
  - Size (scale factor)
  - Opacity
  - Background color
  - Dwell time

## Requirements

- macOS (tested on macOS Tahoe 26.x)
- Accessibility permissions

## Building

```bash
swift build
codesign --force --sign - --entitlements entitlements.plist .build/debug/NotifyMeHow
```

## Usage

```bash
# Move notifications to bottom-left
NotifyMeHow -p bottom-left

# Move to center
NotifyMeHow -p center

# Show custom larger notification alongside the original
NotifyMeHow -p center -c -cp bottom-left -cs 2.0 -cc purple
```

### Options

**Position Options:**
- `-p, --position <pos>` - Set notification position (tr, tl, br, bl, center)
- `-ox, --offset-x <val>` - Horizontal offset from edge
- `-oy, --offset-y <val>` - Vertical offset from edge

**Custom Notification Options:**
- `-c, --custom` - Enable custom duplicate notification
- `-cp, --custom-position` - Position for custom notification
- `-cs, --custom-scale` - Scale factor (default: 1.5)
- `-co, --custom-opacity` - Opacity 0.0-1.0 (default: 0.95)
- `-cd, --custom-dwell` - Display duration in seconds (default: 5.0)
- `-cc, --custom-color` - Background color (hex or name: black, white, blue, red, green, purple, orange)

**Other Options:**
- `-g, --gui` - Run as menu bar application
- `-d, --debug` - Print debug information
- `-h, --help` - Show help

## Permissions

This application requires Accessibility permissions. Grant access in:
**System Settings > Privacy & Security > Accessibility**

## License

MIT
