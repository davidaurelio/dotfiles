# faster nvm
export NVM_DIR=~/.nvm
if [ -d "$NVM_DIR" ]; then
  source /usr/local/opt/nvm/nvm.sh --no-use
  nvm use `ls ~/.nvm/versions/node | sed s/^v// | sort  -t. -s -k 1,1rn -k 2,2rn -k3,3rn -k4,4rn | head -n1` --silent
fi

alias ls='ls -G'

# set env vars
cat ~/.env ~/.env.local 2> /dev/null \
| while IFS== read -r N V; do
  export $N="`eval echo $V`"
done

# append to path
while read -r P; do
  P=`eval echo $P`
  if [ -d "$P" ]; then
    export PATH="$PATH:$P"
  fi
done < <(cat ~/.paths ~/.paths.local 2> /dev/null)
