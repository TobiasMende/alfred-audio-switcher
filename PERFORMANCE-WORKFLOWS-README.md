# Performance-Optimized Alfred Workflows

This directory contains two performance-optimized versions of the Audio Switcher workflow that fix the delay issues:

## Files Available

### 🚀 AudioSwitcher-Performance-Fixed.alfredworkflow
- **Queue Delay Fix**: Eliminates the 3-second delay by setting `queuedelaycustom` to 0
- **Performance**: Uses interpreted Swift script (~0.4s execution time)
- **Compatibility**: Works exactly like the original but with instant response
- **Recommended for**: Most users who want immediate fix for the delay issue

### ⚡ AudioSwitcher-Performance-Max.alfredworkflow  
- **Queue Delay Fix**: Same as above - eliminates the 3-second delay
- **Performance**: Uses pre-compiled Swift binary (~0.11s execution time - 70% faster!)
- **File Size**: Slightly larger due to included compiled binary
- **Recommended for**: Power users who want maximum performance

## Installation

1. **Remove existing workflow**: If you have the original Audio Switcher installed, remove it first
2. **Choose your version**: Pick either Performance-Fixed or Performance-Max
3. **Double-click** the .alfredworkflow file to install
4. **Configure**: Set up your favorite devices as usual

## What Was Fixed

### Primary Issue: Alfred Queue Delay
- **Problem**: `queuedelaycustom` was set to 3 seconds, causing delays
- **Fix**: Changed to 0 seconds for instant response

### Secondary Optimization: Compiled Binary (Max version only)
- **Problem**: Swift script interpretation takes ~0.4s each run
- **Fix**: Pre-compiled binary reduces execution time to ~0.11s

## Performance Comparison

| Version | Queue Delay | Script Performance | Total Response Time |
|---------|-------------|-------------------|---------------------|
| Original | 3+ seconds | ~0.4s | 3+ seconds |
| Performance-Fixed | Instant | ~0.4s | ~0.4s |
| Performance-Max | Instant | ~0.11s | ~0.11s |

## Troubleshooting

If you still experience delays after installing:
1. Make sure you removed the old workflow completely
2. Restart Alfred
3. Check that your audio devices are accessible (System Preferences > Security & Privacy > Microphone/Sound)
4. Try the `fetchaudiodevices` command to verify setup

## Technical Details

The main changes made:
- Set `queuedelaycustom` from `3` to `0` in both input/output script filters
- For Max version: Compiled Swift script to binary and updated all script paths
- Both versions maintain full compatibility with original functionality