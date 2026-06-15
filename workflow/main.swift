#!/usr/bin/swift
import Foundation
import CoreAudio

let arguments = CommandLine.arguments
guard arguments.count > 2 else {
    printUsageAndExit()
    exit(1)
}

let command = arguments[1]
let type = arguments[2] == "input" ? DeviceType.input : DeviceType.output

if command == "list" {
    printDeviceItems(type: type)
} else if command == "switch_by_id" && arguments.count > 3 {
    switchDeviceById(type: type, deviceIDAsString: arguments[3])
} else if command == "print_device_names" {
    printDeviceNames(type: type)
} else if command == "switch_by_name" && arguments.count > 3 {
    switchDeviceByDeviceIndexAndList(type: type, deviceIndexAsString: arguments[3])
} else if command == "rotate_favorites" && arguments.count > 2 {
    rotateFavorites(type: type)
}else {
    printUsageAndExit()
}


enum DeviceType {
    case input, output
}

func createPropertyAddress(selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
    return AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
}

func getPropertyAddress(type: DeviceType) -> AudioObjectPropertyAddress {
    let propertySelector: AudioObjectPropertySelector = (type == .input) ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice
    return createPropertyAddress(selector: propertySelector)
}

func getAudioDeviceNameById(deviceID: AudioDeviceID) -> String {
    guard let deviceName = getDeviceName(deviceID: deviceID) else {
        fatalError("Error: Unable to get name for device ID \(deviceID)")
    }

    return deviceName
}

func getAudioDeviceId(byKey key: String, type: DeviceType) -> AudioDeviceID? {
    let devices = getAudioDeviceList(type: type)

    if !key.isEmpty, let byUID = devices.first(where: { $0.uid == key }) {
        return byUID.id
    }

    return devices.first(where: { $0.name == key })?.id
}

func setDefaultAudioDevice(type: DeviceType, deviceID: AudioDeviceID) -> String? {
    var propertyAddress = getPropertyAddress(type: type)

    var newDeviceID = deviceID
    let propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

    let status = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, propertySize, &newDeviceID)
    if status != noErr {
        fatalError("Error: Unable to set default \(type) device")
    }

    if(type == .output) {
        let syncSoundEffectsOutput = getEnvironmentVariable(named: "sync_sound_effects_output") == "1" ? true : false
        if(syncSoundEffectsOutput) {
            setSoundEffectsOutput(to: deviceID)
        }
    }

    return getAudioDeviceNameById(deviceID: deviceID)
}

func setSoundEffectsOutput(to deviceID: AudioDeviceID) {
    var propertyAddress = createPropertyAddress(selector: kAudioHardwarePropertyDefaultSystemOutputDevice)
    var newDeviceID = deviceID
    let propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

    let status = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, propertySize, &newDeviceID)
    if status != noErr {
        fatalError("Error: Unable to set default \(type) device")
    }
}

func getDeviceName(deviceID: AudioDeviceID) -> String? {
    var nameSize = UInt32(MemoryLayout<CFString>.size)
    var deviceName: CFString = "" as CFString
    var address = createPropertyAddress(selector: kAudioDevicePropertyDeviceNameCFString)

    let status = withUnsafeMutablePointer(to: &deviceName) { ptr in
        AudioObjectGetPropertyData(deviceID, &address, 0, nil, &nameSize, ptr)
    }

    if status == noErr, let name = deviceName as String? {
        return name
    } else {
        return nil
    }
}

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

func getDefaultAudioDevice(type: DeviceType) -> (name: String, uid: String, id: AudioDeviceID) {
    var deviceID = AudioDeviceID()
    var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
    var propertyAddress = getPropertyAddress(type: type)

    let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &deviceID)
    if status != noErr {
        fatalError("Error: Unable to get default \(type) device")
    }
    guard let deviceName = getDeviceName(deviceID: deviceID) else {
        fatalError("Failed to retrieve device Name for \(deviceID)")
    }
    let deviceUID = getDeviceUID(deviceID: deviceID) ?? ""
    return (name: deviceName, uid: deviceUID, id: deviceID)
}

