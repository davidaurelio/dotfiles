# DOTFILES

Install with

```sh
git clone --bare git@github.com:davidaurelio/dotfiles.git $HOME/.dotfiles
alias dotfiles='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
dotfiles config --local status.showUntrackedFiles no
dotfiles sparse-checkout set '/*' '!README.md'
dotfiles checkout
```
