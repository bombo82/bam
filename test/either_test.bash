#!/bin/bash

# Tests for the Either monad implementation
# This file contains tests for the basic either monad functions

# shellcheck disable=SC2329 # Per-type operations are invoked dynamically by the dispatcher
# Source the uniform monad API and test utilities
# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/../src/monad.bash" >/dev/null 2>&1
# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/test_utils.bash"

# Test constructors and accessors
test_constructors() {
  start_test_section "Constructors and accessors"

  local result
  result=$(either_right 5)
  run_test "either_right with atom" "(either right 5)" "$result"

  local result
  result=$(either_left "error")
  run_test "either_left with atom" "(either left error)" "$result"

  local result
  result=$(either_right "$(_atom_from_string "hello world")")
  run_test "either_right with quoted atom" '(either right "hello world")' "$result"

  either_is_left "(either left error)"
  run_test "either_is_left with left" "0" "$?"

  either_is_left "(either right 5)"
  run_test "either_is_left with right" "1" "$?"

  either_is_right "(either right 5)"
  run_test "either_is_right with right" "0" "$?"

  either_is_right "(either left error)"
  run_test "either_is_right with left" "1" "$?"

  local result
  result=$(either_unwrap "(either right 5)")
  run_test "either_unwrap right" "5" "$result"

  local result
  result=$(either_unwrap "(either left error)")
  run_test "either_unwrap left" "error" "$result"

  # Nested values
  local result
  result=$(either_right "(list 1 2)")
  run_test "either_right with nested list" "(either right (list 1 2))" "$result"

  # Strict contract: unit wraps a single value and rejects multi-token input
  unit either "1 2" >/dev/null 2>&1
  run_test "unit rejects multi-token input" "$ERR_UNIT_INPUT" "$?"

  unit either "(ciao" >/dev/null 2>&1
  run_test "unit rejects malformed input" "$ERR_UNIT_INPUT" "$?"

  # unit accepts a compound value (nesting)
  local result
  result=$(unit either "(list 1 2)")
  run_test "unit with compound value" "(either right (list 1 2))" "$result"
}

# Test accessor validation
test_accessor_validation() {
  start_test_section "Accessor validation"

  # either_unwrap fails with a contract error on a non-Either value
  assert_contract_error "either_unwrap with wrong tag" "$ERR_WRONG_TAG" either_unwrap "(maybe just 1)"

  # either_is_left fails with a contract error on a non-Either value
  assert_contract_error "either_is_left with wrong tag" "$ERR_WRONG_TAG" either_is_left "(list 1)"

  # either_is_right fails with a contract error on a non-Either value
  assert_contract_error "either_is_right with wrong tag" "$ERR_WRONG_TAG" either_is_right "(list 1)"
}

# Test return, bind, map, join
test_monad_functions() {
  start_test_section "Monad functions"

  # A function that doubles a value and wraps it in an Either
  double_either() {
    local value="$1"
    either_right $((value * 2))
  }

  # A partial function: fails (Left) on input 0
  half_either() {
    local value="$1"
    if [ "$value" -eq 0 ]; then
      either_left "$(_atom_from_string "division by zero")"
    else
      either_right $((value / 2))
    fi
  }

  # Test return
  local result
  result=$(unit either 5)
  run_test "unit" "(either right 5)" "$result"

  # Test bind with a Right value
  local result
  result=$(bind "(either right 10)" double_either)
  run_test "bind with right" "(either right 20)" "$result"

  # Test bind with a Left value (propagates)
  local result
  result=$(bind "(either left error)" double_either)
  run_test "bind with left" "(either left error)" "$result"

  # Test bind with a failing function
  local result
  result=$(bind "(either right 0)" half_either)
  run_test "bind with failing function" '(either left "division by zero")' "$result"

  # bind fails with a dispatch error on an unknown function name
  bind "(either right 10)" this_function_does_not_exist >/dev/null 2>&1
  run_test "bind with unknown function" "$ERR_UNKNOWN_FUNCTION" "$?"

  # Test bind with extra arguments
  add_either() {
    local value="$1"
    local addend="$2"
    either_right $((value + addend))
  }
  local result
  result=$(bind "(either right 10)" add_either 5)
  run_test "bind with extra args" "(either right 15)" "$result"

  # Test map with a plain function
  double() {
    local value="$1"
    echo $((value * 2))
  }
  local result
  result=$(map "(either right 10)" double)
  run_test "map with right" "(either right 20)" "$result"

  local result
  result=$(map "(either left error)" double)
  run_test "map with left" "(either left error)" "$result"

  # A function returning a raw string with spaces is serialized as an atom,
  # not embedded raw (which would corrupt the payload)
  raw_spaces() {
    echo "hello world"
  }
  local result
  result=$(map "(either right 10)" raw_spaces)
  run_test "map with raw result with spaces" '(either right "hello world")' "$result"

  # The function receives the raw payload of a quoted atom
  identity() {
    local value="$1"
    echo "$value"
  }
  local result
  result=$(map '(either right "a b")' identity)
  run_test "map identity with quoted atom" '(either right "a b")' "$result"

  # Test join
  local result
  result=$(join "(either right (either right 5))")
  run_test "join nested right" "(either right 5)" "$result"

  local result
  result=$(join "(either right (either left error))")
  run_test "join right of left" "(either left error)" "$result"

  local result
  result=$(join "(either left error)")
  run_test "join left" "(either left error)" "$result"

  # Parse errors propagate through bind with their specific code
  double_fn() {
    local value="$1"
    echo $((value * 2))
  }
  bind '(either right "a' double_fn >/dev/null 2>&1
  run_test "bind propagates quote error" "$ERR_PARSE_QUOTE" "$?"

  bind "(either right 1" double_fn >/dev/null 2>&1
  run_test "bind propagates parens error" "$ERR_PARSE_PARENS" "$?"

  # join fails on values nested under a different tag
  join "(either right (list 1 2))" >/dev/null 2>&1
  run_test "join with different tag fails" "$ERR_JOIN_TAG" "$?"
}

# Test MonadPlus functions
test_monadplus_functions() {
  start_test_section "MonadPlus functions"

  local result
  result=$(mzero either)
  run_test "mzero" '(either left "")' "$result"

  # First Right wins
  local result
  result=$(mplus "(either right 1)" "(either right 2)")
  run_test "mplus first right" "(either right 1)" "$result"

  # Falls back to the second value
  local result
  result=$(mplus "(either left e1)" "(either right 2)")
  run_test "mplus left then right" "(either right 2)" "$result"

  local result
  result=$(mplus "(either left e1)" "(either left e2)")
  run_test "mplus both left" "(either left e2)" "$result"
}

# Main function to run all tests
run_either_monad_tests() {
  local file_name="$1"
  print_test_header "Testing Either monad functions" "$file_name"

  test_constructors
  test_accessor_validation
  test_monad_functions
  test_monadplus_functions

  print_test_summary "Either monad functions"
}

# Run the tests if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_either_monad_tests "$0"
fi