func getAudioDeviceList(type: DeviceType) -> [(name: String, uid: String, id: AudioDeviceID)] {
    var propertySize: UInt32 = 0
    var address = createPropertyAddress(selector: kAudioHardwarePropertyDevices)

    var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize)
    guard status == noErr else {
        fatalError("Error: Unable to get the size of the audio devices array")
    }

    let deviceCount = Int(propertySize) / MemoryLayout<AudioDeviceID>.size
    var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

    status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &propertySize, &deviceIDs)
    guard status == noErr else {
        fatalError("Error: Unable to get audio devices")
    }

    var deviceList: [(name: String, uid: String, id: AudioDeviceID)] = []
    for id in deviceIDs {
        let scope: AudioObjectPropertyScope = (type == .input) ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput
        var streamAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain)
        var streamSize: UInt32 = 0

        status = AudioObjectGetPropertyDataSize(id, &streamAddress, 0, nil, &streamSize)
        if status != noErr || streamSize == 0 {
            continue  // Skip device if it doesn't have streams for the specified type
        }

        guard let deviceName = getDeviceName(deviceID: id) else {
            continue
        }

        let deviceUID = getDeviceUID(deviceID: id) ?? ""
        deviceList.append((name: deviceName, uid: deviceUID, id: id))

    }

    return deviceList
}

func convertStringToDeviceID(deviceIDString: String) -> AudioDeviceID? {
    if let deviceIDInt = UInt32(deviceIDString) {
        return AudioDeviceID(deviceIDInt)
    } else {
        fatalError("Invalid Device ID String")
    }
}


func deviceToJson(device: (name: String, uid: String, id: AudioDeviceID), friendlyName: String, subtitle: String, isDefault: Bool, type: DeviceType) -> String {
    let iconName = isDefault ? "\(type)_selected.png" : "\(type).png"
    let favoritesKey = device.uid.isEmpty ? device.name : device.uid
    let favoritesLine = "\(favoritesKey);\(device.name)"
    return "{\"title\": \"\(friendlyName)\", \"subtitle\": \"\(subtitle)\", \"uid\": \"\(device.uid)\", \"autocomplete\": \"\(friendlyName)\", \"arg\": \"\(device.id)\", \"text\": {\"copy\": \"\(favoritesLine)\"}, \"icon\": {\"path\": \"./icons/\(iconName)\"}}"
}

func filterAudioDevices(devices: [(name: String, uid: String, id: AudioDeviceID)], ignoreList: [String]) -> [(name: String, uid: String, id: AudioDeviceID)] {
    return devices.filter { !ignoreList.contains($0.name) && !ignoreList.contains($0.uid) }
}

func printDeviceNames(type: DeviceType) {
    getAudioDeviceList(type: type).forEach { device in
            let key = device.uid.isEmpty ? device.name : device.uid
            print("\(key);\(device.name)")
    }
}

func convertFavoritesList(favoritesAsMultilineString: String) -> [String: String] {
    let favoriteList = convertMultilineArgumentToList(argument: favoritesAsMultilineString)

    var resultMap: [String: String] = [:]

    for favoriteLine in favoriteList {
        let components = favoriteLine.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true)
        
        if components.count == 2 {
            // If there are two components, we have both key and value
            let key = String(components[0]).trimmingCharacters(in: .whitespaces)
            let value = String(components[1]).trimmingCharacters(in: .whitespaces)
            resultMap[key] = value
        } else if components.count == 1 {
            // If there's no semicolon, we can still add the key with an empty value
            let key = String(components[0]).trimmingCharacters(in: .whitespaces)
            resultMap[key] = key
        }
    }

    return resultMap
}

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
        let explicitFriendly = (device.uid.isEmpty ? nil : favoriteList[device.uid]) ?? favoriteList[device.name]
        let friendlyName = explicitFriendly ?? device.name

        let nameCollides = (nameCounts[device.name] ?? 0) > 1
        let subtitle = (explicitFriendly == nil && nameCollides && !device.uid.isEmpty) ? device.uid : ""

        return deviceToJson(device: device, friendlyName: friendlyName, subtitle: subtitle, isDefault: isDefault, type: type)
    }.joined(separator: ",")

    print("{\"items\": [\(devicesAsJson)]}")
}

