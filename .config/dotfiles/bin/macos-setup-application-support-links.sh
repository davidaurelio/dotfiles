#!/bin/bash

set -eu

find ~/.config/dotfiles/Application\ Support -depth 1 -type d | while read CONFIG; do
  LINK=~/Library/Application\ Support/"$(basename "$CONFIG")"

  # Continue if the link already exists
  if [[ -L "$LINK" && "$CONFIG" == "$(readlink "$LINK")" ]]; then
    continue
  fi

  # Back up any previous configuration.
  if [[ -e "$LINK" ]]; then
    BACKUP_SUFFIX=1
    BACKUP="$LINK.dotfiles-backup.$BACKUP_SUFFIX"
    while [[ -e "$BACKUP" ]]; do
      let BACKUP_SUFFIX++
      BACKUP="$LINK.dotfiles-backup.$BACKUP_SUFFIX"
    done

    mv "$LINK" "$BACKUP"
    echo "Backed up $LINK to $BACKUP" >&2
  fi

  ln -Fhis "$CONFIG" "$LINK"
done
