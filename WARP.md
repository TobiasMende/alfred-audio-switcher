# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

This is an Alfred App workflow written in Swift that enables quick switching between audio input and output devices on macOS. The workflow provides hotkeys and Alfred Remote triggers to switch between up to 3 favorite devices per type, with rotation functionality.

## Architecture

The project consists of a single Swift script (`workflow/main.swift`) that serves as an executable workflow for Alfred. The script uses CoreAudio framework to interact with macOS audio devices and provides a JSON-based interface for Alfred's script filter system.

### Key Components

- **`workflow/main.swift`**: Executable Swift script containing all functionality
- **`workflow/info.plist`**: Alfred workflow configuration defining triggers, hotkeys, and workflow connections
- **`workflow/icons/`**: Device state icons (input/output, selected/unselected)
- **Alfred Variables**: Runtime configuration for device lists, keywords, and ignore lists

### Core Functions

- `getAudioDeviceList()`: Retrieves available audio devices using CoreAudio
- `setDefaultAudioDevice()`: Changes system default audio device
- `printDeviceItems()`: Outputs Alfred-compatible JSON for device selection
- `rotateFavorites()`: Cycles through favorite devices
- Device filtering and friendly name mapping

## Common Commands

### Building and Performance Optimization

```bash
# Build compiled version for better performance (70% faster)
cd workflow && swiftc main.swift -o main_compiled

# Performance comparison
time ./main.swift list output "" ""      # ~0.4s (interpreted)
time ./main_compiled list output "" ""   # ~0.11s (compiled)

# Optional: Replace interpreted script with compiled binary
# (Remember to update plist script paths from ./main.swift to ./main_compiled)
```

### Testing the Swift Script

```bash
# Test device listing
cd workflow && ./main.swift list output "" ""

# Test device listing with ignored devices
cd workflow && ./main.swift list input "iPhone Microphone" ""

# Print all device names for configuration
cd workflow && ./main.swift print_device_names output
cd workflow && ./main.swift print_device_names input

# Test device switching (requires valid device ID)
cd workflow && ./main.swift switch_by_id output 12345

# Test rotation functionality
cd workflow && ./main.swift rotate_favorites output "Device1\nDevice2"
```

### Alfred Workflow Development

```bash
# Make script executable (if needed)
chmod +x workflow/main.swift

# Test Swift syntax without execution
swift -parse workflow/main.swift

# Check file permissions
ls -la workflow/main.swift
```

### Packaging for Distribution

```bash
# Create Alfred workflow package (from workflow directory)
cd workflow
zip -r ../AudioSwitcher.alfredworkflow *

# Or using Alfred's built-in export functionality through Alfred Preferences
```

## Development Workflow

### Local Development

1. **Edit `workflow/main.swift`** - All logic is contained in this single file
2. **Test via command line** - Use the testing commands above
3. **Test in Alfred** - Use the `fetchaudiodevices` keyword or hotkeys
4. **Debug via Alfred's workflow debugger** - Enable logging in Alfred Preferences

### Device Configuration

1. Use `fetchaudiodevices` in Alfred to get device names
2. Copy device names to Clipboard
3. Configure in Alfred workflow variables:
   - **Output Favorites**: Up to 3 output device names (one per line)
   - **Input Favorites**: Up to 3 input device names (one per line)
   - **Ignorelist**: Devices to hide from selection (one per line)

### Friendly Names

Device names can include friendly names using semicolon syntax:
```
MacBook Pro Speakers;Mac
RØDE Connect Virtual;RØDE
External Screen
```

## Key Hotkeys and Triggers

- **⌘ + F1/F2/F3**: Switch to output favorites 1/2/3
- **⌥ + F1/F2/F3**: Switch to input favorites 1/2/3
- **⌘ + F12**: Rotate through output favorites
- **⌥ + F12**: Rotate through input favorites
- **Alfred Remote**: All functions available via remote triggers

## Environment Variables

The script reads these Alfred workflow variables:
- `outputs`: Newline-separated list of favorite output devices
- `inputs`: Newline-separated list of favorite input devices
- `ignorelist`: Newline-separated list of devices to ignore
- `output_keyword`: Alfred keyword for output selection (default: "out")
- `input_keyword`: Alfred keyword for input selection (default: "in")
- `sync_sound_effects_output`: If "1", synchronizes sound effects output with main output

## Performance Issues

### Queue Delay Fix

If the workflow feels slow when typing "in" or "out", check the Alfred queue delay settings in `info.plist`:

```bash
# The queuedelaycustom should be 0 or 1, not 3+ seconds
# Look for these lines in info.plist:
# <key>queuedelaycustom</key>
# <integer>3</integer>  <!-- This causes 3-second delays! -->
```

### Script Performance Optimization

```bash
# Compile the script for 70% better performance
cd workflow && swiftc main.swift -o main_compiled

# Update info.plist script references from:
# ./main.swift  →  ./main_compiled
```

## Debugging

### Common Issues

- **Slow response (3+ seconds)**: Check queue delay settings in info.plist - should be 0-1, not 3
- **Permission errors**: Ensure macOS Audio permissions are granted
- **Device not found**: Check device names match exactly (case-sensitive)
- **Swift compilation issues**: Check macOS developer tools are installed

### Debug Commands

```bash
# Check if CoreAudio framework is accessible
swift -c 'import CoreAudio; print("CoreAudio available")'

# Test basic device enumeration
cd workflow && ./main.swift print_device_names output | head -5

# Validate workflow structure
plutil -lint workflow/info.plist
```

## Project Structure Notes

- This is a self-contained Alfred workflow with no external dependencies
- The Swift script is executable and interpreted at runtime (not compiled)
- All audio manipulation uses macOS CoreAudio framework
- Alfred handles UI, hotkeys, and workflow orchestration via the plist configuration
- Icons and visual elements are contained within the workflow bundle