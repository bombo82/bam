# Contributing

This document collects the conventions to follow when contributing to the Bash-Monad project: code style, testing, tooling, and the backlog of possible improvements. For the library's semantics, representational notes, design variants, limitations, and security considerations — the contract observed by its users — see [usage.md](usage.md).

## Code Style Guidelines

When contributing to the Bash-Monad project, follow these style guidelines. These rules reflect the actual conventions used throughout the `src/` codebase:

1. **Function Naming**:
  - Use snake_case for function names
  - Core per-type monad operations use the `<tag>_<op>` convention (e.g. `list_filter`, `maybe_is_just`), so the uniform API can dispatch on the implementation functions
  - Internal/private helper and dispatch functions **must** use the "_" prefix as standard (e.g. `_atom_from_string`, `_sexpr_load_parts`, `_require_kind`, `_value_normalize`, `_maybe_unit`, `_is_monad_type`, `_require_monad_type`). Public API functions (constructors, predicates, `unit`/`bind` etc.) never start with "_"
  - Helper functions that return Maybe values use the suffix `_maybe` (e.g., `add_maybe`)

2. **Variable Naming**:
  - Use descriptive variable names
  - Use `local` for **all** variables inside functions to avoid polluting the global namespace

3. **Comments**:
  - Every function **must** have a header comment explaining its purpose, parameters, and return values, including a `Usage:` line
  - Use comments to explain complex logic

4. **Error Handling**:
  - Use the Maybe or Either monad pattern for operations that might fail
  - Return `NOTHING` (or `either_left` with an error payload) for failure cases — never exit the script

5. **Returning Values**:
  - Functions communicate results by `echo`ing them (captured by callers with `$(...)`) — never via Bash's `return`, which is reserved for exit-status semantics (e.g. predicates like `is_even` use `return 0`/`return 1`)

6. **Formatting**:
  - 2-space indentation, LF line endings, UTF-8, final newline, 120-column limit (enforced by `.editorconfig`)
  - Arithmetic on integers uses `$((...))`; floating-point arithmetic (examples only) goes through `bc`

## Internal Architecture and Conventions (for Contributors)

The following describes the internal layering and implementation details. This information is intended for developers extending the library or understanding dependencies; library users should refer to [usage.md](usage.md) and source only `src/monad.bash`.

**Layered Architecture:**

```
              examples/*.bash                   test/*_test.bash
             (executable demos)          (test suites; use uniform API)
                     |                                 |
                     +----------------+----------------+
                                      |
                               src/monad.bash    (uniform API: unit/bind/map/join/mzero/mplus + dispatch)
                            (source)  |
                               src/{maybe,list,either}.bash    (per-type impl + dispatch helper _<tag>_* )
                               (use)  |
                               src/value.bash    (self-describing encoding, s-expr parser, normalize, _require_*, ERR_*, print_value, global PARTS)
```

Note on `PARTS`: intentional global array (Bash 4.0 workaround: no nameref to return arrays). Populated by `_sexpr_load_parts`/`_sexpr_load_children`; callers consume it immediately after the call. It is not an unwanted coupling but part of the internal contract of the value module.

## Extending the Monad Implementation

