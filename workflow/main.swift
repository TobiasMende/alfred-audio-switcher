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
    printDeviceItems(type: type, ignoreListAsMultilineString: arguments.count > 3 ? arguments[3] : "")
} else if command == "switch_by_id" && arguments.count > 3 {
    switchDeviceById(type: type, deviceIDAsString: arguments[3])
} else if command == "print_device_names" {
    printDeviceNames(type: type)
} else if command == "switch_by_name" && arguments.count > 4 {
    switchDeviceByDeviceIndexAndList(type: type, deviceIndexAsString: arguments[3], deviceListAsMultilineString: arguments[4])
} else {
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

func getAudioDeviceIdByName(deviceName: String, type: DeviceType) -> AudioDeviceID? {
    let devices = getAudioDeviceList(type: type)

    let foundDevice = devices.first { device in
           device.name == deviceName
    }

    return foundDevice?.id
}

func setDefaultAudioDevice(type: DeviceType, deviceID: AudioDeviceID) -> String? {
    var propertyAddress = getPropertyAddress(type: type)

    var newDeviceID = deviceID
    let propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

    let status = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, propertySize, &newDeviceID)
    if status != noErr {
        fatalError("Error: Unable to set default \(type) device")
    }

    return getAudioDeviceNameById(deviceID: deviceID)
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

func getDefaultAudioDevice(type: DeviceType) -> (name: String, id: AudioDeviceID) {
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
    return (name: deviceName, id: deviceID)
}

func getAudioDeviceList(type: DeviceType) -> [(name: String, id: AudioDeviceID)] {
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

    var deviceList: [(name: String, id: AudioDeviceID)] = []
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

        deviceList.append((name: deviceName, id: id))

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


func deviceToJson(device: (name: String, id: AudioDeviceID), isDefault: Bool, type: DeviceType) -> String {
    let iconName = isDefault ? "\(type)_selected.png" : "\(type).png"
    return "{\"title\": \"\(device.name)\", \"uid\": \"\(device.name)\", \"autocomplete\": \"\(device.name)\", \"arg\": \"\(device.id)\", \"icon\": {\"path\": \"./icons/\(iconName)\"}}"
}

func filterAudioDevices(devices: [(name: String, id: AudioDeviceID)], ignoreList: [String]) -> [(name: String, id: AudioDeviceID)] {
    return devices.filter { !ignoreList.contains($0.name) }
}

func printDeviceNames(type: DeviceType) {
    getAudioDeviceList(type: type).forEach { device in
            print(device.name)
    }
}

func printDeviceItems(type: DeviceType, ignoreListAsMultilineString: String) {
    let ignoreList = convertMultilineArgumentToList(argument: ignoreListAsMultilineString)
    let defaultDevice = getDefaultAudioDevice(type: type)
    let devices = getAudioDeviceList(type: type)
    let devicesAsJson = filterAudioDevices(devices: devices, ignoreList: ignoreList).map { device in
        let isDefault = (defaultDevice.id == device.id)
        return deviceToJson(device: device, isDefault: isDefault, type: type)
    }.joined(separator: ",")

    print("{\"items\": [\(devicesAsJson)]}")
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

func switchDeviceByDeviceIndexAndList(type: DeviceType, deviceIndexAsString: String, deviceListAsMultilineString: String) {
    guard let deviceIndex = Int(deviceIndexAsString) else {
        fatalError("Invalid Device Index: \(deviceIndexAsString)")
    }

    let deviceList = convertMultilineArgumentToList(argument: deviceListAsMultilineString)

    guard deviceIndex < deviceList.count else {
        fatalError("Invalid Index Passed")
    }

    let deviceFromList = deviceList[deviceIndex]

    guard let deviceID = getAudioDeviceIdByName(deviceName: deviceFromList, type: type) else {
        fatalError("Device not found: Index: \(deviceIndex), deviceList: \(deviceList)")
    }

    guard let selectedDevice = setDefaultAudioDevice(type: type, deviceID: deviceID) else {
        fatalError("Device Not Found: \(deviceID)")
    }

    print(selectedDevice)
}

func convertMultilineArgumentToList(argument: String) -> [String] {
    return argument.split(separator: "\n").map(String.init)
}

func printUsageAndExit() {
    print("Usage: ./main.swift <command> <type> [<ignoreList>|<deviceIndex> <deviceList>]")
    print("command: (list | switch_by_id | switch_by_name | print_device_names)")
    print("type: (input | output)")
    exit(1)
}
