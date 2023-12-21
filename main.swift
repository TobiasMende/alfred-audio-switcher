#!/usr/bin/swift -suppress-warnings
import Foundation
import CoreAudio

enum DeviceType {
    case input, output
}

enum AudioSwitcherError: Error {
    case runtimeError(String)
}

func getPropertyAddress(type: DeviceType) -> AudioObjectPropertyAddress {
    let propertySelector: AudioObjectPropertySelector = (type == .input) ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice
    return AudioObjectPropertyAddress(
        mSelector: propertySelector,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
}

func getAudioDeviceNameById(deviceId: AudioDeviceID) -> String {
    var nameSize = UInt32(MemoryLayout<CFString>.size)
    var deviceName: CFString = "" as CFString
    var namePropertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceNameCFString,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)

    let status = AudioObjectGetPropertyData(deviceId, &namePropertyAddress, 0, nil, &nameSize, &deviceName)
    if status == noErr {
        return deviceName as String
    } else {
        fatalError("Error: Unable to get name for device ID \(deviceId)")
    }
}

func getAudioDeviceIdByName(deviceName: String, type: DeviceType) -> AudioDeviceID? {
    let devices = try! getAudioDeviceList(type: type)

    let foundDevice = devices.first { device in
           device.name == deviceName
    }

    return foundDevice?.id
}

func setDefaultAudioDevice(type: DeviceType, deviceId: AudioDeviceID) -> String? {
    var propertyAddress = getPropertyAddress(type: type)

    var newDeviceID = deviceId
    let propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

    let status = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, propertySize, &newDeviceID)
    if status != noErr {
        fatalError("Error: Unable to set default \(type) device")
    }

    return getAudioDeviceNameById(deviceId: deviceId)
}

func getDefaultAudioDevice(type: DeviceType) -> (name: String, id: AudioDeviceID) {
    var deviceID = AudioDeviceID()
    var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)
    var propertyAddress = getPropertyAddress(type: type)

    let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &propertyAddress, 0, nil, &propertySize, &deviceID)
    if status != noErr {
        fatalError("Error: Unable to get default \(type) device")
    }

    var nameSize = UInt32(MemoryLayout<CFString>.size)
    var deviceName: CFString = "" as CFString
    var namePropertyAddress = AudioObjectPropertyAddress(
        mSelector: kAudioDevicePropertyDeviceNameCFString,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)

    let nameStatus = AudioObjectGetPropertyData(deviceID, &namePropertyAddress, 0, nil, &nameSize, &deviceName)
    if nameStatus == noErr {
        return (name: deviceName as String, id: deviceID)
    } else {
        fatalError("Error: Unable to get name for default \(type) device")
    }
}

func getAudioDeviceList(type: DeviceType) -> [(name: String, id: AudioDeviceID)] {
    var propertySize: UInt32 = 0
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDevices,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)

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

        var nameSize = UInt32(MemoryLayout<CFString>.size)
        var deviceName: CFString = "" as CFString

        var namePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)

        status = AudioObjectGetPropertyData(id, &namePropertyAddress, 0, nil, &nameSize, &deviceName)
        if status == noErr {
            deviceList.append((name: deviceName as String, id: id))
        }
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

func filterAudioDevices(devices: [(name: String, id: AudioDeviceID)], blocklist: [String]) -> [(name: String, id: AudioDeviceID)] {
    return devices.filter { !blocklist.contains($0.name) }
}

let arguments = CommandLine.arguments
guard arguments.count > 2 else {
    print("Usage: audioDevices <command> <type> [<blocklist>]")
    print("command one of -l || -s")
    print("type one of input || output")
    exit(1)
}

let command = arguments[1]
let type = arguments[2] == "input" ? DeviceType.input : DeviceType.output
          
if command == "-l" {
    let blocklist = arguments.count > 3 ? arguments[3].split(separator: "\n").map(String.init) : []

    let defaultDevice = getDefaultAudioDevice(type: type)
    let devices = getAudioDeviceList(type: type)
    let devicesAsJson = filterAudioDevices(devices: devices, blocklist: blocklist).map { device in
        let isDefault = (defaultDevice.id == device.id)
        return deviceToJson(device: device, isDefault: isDefault, type: type)
    }.joined(separator: ",")
    
    print("{\"items\": [\(devicesAsJson)]}")
    
} else if command == "-s" && arguments.count > 3 {
    let deviceId = convertStringToDeviceID(deviceIDString: arguments[3])
    let deviceName = setDefaultAudioDevice(type: type, deviceId: deviceId.unsafelyUnwrapped)
    let description = deviceName != nil ? deviceName : "unknown"
    print(description!)
} else if command == "-p" {
    getAudioDeviceList(type: type).forEach { device in
        print(device.name)
    }
} else if command == "-n" && arguments.count > 3 {
    guard let deviceIndex = Int(arguments[3]) else {
        throw AudioSwitcherError.runtimeError("Invalid Device Index: \(arguments[3])")
    }
    let deviceList = arguments.count > 4 ? arguments[4].split(separator: "\n").map(String.init) : []
    if deviceIndex < deviceList.count {
        let selectedDevice = deviceList[deviceIndex]

        guard let deviceId = getAudioDeviceIdByName(deviceName: selectedDevice, type: type) else {
            throw AudioSwitcherError.runtimeError("Device not found: Index: \(deviceIndex), deviceList: \(deviceList)")
        }

        setDefaultAudioDevice(type: type, deviceId: deviceId)
        print(selectedDevice)
    }
}
