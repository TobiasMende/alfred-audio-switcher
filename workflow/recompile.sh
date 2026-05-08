#!/bin/bash

DIR="$(cd "$(dirname "$0")" && pwd)"
rm -f "$DIR/main" "$DIR/compile-errors.log"
"$DIR/run.sh" list output >/dev/null 2>&1

if [[ -x "$DIR/main" ]]; then
    echo "Compilation successful"
else
    echo "Compilation failed. See compile-errors.log"
fi
