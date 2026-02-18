" Neovim nightly (0.12) playground — no plugins
" Tests: :h cmdline-autocompletion, :h ins-autocompletion
"
" Source this file:  :source %
" Or launch with:    nvim -u test-native-nightly.vim

" ===========================================================================
" BASIC SETUP
" ===========================================================================

set nocompatible
filetype plugin indent on
syntax on

" ===========================================================================
" INSERT MODE AUTOCOMPLETION  (see :h ins-autocompletion)
" ===========================================================================

" Enable native automatic completion (Neovim 0.12+)
set autocomplete

" Configure completion sources: current buffer, other windows, listed buffers, unloaded
" ^5 limits each source to 5 candidates
set complete=.^5,w^5,b^5,u^5

" Show completions in a popup menu (no preview window)
set completeopt=popup

" Tab to cycle forward through completions when menu is visible
inoremap <silent><expr> <Tab>   pumvisible() ? "\<C-n>" : "\<Tab>"

" Shift-Tab to cycle backward through completions when menu is visible
inoremap <silent><expr> <S-Tab> pumvisible() ? "\<C-p>" : "\<S-Tab>"

" ===========================================================================
" CMDLINE AUTOCOMPLETION  (see :h cmdline-autocompletion)
" ===========================================================================

" Core: show a popup menu of suggestions as you type on : / ?
autocmd CmdlineChanged [:\/\?] call wildtrigger()
set wildmode=noselect:lastused,full
set wildoptions=pum

" Keep <Up>/<Down> for history when the wildmenu is not active
cnoremap <expr> <Up>   wildmenumode() ? "\<C-E>\<Up>"   : "\<Up>"
cnoremap <expr> <Down> wildmenumode() ? "\<C-E>\<Down>" : "\<Down>"

" Smaller popup during search (8 lines), restored on leave
autocmd CmdlineEnter [\/\?] set pumheight=8
autocmd CmdlineLeave [\/\?] set pumheight&

" ===========================================================================
" EXTRAS: FUZZY FILE PICKER  (see :h fuzzy-file-picker)
"
" Usage: :find <fuzzy-term>   — completes against every file under .
" ===========================================================================

set findfunc=Find

func Find(arg, _)
  if empty(s:filescache)
    let s:filescache = globpath('.', '**', 1, 1)
    call filter(s:filescache, '!isdirectory(v:val)')
    call map(s:filescache, "fnamemodify(v:val, ':.')")
  endif
  return a:arg == '' ? s:filescache : matchfuzzy(s:filescache, a:arg)
endfunc

let s:filescache = []
autocmd CmdlineEnter : let s:filescache = []

" Auto-select the first match when pressing <CR> on :find without picking one
autocmd CmdlineLeavePre :
      \ if get(cmdcomplete_info(), 'matches', []) != [] |
      \   let s:info = cmdcomplete_info() |
      \   if getcmdline() =~ '^\s*fin\%[d]\s' && s:info.selected == -1 |
      \     call setcmdline($'find {s:info.matches[0]}') |
      \   endif |
      \   if getcmdline() =~ '^\s*Grep\s' |
      \     let s:selected = s:info.selected != -1
      \         ? s:info.matches[s:info.selected] : s:info.matches[0] |
      \     call setcmdline(s:info.cmdline_orig) |
      \   endif |
      \ endif

" ===========================================================================
" EXTRAS: LIVE GREP  (see :h live-grep)
"
" Usage: :Grep <pattern>   — updates results as you type (>1 char)
" Results land in the quickfix list; the selected entry is visited on <CR>.
" ===========================================================================

command! -nargs=+ -complete=customlist,<SID>Grep
      \ Grep call <SID>VisitFile()

func s:Grep(arglead, cmdline, cursorpos)
  if match(&grepprg, '\$\*') == -1 | let &grepprg ..= ' $*' | endif
  let cmd = substitute(&grepprg, '\$\*', shellescape(escape(a:arglead, '\')), '')
  return len(a:arglead) > 1 ? systemlist(cmd) : []
endfunc

func s:VisitFile()
  let item = getqflist(#{lines: [s:selected]}).items[0]
  call setbufvar(item.bufnr, '&buflisted', 1)
  exe 'b' item.bufnr
  call setpos('.', [0, item.lnum, item.col, 0])
endfunc
