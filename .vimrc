set nocompatible
set encoding=utf-8
set number         " Show line numbers
set wrap
set linebreak
let &showbreak = '⏎  '
set breakindent
set showmatch      " Highlight matching brace
set visualbell

syntax on

let g:os = substitute(system('uname'), '\n', '', '')
if g:os == "Darwin" ||  g:os == "Linux"
    set background=light
    colorscheme solarized
endif

set hlsearch       " Highlight all search results
set smartcase      " Enable smart-case search
set incsearch      " Searches for strings incrementally

set autoindent
set expandtab      " Use spaces instead of tabs
set shiftwidth=2   " Number of auto-indent spaces
set smartindent
set smarttab
set softtabstop=2

set ruler          " Show row and column ruler information
set undolevels=1000
