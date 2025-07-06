#!/bin/bash

# Tests for the Maybe monad implementation on the core value encoding
# This file contains tests for the basic monad functions

# Source the uniform monad API and test utilities
# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/../src/monad.bash" >/dev/null 2>&1
# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/test_utils.bash"

# Test constructors and accessors
test_constructors() {
  start_test_section "Constructors and accessors"

  local result
  result=$(unit maybe 42)
  run_test "unit with atom" "(maybe just 42)" "$result"

  local result
  result=$(unit maybe "$(_atom_from_string "hello world")")
  run_test "unit with quoted atom" '(maybe just "hello world")' "$result"

  maybe_is_nothing "$NOTHING"
  run_test "maybe_is_nothing with NOTHING" "0" "$?"

  maybe_is_nothing "(maybe just 5)"
  run_test "maybe_is_nothing with Just" "1" "$?"

  # maybe_is_just predicate
  maybe_is_just "(maybe just 5)"
  run_test "maybe_is_just with Just" "0" "$?"

  maybe_is_just "$NOTHING"
  run_test "maybe_is_just with Nothing" "1" "$?"

  maybe_is_just "(list 1)" >/dev/null 2>&1
  run_test "maybe_is_just with wrong tag" "$ERR_WRONG_TAG" "$?"

  maybe_is_just "(maybe just" >/dev/null 2>&1
  run_test "maybe_is_just with malformed input" "$ERR_PARSE_PARENS" "$?"

  local result
  result=$(maybe_unwrap "(maybe just 5)")
  run_test "maybe_unwrap" "5" "$result"

  # A payload equal to NOTHING is an ordinary atom and does not collide
  local result
  result=$(unit maybe "NOTHING")
  run_test "unit with NOTHING-like payload" "(maybe just NOTHING)" "$result"

  # Strict contract: unit wraps a single value and rejects multi-token input
  unit maybe "1 2" >/dev/null 2>&1
  run_test "unit rejects multi-token input" "$ERR_UNIT_INPUT" "$?"

  unit maybe "(ciao" >/dev/null 2>&1
  run_test "unit rejects malformed input" "$ERR_UNIT_INPUT" "$?"

  # unit accepts a compound value (nesting)
  local result
  result=$(unit maybe "(list 1 2)")
  run_test "unit with compound value" "(maybe just (list 1 2))" "$result"
}

# Test accessor validation
test_accessor_validation() {
  start_test_section "Accessor validation"

  # maybe_unwrap fails with a contract error on a non-Maybe value
  assert_contract_error "maybe_unwrap with wrong tag" "$ERR_WRONG_TAG" maybe_unwrap "(list 1)"

  # maybe_unwrap propagates parse errors on malformed input
  assert_contract_error "maybe_unwrap with malformed input" "$ERR_PARSE_PARENS" maybe_unwrap "(maybe just"
}

# Test bind operations
test_bind_operations() {
  start_test_section "Bind operations"

  # A Kleisli function that adds 1 (bind requires functions of type a -> M b)
  add_one_maybe() {
    local value="$1"
    unit maybe $((value + 1))
  }

  # A partial function: returns Nothing for input 0
  half_maybe() {
    local value="$1"
    if [ "$value" -eq 0 ]; then
      echo "$NOTHING"
    else
      unit maybe $((value / 2))
    fi
  }

  # Test bind with valid value
  local result
  result=$(bind "(maybe just 10)" add_one_maybe)
  run_test "bind with value" "(maybe just 11)" "$result"

  # Test bind with NOTHING
  local result
  result=$(bind "$NOTHING" add_one_maybe)
  run_test "bind with NOTHING" "$NOTHING" "$result"

  # Test bind with a failing function
  local result
  result=$(bind "(maybe just 0)" half_maybe)
  run_test "bind with failing function" "$NOTHING" "$result"

  # Test bind with extra arguments
  add_maybe_n() {
    local value="$1"
    local addend="$2"
    unit maybe $((value + addend))
  }
  local result
  result=$(bind "(maybe just 10)" add_maybe_n 5)
  run_test "bind with extra args" "(maybe just 15)" "$result"

  # Test chain of binds
  local result
  result=$(bind "(maybe just 10)" add_one_maybe)
  result=$(bind "$result" add_one_maybe)
  run_test "chain of binds" "(maybe just 12)" "$result"

  # Test bind rejects a plain scalar function (not a Kleisli arrow)
  scalar_fn() {
    local value="$1"
    echo $((value + 1))
  }
  bind "(maybe just 10)" scalar_fn >/dev/null 2>&1
  run_test "bind rejects scalar function" "$ERR_JOIN_FLAT" "$?"

  # Parse errors propagate through bind with their specific code
  bind '(maybe just "a' scalar_fn >/dev/null 2>&1
  run_test "bind propagates quote error" "$ERR_PARSE_QUOTE" "$?"

  # bind fails with a dispatch error on an unknown function name
  bind "(maybe just 10)" this_function_does_not_exist >/dev/null 2>&1
  run_test "bind with unknown function" "$ERR_UNKNOWN_FUNCTION" "$?"

  bind "(maybe just 1" scalar_fn >/dev/null 2>&1
  run_test "bind propagates parens error" "$ERR_PARSE_PARENS" "$?"

  # join fails on values nested under a different tag
  join "(maybe just (list 1 2))" >/dev/null 2>&1
  run_test "join with different tag fails" "$ERR_JOIN_TAG" "$?"
}

