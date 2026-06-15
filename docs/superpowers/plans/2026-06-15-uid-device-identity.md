# UID-based Device Identity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Distinguish and address audio devices with identical model names (e.g. two same-model monitors) using the stable Core Audio device UID, while keeping all existing name-based config working.

**Architecture:** Carry a `uid` string (from `kAudioDevicePropertyDeviceUID`) alongside name+id in the device tuple throughout `workflow/main.swift`. Match config keys by UID first, name second. Auto-disambiguate the Alfred list only when names collide and no friendly name is set.

**Tech Stack:** Swift, CoreAudio. Single file `workflow/main.swift`. No unit-test framework — verification is a hard compile plus manual `run.sh`-style invocation.

**Spec:** `docs/superpowers/specs/2026-06-15-uid-device-identity-design.md`

---

## Verification notes (read first)

- **Build (must pass loud):** `swiftc -O workflow/main.swift -o workflow/main`
  Do NOT verify via `run.sh` — it silently falls back to interpreted mode on
  compile failure, masking errors.
- **Run after a successful build:** `./workflow/main list output` (or
  `print_device_names output`, `list input`, etc.). The compiled `workflow/main`
  binary is gitignored; never `git add` it.
- The machine running this plan may have only one of each device. Where a test
  needs two same-name devices and none are present, the step says so and falls
  back to asserting unique-name behavior is unchanged.

---

## Task 1: Add UID to the device model

**Files:**
- Modify: `workflow/main.swift` — add `getDeviceUID`; change device tuple
  `(name, id)` → `(name, uid, id)` at every construction and signature site.

- [ ] **Step 1: Add `getDeviceUID` next to `getDeviceName` (after line 110)**

```swift
func getDeviceUID(deviceID: AudioDeviceID) -> String? {
    var nameSize = UInt32(MemoryLayout<CFString>.size)
    var deviceUID: CFString = "" as CFString
    var address = createPropertyAddress(selector: kAudioDevicePropertyDeviceUID)

    let status = withUnsafeMutablePointer(to: &deviceUID) { ptr in
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &nameSize, ptr)
    }

    if status == noErr, let uid = deviceUID as String? {
        return uid
    } else {
        return nil
    }
}
```

- [ ] **Step 2: Change `getAudioDeviceList` return type and population**

Change the signature (`workflow/main.swift:127`) and the tuple appended in the
loop (`:144` and `:162`):

```swift
func getAudioDeviceList(type: DeviceType) -> [(name: String, uid: String, id: AudioDeviceID)] {
```

```swift
    var deviceList: [(name: String, uid: String, id: AudioDeviceID)] = []
```

Replace the append (`:162`) with:

```swift
        let deviceUID = getDeviceUID(deviceID: id) ?? ""
        deviceList.append((name: deviceName, uid: deviceUID, id: id))
```

- [ ] **Step 3: Change `getDefaultAudioDevice` to carry uid**

Replace signature/return (`:112` and `:124`):

```swift
func getDefaultAudioDevice(type: DeviceType) -> (name: String, uid: String, id: AudioDeviceID) {
```

Before the `return`, add the uid lookup and include it:

```swift
    let deviceUID = getDeviceUID(deviceID: deviceID) ?? ""
    return (name: deviceName, uid: deviceUID, id: deviceID)
```

- [ ] **Step 4: Update tuple parameter types on dependent functions**

`getAudioDeviceIdByName` (`:54-62`) body uses `device.name` — only the param
type of the array changes, via `getAudioDeviceList`'s new return, so no signature
edit needed there yet (it reads `.name`, still valid).

Update these explicit tuple-typed signatures:

`deviceToJson` (`:178`):

```swift
func deviceToJson(device: (name: String, uid: String, id: AudioDeviceID), friendlyName: String, isDefault: Bool, type: DeviceType) -> String {
```

`filterAudioDevices` (`:183`):

```swift
func filterAudioDevices(devices: [(name: String, uid: String, id: AudioDeviceID)], ignoreList: [String]) -> [(name: String, uid: String, id: AudioDeviceID)] {
```

- [ ] **Step 5: Build (must pass)**

