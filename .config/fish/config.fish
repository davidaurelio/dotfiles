test -f ~/.aliases; and . ~/.aliases
test -f ~/.aliases.local; and . ~/.aliases.local

# set env vars
cat ~/.env ~/.env.local 2> /dev/null | while read N V
  set -xg $N (eval echo $V)
end

# append to path
cat ~/.paths ~/.paths.local 2> /dev/null | while read P
  set -xg PATH $PATH (eval echo $P)
end

test -f ~/.config/fish/config.local.fish; and . ~/.config/fish/config.local.fish
test -f ~/.iterm2_shell_integration.fish; and source ~/.iterm2_shell_integration.fish

fish_vi_key_bindings