For guidance on writing your own functions that work with the monads (Kleisli arrows, plain transformations, chaining), see [usage.md](usage.md#writing-your-own-functions).

When contributing new functionality to the library itself:

- Always create tests for new functions (see [testing.md](testing.md) for the test conventions)
- Test both success and failure cases
- Test integration with existing functionality
- New monad types are registered via `MONAD_TYPES` and `MONADPLUS_FLAVORS` in `src/monad.bash`; the generic laws suite covers them automatically

## Error Status Codes

The library uses two-digit error statuses (tens = category, units = specific error), documented for users in [usage.md](usage.md#error-handling); the registry lives in `src/value.bash`. When adding code that can fail, return the appropriate constant, propagate it with `|| return $?`, and keep predicates (`is_*` functions) on plain 0/1 — a status ≥ 10 must unambiguously mean "error". Tests assert the constant names, never the content of stderr.

## Debugging Tips

1. **Tracing Execution**:
  - Add `set -x` at the beginning of your script to enable Bash's trace mode
  - Use `echo "[DEBUG] Variable: $variable"` for debug output

2. **Testing Monad Values**:
  - Use `print_value` to display monad values in a readable format
  - Check if a value is `NOTHING` with: `if [ "$value" = "$NOTHING" ]; then ...`

3. **Common Issues**:
  - Make sure `bc` is installed for arithmetic operations
  - Check that all required files are sourced in the correct order — example and test files use relative paths (`source ./...`), so they only work from their own directory
  - Ensure that functions return values using `echo` rather than Bash's `return`

## Tooling

The project is validated with two external tools; both are expected to pass clean on the whole codebase:

- **ShellCheck** (static analysis): quoting issues, word splitting, unused variables, masked return values, deprecated constructs.
  ```bash
  shellcheck src/*.bash test/*.bash examples/*.bash
  ```
  Expected result: no warnings. False positives are suppressed with targeted directives that always carry a justification comment on the same line, e.g. `# shellcheck disable=SC2034 # Public API registry: ...` or `# shellcheck source=/dev/null # Dynamic path ...`. Never add a blanket disable without a documented reason; the current directives cover only dynamic source paths (SC1091), the public constant registry used across modules (SC2034), dynamically dispatched functions (SC2329), and regex-based ANSI stripping (SC2001).

- **shfmt** (formatting): enforces the `.editorconfig` style (2-space indentation) on shell files.
  ```bash
  shfmt -d -i 2 src/ test/ examples/   # diff mode: must print nothing
  shfmt -w -i 2 src/ test/ examples/   # write mode: apply formatting
  ```
  Run `shfmt -d` before committing; `max_line_length` in `.editorconfig` applies to code only (Markdown prose is exempt).

## Possible Improvements

Features and improvements that could be implemented, ordered by priority — taking into account dependencies (implementing an item simplifies the items that follow it):

1. **`sequence` and `mapM` (monadic traversal)**: map a Kleisli function over a list and collect the results inside the monad — `sequence "(list (maybe just 1) (maybe just 2))"` → `(maybe just (list 1 2))`, with short-circuit on the first failure. Independent of the Applicative functor (needs only `bind`), high didactic value ("the effectful loop"), and it lays the groundwork for `traverse`. Design notes: the monad type can be inferred from the elements (validating a uniform tag, `ERR_TAG_MISMATCH` on mixed tags); an empty list allows no inference, so it needs an explicit type argument or a contract error.

2. **Applicative functor (`ap`)**: the project documents the applicative functor laws as theoretical context (see [monad-theory.md](monad-theory.md#applicative-functor-laws)), but does not implement the `ap` operation. It could be defined generically through the uniform API (`ap mf mx = mf >>= \f -> mx >>= \x -> return (f x)`), and its four laws (identity, homomorphism, interchange, composition) could join the generic laws suite in `test/monad_laws_test.bash` — completing the functor → applicative → monad hierarchy with tests at every level. Prerequisite for the canonical `traverse` (item 4).

3. **Extended law coverage**: the generic laws suite verifies each law on a representative set of mostly-integer values. Coverage could be extended to string payloads, quoted atoms, and nested values (the encoding already supports them). After item 2, the extension would also cover the four `ap` laws.

4. **`traverse` (canonical traversal)**: the Applicative-based generalization of `mapM` (`traverse :: (a -> f b) -> t a -> f (t b)`, i.e. `sequenceA . fmap f`). For monads it coincides with `mapM`, so if item 1 is done this becomes a thin generalization/alias over the same machinery rather than a rewrite — the reason it comes after items 1 and 2.

5. **Additional monads (State, Reader, Writer)**: listed in [monad-theory.md](monad-theory.md#common-types-of-monads) as not implemented. The type registration mechanism makes them cheap to add: implement the `<tag>_*` operations, register the tag in `MONAD_TYPES` (and its MonadPlus flavour in `MONADPLUS_FLAVORS`, if applicable) in `src/monad.bash`, and the generic laws suite covers the new type automatically. After item 2, new monads would inherit `ap` for free.

6. **Generalized `filter` for Maybe and Either**: in Haskell, `filter` generalises to any `MonadPlus` via `guard`. A generic `filter` could keep the payload when the predicate holds and return `mzero` otherwise. Independent, but it shares the MonadPlus structure of items 1–5 and is testable in the generic laws suite.

7. **Property-based testing (PBT) for laws**: the current laws suite uses a fixed representative set of mostly-integer values. Implementing a lightweight PBT harness (value generators for strings/quoted/nested payloads, reproducible seeds, optional shrinkers) would enable verifying all laws on a much larger domain automatically. Could be gated behind an environment variable to keep the core test harness minimal. Natural extension of item 3 ("Extended law coverage"). Could be implemented in parallel since it has no dependencies and unlocks nothing; it could also serve as an alternative implementation approach for item 3.

8. **Additional monad combinators, eliminators and utilities**: several other standard monadic functions could be implemented for API completeness, without overlapping the items above:

   - Generic combinators (uniform API): `then` (or `>>` / `bind_ignore`), `msum`, `when`/`unless`, `foldM`/`foldM_`, `replicateM`/`replicateM_`
   - Eliminators / catamorphisms (type-specific): `maybe`/`from_maybe` for Maybe; `either`/`from_left`/`from_right` for Either
   - Conversion and collection utilities: Maybe ↔ List (`maybe_to_list`, `list_to_maybe`, `cat_maybes`), Either-on-lists (`lefts`, `rights`, `partition_eithers`), additional List ops (`list_foldl`/`list_foldr`, `list_head`/`list_tail`/`list_length`)
   - Minor / derived: `void`, `liftM`/`liftM2`, `_`-suffixed variants that discard results

   Many follow classic monad patterns and some admit generic implementation via the dispatch mechanism.

9. **Trailing newline limitation** *(decide together with item 10)*: the two candidate solutions identified in [Known Limitation: Trailing Newlines in Raw Strings](usage.md#known-limitation-trailing-newlines-in-raw-strings) (sentinel-based protocol, scoped fix at the raw boundaries) remain available if the limitation ever becomes worth solving, at the cost documented there.

10. **Subshell overhead reduction** *(decide together with item 9)*: every `bind`/`map`/`join` nests command substitutions. Internal hot paths could use `printf -v` into named variables instead of `$(...)` where profiling shows a benefit, without changing the external echo-based contract. The sentinel-based solution of item 9 would conflict with this optimization, so the two should be decided together.

**A note on the IO monad**: it is listed in [monad-theory.md](monad-theory.md#common-types-of-monads) but deliberately not among the candidates above. The IO monad exists to isolate side effects in a *pure* functional language, making effects explicit in the type system; Bash is an imperative language where every command already performs I/O, so there is no purity to protect — an IO monad in Bash would demonstrate a pattern without the problem that motivates it.
