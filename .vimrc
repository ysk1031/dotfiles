if has('vim_starting')
  set runtimepath+=~/.vim/bundle/neobundle.vim/
endif

call neobundle#begin(expand('~/.vim/bundle'))

NeoBundleFetch 'Shougo/neobundle.vim'

NeoBundle 'altercation/vim-colors-solarized'
NeoBundle 'chriskempson/vim-tomorrow-theme'

NeoBundle 'kien/ctrlp.vim'
NeoBundle 'tpope/vim-endwise.git'
NeoBundle 'scrooloose/syntastic.git'
NeoBundle 'ngmy/vim-rubocop.git'
NeoBundle 'ervandew/supertab.git'
NeoBundle 'kchmck/vim-coffee-script'

call neobundle#end()

filetype plugin indent on

NeoBundleCheck


syntax enable
set background=dark
colorscheme solarized
let g:solarized_termcolors=256

set autoindent   " 自動でインデント
set smartindent   " 新しい行を開始したときに、新しい行のインデントを現在行と同じ量にする
set number   " 行番号表示
set ambiwidth=double   " 全角文字（2バイト文字）の扱い
set title   " 編集中のファイル名を表示
set showmatch   " 括弧の対応をハイライト
set expandtab   " Tabキーを空白に変換
set ts=2 sw=2 sts=0   " タブは半角2文字分のスペース
set noswapfile   " スワップファイルを作らない
set vb t_vb=   " ビープを鳴らさない
set list   " 不可視文字表示
set listchars=tab:>.,trail:_,extends:>,precedes:<   " 不可視文字の表示形式
set autoread    " ファイル変更があった場合に自動再読み込み
set backspace=indent,eol,start  " Deleteキー有効に
set wildmenu               " コマンド補完を強化
set wildchar=<tab>         " コマンド補完を開始するキー
set wildmode=list:full     " リスト表示，最長マッチ
set history=100           " コマンド・検索パターンの履歴数
set complete+=k            " 補完に辞書ファイル追加
set wrapscan   " 最後まで検索したら先頭へ戻る
set ignorecase " 大文字小文字無視
set smartcase  " 検索文字列に大文字が含まれている場合は区別して検索する
set incsearch  " インクリメンタルサーチ
set hlsearch   " 検索文字をハイライト
set laststatus=2   " 常にステータスライン表示

" 前回終了したカーソル行から開く
autocmd BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal g`\"" | endif

"Escの2回押しでハイライト消去
nmap <ESC><ESC> :nohlsearch<CR><ESC>

set ffs=unix,dos,mac  " 改行文字
set encoding=utf-8    " デフォルトエンコーディング
set fileformats=unix,dos,mac  " 改行コードの自動認識

" 80列目にマーク
set textwidth=80
if exists('&colorcolumn')
  set colorcolumn=+1
endif

" 以下のファイルの時は文字コードをutf-8に設定
autocmd FileType js :set fileencoding=utf-8
autocmd FileType css :set fileencoding=utf-8
autocmd FileType html :set fileencoding=utf-8
autocmd FileType xml :set fileencoding=utf-8

autocmd BufWritePre * :%s/\s\+$//ge  " 保存時に行末の空白を除去する
autocmd BufWritePre * :%s/\t/  /ge   " 保存時にtabをスペースに変換する

let g:syntastic_ruby_checkers = ['rubocop']   " Check coding-convention by rubocop
