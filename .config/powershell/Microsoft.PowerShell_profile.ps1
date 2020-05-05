function dotfiles { git --git-dir=$HOME/.dotfiles --work-tree=$HOME $args }

# include local configuration
if (Test-Path ($PSCommandPath -replace '\.ps1', '.local$0') -PathType Leaf) {
  . ($PSCommandPath -replace '\.ps1', '.local$0')
}

foreach ($file in "$HOME/.env", "$HOME/.env.local")  {
    if (Test-Path $file -PathType Leaf) {
        Get-Content $file | ForEach-Object $line {
            $var = $_ -Split '=',2
            Invoke-Expression ('$Env:{0} = "{1}"' -f $var[0],$var[1])
        }
    }
}