Run: `swiftc -O workflow/main.swift -o workflow/main`
Expected: no output, exit 0. Any type-mismatch error means a tuple site was
missed — fix it before continuing.

- [ ] **Step 6: Verify behavior unchanged**

Run: `./workflow/main list output`
Expected: same JSON as before this task (uid is carried internally but not yet
shown). Run: `./workflow/main print_device_names output` → still name-only lines.

- [ ] **Step 7: Commit**

```bash
git add workflow/main.swift
git commit -m "Add device UID to internal device model"
```

---

## Task 2: Surface UID via print_device_names

**Files:**
- Modify: `workflow/main.swift` — `printDeviceNames` (`:187-191`).

- [ ] **Step 1: Change output to `name\tUID`**

Replace `printDeviceNames`:

```swift
func printDeviceNames(type: DeviceType) {
    getAudioDeviceList(type: type).forEach { device in
            print("\(device.name)\t\(device.uid)")
    }
}
```

- [ ] **Step 2: Build**

Run: `swiftc -O workflow/main.swift -o workflow/main`
Expected: exit 0.

- [ ] **Step 3: Verify**

Run: `./workflow/main print_device_names output`
Expected: each line is `<name><TAB><uid>`, e.g.
`MacBook Pro Speakers	BuiltInSpeakerDevice`. UID column non-empty for real
devices.

- [ ] **Step 4: Commit**

```bash
git add workflow/main.swift
git commit -m "Emit device UID from print_device_names"
```

---

## Task 3: Match config keys by UID or name

**Files:**
- Modify: `workflow/main.swift` — rename/extend `getAudioDeviceIdByName`
  (`:54-62`); update callers (`:266`, `:296`).

- [ ] **Step 1: Replace `getAudioDeviceIdByName` with key-based matcher**

```swift
func getAudioDeviceId(byKey key: String, type: DeviceType) -> AudioDeviceID? {
    let devices = getAudioDeviceList(type: type)

    if let byUID = devices.first(where: { $0.uid == key }) {
        return byUID.id
    }

    return devices.first(where: { $0.name == key })?.id
}
```

- [ ] **Step 2: Update caller in `switchDeviceByDeviceIndexAndList` (`:266`)**

Replace:

```swift
    guard let deviceID = getAudioDeviceIdByName(deviceName: deviceName, type: type) else {
```

with:

```swift
    guard let deviceID = getAudioDeviceId(byKey: deviceName, type: type) else {
```

(The local is still named `deviceName`; it now holds a name-or-UID key. Leave the
name as-is to keep the diff minimal.)

- [ ] **Step 3: Update caller in `rotateFavorites` (`:296`)**

Replace:

```swift
        if let nextDeviceID = getAudioDeviceIdByName(deviceName: nextDeviceName, type: type),
```

with:

```swift
        if let nextDeviceID = getAudioDeviceId(byKey: nextDeviceName, type: type),
```

- [ ] **Step 4: Build**

Run: `swiftc -O workflow/main.swift -o workflow/main`
Expected: exit 0, no remaining references to `getAudioDeviceIdByName`.

- [ ] **Step 5: Verify name-based switching still works**

Pick a device name from `./workflow/main print_device_names output`. Then, in
Alfred this path is exercised by `switch_by_name`; CLI-equivalent check: confirm
the function resolves by running a known switch via id is unaffected and that the
binary still lists. Minimal regression check:
Run: `./workflow/main list output` → unchanged JSON.

- [ ] **Step 6: Commit**

```bash
git add workflow/main.swift
git commit -m "Match device config keys by UID or name"
```

---

## Task 4: Resolve friendly names by UID or name

**Files:**
- Modify: `workflow/main.swift` — `printDeviceItems` (`:216-229`).

- [ ] **Step 1: Resolve friendly name by uid first, then name**

In `printDeviceItems`, replace the map body (`:222-226`):

```swift
    let devicesAsJson = filterAudioDevices(devices: devices, ignoreList: ignoreList).map { device in
        let isDefault = (defaultDevice.id == device.id)
        let friendlyName = favoriteList[device.uid] ?? favoriteList[device.name] ?? device.name
        return deviceToJson(device: device, friendlyName: friendlyName, isDefault: isDefault, type: type)
    }.joined(separator: ",")
```

