function fish_mode_prompt
  set -l colour
  set -l indicator

  switch $fish_bind_mode
    case default
      set colour red
      set indicator 🅽
    case insert
      set colour green
      set indicator 🅸
    case replace_one
      set colour green
      set indicator 🆁
    case visual
      set colour brmagenta
      set indicator 🆅
    case '*'
      set colour red
      set indicator '?'
  end


  if test -n $indicator
    echo -n (set_color $colour)"$indicator  "(set_color normal)
  end
end
