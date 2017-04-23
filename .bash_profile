# Load .profile
if [ -f ~/.profile ]; then
    . ~/.profile
fi

# Load aliases
if [ -f ~/.aliases ]; then
    . ~/.aliases
fi

# bash-completion / homebrew
BREW_PREFIX=$(dirname "$(dirname "$(which brew)")")
if [ -f "$BREW_PREFIX"/etc/bash_completion ]; then
  . "$BREW_PREFIX"/etc/bash_completion
  true
fi

#if [ -f $(brew --prefix)/Library/Taps/bfontaine/homebrew-command-not-found/handler.sh ]; then
#  . $(brew --prefix)/Library/Taps/bfontaine/homebrew-command-not-found/handler.sh
#fi


# bash-completion / npm
#if (which npm > /dev/null); then
#	. <(npm completion)
#fi

# Git prompt
export PS1='\u:\W$(__git_ps1 " (\[\033[0;35m\]git:\[\033[0;34m\]%s\[\033[0m\])")\$ '

todatauri(){ M=`file "$1" --mime-type|sed 's/^.*: //'`; D=`openssl base64 -in "$1"|tr -d '\n'`; echo "data:$M;base64,$D";}

test -e ${HOME}/.iterm2_shell_integration.bash && source ${HOME}/.iterm2_shell_integration.bash
