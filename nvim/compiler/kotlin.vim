" Vim compiler file
" Compiler: Kotlin

if exists("current_compiler")
  finish
endif
let current_compiler = "kotlin"

if exists(":CompilerSet") != 2
  command -nargs=* CompilerSet setlocal <args>
endif

CompilerSet errorformat=%f:%l:%c:\ %t%*[^:]:\ %m,%f:%l:%c:\ %m,%-G%.%#

" Compile the current file using the contest JVM limits while keeping class
" output in .out/<file-stem> for kotlin-watch.
let &l:makeprg = "mkdir -p .out/%:t:r:S && kotlinc -J-Xms1024m -J-Xmx1024m -J-Xss100m -include-runtime %:p:S -d .out/%:t:r:S"
