[EBNF](https://en.wikipedia.org/wiki/Extended_Backus%E2%80%93Naur_form)

```
config ::= declaration*

declaration ::= target_declaration

target_declaration ::= "target", identifier, "{", statement*, "}"

statement ::= bare_statement

bare_statement ::= expression, ";"

expression ::= call_expression

call_expression ::= identifier, "(", expression?, ")"

identifier ::= '"', character, '"'
```
