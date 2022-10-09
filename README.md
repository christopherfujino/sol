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
  variable allNumbers = Number[1, 7, 3];
  variable bigNumber = maxNumber(allNumbers);
  print("The biggest number is " + String(bigNumber)); # The biggest number is 7
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
arguments.

## Sol Syntax

### Keywords

Keyword | Description | Implemented?
--- | --- | ---
`variable` | A mutable variable | [x]
`constant` | An immutable variable | [ ]
`function` | A custom function. | [x]

### Primitives

Type | Example | Description | Implemented?
--- | --- | --- | ---
String | `"Hello, world!"` | ASCII, immutable string | [x]
Number | `12.3` | Floating point number (currently 32-bit) | [x]
`boolean` | `variable shouldUpdate = false;` | Either `true` or `false` | [x]

### Composite Types

Type | Example | Description | Implemented?
--- | --- | --- | ---
List | `String["A", "b", "Hello, world!"]` | An untyped, growable list of objects | [x]
Map | `Number{"age": 36}` | Hash map from `String` to a single type. | [ ]

### Control Flow

Keyword | Example | Implemented?
--- | --- | ---
`if` | `if check() {}` | [x]
`for` & `in` | `for idx, el in elementList {}` | [x]

### Standard Library

#### Process

Function Name | Description | Implemented?
--- | --- | ---
`run(String[])` | Run a subprocess. | [x]

#### I/O

Function Name | Description | Implemented?
--- | --- | ---
`print(String)` | Print a `String` to STDOUT | [x]
`printError(String)` | Print a `String` to STDERR | [ ]
