todatauri () {
  local M=`file "$1" --mime-type | sed 's/^.*: //'`;
  local D=`openssl base64 -in "$1"|tr -d '\n'`;
  echo "data:$M;base64,$D";
}
