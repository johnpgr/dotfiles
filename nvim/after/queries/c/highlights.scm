; extends

((type_identifier) @keyword.modifier
  (#any-of? @keyword.modifier
    "internal"
    "global"
    "local_persist")
  (#set! priority 110))
