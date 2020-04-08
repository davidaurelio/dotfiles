function hg_tip
  set -l dir "$PWD"
  while [ -n "$dir" ]
    if [ -d "$dir/.hg" ]
      test -f "$hg_dir/.hg/bookmarks.current"
      and cat "$hg_dir/.hg/bookmarks.current"
      or xxd -p -l4 "$hg_dir/.hg/dirstate"
      return
    end
    set dir (string match --regex '.*(?=/)' "$dir")
  end
  return 1
end
