set -gx HOMEBREW_NO_ANALYTICS 1
test -f ~/.aliases; and . ~/.aliases

# set env vars
cat ~/.env ~/.env.local | while read N V
  set -xg $N (eval echo $V)
end

# append to path
cat ~/.paths ~/.paths.local | while read P
  set -xg PATH $PATH P
end

test -f ~/.config/fish/config.local.fish; and . ~/.config/fish/config.local.fish
fish_vi_mode
