# Bash-Monad

An educational project that implements monad-like constructs in pure Bash. Bash has no type system, so these are not true monads — they are constructs that follow the key principles of monads: a unit (`return`) function, a `bind` function, and compliance with the three monad laws (left identity, right identity, associativity), verified by automated tests.

Three monads are implemented, all on a shared structured value encoding (s-expression-like, self-describing — see [docs/usage.md](docs/usage.md#the-value-encoding)):

1. A **Maybe monad** (`src/maybe.bash`), for operations that might fail — absence of a value is `(maybe nothing)`
2. A **List monad** (`src/list.bash`), for computations with multiple results — `(list 1 2 3)`
3. An **Either monad** (`src/either.bash`), for failures that carry information — `(either left "error")` / `(either right 42)`

The structured encoding makes values self-describing, which enables:

- **nesting**, both of the same type (`(maybe just (maybe nothing))` — Just Nothing is a value distinct from Nothing) and of different types (`(list (maybe just 1))`)
- a **uniform monad API** (`src/monad.bash`) with tag-based dispatch: `unit`, `bind`, `map`, `join`, `mzero`, `mplus`, `print_value` work with any monad, without type-specific suffixes

Each monad also provides its functor `map` and is a MonadPlus instance (the List monad satisfies all four MonadPlus laws; Maybe and Either satisfy left catch in place of left distribution).

## Documentation

- [Monad Theory](docs/monad-theory.md) — what monads are, their core components and Kleisli arrows, the three monad laws, the additional properties (functor, applicative, MonadPlus, `join`), which laws are implemented and tested, and a glossary of related concepts
- [Usage](docs/usage.md) — the value encoding, the monad API, error status codes, semantics and limitations, and runnable examples for every monad
- [Testing](docs/testing.md) — how to run the test suites, what they cover, and how to write new tests
- [Contributing](docs/contributing.md) — code style guidelines, testing and tooling conventions, debugging tips, and a list of possible improvements (Applicative `ap`, additional monads)

## Requirements

- Bash shell (version 4.0 or higher recommended)
- `bc` command-line calculator (used for arithmetic operations in the Maybe monad examples)

## Project Structure

- `src/value.bash` - Structured value encoding: atom serialization, s-expression parser, normalize/equal/kind accessors, recursive printer with monad dispatch
- `src/monad.bash` - Uniform monad API with tag-based dispatch (unit, bind, map, join, mzero, mplus)
- `src/maybe.bash` - Maybe monad implementation (maybe_just, maybe_is_nothing, maybe_is_just, maybe_unwrap, and the NOTHING constant)
- `src/list.bash` - List monad implementation (list_create, list_filter, and the EMPTY_LIST constant)
- `src/either.bash` - Either monad implementation (either_left, either_right, either_is_left, either_is_right, either_unwrap)
- `test/test_utils.bash` - Testing utilities
- `test/test_utils_test.bash` - Tests for testing utilities
- `test/value_test.bash` - Tests for the value encoding
- `test/monad_test.bash` - Tests for the uniform API dispatch
- `test/monad_laws_test.bash` - All monad, functor, consistency, and MonadPlus laws, verified generically through the uniform API for all registered types
- `test/nesting_test.bash` - Tests for same-type and cross-type nesting
- `test/maybe_test.bash` - Tests for core Maybe monad functions
- `test/list_test.bash` - Tests for core List monad functions
- `test/either_test.bash` - Tests for core Either monad functions
- `test/run_all_tests.bash` - Script to run all tests in the project
- `examples/maybe.bash` - Example usage and helper functions for the Maybe monad (safe_divide, add_maybe, multiply_maybe)
- `examples/list.bash` - Example usage and helper functions for the List monad
- `examples/either.bash` - Example usage for the Either monad
- `examples/composition.bash` - Composition and nesting examples
- `docs/` - Detailed documentation (see above)

## Quick Start

Run the full test suite:

```bash
bash test/run_all_tests.bash
```

Try the examples:

```bash
bash examples/maybe.bash
bash examples/list.bash
bash examples/either.bash
bash examples/composition.bash  # composition and nesting examples
```

Then see [docs/usage.md](docs/usage.md) to start using the monads in your own scripts.
