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

" Compile only the current file to JVM class files. This avoids runnable JAR
" packaging and -include-runtime, which dominate compile time for small files.
let &l:makeprg = "mkdir -p .out/%:t:r:S && kotlinc %:p:S -d .out/%:t:r:S"
