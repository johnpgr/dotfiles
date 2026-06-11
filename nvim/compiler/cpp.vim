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

" Compile the current file with competitive-programming debug checks while
" keeping the executable in .out/<file-stem>/<file-stem> for cpp-watch.
let &l:makeprg = "mkdir -p .out/%:t:r:S && g++ -x c++ -std=gnu++20 -g -O1 -Wall -Wextra -Wshadow -D_GLIBCXX_DEBUG -D_GLIBCXX_DEBUG_PEDANTIC -fsanitize=address,undefined,bounds -fno-omit-frame-pointer %:p:S -o .out/%:t:r:S/%:t:r:S"
