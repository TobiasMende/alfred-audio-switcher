# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an Alfred workflow for macOS that provides quick switching between audio input and output devices. The workflow is written in Swift and integrates with Alfred's workflow system to provide hotkey-based device switching, favorite device management, and device rotation functionality.

## Architecture

### Core Components

- **main.swift**: Single Swift script that handles all audio device operations using Core Audio APIs
- **info.plist**: Alfred workflow configuration defining triggers, hotkeys, and workflow connections
- **Icons and Images**: Visual assets for the workflow UI (input/output device icons, workflow icons)

### Key Functions in main.swift

- `getAudioDeviceList()`: Retrieves available audio devices for input/output
- `setDefaultAudioDevice()`: Sets the default audio device and optionally syncs sound effects output
- `switchDeviceById()`: Switches to a device by its unique ID
- `switchDeviceByDeviceIndexAndList()`: Switches to a device by index from favorites list
- `rotateFavorites()`: Cycles through favorite devices in sequence
- `printDeviceItems()`: Generates JSON output for Alfred's script filter
- `convertFavoritesList()`: Parses favorite device configurations with optional friendly names

### Alfred Workflow Integration

The workflow uses Alfred's script filter and action system:
- **Script Filters**: Generate dynamic lists of audio devices
- **Hotkeys**: Provide quick access (⌘+F1-F3 for outputs, ⌥+F1-F3 for inputs, F12 for rotation)
- **Remote Triggers**: Allow control via Alfred Remote app
- **Environment Variables**: Configuration through Alfred's workflow variables

## Common Development Tasks

### Testing the Swift Script

Run the main Swift script directly to test functionality:
```bash
# List available output devices
./workflow/main.swift list output

# List available input devices  
./workflow/main.swift list input

# Switch to a device by ID
./workflow/main.swift switch_by_id output <device_id>

# Print device names (for configuration)
./workflow/main.swift print_device_names output
```

### Workflow Configuration

The workflow uses environment variables for configuration:
- `output_keyword`: Alfred keyword for output selection (default: "out")
- `input_keyword`: Alfred keyword for input selection (default: "in")
- `ignorelist`: Devices to exclude from listings (newline-separated)
- `outputs`: Up to 3 favorite output devices (newline-separated)
- `inputs`: Up to 3 favorite input devices (newline-separated)
- `sync_sound_effects_output`: Whether to sync sound effects output (checkbox)

### Friendly Names Feature

Devices can have friendly names by adding a semicolon separator:
```
MacBook Pro Speakers;Mac
RØDE Connect Virtual;RØDE
External Screen
```

### Key Hotkeys

- **⌘+F1/F2/F3**: Switch to output favorites 1/2/3
- **⌥+F1/F2/F3**: Switch to input favorites 1/2/3  
- **⌘+F12**: Rotate through output favorites
- **⌥+F12**: Rotate through input favorites

## Development Notes

- The workflow is self-contained with no external dependencies beyond macOS Core Audio
- All audio device operations use Core Audio APIs directly
- The script handles device availability gracefully (missing favorites won't crash rotation)
- Error handling uses `fatalError()` for critical failures
- JSON output format is compatible with Alfred's script filter requirements
- The workflow supports Alfred Remote for mobile control

## File Structure

```
workflow/
├── main.swift           # Main Swift script with all functionality
├── info.plist          # Alfred workflow configuration
├── icon.png            # Main workflow icon
├── icons/              # Device state icons
│   ├── input.png
│   ├── input_selected.png
│   ├── output.png
│   └── output_selected.png
└── _remote/            # Alfred Remote assets
```

## Installation and Distribution

The workflow is distributed as a `.alfredworkflow` file. Users configure it through Alfred's workflow preferences, setting up favorite devices and keywords as needed.