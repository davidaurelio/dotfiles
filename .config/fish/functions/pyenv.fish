function pyenv
  functions --erase pyenv
  source (pyenv init - | psub)
  pyenv $argv
end
