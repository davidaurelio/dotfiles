function git_tip
  if set -l git_rev (git rev-parse --short HEAD 2>/dev/null)
    git symbolic-ref --quiet --short HEAD
    or echo "$git_rev"
  else
    return 1
  end
end
