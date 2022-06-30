function find_parent
  set -l dir $PWD
  if [ -n "$argv[2]" ]
    set dir $argv[2]
  end
  set -l q $argv[1]
  while test "$dir" != /
    if test -e "$dir/$q"
      echo $dir
      return
    else
      set dir (dirname "$dir")
    end
  end
end
