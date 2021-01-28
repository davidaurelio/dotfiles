Import-Module posh-git
Import-Module PSReadLine


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

function prompt() {
  $userColor = 'Gray'
  try {
    if (([Security.Principal.WindowsPrincipal] `
          [Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
      $userColor = 'DarkRed'
    }
  } catch {}

  $dir = "$($executionContext.SessionState.Path.CurrentLocation)"
  if ($dir.StartsWith("$HOME")) {
    $dir = $dir.replace("$HOME", "~")
  }

  Write-Host -NoNewline "PS "
  if ($gitHead = git rev-parse --short HEAD 2>$null) {
    $gitRef = git symbolic-ref --quiet --short HEAD
    if ("$gitRef" -ne '') {
      $gitHead = $gitRef
    } else {
      $gitTag = git describe --tags --exact-match
      if ("$gitTag" -ne '') {
        $gitHead = "$gitTag"
      }
    }
    Write-Host -NoNewline -ForegroundColor DarkYellow "($gitHead) "
  }
  Write-Host -NoNewline -ForegroundColor $userColor "$dir$('>' * ($nestedPromptLevel + 1))"

  return " "
}
