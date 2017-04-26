HISTSIZE=130000
HISTFILESIZE=-1

export PYENV_SHELL=bash
if [ -f ~/.profile ]; then
    . ~/.profile
fi

if [ -f ~/.aliases ]; then
    . ~/.aliases
fi

if type -p brew 2> /dev/null && [ -f $(brew --prefix)/etc/bash_completion ]; then
  . $(brew --prefix)/etc/bash_completion
fi

if [ -f ~/.bash_functions ]; then
  . ~/.bash_functions
fi

if [ -f ~/.ps1 ]; then
  . ~/.ps1
fi

if [ -f ~/.bash_profile.local ]; then
  . ~/.bash_profile.local
fi

if [ -f ~/.iterm2_shell_integration.bash ]; then
  . ~/.iterm2_shell_integration.bash
fi

set -o vi
