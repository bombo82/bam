# BAM! Bourne Again Monad!

[![CI](https://github.com/bombo82/bam/actions/workflows/ci.yml/badge.svg)](https://github.com/bombo82/bam/actions/workflows/ci.yml)

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

## The Story Behind BAM!

I am a professional freelance software developer, always focused on good development practices and code maintainability — for me, programming languages are mere tools for building applications that solve real problems. In early 2025 I started studying functional programming in Scala, and monads in particular, for a client project.

Monads have always felt very complex to me: behind them sit mathematical theorems and laws, and I have always had an aversion to that stuff — I am an engineer, not a mathematician. The only way I can truly digest a concept is by applying it concretely. So, for personal study and for fun, I decided to implement monads myself, in a programming language that doesn't have them. The initial candidates were:

- **Kotlin** — supports FP and has excellent monad libraries: no challenge, no fun
- **Go** — a great challenge, but someone might take me seriously
- **Bash** — BAM! Who could ever take me seriously? My implementation would clearly be a game

Needless to say, Bash won. I started with two simple monads, Maybe and List. That first implementation had huge limitations, but the [core components and the three monad laws](docs/monad-theory.md) were respected — and tested! WOW!

The study continued, and implementing the functors went smoothly; the next step was adding more monads and finding a way to nest them. That is where the first version's limits really started to bite: without radically changing the internal data representation, no further feature was possible — and that is how the current structured, self-describing [value encoding](docs/usage.md#the-value-encoding) was born.

Then October came, and with it [SoCraTes Italy](https://www.socrates-conference.it/), the software-craft unconference in Rimini. I presented the project to developer friends, making it clear that it was personal study and a joke — and instead I collected unbridled enthusiasm. Much of the feedback pushed toward stabilizing, extending, and making my toy project genuinely usable, which honestly surprised me. In the evening we gathered to pick a name for the library: the brainstorming was long and hard, and only a good beer made us converge. Heartfelt thanks to Betty, Francesca, Dario, Antonio, Angelo, and everyone I have forgotten.

Special thanks go to [Ferdinando Santacroce (jesuswasrasta)](https://github.com/jesuswasrasta) — because everyone is one of his ex-colleagues, and thanking Nando is always the right thing to do — and to [Arialdo Martini (arialdomartini)](https://github.com/arialdomartini): mechanical keyboard collector, FP addict, Jujutsu Hanshi, and enthusiast of just about anything.

Another SoCraTes is approaching, and the monads never actually turned out to be needed for the client :-( With some free time on my hands, I decided to resume studying monads with a serious FP language — Haskell, this time — but these Bash monads could not be left abandoned to themselves :-)

— Gianni Bombelli (bombo82)

## License

BAM! is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

See [LICENSE](LICENSE.md) for the full license text.
