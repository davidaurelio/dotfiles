function data-uri
  for file in $argv[1]
    echo -n data:
    file --brief --mime-type $file
    echo -n ";base64,"
    openssl base64 -in $file
  end | tr -d '\n'
  echo
end
