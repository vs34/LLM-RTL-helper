" Specify encoding
set encoding=utf-8

" Enable relative number lines
set relativenumber
set number
set background=dark


" Enable syntax highlighting
syntax on

" Enable filetype detection and plugins
filetype plugin indent on

" Tabs and Indentation
set tabstop=4        " Number of spaces a tab counts for
set shiftwidth=4     " Number of spaces for auto-indent
set expandtab        " Convert tabs to spaces
set autoindent       " Copy indent from the current line

" Search settings
set ignorecase       " Ignore case in search
set smartcase        " Override ignorecase if search contains uppercase
set incsearch        " Highlight matches as you type
set hlsearch         " Highlight all search matches

" Enable mouse support
set mouse=a

" Enable persistent undo
set undofile
set undodir=~/.config/nvim/undo

" Better display for messages
set cmdheight=1

" Highlight current line
set cursorline
set cursorcolumn


" Enable line wrapping
set wrap

" Show matching brackets
set showmatch

" Set wildmenu for better command-line completion
set wildmenu
set wildmode=longest:full,full

" Enable clipboard sharing between system and Neovim
set clipboard=unnamedplus

" Set a nice status line
set laststatus=2
set ruler

" Disable backup and swap files for a cleaner experience
set nobackup
set nowritebackup
set noswapfile

" Faster UI updates (improves responsiveness)
set updatetime=300

" Leader key mapping
let mapleader=" "

" Key mappings
nnoremap <leader>w :w<CR>       " Save with leader + w
nnoremap <leader>q :q<CR>       " Quit with leader + q
nnoremap <leader>s :source %<CR> " Source the current file

" Plugin Manager (e.g., vim-plug)
" Uncomment if you use vim-plug
" call plug#begin('~/.config/nvim/plugged')
" call plug#end()

" Colorscheme (optional, add your favorite)
colorscheme gruvbox 

call plug#begin()

Plug 'neoclide/coc.nvim', {'branch': 'release'}

call plug#end()

set runtimepath+=~/.config/nvim

lua require('ai_annotations').setup()

