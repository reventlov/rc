" Options
set nocompatible                " Vim not Vi; must be first

set expandtab                   " no tabs
set shiftwidth=4                " 4 spaces autoindent
set number                      " show line numbers
if v:version >= 700
    set numberwidth=5           " use 5 columns for them
endif
set backspace=indent,eol,start  " allow backspacing over everything
set scrolloff=1000              " center cursor vertically
set autoindent                  " always set autoindenting on
set nobackup                    " do not keep a backup file
set history=50                  " keep 50 lines of command line history
set ruler                       " show the cursor position all the time
set showcmd                     " display incomplete commands
set incsearch                   " do incremental searching
set guioptions-=t               " no toolbar, tearoff menus, menus
set guioptions-=T
set guioptions-=m
set guioptions-=r
set nohlsearch                  " hlsearch is distracting
set whichwrap+=<,>,[,]          " cursor keys wrap
set vb t_vb=                    " silence
set nrformats-=octal            " Ctrl+A, Ctrl+X do not use octal
set guitablabel=%N\ %f          " Number and name for tabs

" store swap files centrally, avoid littering the filesystem
if has("unix")
    set directory=~/.r/tmp//,~/.tmp//,/var/tmp//,/tmp//
endif

" Switch syntax highlighting on, when the terminal has colors
if &t_Co > 2 || has("gui_running")
    syntax on
endif

if has("gui_running")
    " 72 columns + line numbers
    if v:version >= 700
        set columns=77
    else
        set columns=80
    endif

    " maximize vertical space
    set lines=1000
endif

behave xterm

set clipboard=unnamed

if has("gui_win32")
    set guifont=lucida_console:h10
endif


" Autocommand stuff
if has("autocmd")
    " Enable file type detection.
    filetype plugin indent on

    " Correct incredibly stupid default filters for the open dialog when
    " in C/C++ mode in Win32.
    if has("gui_win32")
        autocmd FileType c,cpp let b:browsefilter =
            \   "C/C++ Source Files (*.cpp *.c++ *.cxx *.C *.c *.hpp"
            \ . " *.h++ *.h)\t*.cpp;*.c++;*.cxx;*.c;*.hpp;*.h++;*.h\n"
            \ . "C/C++ Header Files (*.h *.hpp *.h++)\t"
            \ . "*.h;*.hpp;*.h++\n"
            \ . "C/C++ Source Files (*.cpp *.c++ *.cxx *.C *.c)\t"
            \ . "*.cpp;*.c++;*.cxx;*.C;*.c\n"
            \ . "All Files (*.*)\t*.*\n"
    endif

    " For all text files set 'textwidth' to 72 characters.
    autocmd FileType text setlocal textwidth=72

    " When editing a file, always jump to the last known cursor position.
    " Don't do it when the position is invalid or when inside an event
    " handler (happens when dropping a file on gvim).
    autocmd BufReadPost *
        \ if line("'\"") > 0 && line("'\"") <= line("$") |
        \   exe "normal g`\"" |
        \ endif
endif



" Miscellaneous
"
" Y matches D, C.
nnoremap Y y$

" Shift-Enter is opposite-enter in insert
inoremap <S-Enter> <Enter><C-O>"udd<C-O>2k<C-O>"up<C-O>0

" Tab autocompletes
inoremap <Tab> <C-N>

" Tab navigation
nnoremap <C-Tab> <C-PageDown>
nnoremap <C-S-Tab> <C-PageUp>
inoremap <C-Tab> <Esc><C-PageDown>
inoremap <C-S-Tab> <Esc><C-PageUp>

nnoremap <A-1> 1gt
nnoremap <A-2> 2gt
nnoremap <A-3> 3gt
nnoremap <A-4> 4gt
nnoremap <A-5> 5gt
nnoremap <A-6> 6gt
nnoremap <A-7> 7gt
nnoremap <A-8> 8gt
nnoremap <A-9> :tablast<Enter>
inoremap <A-1> <Esc>1gt
inoremap <A-2> <Esc>2gt
inoremap <A-3> <Esc>3gt
inoremap <A-4> <Esc>4gt
inoremap <A-5> <Esc>5gt
inoremap <A-6> <Esc>6gt
inoremap <A-7> <Esc>7gt
inoremap <A-8> <Esc>8gt
inoremap <A-9> <Esc>:tablast<Enter>

nnoremap gf :tab drop <cfile><Enter>


" set color scheme inline instead of trying to deal with it as a second
" script.
hi clear
set background=dark
if exists("syntax_on")
    syntax reset
endif

hi RedundantSpaces guibg=#a82c2c
match RedundantSpaces /\s\+$\| \+\ze\t/

" based on http://colorschemedesigner.com/#2P42.fL--v5vy
hi Normal       gui=none      guibg=#181818    guifg=#c0c0c0
hi Comment      gui=none      guibg=bg         guifg=#c17979
hi Constant     gui=none      guibg=bg         guifg=#ffffff
hi Identifier   gui=none      guibg=bg         guifg=#ffdf82
hi Ignore       gui=none      guibg=bg         guifg=#555555
hi PreProc      gui=none      guibg=bg         guifg=#8485c1
hi Special      gui=none      guibg=bg         guifg=#ffedb9
hi Statement    gui=none      guibg=bg         guifg=#c3c5ff
hi Type         gui=none      guibg=bg         guifg=#a0ffa0
hi Operator     gui=none      guibg=bg         guifg=#b9ffb9
hi Error        gui=none      guibg=#a82c2c    guifg=#ff8282
hi Todo         gui=none      guibg=bg         guifg=#ffa0a0
hi Cursor       gui=none      guibg=#ffffff    guifg=#000000
hi Visual       gui=none      guibg=#c0c0c0    guifg=#000000
hi Search       gui=none      guibg=#808080    guifg=#ffffff
hi IncSearch    gui=none      guibg=#c0c0c0    guifg=#000000
hi LineNr       gui=none      guibg=bg         guifg=#777777
hi StatusLine   gui=none      guibg=#505050    guifg=#ffffff
hi StatusLineNC gui=none      guibg=#303030    guifg=#c0c0c0
hi NonText      gui=none      guibg=bg         guifg=#808080

hi Pmenu        gui=none      guibg=#808080    guifg=#ffffff
hi PmenuSel     gui=none      guibg=#c0c0c0    guifg=#ffffff


if filereadable($MYVIMRC . ".local")
    source $MYVIMRC.local
endif
