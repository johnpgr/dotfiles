;; extends

; Upstream ecma/highlights.scm captures *any* capitalized `identifier` node
; as `@type` ("looks like a type/component name"), which also fires on
; plain import bindings and other capitalized value references -- not just
; real type positions (those are `type_identifier` nodes, captured
; separately and unaffected by this). Recapture them as `@variable` so they
; get treated as an ordinary reference instead.
((identifier) @variable
  (#lua-match? @variable "^[A-Z]"))
