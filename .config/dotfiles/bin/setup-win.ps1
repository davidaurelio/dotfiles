#Requires -Version 5

# install scoop
if (!(Get-Command scoop -errorAction SilentlyContinue)) {
  iwr -useb get.scoop.sh | iex
}

scoop install `
    cmake `
    curl `
    diffutils `
    fd `
    fzf `
    git `
    jq `
    nvm `
    pwsh `
    ripgrep `
    vim

scoop bucket add extras

scoop install `
    sublime-text

# clone dotfiles
if (!(Test-Path $HOME/.dotfiles/ -PathType Container)) {
    git clone --bare git@github.com:davidaurelio/dotfiles.git $HOME/.dotfiles
    git --git-dir=$HOME/.dotfiles --work-tree=$HOME config --local status.showUntrackedFiles no
    git --git-dir=$HOME/.dotfiles --work-tree=$HOME checkout
}

$configPath = "$HOME\.config"
$sublimeConfigPath = "$HOME\scoop\persist\sublime-text\Data"
if (!(Test-Path $sublimeConfigPath -PathType Container)) {
    New-Item -ItemType Junction `
             -Path $sublimeConfigPath `
             -Value $configPath\sublime-text-3
}


# source profile for pwsh and system powershell
Function Link-Profile($psProfile) {
    $dir = Split-Path -Parent $psProfile
    if (!(Test-Path $dir -PathType Container)) {
        New-Item -ItemType Directory -Path $dir
    }
    if (!(Test-Path $psProfile -PathType Leaf)) {
        Set-Content -Path $psProfile `
                    -Value '. $HOME/.config/powershell/Microsoft.PowerShell_profile.ps1'
    }
}

Link-Profile $(pwsh -NoProfile -c 'echo $PROFILE')
Link-Profile $(PowerShell -NoProfile -c 'echo $PROFILE')

# Install pwsh extensions
Install-Module -Force -Scope CurrentUser PSReadLine
Install-Module -Force -Scope CurrentUser posh-git
