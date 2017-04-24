function hg_tip
  set -l hg_dir (find_parent .hg)
  set -l tip
  if test -n "$hg_dir"
    set tip (
      head -n1 "$hg_dir/.hg/bookmarks.current" 2> /dev/null;
      or xxd -p -l4 "$hg_dir/.hg/dirstate"
    )
  end
  if [ -n "$tip" ]
    if [ -n "{$argv[1]}" ]
      printf $argv[1] $tip
    else
      echo $tip
    end
  end
end
