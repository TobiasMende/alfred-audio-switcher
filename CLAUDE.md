# CLAUDE.md

Alfred workflow for macOS audio input/output device switching via Core Audio APIs.

## Architecture

- **main.swift**: All audio device logic (Core Audio). Compiled on first run by `run.sh`.
- **run.sh**: Wrapper. Compiles `main.swift` → `main` binary if missing or stale. Falls back to interpreted mode without `swiftc`.
- **info.plist**: Alfred workflow config (triggers, hotkeys, connections). All script refs point to `./run.sh`.

## Testing

```bash
./workflow/run.sh list output
./workflow/run.sh list input
./workflow/run.sh switch_by_id output <device_id>
./workflow/run.sh print_device_names output
```

## Environment Variables

- `output_keyword` / `input_keyword`: Alfred keywords (default: "out" / "in")
- `ignorelist`: Excluded devices (newline-separated)
- `outputs` / `inputs`: Up to 3 favorites (newline-separated)
- `sync_sound_effects_output`: Sync sound effects output ("1" = on)

## Friendly Names

Semicolon-separated: `MacBook Pro Speakers;Mac`

## Hotkeys

- **Cmd+F1/F2/F3**: Output favorites 1/2/3
- **Opt+F1/F2/F3**: Input favorites 1/2/3
- **Cmd+F12** / **Opt+F12**: Rotate output / input favorites

## Dev Notes

- No external dependencies. Core Audio only.
- Missing favorites skip gracefully during rotation.
- `fatalError()` for critical failures.
- JSON output matches Alfred script filter format.
- `workflow/main` (compiled binary) is gitignored.

## File Structure

```
workflow/
├── main.swift        # Swift source
├── run.sh            # Compile-and-run wrapper
├── main              # Compiled binary (gitignored)
├── info.plist        # Alfred workflow config
├── icon.png
├── icons/            # Device state icons
└── _remote/          # Alfred Remote assets
```

## Distribution

Distributed as `.alfredworkflow`. First run compiles binary (~7s), then ~150ms per invocation.
