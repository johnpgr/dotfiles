;; extends

; Upstream typescript/highlights.scm captures the names in a whole-statement
; type-only import (`import type { Foo, Bar } from "..."`) as `@type`. It's
; still just an import binding brought into scope, same as a plain
; `import { Foo }` -- not a type used in an expression/annotation position
; (that's `type_identifier`, captured separately and unaffected here).
(import_statement
  "type"
  (import_clause
    (named_imports
      (import_specifier
        name: (identifier) @variable))))
