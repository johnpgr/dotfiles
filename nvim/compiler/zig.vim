" Vim compiler file
" Compiler: Zig

if exists("current_compiler")
  finish
endif
let current_compiler = "zig"

if exists(":CompilerSet") != 2
  command -nargs=* CompilerSet setlocal <args>
endif

CompilerSet errorformat=%f:%l:%c:\ %t%*[^:]:\ %m,%-G\	%#\ ^%#[-~^],%-G%#\ ^%#[-~^],%-G\	%m,%-G\ %m

let &l:makeprg = "zig build"
