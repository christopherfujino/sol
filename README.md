# SOL: Simple Obvious Language

Sol is an imperative, statically-typed language designed as a tool for learning
how to program. It is **simple**, in that it has few language features and can
thus be learned quickly. It is **obvious**, in that it should be clear from
reading the source code of an application what instructions the computer will
execute.

Many common programming language features that allow programs to be more
**expressive** were intentionally left out. See [non-features](#non-features)
for more details.

## Examples

### Hello, world!

```
function main() {
  print("Hello, world!");
}
```

### Explicit Type Casts

```
function main() {
  constant answer = 42;
  constant message = "The secret is " + String(42);
  print(message);
}
```

### Max Number

```
function maxNumber(numbers Number[]) -> Number {
  variable max = 0;
  for index, number in numbers {
    if index == 0 {
      max = number;
      continue;
    }
    if number > max {
      max = number;
    }
  }
  return max;
}

function main() {
  variable allNumbers = Number[1, 2];
  variable bigNumber = maxNumber(allNumbers);
  print("The biggest number is " + bigNumber);
}
```

### Recursion

```
function fibonacci(num Number) -> Number {
  if (n <= 1) {
    return n;
  }
  return fibonacci(n - 1) + fibonacci(n - 2);
}
```

## Non-features

What should be of more note to existing programmers is not what features Sol
implements, but rather those it does not. What follows is a non-comprehensive
list, along with the rationale for omitting it.

### Mutable Global State

While Sol allows constants to be defined globally, it does not have global
variables. Variables only exist within the scope of a function, and to share
them you must either pass their value or a pointer to them via function
arguments. Similarly...

### Garbage Collection

Sol does not have garbage collection for two reasons: simplicity of
implementation and to expose the user more closely to their application's memory
management. See [memory model](#memory-model) for more details.

## Concepts

### Memory Model

Sol uses a statically-determined stack-based memory management system, similar
to [RAII](https://en.wikipedia.org/wiki/Resource_acquisition_is_initialization)
in C++ or Rust. The only heap allocations that occur in a Sol program are when
elements are added to the built-in `List` and `Map` data structures. `List` or
`Map` instances are stack-allocated containers that hold references to
heap-allocated elements. When the references to these containers leave the
current function scope (global constants are the exception), the Sol runtime
will free up all of the heap allocated elements (like a C++ destructor).

Because the Sol runtime assumes that these heap-allocated data structure
elements will never again be used once the function that allocated the container
leaves scope, Sol does not allow functions to return pointers. If a Sol program
needs to have a function initialize a data structure and then return it to the
caller, either the caller needs to allocate the container and pass a pointer to
the initializing function or the function must return the data structure's value
(this will require a copy and thus be slower, but is the simplest to reason
about).

Sol does not use manual memory management (as in C or Zig) as this can easily
introduce errors that are difficult to debug.

Sol does not use garbage collection (as in most scripting languages like Python
or JavaScript) because it adds implementation complexity and hides the memory
management from the user. In other words, most garbage collection
implementations make it impossible to know when memory has been freed simply
from reading the source code.

Sol does not use reference-counting as most implementations require either the
cognitive overhead on the part of the programmer to avoid cycles or they rely on
a backup garbage collector.

## Sol Syntax

### Keywords

Keyword | Description | Implemented?
--- | --- | ---
`variable` | A mutable variable | [ ]
`constant` | An immutable variable | [ ]
`function` | A custom function. | [x]

### Primitives

Type | Example | Description | Implemented?
--- | --- | --- | ---
String | `"Hello, world!"` | ASCII, immutable string | [x]
Number | `12.3` | Floating point number (currently 32-bit) | [ ]
`boolean` | `variable shouldUpdate = false;` | Either `true` or `false` | [ ]
null | `null` | null literal | [ ]

### Composite Types

Type | Example | Description | Implemented?
--- | --- | --- | ---
List | `String["A", "b", "Hello, world!"]` | An untyped, growable list of objects | [ ]
Map | `Number{"age": 36}` | Hash map from `String` to a single type. | [ ]

### Control Flow

Keyword | Example | Implemented?
--- | --- | ---
`if` | `if check() {}` | [ ]
`for` & `in` | `for idx, el in elementList {}` | [ ]

### Standard Library

#### Process

Function Name | Description | Implemented?
--- | --- | ---
`run(String[])` | Run a subprocess. | [ ]

#### I/O

Function Name | Description | Implemented?
--- | --- | ---
`print(String)` | Print a `String` to STDOUT | [ ]
`printError(String)` | Print a `String` to STDERR | [ ]
