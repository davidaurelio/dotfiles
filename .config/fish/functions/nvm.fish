set -gx NVM_DIR ~/.nvm
function nvm
  bass source (brew --prefix)/opt/nvm/nvm.sh --no-use ';' nvm $argv
end
