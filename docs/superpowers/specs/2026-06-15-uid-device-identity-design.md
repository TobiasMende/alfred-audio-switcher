# UID-based Device Identity

**Date:** 2026-06-15
**Status:** Approved, pending implementation

## Problem

Two monitors of the same model report an identical Core Audio device name
(`kAudioDevicePropertyDeviceNameCFString`). The workflow keys everything on this
name, which breaks in three ways:

1. **List** (`printDeviceItems`): both monitors render with the same title — the
   user cannot tell them apart.
2. **Friendly Names** (`convertFavoritesList`): the map is keyed by name, so both
   monitors receive the same mapping. One cannot be relabelled independently.
3. **Switching / favorites / rotation** (`getAudioDeviceIdByName`): matches with
   `.first { $0.name == ... }`, so the same monitor is always selected and the
   other is unreachable via name-based config.

A secondary defect: the JSON `uid` field in `deviceToJson` is misnamed — it sends
`device.name`, not a real device UID.

## Goal

Make a specific physical device addressable and distinguishable everywhere
(list, friendly names, favorites, switching, rotation), using the stable
Core Audio device UID (`kAudioDevicePropertyDeviceUID`), while keeping all
existing name-based configuration working unchanged.

## Non-goals

- No automatic migration / rewrite of existing env-var config.
- No clipboard / Alfred-modifier action for copying UIDs (deferred).
- No new test framework — testing stays manual via `run.sh`.

## Design

All changes are in `workflow/main.swift` unless noted.

### 1. Data model

The device tuple `(name: String, id: AudioDeviceID)` becomes
`(name: String, uid: String, id: AudioDeviceID)`.

New function:

```swift
func getDeviceUID(deviceID: AudioDeviceID) -> String? {
    var size = UInt32(MemoryLayout<CFString>.size)
    var uid: CFString = "" as CFString
    var address = createPropertyAddress(selector: kAudioDevicePropertyDeviceUID)
    let status = withUnsafeMutablePointer(to: &uid) { ptr in
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, ptr)
    }
    return status == noErr ? (uid as String) : nil
}
```

`getAudioDeviceList` populates `uid` for each device. If `getDeviceUID` returns
`nil`, `uid` is set to `""` (empty). UID retrieval is non-critical: do **not**
`fatalError`. With an empty UID, collision suffixing cannot apply to that device
and only name-based matching is available for it — acceptable degradation.

### 2. Matching

Rename `getAudioDeviceIdByName(deviceName:type:)` →
`getAudioDeviceId(byKey:type:)`. Match precedence:

1. exact `device.uid == key`
2. else first `device.name == key`

Callers: `switchDeviceByDeviceIndexAndList`, `rotateFavorites`.

Name fallback keeps existing name-based config working. A UID key targets one
specific monitor. UIDs contain no `;`, so they are safe inside the
semicolon-delimited favorites format.

### 3. Friendly name resolution

In `printDeviceItems`, resolve a device's display name as:

```
favoriteMap[device.uid] ?? favoriteMap[device.name] ?? device.name
```

One env-var line may key on either the UID or the name.

### 4. Rotation

`rotateFavorites` currently locates the current device by name only
(`deviceList.firstIndex(of: defaultDevice.name)`) and matches list entries by
name. Update so the current-device match and the per-entry lookup both compare
against UID **or** name (reuse `getAudioDeviceId(byKey:)` and compare the default
device's `uid`/`name` against each key). This lets a UID-keyed favorites list
rotate correctly between two identically-named monitors.

### 5. Collision display

In `printDeviceItems`, after computing the displayed (friendly) name for each
device: if **two or more devices share the same `device.name`** AND a device has
**no explicit friendly mapping** (neither `favoriteMap[uid]` nor
`favoriteMap[name]` matched), put the full `<uid>` in that item's Alfred
**subtitle**. The title stays the clean device name.

- Devices with unique names: empty subtitle.
- Devices the user explicitly named: empty subtitle (already distinct).
- The subtitle UID doubles as the exact string to paste into config. If `uid` is
  empty, no subtitle is set.

Example colliding output: title `Dell U2720Q`, subtitle
`AppleHDAEngineOutput:1B,0,1,0:0`.

### 6. print_device_names

`printDeviceNames` outputs one line per device as `name\tUID` (tab-separated),
replacing name-only output. This is the user's UID-discovery path.

### 7. JSON `uid` field

`deviceToJson` currently sends `device.name` in the JSON `uid` field. Change it
to the real `device.uid` for correct Alfred result dedup. The `arg` field stays
`device.id` (the transient `AudioDeviceID`), so immediate switching from the list
is unchanged.

### 8. Ignore list

`filterAudioDevices` matches by name. Extend to exclude a device when the
ignore-list entry equals `device.name` **or** `device.uid`, consistent with the
rest of the key-or-uid handling. Low cost, keeps semantics uniform.

### 9. Documentation

Update `CLAUDE.md`:
- Friendly Names / env-var sections: keys (favorites, friendly names, ignorelist)
  accept a device name **or** a device UID.
- `print_device_names` now emits `name\tUID`.

## Error handling

- UID read failure → empty UID, name-based behavior only, no crash.
- Existing `fatalError` paths for genuinely critical failures unchanged.

## Testing (manual, via `run.sh`)

- `./workflow/run.sh list output` — verify JSON, friendly names, collision suffix
  when both monitors attached.
- `./workflow/run.sh print_device_names output` — verify `name\tUID` format.
- `./workflow/run.sh list input` / `print_device_names input` — input scope.
- `./workflow/run.sh switch_by_id output <id>` — immediate switch unchanged.
- With both monitors: set a UID-keyed favorite/friendly name, confirm the correct
  physical monitor is targeted and rotation alternates between them.
- Regression: a unique-name device with existing name-based config still switches
  and displays unchanged.
