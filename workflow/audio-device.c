// Minimal CoreAudio device switcher for Alfred Audio Switcher workflow.
// Compile: cc -O2 -framework CoreAudio -framework CoreFoundation audio-device.c -o audio-device
// Usage:
//   ./audio-device list (input|output)
//   ./audio-device current (input|output)
//   ./audio-device set (input|output) <device-name>
//   ./audio-device set-system <device-name>
#include <CoreAudio/CoreAudio.h>
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

static int get_device_name(AudioDeviceID id, char *buf, size_t buflen) {
    AudioObjectPropertyAddress addr = {
        kAudioDevicePropertyDeviceNameCFString,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    CFStringRef name = NULL;
    UInt32 size = sizeof(name);
    if (AudioObjectGetPropertyData(id, &addr, 0, NULL, &size, &name) != noErr)
        return -1;
    Boolean ok = CFStringGetCString(name, buf, buflen, kCFStringEncodingUTF8);
    CFRelease(name);
    return ok ? 0 : -1;
}

static int has_streams(AudioDeviceID id, int is_input) {
    AudioObjectPropertyAddress addr = {
        kAudioDevicePropertyStreams,
        is_input ? kAudioDevicePropertyScopeInput : kAudioDevicePropertyScopeOutput,
        kAudioObjectPropertyElementMain
    };
    UInt32 size = 0;
    if (AudioObjectGetPropertyDataSize(id, &addr, 0, NULL, &size) != noErr)
        return 0;
    return size > 0;
}

static AudioDeviceID *get_all_devices(UInt32 *count) {
    AudioObjectPropertyAddress addr = {
        kAudioHardwarePropertyDevices,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    UInt32 size = 0;
    if (AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &addr, 0, NULL, &size) != noErr)
        return NULL;
    *count = size / sizeof(AudioDeviceID);
    AudioDeviceID *ids = malloc(size);
    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, ids) != noErr) {
        free(ids);
        return NULL;
    }
    return ids;
}

static AudioDeviceID get_default_device(int is_input) {
    AudioObjectPropertyAddress addr = {
        is_input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    AudioDeviceID id = 0;
    UInt32 size = sizeof(id);
    AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, &size, &id);
    return id;
}

static int set_default_device(AudioDeviceID id, int is_input) {
    AudioObjectPropertyAddress addr = {
        is_input ? kAudioHardwarePropertyDefaultInputDevice : kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    return AudioObjectSetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, sizeof(id), &id) == noErr ? 0 : -1;
}

static int set_system_device(AudioDeviceID id) {
    AudioObjectPropertyAddress addr = {
        kAudioHardwarePropertyDefaultSystemOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    return AudioObjectSetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL, sizeof(id), &id) == noErr ? 0 : -1;
}

static AudioDeviceID find_device_by_name(const char *name, int is_input) {
    UInt32 count = 0;
    AudioDeviceID *ids = get_all_devices(&count);
    if (!ids) return 0;
    char buf[256];
    for (UInt32 i = 0; i < count; i++) {
        if (!has_streams(ids[i], is_input)) continue;
        if (get_device_name(ids[i], buf, sizeof(buf)) == 0 && strcmp(buf, name) == 0) {
            AudioDeviceID found = ids[i];
            free(ids);
            return found;
        }
    }
    free(ids);
    return 0;
}

static void cmd_list(int is_input) {
    UInt32 count = 0;
    AudioDeviceID *ids = get_all_devices(&count);
    if (!ids) return;
    char buf[256];
    for (UInt32 i = 0; i < count; i++) {
        if (!has_streams(ids[i], is_input)) continue;
        if (get_device_name(ids[i], buf, sizeof(buf)) == 0)
            printf("%s\n", buf);
    }
    free(ids);
}

static void cmd_current(int is_input) {
    AudioDeviceID id = get_default_device(is_input);
    char buf[256];
    if (get_device_name(id, buf, sizeof(buf)) == 0)
        printf("%s\n", buf);
}

static int cmd_set(const char *name, int is_input) {
    AudioDeviceID id = find_device_by_name(name, is_input);
    if (!id) {
        fprintf(stderr, "Device not found: %s\n", name);
        return 1;
    }
    if (set_default_device(id, is_input) != 0) {
        fprintf(stderr, "Failed to set device: %s\n", name);
        return 1;
    }
    printf("%s\n", name);
    return 0;
}

static int cmd_set_system(const char *name) {
    AudioDeviceID id = find_device_by_name(name, 0);
    if (!id) {
        fprintf(stderr, "Device not found: %s\n", name);
        return 1;
    }
    if (set_system_device(id) != 0) {
        fprintf(stderr, "Failed to set system device: %s\n", name);
        return 1;
    }
    return 0;
}

int main(int argc, char *argv[]) {
    if (argc < 3) goto usage;

    const char *cmd = argv[1];
    int is_input = strcmp(argv[2], "input") == 0;

    if (strcmp(cmd, "list") == 0) {
        cmd_list(is_input);
    } else if (strcmp(cmd, "current") == 0) {
        cmd_current(is_input);
    } else if (strcmp(cmd, "set") == 0 && argc > 3) {
        return cmd_set(argv[3], is_input);
    } else if (strcmp(cmd, "set-system") == 0 && argc > 2) {
        return cmd_set_system(argv[2]);
    } else {
        goto usage;
    }
    return 0;

usage:
    fprintf(stderr, "Usage:\n");
    fprintf(stderr, "  %s list (input|output)\n", argv[0]);
    fprintf(stderr, "  %s current (input|output)\n", argv[0]);
    fprintf(stderr, "  %s set (input|output) <device-name>\n", argv[0]);
    fprintf(stderr, "  %s set-system <device-name>\n", argv[0]);
    return 1;
}
