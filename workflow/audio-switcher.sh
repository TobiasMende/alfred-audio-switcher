#!/bin/zsh
# Alternative to main.swift using SwitchAudioSource (brew install switchaudio-osx)
# Fixes slow startup caused by interpreted Swift on recent macOS versions (see #16)
COMMAND="${1:-}"
TYPE="${2:-output}"

get_friendly_name() {
    local device="$1" favs="$2"
    if [[ -n "$favs" ]]; then
        while IFS= read -r line; do
            local key="${line%%;*}"
            [[ "$key" == "$device" ]] || continue
            local val="${line#*;}"
            [[ -n "$val" && "$val" != "$line" ]] && echo "$val" && return
        done <<< "$favs"
    fi
    echo "$device"
}

list_devices() {
    local current
    current=$(SwitchAudioSource -c -t "$TYPE")
    local ignorelist="${ignorelist:-}"
    local favs
    if [[ "$TYPE" == "output" ]]; then
        favs="${outputs:-}"
    else
        favs="${inputs:-}"
    fi

    local items=""
    while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        if [[ -n "$ignorelist" ]] && echo "$ignorelist" | grep -qxF "$name"; then
            continue
        fi

        local display=""
        display=$(get_friendly_name "$name" "$favs")
        local icon="${TYPE}.png"
        [[ "$name" == "$current" ]] && icon="${TYPE}_selected.png"

        local escaped_name="${name//\"/\\\"}"
        local escaped_display="${display//\"/\\\"}"

        [[ -n "$items" ]] && items+=","
        items+="{\"title\":\"${escaped_display}\",\"uid\":\"${escaped_name}\",\"autocomplete\":\"${escaped_display}\",\"arg\":\"${escaped_name}\",\"icon\":{\"path\":\"./icons/${icon}\"}}"
    done < <(SwitchAudioSource -a -t "$TYPE")

    echo "{\"items\":[${items}]}"
}

switch_device() {
    local device_name="$1"
    SwitchAudioSource -s "$device_name" -t "$TYPE"
    if [[ "$TYPE" == "output" && "${sync_sound_effects_output:-}" == "1" ]]; then
        SwitchAudioSource -s "$device_name" -t system
    fi
}

rotate_favorites() {
    local favs
    if [[ "$TYPE" == "output" ]]; then
        favs="${outputs:-}"
    else
        favs="${inputs:-}"
    fi
    [[ -z "$favs" ]] && exit 1

    local current
    current=$(SwitchAudioSource -c -t "$TYPE")

    local -a device_list=()
    while IFS= read -r line; do
        device_list+=("${line%%;*}")
    done <<< "$favs"

    local count=${#device_list[@]}
    [[ $count -eq 0 ]] && exit 1

    local current_idx=0
    for i in {1..$count}; do
        [[ "${device_list[$i]}" == "$current" ]] && current_idx=$i && break
    done

    for ((j=1; j<=count; j++)); do
        local next_idx=$(( (current_idx - 1 + j) % count + 1 ))
        local next_name="${device_list[$next_idx]}"
        if SwitchAudioSource -a -t "$TYPE" | grep -qxF "$next_name"; then
            switch_device "$next_name"
            return
        fi
    done
    exit 1
}

case "$COMMAND" in
    list) list_devices ;;
    switch_by_id|switch_by_name|switch) switch_device "$3" ;;
    rotate_favorites) rotate_favorites ;;
    print_device_names) SwitchAudioSource -a -t "$TYPE" ;;
    *) echo "Usage: $0 (list|switch|rotate_favorites|print_device_names) (input|output) [device_name]"; exit 1 ;;
esac