- [ ] **Step 2: Build**

Run: `swiftc -O workflow/main.swift -o workflow/main`
Expected: exit 0.

- [ ] **Step 3: Verify UID-keyed friendly name**

Grab a UID from `./workflow/main print_device_names output`, then:

```bash
outputs="<paste-uid>;UID Test Label" ./workflow/main list output
```

Expected: that device's `title` and `autocomplete` are `UID Test Label`. Also
confirm an existing `name;Label` form still maps (name fallback):

```bash
outputs="MacBook Pro Speakers;Name Test Label" ./workflow/main list output
```

Expected: speakers titled `Name Test Label`.

- [ ] **Step 4: Commit**

```bash
git add workflow/main.swift
git commit -m "Resolve friendly names by UID or name"
```

---

## Task 5: Auto-disambiguate colliding names in the list

**Files:**
- Modify: `workflow/main.swift` — `printDeviceItems` (`:216-229`).

- [ ] **Step 1: Compute name-collision set and append UID suffix**

Replace the `printDeviceItems` map block from Task 4 with collision-aware logic.
Full function body:

```swift
func printDeviceItems(type: DeviceType) {
    let favoritesAsMultilineString = getAppropriateDeviceList(type: type)
    let ignoreList = convertMultilineArgumentToList(argument: getEnvironmentVariable(named: "ignorelist"))
    let favoriteList = convertFavoritesList(favoritesAsMultilineString: favoritesAsMultilineString)
    let defaultDevice = getDefaultAudioDevice(type: type)
    let devices = filterAudioDevices(devices: getAudioDeviceList(type: type), ignoreList: ignoreList)

    var nameCounts: [String: Int] = [:]
    for device in devices {
        nameCounts[device.name, default: 0] += 1
    }

    let devicesAsJson = devices.map { device in
        let isDefault = (defaultDevice.id == device.id)
        let explicitFriendly = favoriteList[device.uid] ?? favoriteList[device.name]
        var friendlyName = explicitFriendly ?? device.name

        let nameCollides = (nameCounts[device.name] ?? 0) > 1
        if explicitFriendly == nil, nameCollides, !device.uid.isEmpty {
            friendlyName = "\(device.name) (\(device.uid))"
        }

        return deviceToJson(device: device, friendlyName: friendlyName, isDefault: isDefault, type: type)
    }.joined(separator: ",")

    print("{\"items\": [\(devicesAsJson)]}")
}
```

- [ ] **Step 2: Build**

Run: `swiftc -O workflow/main.swift -o workflow/main`
Expected: exit 0.

- [ ] **Step 3: Verify (two same-name devices)**

If two same-name output devices are attached:
Run: `./workflow/main list output`
Expected: both entries titled `<name> (<uid>)` with differing UIDs; all other
devices' titles unchanged. A device given an explicit friendly name (via
`outputs="<uid>;Label"`) shows `Label`, no suffix.

If no duplicate-name devices are available: confirm every title is unchanged
(no suffix appears when names are unique).

- [ ] **Step 4: Commit**

```bash
git add workflow/main.swift
git commit -m "Auto-disambiguate colliding device names with UID suffix"
```

---

## Task 6: Put the real UID in the JSON uid field

**Files:**
- Modify: `workflow/main.swift` — `deviceToJson` (`:178-181`).

- [ ] **Step 1: Use `device.uid` for the JSON `uid` field**

Replace the `return` in `deviceToJson`:

```swift
    return "{\"title\": \"\(friendlyName)\", \"uid\": \"\(device.uid)\", \"autocomplete\": \"\(friendlyName)\", \"arg\": \"\(device.id)\", \"icon\": {\"path\": \"./icons/\(iconName)\"}}"
```

- [ ] **Step 2: Build**

Run: `swiftc -O workflow/main.swift -o workflow/main`
Expected: exit 0.

- [ ] **Step 3: Verify**

Run: `./workflow/main list output`
Expected: each item's `uid` field now holds the device UID string (was the
device name). `arg` still holds the numeric device id.

