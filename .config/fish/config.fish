test -f ~/.aliases; and . ~/.aliases
test -f ~/.aliases.local; and . ~/.aliases.local

# set env vars
cat ~/.env{,.local} 2> /dev/null | while read -d= N V
  echo -- $V | read --tokenize --list V
  set -xg $N $V
end

# append to path
cat cat ~/.paths ~/.paths.local 2> /dev/null \
| while read P
  set -a PATH (eval echo $P | string join " ")
end

# force load postexec function
functions -q _postexec_hook

test -f ~/.config/fish/config.local.fish; and . ~/.config/fish/config.local.fish
test -f ~/.iterm2_shell_integration.fish; and source ~/.iterm2_shell_integration.fish

fish_vi_key_bindings
