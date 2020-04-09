#!/bin/bash

set -eu -o pipefail

CONFIG=~/.config
DOTFILES="$CONFIG/dotfiles"

debug_msg () {
  echo "$@" >&2
}

safelink () {
  DOTFILE="$1"
  CONFIG="$2"

  # Continue if the link already exists
  if [[ -L "$CONFIG" && "$DOTFILE" = "$(readlink "$CONFIG")" ]]; then
    debug_msg "link $CONFIG -> $DOTFILE is already set up."
    return
  fi

  # Back up any existing configuration.
  if [[ -e "$CONFIG" ]]; then
    local BACKUP="$CONFIG.dotfiles-backup.$(date '+%Y%m%d-%H%M%S')"
    mv "$CONFIG" "$BACKUP"
    debug_msg "Backed up $CONFIG to $BACKUP"
  fi

  # Write the link
  ln -Fhis "$DOTFILE" "$CONFIG"
}

safelink_config () {
  safelink "$CONFIG/$1" ~/Library/"$2"
}

safelink_library () {
  safelink "$DOTFILES/Library/$1" ~/Library/"$1"
}

defaults write com.googlecode.iterm2 "PrefsCustomFolder" -string "~/.config/dotfiles/Library/Preferences"
defaults write com.googlecode.iterm2 "LoadPrefsFromCustomFolder" -bool true
safelink_config sublime-text-3 "Application Support/Sublime Text 3"
safelink_library "Application Support/ControllerMate"
