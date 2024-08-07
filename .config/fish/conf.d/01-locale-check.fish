status --is-interactive
and test -f /usr/bin/locale-check -a -x /usr/bin/locale-check
and /usr/bin/locale-check C.UTF-8 | while read -d= N V
  echo -- $V | read --tokenize --list V
  set -xg $N $V
end
