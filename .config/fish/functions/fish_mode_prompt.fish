function fish_mode_prompt
  set -l color
  set -l indicator

  switch $fish_bind_mode
    case default
      set color red
      set indicator 🅽
    case insert
      set color green
      set indicator 🅸
    case replace_one
      set color green
      set indicator 🆁
    case visual
      set color brmagenta
      set indicator 🆅
    case '*'
      set color red
      set indicator '?'
  end

  echo -n (set_color $color)"$indicator"(set_color normal)
end
