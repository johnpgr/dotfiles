" Vim compiler file
" Compiler: Odin

if exists("current_compiler")
  finish
endif
let current_compiler = "odin"

if exists(":CompilerSet") != 2
  command -nargs=* CompilerSet setlocal <args>
endif

CompilerSet errorformat=%f(%l:%c)\ %t%*[^:]:\ %m,%f:%l:%c:\ %t%*[^:]:\ %m,%-G\	%#\ ^%#[-~^],%-G%#\ ^%#[-~^],%-G\	%m,%-G\ %m

let &l:makeprg = "odin build ."
