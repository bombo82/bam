# Usage

This document shows how to use the Bash-Monad library in your own scripts. It starts with the information that is valid for every monad (file dependencies, the value encoding, the monad API with its contract and error handling, semantics and limitations) and then covers the specifics of each monad with examples.

All monadic values use the structured encoding described in [The Value Encoding](#the-value-encoding) below: `(maybe just V)` / `(maybe nothing)`, `(list V1 V2 ...)` / `(list)`, `(either right V)` / `(either left V)`, where `V` is a serialized atom or another monadic value. The constructors (`maybe_just`, `list_create`, `either_left`/`either_right`, `unit`) automatically serialize raw strings; there is no need to invoke serialization helpers manually.

## File Dependencies

**Recommended**: source the monad API — it also sources the value encoding and all three monad implementations:

```bash
source ./src/monad.bash
```

There is no reason to import a single monad in normal use: the API works with every type, and the per-type modules (`src/maybe.bash`, `src/list.bash`, `src/either.bash`) are its implementation layer. Sourcing them directly is discouraged — do it only for advanced scenarios where you deliberately exclude the other monads.

For the example helper functions:

```bash
source ./examples/maybe.bash    # safe_divide, add_maybe, multiply_maybe
source ./examples/list.bash     # square, get_divisors, is_even, is_odd
source ./examples/either.bash   # safe_divide, add_either, multiply_either
```

Note that the example files also run their examples when sourced; suppress the output if unwanted (`source ./examples/maybe.bash >/dev/null 2>&1`).

Files source their dependencies relative to their own location, so they work when sourced from any directory — adjust the path prefix shown here (relative to the repository root) to your script's location.

See [contributing.md](contributing.md#internal-architecture-and-conventions-for-contributors) for the internal layered architecture (intended for library contributors only).

## The Value Encoding

All monadic values share a self-describing, s-expression-like encoding:

- `(maybe nothing)` / `(maybe just V)` — Maybe
- `(list)` / `(list V1 V2 ... Vn)` — List
- `(either left V)` / `(either right V)` — Either
- **Atoms** (plain values): bare when they contain no whitespace, parentheses, quotes or backslashes (`5`, `NOTHING`, `x|y`); otherwise quoted with the escapes `\\`, `\"`, `\n` (`"hello world"`, `""`)

Since every value carries its own type tag, `V` can itself be any monadic value — this is what makes nesting representable, and what allows the uniform API (`unit`, `bind`, `map`, `join`, `mzero`, `mplus` in `src/monad.bash`) to dispatch on the tag instead of relying on type-specific function suffixes. The encoding has no forbidden characters: empty strings, spaces, pipes, glob characters, and sentinel-like payloads are all ordinary values.

## The Monad API

This is the intended interface. Every operation dispatches on the type tag embedded in the value, so the same functions work with Maybe, List, and Either — no type-specific suffixes:

| Operation | Signature | Purpose |
|---|---|---|
| `unit` | `unit TYPE VALUE` | wraps a value in the monad of the given type |
| `mzero` | `mzero TYPE` | the empty element of a MonadPlus type |
| `bind` | `bind VALUE FUNCTION [ARGS...]` | chains a Kleisli function (`a -> M b`) |
| `map` | `map VALUE FUNCTION [ARGS...]` | applies a plain function (`a -> b`) |
| `join` | `join VALUE` | flattens a nested monadic value |
| `mplus` | `mplus VALUE1 VALUE2` | combines two values of the same MonadPlus type |
| `print_value` | `print_value VALUE` | human-readable printing |

```bash
m1=$(unit maybe 5)        # (maybe just 5)
m2=$(unit list 5)         # (list 5)
m3=$(unit either 5)       # (either right 5)

result=$(bind "$m1" some_kleisli_function)
print_value "$result"

empty=$(mzero list)       # (list)
result=$(mplus "$m2" "$(unit list 6)")
```

### The Function Contract

Functions passed to `bind`/`map` follow the same contract in every monad: they **receive** the raw string for atom payloads and the serialized form for compound (nested) payloads, and their **result** is embedded as-is only if it is a well-formed compound value (e.g. a monadic value returned by a Kleisli function) — anything else is serialized as an atom. Functions passed to `bind` must be Kleisli arrows (`a -> M b`) returning a monadic value **of the same monad type** — the strict `join` enforces this and fails otherwise; plain transformations (`a -> b`) belong to `map`, which never fails and never drops elements. **Predicates** (used with `list_filter`) follow the status convention: `0` = true, `1` = false, `>= 10` = error — error statuses are propagated by `list_filter`, so a failing predicate aborts the operation instead of silently dropping elements.

### Type-Specific Operations

The generic operations above cover the whole monad contract. Each monad also has type-specific operations for what cannot be expressed generically; the implementation details of the dispatcher are not part of the public API.

**Maybe** (`src/maybe.bash`):

| Operation | Signature | Purpose |
|---|---|---|
| `maybe_just` | `maybe_just VALUE` | builds a Just wrapping a value; accepts raw string (auto-serialized) or serialized value (`unit maybe` only builds from pre-serialized) |
| `maybe_is_nothing` | `maybe_is_nothing VALUE` | predicate (exit status): is the value `(maybe nothing)`? |
| `maybe_is_just` | `maybe_is_just VALUE` | predicate (exit status): is the value a Just? (fails with `ERR_WRONG_TAG` on non-Maybe values) |
| `maybe_unwrap` | `maybe_unwrap VALUE` | extracts the payload of a Just (fails with `ERR_WRONG_TAG` on non-Maybe values) |
| `$NOTHING` | — | the `(maybe nothing)` constant |

```bash
result=$(safe_divide 10 0)
if maybe_is_nothing "$result"; then
  echo "the computation failed"
fi
```

**List** (`src/list.bash`):

| Operation | Signature | Purpose |
|---|---|---|
| `list_create` | `list_create [VALUE...]` | variadic list constructor: raw strings are serialized as atoms, well-formed compound values are embedded (enabling nesting) |
| `list_filter` | `list_filter LIST PREDICATE [ARGS...]` | keeps the elements for which the predicate exits with status 0 |
| `$EMPTY_LIST` | — | the `(list)` constant |

**Either** (`src/either.bash`):

| Operation | Signature | Purpose |
|---|---|---|
| `either_left` | `either_left VALUE` | builds a failure carrying a payload; accepts raw string (auto-serialized) or serialized value (`unit either` only builds Rights) |
| `either_right` | `either_right VALUE` | builds a success (same as `unit either`); accepts raw string (auto-serialized) or serialized value |
| `either_is_left` | `either_is_left VALUE` | predicate (exit status): is the value a Left? (fails with `ERR_WRONG_TAG` on non-Either values) |
| `either_is_right` | `either_is_right VALUE` | predicate (exit status): is the value a Right? (fails with `ERR_WRONG_TAG` on non-Either values) |
| `either_unwrap` | `either_unwrap VALUE` | extracts the payload of a Left or Right (fails with `ERR_WRONG_TAG` on non-Either values) |

```bash
result=$(safe_divide 10 0)
if either_is_left "$result"; then
  # Note: _atom_to_string is an internal helper (not public API); constructors serialize automatically
  echo "Error: $(_atom_to_string "$(either_unwrap "$result")")"
fi
```

### Nesting Monadic Values

Values of any monad can contain values of any monad:

```bash
# Same type: Just Nothing is distinct from Nothing
nested="(maybe just $(mzero maybe))"
result=$(join "$nested")
print_value "$result"   # Output: Nothing

# Different types: a list of Maybes
print_value "(list $(unit maybe 1) $(mzero maybe))"
# Output: [Just 1, Nothing]

# A Maybe carrying a list
print_value "$(unit maybe "$(list_create 1 2)")"
# Output: Just [1, 2]
```

The tag-based API is what makes nesting practical: since every value carries its own tag, a `map` over a `(list (maybe just 1) (maybe nothing))` can apply functions that themselves use `bind` or `map` on the inner Maybe values (cross-type transformations use `map`; `bind` stays within a single monad type — see the strict contract above).

### Error Handling

Operations signal errors with two-digit exit statuses: the tens digit is the category, the units digit the specific error. **Predicates** (`maybe_is_nothing`, `maybe_is_just`, `either_is_left`, `list_filter` predicates) always use plain 0/1 — so a status ≥ 10 unambiguously means "error". The registry lives in `src/value.bash`; the round numbers (10/20/30) act as category fallbacks. Error codes propagate through the call chain (`bind` → `join` → `map`).

| Code | Constant              | Description |
|------|-----------------------|-------------|
| 10   | `ERR_PARSE`           | generic malformed value (category fallback) |
| 11   | `ERR_PARSE_PARENS`    | unbalanced parentheses |
| 12   | `ERR_PARSE_QUOTE`     | unterminated quote |
| 13   | `ERR_PARSE_NOT_EXPR`  | not a parenthesized expression |
| 20   | `ERR_CONTRACT`        | generic contract violation (category fallback) |
| 21   | `ERR_JOIN_FLAT`       | join on a non-nested value — also reported when `bind` is used with a scalar function |
| 22   | `ERR_JOIN_TAG`        | join on a value nested under a different tag |
| 24   | `ERR_UNIT_INPUT`      | unit with multi-token or malformed input |
| 25   | `ERR_WRONG_TAG`       | accessor used on a value of a different monad type |
| 30   | `ERR_DISPATCH`        | generic dispatch error (category fallback) |
| 31   | `ERR_UNKNOWN_TYPE`    | unregistered type tag |
| 32   | `ERR_TAG_MISMATCH`    | mplus with mismatched tags |
| 33   | `ERR_UNKNOWN_FUNCTION`| function name not found |

Handle errors by checking the status against the constants, for example:

```bash
result=$(join "$(unit maybe 5)")
case $? in
  0)              print_value "$result" ;;
  $ERR_JOIN_FLAT) echo "not a nested value" ;;
  $ERR_JOIN_TAG)  echo "nested under a different monad" ;;
  *)              echo "unexpected error $?" ;;
esac
```

### Writing Your Own Functions

To write helper functions that work with the monads:

1. **Adding New Helper Functions**:
  - Create functions that take regular values and return monadic values
  - Use `unit maybe` (or the new `maybe_just`) to wrap the result; `maybe_just` (like `either_left`/`either_right` and `list_create`) accepts raw strings and serializes automatically
  - Handle potential failure cases by returning `NOTHING` (Maybe), `either_left` with an error payload (Either), or `mzero` of the appropriate type
  - For List helpers, build results with `list_create`

2. **Chaining Operations**:
  - Use the uniform `bind` to chain operations
  - Remember that if any operation in the chain returns `NOTHING`, subsequent operations will be skipped

## Semantics and Limitations

### Representational Notes

The structured value encoding has no forbidden characters: empty strings, spaces, pipes, glob characters, and sentinel-like payloads are all ordinary values. Keep these conventions in mind when using the library:

- **Empty strings are first-class values**: the empty string is a perfectly valid payload (`(maybe just "")` via `unit maybe ""`). A function returning `""` produces the empty atom `""` — `map` never fails and never drops elements (functor structure preservation). Failure belongs to Kleisli functions via `mzero`, deletion to `filter`.
- **Strict `join`/`bind`/`unit` contract**: `join` enforces `M (M a) -> M a` and fails (non-zero status, message to stderr) on non-nested values or values nested under a different tag. Consequently `bind` requires proper Kleisli arrows (`a -> M b` of the *same* monad type): plain scalar functions must go through `map`, and a function returning a different monad type is rejected. Cross-type nesting is built with `map` (e.g. mapping a `Maybe`-returning function over a list), never with `bind`. Likewise, `unit` wraps exactly one serialized value and rejects multi-token or malformed input; multi-element lists are built with `list_create`, which embeds well-formed compound arguments as-is (enabling nested structures) and serializes everything else as atoms.
- **Malformed s-expressions**: parse errors occur on unbalanced parentheses or unterminated quotes — constructors always produce well-formed values, so this only matters for hand-written literals. Accessors (`maybe_unwrap`, `either_unwrap`, `either_is_left`, ...) validate their input and fail with `ERR_WRONG_TAG` when used on a value of a different monad type.

### Design Variants and Simplifications

Deviations from the formal monad discipline that are deliberate consequences of the untyped string encoding; keep them in mind when using the library:

- **Functions receive decoded payloads**: functions passed to `bind`/`map` receive the raw string for atom payloads and the serialized form for compound payloads; results are embedded only if well-formed compound values, otherwise serialized as atoms. A raw result that happens to be a well-formed s-expression (e.g. the string `(a b)`) is embedded as a compound value — an irreducible ambiguity of the untyped encoding.
- **Syntactic vs semantic equality**: raw string comparison is syntactic — semantically equal values with different serializations (a bare atom `5` vs the quoted `"5"`, extra whitespace) compare as different. Constructors always produce the canonical form, but hand-written literals may not.
- **Arbitrary `mzero` for Either**: `(either left "")` is a convention — Haskell's base has no standard `MonadPlus` instance for `Either`.
- **`filter` is List-only**: in Haskell it generalises to any `MonadPlus` (via `guard`); here Maybe and Either have no filter operation.
- **Functions by name, not closures**: user functions are global function names passed as strings — there are no anonymous lambdas or captured variables.
- **`print_value` is injective**: atoms that need quoting are printed in their serialized (quoted) form, so different values never print identically (e.g. `(list "1, 2")` prints `["1, 2"]` while `(list 1 2)` prints `[1, 2]`). It is intended for human-readable display, not for round-tripping.
- **Subshell overhead**: every `bind`/`map`/`join` call nests command substitutions — fine for an educational project, noticeable on large lists.

### Known Limitation: Trailing Newlines in Raw Strings

**Behaviour**: an atom whose raw string value *ends* with one or more newlines does not round-trip perfectly: when the raw string is decoded back with the internal `_atom_to_string` and captured with `$(...)`, the trailing newlines are lost (command substitution strips them). Interior newlines are unaffected.

**Analysis**: the loss does not affect serialized monadic values — newlines inside atoms are escaped as `\n` (two characters), so values traverse `bind`/`map`/`join` and command substitution intact. The loss happens only at the *raw boundaries* of the library:

1. the internal `_atom_to_string`, which decodes a serialized atom to a raw string and emits it via `echo`;
2. plain functions passed to `map`, which return raw strings via `echo` — the trailing newlines are lost during capture, before serialization.

It is therefore a limitation of the echo/`$(...)` communication idiom, not of the encoding itself.

**Candidate solutions** (identified and evaluated, deliberately not implemented to preserve API compatibility):

1. **Sentinel-based communication protocol**: appending a control character as an end-of-output marker to every function result, removed by the capturer — a general fix, but it breaks the existing capture idiom for all users.
2. **Scoped fix at the raw boundaries**: accepting pre-serialized results in mapped functions (so exact content travels escaped through the pipeline) plus an optional sentinel-based exact-capture helper — additive, but leaves the raw `atom_to_string` boundary as-is.

Until one is adopted, code that must carry raw strings ending with newlines should keep them in serialized form and avoid decoding them to raw variables.

### Security Considerations

`list_filter`, and the uniform `bind`/`map` execute the function name passed as an argument (`$func "$value" "$@"`). Never call them with untrusted input: the function name must always come from code you control.

For debugging tips when developing your own scripts, see [contributing.md](contributing.md#debugging-tips).

## Examples by Monad

The sections below apply the generic API to each monad, with runnable examples for the typical operations of that type.

### Maybe Monad Usage

The Maybe monad represents a value that may be absent. Absence is `(maybe nothing)` (also the `$NOTHING` constant); a present value is `(maybe just V)`.

#### Basic Usage

```bash
result=$(unit maybe 10)
print_value "$result"   # Output: Just 10

result=$(mzero maybe)
print_value "$result"   # Output: Nothing
```

#### Safe Operations

The helper functions in `examples/maybe.bash` return `NOTHING` on failure:

```bash
result=$(safe_divide 10 2)
print_value "$result"   # Output: Just 5.00

result=$(safe_divide 10 0)
print_value "$result"   # Output: Nothing
```

#### Chaining Operations

```bash
result=$(unit maybe 10)
result=$(bind "$result" add_maybe 5)
result=$(bind "$result" multiply_maybe 2)
print_value "$result"   # Output: Just 30

# A Nothing value short-circuits the chain
result=$(mzero maybe)
result=$(bind "$result" add_maybe 5)
print_value "$result"   # Output: Nothing
```

#### Mapping a Plain Function

```bash
double() {
    local value="$1"
    echo $((value * 2))
}

result=$(map "$(unit maybe 10)" double)
print_value "$result"   # Output: Just 20

result=$(map "$(mzero maybe)" double)
print_value "$result"   # Output: Nothing
```

#### Choosing the First Available Value

`mplus` implements a left-biased choice — the first argument that is not `NOTHING` wins:

```bash
result=$(mplus "$(unit maybe 1)" "$(unit maybe 2)")
print_value "$result"   # Output: Just 1

result=$(mplus "$(mzero maybe)" "$(unit maybe 2)")
print_value "$result"   # Output: Just 2
```

#### Flattening

`join` flattens a nested Maybe: `(maybe just (maybe nothing))` (Just Nothing, a value distinct from Nothing) becomes `(maybe nothing)`.

```bash
result=$(join "(maybe just $(unit maybe 42))")
print_value "$result"   # Output: Just 42
```

### List Monad Usage

The List monad represents a computation with multiple results. Lists are `(list V1 V2 ... Vn)`; the empty list is `(list)` (also the `$EMPTY_LIST` constant). Elements are serialized atoms or nested monadic values — there are no forbidden characters.

#### Basic Usage

```bash
result=$(unit list 10)
print_value "$result"   # Output: [10]

result=$(list_create 1 2 3 4 5)
print_value "$result"   # Output: [1, 2, 3, 4, 5]
```

#### Creating an Empty List

There is no dedicated `empty_list` function, by design: the empty list contains no elements, so there is nothing to serialize — it is simply the constant `EMPTY_LIST` (also produced by `mzero list`, and by `list_create` with no arguments). Multi-element lists instead need a constructor (`list_create`) because each element must be serialized (quoting and escaping atoms) or validated for embedding:

```bash
empty=$EMPTY_LIST                # the constant: (list)
empty=$(mzero list)              # via the MonadPlus empty element
empty=$(list_create)             # the variadic constructor with no arguments
print_value "$empty"             # Output: []
```

#### Mapping and Filtering

```bash
square() {
    local value="$1"
    echo $((value * value))
}

result=$(list_create 1 2 3 4 5)
result=$(map "$result" square)
print_value "$result"   # Output: [1, 4, 9, 16, 25]

is_even() {
    local value="$1"
    return $(( value % 2 ))
}

result=$(list_create 1 2 3 4 5 6 7 8 9 10)
result=$(list_filter "$result" is_even)
print_value "$result"   # Output: [2, 4, 6, 8, 10]
```

Note the two different conventions: mapped functions communicate results via `echo`, while predicate functions like `is_even` communicate via Bash's exit status (`return 0` for true, non-zero for false).

#### Chaining Operations

`bind` applies a function that returns a list to every element, and flattens (concatenates) all the resulting lists — this is the `join` behaviour of the List monad:

```bash
result=$(list_create 1 2 3 4 5)
result=$(bind "$result" get_divisors)
print_value "$result"   # Output: [1, 1, 2, 1, 3, 1, 2, 4, 1, 5]
```

#### Concatenating Lists

```bash
list1=$(list_create 1 2 3)
list2=$(list_create 4 5 6)
result=$(mplus "$list1" "$list2")
print_value "$result"   # Output: [1, 2, 3, 4, 5, 6]
```

#### Flattening

`join` flattens a list of lists: `(list (list 1 2) (list 3))` becomes `(list 1 2 3)`. The contract is strict: it fails if any element is not a list.

```bash
result=$(join "(list (list 1 2) (list 3))")
print_value "$result"   # Output: [1, 2, 3]
```

### Either Monad Usage

The Either monad represents a computation that may fail, carrying information about the failure. A failure is `(either left V)` and a success is `(either right V)`; unlike Maybe's `NOTHING`, a `Left` can carry an error message.

```bash
result=$(unit either 10)
print_value "$result"   # Output: Right 10

# Safe division: Left carries the error message
result=$(safe_divide 10 0)
print_value "$result"   # Output: Left "division by zero"

# Chain operations with bind (Left short-circuits)
result=$(unit either 10)
result=$(bind "$result" add_either 5)
result=$(bind "$result" multiply_either 2)
print_value "$result"   # Output: Right 30

# Fallback with mplus: the first Right wins
result=$(mplus "$(safe_divide 10 0)" "$(unit either 42)")
print_value "$result"   # Output: Right 42
```

## Running the Example Scripts

The example scripts can be run directly from any directory:

```bash
bash examples/maybe.bash
bash examples/list.bash
bash examples/either.bash
bash examples/composition.bash  # composition and nesting examples
```
