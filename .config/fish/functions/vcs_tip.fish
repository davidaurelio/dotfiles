function vcs_tip --description "Prints the current git or hg tip. Focused on speed"
  if not set -l tip (git_tip or hg_tip)
    return 1
  end
  set -l format $argv[1] '%s'
  printf "$format[1]" "$tip"
end
