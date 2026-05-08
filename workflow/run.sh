#!/bin/bash

DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY="$DIR/main"
SOURCE="$DIR/main.swift"

if [[ ! -x "$BINARY" ]] || [[ "$SOURCE" -nt "$BINARY" ]]; then
    if command -v swiftc &>/dev/null; then
        swiftc -O "$SOURCE" -o "$BINARY" 2>/dev/null
    fi
fi

if [[ -x "$BINARY" ]]; then
    exec "$BINARY" "$@"
else
    exec "$SOURCE" "$@"
fi
