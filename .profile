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

# enable fnm
if command -v fnm >/dev/null 2>&1; then
  eval "$(fnm env)"
fi