func getAppropriateDeviceList(type: DeviceType) -> String {
    return getEnvironmentVariable(named: (type == .output ? "outputs" : "inputs"))
}

func switchDeviceById(type: DeviceType, deviceIDAsString: String) {
    guard let deviceID = convertStringToDeviceID(deviceIDString: deviceIDAsString) else {
        fatalError("Could not convert to AudioDeviceId: \(deviceIDAsString)")
    }
    guard let selectedDevice = setDefaultAudioDevice(type: type, deviceID: deviceID) else {
        fatalError("Device Not Found: \(deviceID)")
    }

    print(selectedDevice)
}

func getEnvironmentVariable(named name: String) -> String {
    return ProcessInfo.processInfo.environment[name] ?? ""
}

func switchDeviceByDeviceIndexAndList(type: DeviceType, deviceIndexAsString: String) {
    guard let deviceIndex = Int(deviceIndexAsString) else {
        fatalError("Invalid Device Index: \(deviceIndexAsString)")
    }

    let deviceList = convertMultilineArgumentToList(argument: getAppropriateDeviceList(type: type))

    guard deviceIndex < deviceList.count else {
        fatalError("Invalid Index Passed")
    }

    let favorite = parseFavoriteLine(deviceList[deviceIndex])
    guard !favorite.key.isEmpty else {
        fatalError("Invalid Device Index: \(deviceIndex)")
    }

    guard let deviceID = getAudioDeviceId(byKey: favorite.key, type: type) else {
        fatalError("Device not found: '\(favorite.key)' at Index: \(deviceIndex), deviceList: \(deviceList)")
    }

    guard let selectedDevice = setDefaultAudioDevice(type: type, deviceID: deviceID) else {
        fatalError("Device Not Found: \(deviceID)")
    }

    print(favorite.label ?? selectedDevice)
}

func parseFavoriteLine(_ line: String) -> (key: String, label: String?) {
    let components = line.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true)
    let key = String(components.first ?? "").trimmingCharacters(in: .whitespaces)
    let label = components.count == 2 ? String(components[1]).trimmingCharacters(in: .whitespaces) : nil
    return (key, label)
}

func convertMultilineArgumentToList(argument: String) -> [String] {
    return argument.split(separator: "\n").map(String.init)
}

func rotateFavorites(type: DeviceType) {
    let defaultDevice = getDefaultAudioDevice(type: type)
    let favorites = convertMultilineArgumentToList(argument: getAppropriateDeviceList(type: type)).map(parseFavoriteLine)
    guard favorites.count > 0 else {
        fatalError("No devices in list")
    }

    let defaultDeviceIndex = favorites.firstIndex {
        (!defaultDevice.uid.isEmpty && $0.key == defaultDevice.uid) || $0.key == defaultDevice.name
    } ?? -1
    var nextDeviceIndex = (defaultDeviceIndex + 1) % favorites.count

    for _ in 0..<favorites.count {
        let nextFavorite = favorites[nextDeviceIndex]

        if let nextDeviceID = getAudioDeviceId(byKey: nextFavorite.key, type: type),
           let selectedDevice = setDefaultAudioDevice(type: type, deviceID: nextDeviceID) {
            print(nextFavorite.label ?? selectedDevice)
            return
        }

        nextDeviceIndex = (nextDeviceIndex + 1) % favorites.count
    }

    fatalError("No available devices found. Current device: '\(defaultDevice.name)', Available devices in list: \(favorites.map { $0.key })")

}

func printUsageAndExit() {
    print("Usage: ./run.sh <command> <type> [<ignoreList>|<deviceIndex> <deviceList>]")
    print("command: (list | switch_by_id | switch_by_name | rotate_favorites | print_device_names)")
    print("type: (input | output)")
    exit(1)
}
