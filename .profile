# faster nvm
export NVM_DIR=~/.nvm
source /usr/local/opt/nvm/nvm.sh --no-use
nvm use `ls ~/.nvm/versions/node | sed s/^v// | sort  -t. -s -k 1,1rn -k 2,2rn -k3,3rn -k4,4rn | head -n1` --silent

# set env vars
while read -r N V; do
  export $N="`eval echo $V`"
done < <(cat ~/.env ~/.env.local 2> /dev/null)

# append to path
while read -r P; do
  P=`eval echo $P`
  if [ -d "$P" ]; then
    export PATH="$PATH:$P"
  fi
done < <(cat ~/.paths ~/.paths.local 2> /dev/null)
