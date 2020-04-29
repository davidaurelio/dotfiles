# DOTFILES

## macos

Install with

```sh
git clone --bare git@github.com:davidaurelio/dotfiles.git $HOME/.dotfiles
alias dotfiles='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
dotfiles config --local status.showUntrackedFiles no
dotfiles sparse-checkout set '/*' '!README.md'
dotfiles checkout
```

### optional setup

```sh
~/.config/dotfiles/bin/setup-macos.sh
```

## Windows

In PowerShell
```pwsh
# run install script
iwr -useb https://raw.githubusercontent.com/davidaurelio/dotfiles/master/.config/dotfiles/bin/setup-win.ps1 | iex
```

Errors?

```pwsh
# allow execution 
Set-ExecutionPolicy RemoteSigned -scope CurrentUser
```
