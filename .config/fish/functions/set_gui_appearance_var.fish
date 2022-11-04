function set_gui_appearance_var --argument-names appearance
  if test -z $appearance
    set appearance (
      test (uname) = Darwin;
      and defaults read -g AppleInterfaceStyle 2>/dev/null;
      or echo Light
    )
  end

  set --universal GUI_APPEARANCE "$appearance"
end
