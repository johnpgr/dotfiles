" Vim compiler file
" Compiler: C++

if exists("current_compiler")
  finish
endif
let current_compiler = "cpp"

if exists(":CompilerSet") != 2
  command -nargs=* CompilerSet setlocal <args>
endif

CompilerSet errorformat=%f:%l:%c:\ %t%*[^:]:\ %m,%f:%l:\ %t%*[^:]:\ %m,%-G%.%#

" Compile the current file using the contest C++20 command while keeping the
" executable in .out/<file-stem>/<file-stem> for cpp-watch.
let &l:makeprg = "mkdir -p .out/%:t:r:S && g++ -x c++ -g -O2 -std=gnu++20 -static %:p:S -o .out/%:t:r:S/%:t:r:S"
