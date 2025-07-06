# Monad Theory

This document explains the theoretical foundations of monads: what they are, their core components, the laws they must satisfy, and the additional properties (functor, applicative functor, MonadPlus, `join`) that sit around them. Each section also notes how the theory maps onto the Bash implementations in this project.

## What is a Monad?

A monad is a design pattern used in functional programming that provides a way to structure computations in terms of values and sequences of operations on those values. Monads are defined by three core components and must satisfy three laws.

## Core Components of a Monad

1. **Type Constructor (M)**: A way to create a monadic type from an existing type. For example, `Maybe a` is a monadic type constructed from the type `a`.

2. **Unit Function (return)**: A function that wraps a value in a monadic context. This is called `return` in Haskell, where `pure` (from the `Applicative` typeclass) serves the same purpose; other languages often call it `of` or `unit`.
   - Signature: `a -> M a` (takes a value of type `a` and returns a monadic value of type `M a`)
   - Example: `return 5` creates a monad containing the value 5

3. **Bind Function (>>=)**: A function that chains operations on monadic values. This is the key to sequencing operations.
   - Signature: `M a -> (a -> M b) -> M b` (takes a monadic value and a function that maps a value to a new monadic value, and returns a new monadic value)
   - Example: `maybeValue >>= computeFunction` applies `computeFunction` to the value inside `maybeValue` if it exists

