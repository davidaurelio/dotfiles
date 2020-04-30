function dotfiles { git --git-dir=$HOME/.dotfiles --work-tree=$HOME $args }

# include local configuration
$localConfig =$PSCommandPath -replace '\.ps1', '.local$0'
if (Test-Path $localConfig -PathType Leaf) {
  . $localConfig
}
