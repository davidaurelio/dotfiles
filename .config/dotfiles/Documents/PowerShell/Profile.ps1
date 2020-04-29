function dotfiles { git --git-dir=$HOME/.dotfiles --work-tree=$HOME $args }

# include local configuration
$localConfig = "$HOME/.config\dotfiles\Documents\PowerShell\Profile.local.ps1"
if (Test-Path $localConfig -PathType Leaf) {
  . $localConfig
}
