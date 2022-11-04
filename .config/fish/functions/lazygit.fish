function lazygit --wraps lazygit --description "Wrapper for lazygit that chooses a light theme when necessary"
  set -l extra_args

  # Enable light theme iff we are running inside an iterm session and light theme is active.
  # Iterm is configured to automatically switch between dark and light mode.
  if test -n "$ITERM_SESSION_ID" -a "$GUI_APPEARANCE" = "Light"
    set extra_args --use-config-file "$HOME/.config/lazygit/light.yml"
  end

  command lazygit $extra_args $argv
end
