#!/bin/bash

APPEARANCE=$(defaults read -g AppleInterfaceStyle 2>/dev/null || echo Light)

env PATH="$PATH:/opt/homebrew/bin" fish --command "set_gui_appearance_var '$APPEARANCE'"

MY_DIR=$(dirname "${BASH_SOURCE[0]:-$0}")
shopt -s nullglob
for SCRIPT in "$MY_DIR/"*.applescript; do
  osascript "$SCRIPT" "$APPEARANCE"
done
