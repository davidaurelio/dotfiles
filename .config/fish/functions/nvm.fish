set -gx NVM_DIR ~/.nvm
function nvm
  if type -p -q brew 2> /dev/null and [ -f (brew --prefix)/opt/nvm/nvm.sh ]
    bass source (brew --prefix)/opt/nvm/nvm.sh --no-use ';' nvm $argv
  else
    echo "nvm is not installed" >&2
    return 1
  end
end
