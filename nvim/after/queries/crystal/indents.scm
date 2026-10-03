; extends

[
  (method_def)
  (class_def)
  (module_def)
  (struct_def)
  (enum_def)
  (lib_def)
  (macro_def)
  (fun_def)
  (block)
  (begin)
  (if)
  (unless)
  (case)
  (while)
  (until)
  (array)
  (hash)
  (tuple)
  (named_tuple)
] @indent.begin

(ERROR "do") @indent.begin

[
  "end"
  "}"
  "]"
  ")"
] @indent.end

[
  "end"
  "}"
  "]"
  ")"
] @indent.branch

[
  "else"
  "elsif"
  "when"
  "in"
  "rescue"
  "ensure"
] @indent.branch

((heredoc_start) @indent.begin
  (#set! indent.immediate))

((heredoc_body) @indent.begin
  (#set! indent.start_at_same_line))

(heredoc_body
  (literal_content) @indent.auto)

(heredoc_end) @indent.end @indent.branch
