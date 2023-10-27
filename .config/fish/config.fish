set_gui_appearance_var
source ~/.config/fish/colors.fish

test -f ~/.aliases; and . ~/.aliases
test -f ~/.aliases.local; and . ~/.aliases.local

# set env vars
cat ~/.env{,.local} 2> /dev/null | while read -d= N V
  echo -- $V | read --tokenize --list V
  set -xg $N $V
end

# append to path
cat ~/.paths ~/.paths.local 2> /dev/null \
| while read P
  set -a PATH (eval echo $P | string join " ")
end

# enable fnm
type -q fnm; and fnm env --shell=fish | source

# enable direnv. We prefer a custom `--on-variable PWD` hook
type -q direnv
and function __direnv_export_eval --on-variable PWD
  direnv export fish | source;
end

# force load postexec function
functions -q _postexec_hook

test -f ~/.config/fish/config.local.fish; and . ~/.config/fish/config.local.fish
test -f ~/.iterm2_shell_integration.fish; and source ~/.iterm2_shell_integration.fish

fish_vi_key_bindings

set -qx TMUX
and function __update_env_from_tmux --on-event fish_preexec
  tmux show-environment | while read -d= N V
    echo -- $V | read --tokenize --list V
    set -xg $N $V
  end
end

