# Testing

The project has a hand-rolled test harness in `test/test_utils.bash`; there is no external test framework. This document explains how to run the tests, what the output means, and how the suites are organised.

## Running Tests

Run the full suite from the repository root — it completes in a few seconds, so this is the recommended way to verify any change:

```bash
bash test/run_all_tests.bash
```

The script runs all tests in the project in the following order:
1. First runs test_utils tests
2. Then runs all monad implementation tests in alphabetical order
3. Provides a summary of all test suites with pass/fail statistics

The script exits with code `0` if every suite passes, `1` otherwise, so it can be used in CI or pre-commit checks.

Individual test files can also be run on their own — files source their dependencies relative to their own location, so every suite works from any working directory.

## Test Suites

- `test/test_utils_test.bash` — tests for the test harness itself (`run_test`, counters, formatting helpers)
- `test/value_test.bash` — tests for the structured value encoding (atom round-trips, s-expression parsing, malformed input, recursive printing)
- `test/monad_test.bash` — tests for the uniform API dispatch (`unit`, `bind`, `map`, `join`, `mzero`, `mplus`)
- `test/monad_laws_test.bash` — **all** the laws (three monad laws, functor laws, functor-monad consistency, MonadPlus laws) verified generically through the uniform API for every registered type, plus the strictness contract (join fails on flat values, bind rejects scalar functions and wrong monad types); the only per-type input is the type name, plus the MonadPlus flavour (left distribution for List, left catch for Maybe and Either)
- `test/nesting_test.bash` — same-type nesting (`Just Nothing` vs `Nothing`, lists of lists), cross-type nesting (`List (Maybe a)`, `Maybe (List a)`, `Either e (List a)`), nested printing, and `mplus` tag mismatch
- `test/either_test.bash` — unit tests for the Either monad functions (`either_left`, `either_right`, `either_is_left`, `either_is_right`, `either_unwrap` and internal dispatch)
- `test/maybe_test.bash` — unit tests for the Maybe monad functions (`maybe_just`, `maybe_is_nothing`, `maybe_is_just`, `maybe_unwrap` and internal dispatch)
- `test/list_test.bash` — unit tests for the List monad functions (`list_create`, `list_filter` and internal dispatch)

The laws are consolidated in the single generic suite `test/monad_laws_test.bash`: fixtures (Kleisli functions, return wrappers, lambdas) are built through the uniform API (`unit`, `mzero`, `bind`, `map`, `join`, `mplus`), so registering a new monad type automatically extends the laws coverage to it. The suite uses functions of the correct type for each law: functions passed to `bind` return monadic values (Kleisli arrows, `a -> M b`), while functions passed to `map` are plain transformations (`a -> b`). It also covers edge cases such as `mzero` inputs, functions that fail mid-chain, and functions that return the empty value. Law assertions use `_value_equal` (semantic equality via canonical forms), so they are insensitive to serialization details like whitespace or bare-vs-quoted atoms. Note that the verification is experimental: each law is checked on a representative set of (mostly integer) values and functions, not proved for all values.

## Test Output

Test output includes:
- Individual test results (✓ for passed, ✗ for failed)
- Section headers for different test categories
- A summary showing total tests, passed tests, and failed tests with percentage
- For failed tests, the expected and actual values are displayed
- Coloured output for better readability (green for passed, red for failed)

## Writing New Tests

When adding tests, follow the conventions used by the existing suites:

- Source the unit under test and the harness relative to the test file's own location:
  ```bash
  source "$(dirname "${BASH_SOURCE[0]}")/../src/maybe.bash" >/dev/null 2>&1
  source "$(dirname "${BASH_SOURCE[0]}")/test_utils.bash"
  ```
- Group assertions into `test_*` functions, each opening with `start_test_section "Title"`.
- Assert with `run_test "test name" "expected" "$actual"`. For error cases, assert the specific status constant from the registry in `src/value.bash` (e.g. `"$ERR_JOIN_FLAT"`), never the content of stderr. Use the convenience helper `assert_contract_error "test name" "$ERR_XXX" command args...` (defined in `test_utils.bash`) to reduce duplication when testing contract/parse errors on accessors.
- End with an entry function that prints the header, calls the section functions, and calls `print_test_summary` (its return code becomes the suite's exit code).
- Guard execution so sourcing the test file does not run the tests:
  ```bash
  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_maybe_monad_tests "$0"
  fi
  ```
- Test both success and failure/Nothing cases, and extend `test/monad_laws_test.bash` when changing `return`/`bind` semantics — all monads are expected to satisfy all three monad laws. To register a new monad type, add its `<tag>_*` operations, list it in `MONAD_TYPES`, and add its MonadPlus flavour to `MONADPLUS_FLAVORS` (both in `src/monad.bash`).
