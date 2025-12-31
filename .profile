# faster nvm
export NVM_DIR=~/.nvm
if [ -d "$NVM_DIR" ]; then
  source /usr/local/opt/nvm/nvm.sh --no-use
  nvm use `ls ~/.nvm/versions/node | sed s/^v// | sort  -t. -s -k 1,1rn -k 2,2rn -k3,3rn -k4,4rn | head -n1` --silent
fi

alias ls='ls -G'

# set env vars
while IFS== read -r N V; do
  export "$N=$(eval echo "$V")"
done < <(cat ~/.env ~/.env.local 2>/dev/null)

# prepend to path
EXTRA_PATH=""
while read -r P; do
  P=$(eval echo "$P")
  if [ -d "$P" ]; then
    EXTRA_PATH="$P:$EXTRA_PATH"
  fi
done < <(cat ~/.paths ~/.paths.local 2>/dev/null)
test -n "$EXTRA_PATH" && export PATH="$EXTRA_PATH$PATH"