In this project, the type constructor is realised by the structured value encoding (`(maybe ...)`, `(list ...)`, `(either ...)` — see [usage.md](usage.md#the-value-encoding)), `return` is realised generically by `unit`, and `>>=` by `bind` (generico, implementato in `src/monad.bash`). The monad API is documented in [usage.md](usage.md#the-monad-api).

### Kleisli Arrows

A **Kleisli arrow** (or Kleisli function) is a function with signature `a -> M b`: it takes a plain value and returns a monadic value. Kleisli arrows are the functions passed to `bind` — they are what `>>=` sequences: `m >>= f` feeds the value inside `m` into the Kleisli arrow `f`. They differ from *plain* functions (`a -> b`), which are used with `fmap`/`map` and cannot introduce effects on their own.

Two Kleisli arrows `f :: a -> M b` and `g :: b -> M c` can be composed with the **Kleisli composition** operator (`>=>` in Haskell): `(f >=> g) x = f x >>= g`. In this formulation, the associativity law reads as ordinary function composition being associative: `(f >=> g) >=> h` is the same as `f >=> (g >=> h)`, and `return` is its identity — the monad laws are exactly the laws of a category whose arrows are Kleisli arrows. In this project, test fixtures named `*_kleisli_*` are examples of Kleisli arrows, while fixtures like `law_add_one` are plain functions used with `map`.

## The Three Monad Laws

For a construct to be a true monad, it must satisfy these three laws:

1. **Left Identity**: Wrapping a value in a monad and feeding it to a function is the same as applying the function to the value directly.
   - `return a >>= f` is the same as `f a` (note: `f` already returns a monadic value, so no extra wrapping is involved)

2. **Right Identity**: Feeding the value inside a monad back into `return` re-wraps it and yields the original monadic value unchanged.
   - `m >>= return` is the same as `m`

3. **Associativity**: The order of nesting when chaining multiple operations doesn't matter.
   - `(m >>= f) >>= g` is the same as `m >>= (\x -> f x >>= g)`

These laws are what make monadic composition predictable: left and right identity guarantee that `return` is a "neutral" wrapper that neither adds nor removes behaviour, while associativity guarantees that long chains of `>>=` can be refactored and nested without changing their meaning.

## Additional Laws and Properties

Beyond the three monad laws, monads sit within a hierarchy of abstractions — functor, applicative functor, monad — each with its own laws. Some monads also support additional structure (MonadPlus) or can be characterized in alternative ways (`join`).

### Functor Laws

Every monad is also a **functor**: it provides a `map` operation (`fmap` in Haskell) that applies a plain function to the value(s) inside the context, with signature `(a -> b) -> M a -> M b`. A valid functor must satisfy two laws:

1. **Identity**: Mapping the identity function changes nothing.
   - `fmap id xs` is the same as `xs`

2. **Composition**: Mapping a composed function is the same as mapping one function after the other.
   - `fmap (f . g) xs` is the same as `fmap f (fmap g xs)`

Intuitively, these laws say that `map` only transforms the contained value(s) and never alters the structure of the context: it cannot drop a `Just` into `Nothing`, duplicate list elements, or reorder them.

In this project, the generic `map` is the `fmap` of every monad; all three satisfy the two functor laws, as verified by the tests in `test/monad_laws_test.bash`.

### Applicative Functor Laws

Between functor and monad sits the **applicative functor**, which adds the ability to apply a function *inside* a context to a value *inside* a context. It is defined by `pure` (the same as the monadic `return`) and an apply operator (`<*>` in Haskell) with signature `M (a -> b) -> M a -> M b`. It must satisfy four laws:

1. **Identity**: `pure id <*> v` is the same as `v`
2. **Homomorphism**: `pure f <*> pure x` is the same as `pure (f x)` — applying a pure function to a pure value stays pure
3. **Interchange**: `u <*> pure y` is the same as `pure (\f -> f y) <*> u` — a pure argument can be applied to a contextual function
4. **Composition**: `pure (.) <*> u <*> v <*> w` is the same as `u <*> (v <*> w)`

Every monad is an applicative functor (`ap` can be defined as `mf <*> mx = mf >>= \f -> mx >>= \x -> return (f x)`). This project does not implement an `ap`/`apply` operation, so these laws are included as theoretical context only.

### MonadPlus Laws

Monads that model failure or choice can support an additional structure called **MonadPlus**, defined by an empty element `mzero` and a combining operation `mplus` (`⊕`). In addition to the monad laws, it must satisfy:

1. **Identity**: `mzero ⊕ m` is the same as `m`, and `m ⊕ mzero` is the same as `m`
2. **Associativity**: `(m ⊕ n) ⊕ p` is the same as `m ⊕ (n ⊕ p)`
3. **Left zero**: `mzero >>= f` is the same as `mzero` — binding over the empty element stays empty
4. **Left distribution**: `(m ⊕ n) >>= f` is the same as `(m >>= f) ⊕ (n >>= f)`

In this project, the List monad is a MonadPlus with `mzero = (list)` and `mplus` being concatenation, and it satisfies all four laws. The Maybe and Either monads are also MonadPlus instances, with `mzero = (maybe nothing)` / `mzero = (either left "")` and a left-biased `mplus` (the first non-failing argument wins). However, with this `mplus` they do **not** satisfy left distribution: if `m = return a` and `f a` fails, then `(m ⊕ n) >>= f` fails while `(m >>= f) ⊕ (n >>= f)` can still succeed via `n`. In place of left distribution, Maybe and Either satisfy the **left catch** law:

- **Left catch**: `return a ⊕ m` is the same as `return a`

This distinction is typical: left distribution characterises "choice" monads (like List), while left catch characterises "failure" monads (like Maybe and Either).

### The `join` Characterization

A monad can equivalently be defined by `return` and a **join** operation (`μ`) with signature `M (M a) -> M a`, which flattens a nested monadic value. The two formulations are interdefinable:

- `m >>= f` is the same as `join (fmap f m)`
- `join mm` is the same as `mm >>= id`

In this formulation, the monad laws state that `join` is associative (`join . join` is the same as `join . fmap join`) and that `return` is its unit (`join . return` and `join . fmap return` are both the identity).

This project implements `join` for all three monads, and defines `bind` in terms of it: `bind m f` is `join (map f m)`. The structured value encoding makes nested monadic values representable — `(maybe just (maybe nothing))` is distinct from `(maybe nothing)`, and `(list (list 1 2) (list 3))` is a genuine list of lists — so `join` performs real flattening and its behaviour is directly tested (see `test/nesting_test.bash`).

The agreement between the two characterizations is verified directly by the functor-monad consistency tests in `test/monad_laws_test.bash`:

- **Consistency**: `fmap f m` is the same as `m >>= (return . f)`, and `m >>= f` is the same as `join (fmap f m)`

## Common Types of Monads

1. **Maybe Monad**: Represents computations that may return a result or no value at all.
   - Example: Safe division that returns Nothing for division by zero

2. **List Monad**: Represents computations with multiple possible results.
   - Example: Generating all possible combinations of elements

3. **Either Monad**: Represents computations that may fail, carrying information about the failure.
   - Example: Safe division that returns an error message for division by zero

4. **IO Monad**: Represents computations that perform input/output operations.
   - Example: Reading from a file and then writing to another file

5. **State Monad**: Represents computations that maintain state.
   - Example: Keeping track of a counter while traversing a data structure

6. **Reader Monad**: Represents computations that read from a shared environment.
   - Example: Accessing configuration settings throughout an application

7. **Writer Monad**: Represents computations that produce a secondary, accumulated output alongside their primary result.
   - Example: Appending entries to a log for debugging, tracing, and auditing while computing a value

Only the first three are implemented in this project; the others are listed to give a broader view of what the pattern can express.

## Benefits of Monads

Monads provide several key benefits in functional programming:

1. **Separation of Concerns**: They separate the "what" (the computation) from the "how" (the context or effect).

2. **Composition**: They allow complex operations to be built from simpler ones in a clean, readable way.

3. **Error Handling**: They provide elegant ways to handle errors and edge cases without cluttering the main logic.

4. **Side Effect Management**: They provide a controlled way to handle side effects in pure functional languages.

5. **Abstraction**: They abstract away common patterns of computation, reducing boilerplate code.

In this project, we implement three monad-like constructs in Bash — Maybe, List, and Either — to demonstrate these concepts, particularly focusing on error handling and composition of operations.

## Monad Laws Compliance

The table below lists exactly which laws are implemented and verified by automated tests, and for which monads. All checks run in the generic suite `test/monad_laws_test.bash`, which exercises every registered type through the uniform API (`unit`, `bind`, `map`, `join`, `mzero`, `mplus`):

| Law family | Laws | Maybe | List | Either |
|---|---|:---:|:---:|:---:|
| Monad | left identity, right identity, associativity | ✓ | ✓ | ✓ |
| Functor | identity, composition | ✓ | ✓ | ✓ |
| Functor-monad consistency | `fmap f m = m >>= (return . f)`, `m >>= f = join (fmap f m)` | ✓ | ✓ | ✓ |
| MonadPlus | identity, associativity, left zero | ✓ | ✓ | ✓ |
| MonadPlus (fourth law) | left distribution | — | ✓ | — |
| MonadPlus (fourth law) | left catch | ✓ | — | ✓ |
| Strictness contract | join fails on flat values, bind rejects scalar functions and wrong monad types | ✓ | ✓ | ✓ |

Law assertions compare the two sides with semantic equality (via canonical forms), so they hold regardless of serialization details such as whitespace or bare-vs-quoted atoms.

Notes on what is **not** covered:

- The fourth MonadPlus law differs by type on purpose: List satisfies left distribution, while Maybe and Either satisfy left catch instead (see [MonadPlus Laws](#monadplus-laws)).
- The Applicative functor laws are documented above as theoretical context only — no `ap` operation is implemented or tested.
- Compliance is **experimental, not a formal proof**: each law is checked on a representative set of values and functions (mostly integers) for every registered type. The encoding imposes no domain restrictions — empty strings, sentinel-like payloads, and pipe characters are all representable — so the sampled domain is not artificially narrowed.

Per-type unit tests in `test/maybe_test.bash`, `test/list_test.bash`, and `test/either_test.bash` additionally cover the representation contract, accessors, edge cases, and error status codes of each implementation.

## Appendix: Related Concepts

General (non-monadic) concepts used in the code and documentation, in one line each:

- **Predicate**: a yes/no test on a value; here expressed via exit status (`0` = true, `1` = false, `>= 10` = error).
- **Sentinel value**: a designated value signalling a condition rather than carrying data (e.g. `(maybe nothing)`, `(list)`).
- **Short-circuit evaluation**: stopping a chain at the first failure, skipping the remaining steps.
- **Closure**: a function plus the variables it captured; Bash lacks them, so functions here are passed *by name*.
- **S-expression**: parenthesized prefix notation from Lisp; the shape of our value encoding.
- **Canonical form**: the unique designated representation of a value; what `_value_normalize` produces and `_value_equal` compares.
- **Function composition**: `f . g` ("f after g"), i.e. `(f . g) x = f (g x)`; used by the functor and applicative composition laws.
- **Tag-based dispatch**: choosing an implementation at runtime by inspecting a tag inside the value; how the monad API selects per-type operations.
- **Purity / side effects**: a pure function depends only on its arguments and causes no observable effects; pure languages track effects in the type system (the IO monad's purpose — absent in imperative Bash).
- **Traversable / `sequence` / `mapM` / `traverse`**: walking a structure while collecting effects: `sequence :: [M a] -> M [a]`, `mapM f = sequence . map f`, `traverse` the Applicative generalization.
- **`guard`**: a MonadPlus helper yielding `unit` when a predicate holds and `mzero` otherwise; the basis of generic `filter`.
