test -d ~/.opam/system/bin; and set -gx PATH ~/.opam/system/bin $PATH;
test -d ~/.opam/system/lib/toplevel; and set -gx OCAML_TOPLEVEL_PATH ~/.opam/system/lib/toplevel;
test -d ~/.opam/system/lib/perl5; and set -gx "PERL5LIB" ~/.opam/system/lib/perl5:"$PERL5LIB";
test -d ~/.opam/system/man; and set -gx MANPATH $MANPATH ~/.opam/system/man;
set -gx OPAMUTF8MSGS "1";
test -d ~/.opam/system/lib/stublibs; and set -gx CAML_LD_LIBRARY_PATH ~/.opam/system/lib/stublibs:"/usr/local/lib/ocaml/stublibs";