- [ ] **Step 4: Commit**

```bash
git add workflow/main.swift
git commit -m "Send real device UID in Alfred JSON uid field"
```

---

## Task 7: Rotation matches default device by UID or name

**Files:**
- Modify: `workflow/main.swift` — `rotateFavorites` (`:281-307`).

- [ ] **Step 1: Match the current default against keys by uid or name**

The favorites list holds name-or-UID keys. The current default must be located
whether the user keyed it by uid or name. Replace the index computation
(`:290`):

```swift
    let defaultDeviceIndex = deviceList.firstIndex {
        $0 == defaultDevice.uid || $0 == defaultDevice.name
    } ?? -1
```

(The per-entry switch already uses `getAudioDeviceId(byKey:)` from Task 3, so the
rest of the loop is correct.)

- [ ] **Step 2: Build**

Run: `swiftc -O workflow/main.swift -o workflow/main`
Expected: exit 0.

- [ ] **Step 3: Verify**

With a UID-keyed favorites list of at least two devices:

```bash
outputs=$'<uid-A>\n<uid-B>' ./workflow/main rotate_favorites output
```

Expected: prints the name of the next device after the current default and
actually switches it. Run again → advances to the other. Name-keyed list still
rotates:

```bash
outputs=$'MacBook Pro Speakers\n<other-name>' ./workflow/main rotate_favorites output
```

- [ ] **Step 4: Commit**

```bash
git add workflow/main.swift
git commit -m "Rotate favorites matching default device by UID or name"
```

---

## Task 8: Ignore list matches by UID or name

**Files:**
- Modify: `workflow/main.swift` — `filterAudioDevices` (`:183-185`).

- [ ] **Step 1: Exclude by name or uid**

```swift
func filterAudioDevices(devices: [(name: String, uid: String, id: AudioDeviceID)], ignoreList: [String]) -> [(name: String, uid: String, id: AudioDeviceID)] {
    return devices.filter { !ignoreList.contains($0.name) && !ignoreList.contains($0.uid) }
}
```

- [ ] **Step 2: Build**

Run: `swiftc -O workflow/main.swift -o workflow/main`
Expected: exit 0.

- [ ] **Step 3: Verify**

Ignore a device by UID and confirm it disappears:

```bash
ignorelist="<some-uid>" ./workflow/main list output
```

Expected: that device absent from items. Name-based ignore still works:

```bash
ignorelist="MacBook Pro Speakers" ./workflow/main list output
```

Expected: speakers absent.

- [ ] **Step 4: Commit**

```bash
git add workflow/main.swift
git commit -m "Filter ignore list by UID or name"
```

---

## Task 9: Document UID support

**Files:**
- Modify: `CLAUDE.md` — Environment Variables, Friendly Names, Testing sections.

- [ ] **Step 1: Update Friendly Names section**

Replace the `## Friendly Names` block:

```markdown
## Friendly Names

Semicolon-separated, keyed by device **name or UID**: `MacBook Pro Speakers;Mac`
or `BuiltInSpeakerDevice;Mac`. Use a UID to target one specific device when two
devices share a name (e.g. two identical monitors). Get UIDs with
`print_device_names` (see Testing).
```

- [ ] **Step 2: Update Environment Variables section**

Under the existing list, append a note:

```markdown
- Keys in `ignorelist`, `outputs`, and `inputs` accept a device **name or UID**.
  UIDs are stable per device and disambiguate identical model names.
```

- [ ] **Step 3: Update Testing section**

Note the new `print_device_names` output format under the testing commands:

```markdown
`print_device_names` prints one `name<TAB>UID` line per device — use it to copy
a device's UID for the env vars above.
```

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "Document UID-based device configuration"
```

---

## Final verification

- [ ] **Build clean:** `swiftc -O workflow/main.swift -o workflow/main` → exit 0.
- [ ] **Smoke:** `./workflow/main list output`, `./workflow/main list input`,
  `./workflow/main print_device_names output` all produce well-formed output.
- [ ] **No stray binary committed:** `git status` shows `workflow/main` untracked
  (gitignored), not staged.
