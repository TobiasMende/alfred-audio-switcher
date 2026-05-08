#!/bin/bash

DIR="$(cd "$(dirname "$0")" && pwd)"
BINARY="$DIR/main"
SOURCE="$DIR/main.swift"
FAILED="$DIR/compile-errors.log"

needs_compile() {
    [[ ! -x "$BINARY" ]] || [[ "$SOURCE" -nt "$BINARY" ]]
}

if needs_compile; then
    if [[ -f "$FAILED" ]] && [[ "$SOURCE" -nt "$FAILED" ]]; then
        rm -f "$FAILED"
    fi

    if [[ ! -f "$FAILED" ]] && command -v swiftc &>/dev/null; then
        if errors=$(swiftc -O "$SOURCE" -o "$BINARY" 2>&1); then
            :
        else
            echo "$errors" > "$FAILED"
            echo "" >&2
            echo "Compilation failed. Running interpreted (slower). See $FAILED" >&2
        fi
    fi
fi

if [[ -x "$BINARY" ]]; then
    exec "$BINARY" "$@"
else
    exec "$SOURCE" "$@"
fi
