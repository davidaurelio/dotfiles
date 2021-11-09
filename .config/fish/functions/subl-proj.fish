function subl-proj
  set -l projects_dir ~/.sublime-projects
  set -l project_file

  if count $argv > /dev/null
    set project_file $argv[1]
  else
    set project_file (ls $projects_dir/*.sublime-project | xargs basename -a | fzf --height=10) || return
  end

  ln -s $projects_dir/(basename -s .sublime-project $project_file).sublime-project
end
