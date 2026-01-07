#!/bin/bash

set -eu -o pipefail

CONFIG=~/.config
DOTFILES="$CONFIG/dotfiles"

debug_msg() {
  echo "$@" >&2
}

safelink() {
  DOTFILE="$1"
  CONFIG="$2"

  # Bail if the dotfile doesn't exist
  if [[ ! -e "$DOTFILE" ]]; then
    return
  fi

  # Continue if the link already exists
  if [[ -L "$CONFIG" && "$DOTFILE" = "$(readlink "$CONFIG")" ]]; then
    debug_msg "link $CONFIG -> $DOTFILE is already set up."
    return
  fi

  # Back up any existing configuration.
  if [[ -e "$CONFIG" ]]; then
    local BACKUP
    BACKUP="$CONFIG.dotfiles-backup.$(date '+%Y%m%d-%H%M%S')"
    mv "$CONFIG" "$BACKUP"
    debug_msg "Backed up $CONFIG to $BACKUP"
  fi

  # Write the link
  mkdir -p "$(dirname "$CONFIG")"
  ln -Fhis "$DOTFILE" "$CONFIG"
}

safelink_config() {
  safelink "$CONFIG/$1" ~/Library/"$2"
}

safelink_library() {
  safelink "$DOTFILES/Library/$1" ~/Library/"$1"
}

# macos defaults
defaults write -globalDomain AppleInterfaceStyleSwitchesAutomatically -bool true ## auto dark mode
defaults write -globalDomain AppleScrollerPagingBehavior -bool true              ## scroll bar click jump to spot
defaults write -globalDomain AppleShowScrollBars WhenScrolling                   ## show scrollbars when scrolling
defaults write -globalDomain KeyRepeat -int 2
defaults write -globalDomain InitialKeyRepeat -int 15
defaults write -globalDomain AppleKeyboardUIMode -int 3 ## use tab to focus all controls
defaults write -globalDomain com.apple.mouse.scaling -float 3
defaults write -globalDomain NSCloseAlwaysConfirmsChanges -bool true
defaults write -globalDomain NSQuitAlwaysKeepsWindows -bool true
defaults write -globalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write -globalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write -globalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write -globalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write -globalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write -globalDomain WebAutomaticSpellingCorrectionEnabled -bool false

# Configuration
defaults write com.googlecode.iterm2 "PrefsCustomFolder" -string "$HOME/.config/dotfiles/Library/Preferences"
defaults write com.googlecode.iterm2 "LoadPrefsFromCustomFolder" -bool true
safelink_config sublime-text "Application Support/Sublime Text"
safelink_config Code "Application Support/Code"
safelink_config Cursor "Application Support/Cursor"

# Install homebrew
if ! which -s brew; then
  /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
fi

set +e

brew install \
  browser \
  cdecl \
  cmake \
  colordiff \
  difftastic \
  direnv \
  fd \
  fish \
  fnm \
  fzf \
  htop \
  git \
  gh \
  htop \
  jq \
  lazygit \
  miniserve \
  mitmproxy \
  pnpm \
  ripgrep \
  s5cmd \
  shellcheck \
  shfmt \
  tree \
  uv

# Casks
CASKS=(
  dash@6
  firefox
  ghostty
  gitup-app
  google-chrome
  iterm2
  itsycal
  suspicious-package
  the-unarchiver
  zed
)

for C in "${CASKS[@]}"; do
  brew install --cask "$C"
done
