#!/bin/bash

APPEARANCE=Light
if defaults read -g AppleInterfaceStyle >/dev/null 2>&1; then
  APPEARANCE=Dark
fi

MY_DIR="$(dirname ${BASH_SOURCE[0]:-$0})"
shopt -s nullglob
for SCRIPT in "$MY_DIR/"*.applescript; do
  osascript "$SCRIPT" "$APPEARANCE"
done
