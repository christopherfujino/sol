# Sol Language TODO

## Features Next

- [ ] constants
- [ ] logical keywords/operators
- [ ] Hash maps
- [ ] Errors
- [ ] += (et al) operators

## Bugs Next

- [ ] Variables should be block-scoped and not function-scoped; else, the
  compiler could not statically determine if a variable has already been
  declared if the declaration appeared within a conditional or loop.

## Long-term

- [ ] Add debug info to parse objects
- [ ] Add a "compile" phase, that statically analyzes the parse tree for
  correctness.
    signature.

## Done

- [x] Differentiate var declaration and re-assignment
- [x] if, else if, and else
- [x] comparison expressions
- [x] Validate each function can only return values that match the function's
- [x] Parens expressions
- [x] while loops
- [x] lists
- [x] Structures!
- [x] for loops