# Test map function
test_map_function() {
  start_test_section "Map function"

  # For these tests, we create a simple function that doubles a value
  double() {
    local value="$1"
    echo $((value * 2))
  }

  # Test map with valid value
  local result
  result=$(map "(maybe just 10)" double)
  run_test "map with value" "(maybe just 20)" "$result"

  # Test map with NOTHING
  local result
  result=$(map "$NOTHING" double)
  run_test "map with NOTHING" "$NOTHING" "$result"

  # Test map with a function returning a string that needs quoting
  greet() {
    echo "hello world"
  }
  local result
  result=$(map "(maybe just 10)" greet)
  run_test "map with string result" '(maybe just "hello world")' "$result"

  # Test map with a function returning an empty string: the empty string is
  # a first-class value and becomes the empty atom ""
  empty_func() {
    echo ""
  }
  local result
  result=$(map "(maybe just 10)" empty_func)
  run_test "map with empty string result" '(maybe just "")' "$result"

  # The identity law must hold for quoted atoms too: the function receives
  # the raw payload, and the raw result is serialized back
  identity() {
    local value="$1"
    echo "$value"
  }
  local result
  result=$(map '(maybe just "a b")' identity)
  run_test "map identity with quoted atom" '(maybe just "a b")' "$result"

  # A raw result starting with ( is serialized as an atom, not embedded
  raw_paren() {
    echo "(ciao"
  }
  local result
  result=$(map "(maybe just 10)" raw_paren)
  run_test "map with raw result starting with paren" '(maybe just "(ciao")' "$result"

  # Test bind passes the raw payload of a quoted atom to the function
  kleisli_identity() {
    local value="$1"
    unit maybe "$(_atom_from_string "$value")"
  }
  local result
  result=$(bind '(maybe just "a b")' kleisli_identity)
  run_test "bind with quoted atom payload" '(maybe just "a b")' "$result"
}

# Test join function
test_join_function() {
  start_test_section "Join function"

  # join flattens a nested Maybe: Just (Just x) becomes Just x
  local result
  result=$(join "(maybe just (maybe just 42))")
  run_test "join with nested Just" "(maybe just 42)" "$result"

  # join flattens Just Nothing into Nothing: the two are now distinct values
  local result
  result=$(join "(maybe just $NOTHING)")
  run_test "join with Just Nothing" "$NOTHING" "$result"

  # Strict contract: join on a flat (non-nested) value fails
  join "(maybe just 42)" >/dev/null 2>&1
  run_test "join on a flat value fails" "$ERR_JOIN_FLAT" "$?"

  local result
  result=$(join "$NOTHING")
  run_test "join with NOTHING" "$NOTHING" "$result"
}

# Test MonadPlus functions
test_monadplus_functions() {
  start_test_section "MonadPlus functions"

  local result
  result=$(mzero maybe)
  run_test "mzero" "$NOTHING" "$result"

  # Test mplus with first value present (first wins)
  local result
  result=$(mplus "(maybe just 1)" "(maybe just 2)")
  run_test "mplus with first value present" "(maybe just 1)" "$result"

  # Test mplus with first value Nothing (second wins)
  local result
  result=$(mplus "$NOTHING" "(maybe just 2)")
  run_test "mplus with first value Nothing" "(maybe just 2)" "$result"

  # Test mplus with both values Nothing
  local result
  result=$(mplus "$NOTHING" "$NOTHING")
  run_test "mplus with both Nothing" "$NOTHING" "$result"
}

# Main function to run all tests
run_maybe_monad_tests() {
  local file_name="$1"
  print_test_header "Testing Maybe monad functions" "$file_name"

  test_constructors
  test_accessor_validation
  test_bind_operations
  test_map_function
  test_join_function
  test_monadplus_functions

  print_test_summary "Maybe monad functions"
}

# Run the tests if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_maybe_monad_tests "$0"
fi
