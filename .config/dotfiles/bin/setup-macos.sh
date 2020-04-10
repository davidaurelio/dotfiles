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
  mkdir -p "$(dirname "$CONFIG")"
  ln -Fhis "$DOTFILE" "$CONFIG"
}

safelink_config () {
  safelink "$CONFIG/$1" ~/Library/"$2"
}

safelink_library () {
  safelink "$DOTFILES/Library/$1" ~/Library/"$1"
}

# macos defaults
defaults write -globalDomain AppleInterfaceStyleSwitchesAutomatically -bool true  ## auto dark mode
defaults write -globalDomain AppleScrollerPagingBehavior -bool true  ## scroll bar click jump to spot
defaults write -globalDomain AppleShowScrollBars WhenScrolling  ## show scrollbars when scrolling
defaults write -globalDomain KeyRepeat -int 2
defaults write -globalDomain InitialKeyRepeat -int 15
defaults write -globalDomain AppleKeyboardUIMode -int 3  ## use tab to focus all controls
defaults write -globalDomain com.apple.mouse.scaling -float 3

# Configuration
defaults write com.googlecode.iterm2 "PrefsCustomFolder" -string "~/.config/dotfiles/Library/Preferences"
defaults write com.googlecode.iterm2 "LoadPrefsFromCustomFolder" -bool true
safelink_config sublime-text-3 "Application Support/Sublime Text 3"
safelink_library "Application Support/ControllerMate"
safelink_library "Application Support/Alfred/Alfred.alfredpreferences/preferences"

# Install homebrew
if ! which -s brew; then
  /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
fi

brew install \
  cmake \
  colordiff \
  fish \
  git \
  htop \
  jq \
  neovim \
  nvm \
  ripgrep \
  socat \
  tree \
  yarn

brew cask install \
  dash4 \
  firefox \
  google-chrome \
  sublime-text
