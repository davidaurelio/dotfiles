# put /usr/local/bin to front
PATH=`echo $PATH | sed 's/\(.*\):\(\/usr\/local\/bin\)/\2:\1/'`

# Add local sbin
if [ -d "/usr/local/sbin" ] ; then
    PATH="$PATH:/usr/local/sbin"
fi

# Add user bin
if [ -d "$HOME/bin" ] ; then
    PATH="$PATH:$HOME/bin"
fi

# custom rolled nvm
NVM_PREFIX=/usr/local/opt/nvm # brew --prefix nvm
DEFAULT_NODE_VERSION=v6.9.1
export NVM_DIR=~/.nvm
. "$NVM_PREFIX"/nvm.sh
#export PATH="$HOME/.nvm/versions/node/$DEFAULT_NODE_VERSION/bin/:$PATH"

# export CLASSPATH=$CLASSPATH:$(brew list clojure-contrib | grep 'clojure-contrib\.jar')
export CXXFLAGS="$CXXFLAGS --std=c++14 -Wextra -Wpedantic -Wuninitialized"
