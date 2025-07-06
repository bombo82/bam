#!/bin/bash

# Tests for nesting of monadic values
#
# The structured encoding makes nesting representable, both of the same
# monad type (Maybe (Maybe a), List (List a)) and of different types
# (List (Maybe a), Maybe (List a), Either e (List a)). These tests verify
# that nested values are distinct, printable, and work with the uniform API.

# Source the uniform monad API and test utilities
# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/../src/monad.bash" >/dev/null 2>&1
# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/test_utils.bash"

# Test nesting of monads of the same type
test_same_type_nesting() {
  start_test_section "Same-type nesting"

  # Just Nothing is now a value distinct from Nothing
  local just_nothing="(maybe just $NOTHING)"
  if [ "$just_nothing" != "$NOTHING" ]; then
    run_test "Just Nothing differs from Nothing" "distinct" "distinct"
  else
    run_test "Just Nothing differs from Nothing" "distinct" "equal"
  fi

  # join flattens Just Nothing into Nothing
  local result
  result=$(join "$just_nothing")
  run_test "join on Just Nothing" "$NOTHING" "$result"

  # join flattens Just (Just 5) into Just 5
  local result
  result=$(join "(maybe just (maybe just 5))")
  run_test "join on Just (Just 5)" "(maybe just 5)" "$result"

  # (list (list)) flattens to the empty list, but differs from it
  local nested_empty="(list (list))"
  if [ "$nested_empty" != "$EMPTY_LIST" ]; then
    run_test "(list (list)) differs from (list)" "distinct" "distinct"
  else
    run_test "(list (list)) differs from (list)" "distinct" "equal"
  fi

  # join flattens a list of lists
  local result
  result=$(join "(list (list 1 2) (list 3) (list))")
  run_test "join on list of lists" "(list 1 2 3)" "$result"

  # bind over a nested Maybe applies the function to the inner Maybe
  identity() {
    local value="$1"
    echo "$value"
  }
  local result
  result=$(bind "$just_nothing" identity)
  run_test "bind on Just Nothing with identity" "$NOTHING" "$result"
}

# Test nesting of monads of different types
test_cross_type_nesting() {
  start_test_section "Cross-type nesting"

  add_one() {
    local value="$1"
    echo $((value + 1))
  }

  double() {
    local value="$1"
    echo $((value * 2))
  }

  # List (Maybe Int): map over the list a function that maps the inner Maybe
  # (map, not bind: the function returns Maybe values, which become elements —
  # there is no list-of-lists to flatten)
  map_inner_maybe_add_one() {
    local value="$1"
    map "$value" add_one
  }
  local result
  result=$(map "(list (maybe just 1) $NOTHING)" map_inner_maybe_add_one)
  run_test "map over List of Maybe" "(list (maybe just 2) $NOTHING)" "$result"

  # Maybe (List Int): map with a function that maps the inner list
  map_inner_list_double() {
    local value="$1"
    map "$value" double
  }
  local result
  result=$(map "(maybe just (list 1 2))" map_inner_list_double)
  run_test "map over Maybe of List" "(maybe just (list 2 4))" "$result"

  # Either String (List Int): a Right carrying a list
  local result
  result=$(map "(either right (list 1 2))" map_inner_list_double)
  run_test "map over Either of List" "(either right (list 2 4))" "$result"

  # mplus over Maybe values carrying lists
  local result
  result=$(mplus "$NOTHING" "(maybe just (list 1 2))")
  run_test "mplus with nested values" "(maybe just (list 1 2))" "$result"
}

# Test printing of nested values
test_nested_printing() {
  start_test_section "Nested printing"

  local result
  result=$(print_value "(list (maybe just 1) $NOTHING)")
  run_test "print List of Maybe" "[Just 1, Nothing]" "$result"

  local result
  result=$(print_value "(maybe just (list 1 2))")
  run_test "print Maybe of List" "Just [1, 2]" "$result"

  local result
  result=$(print_value "(either left (list 1 2))")
  run_test "print Left of List" "Left [1, 2]" "$result"

  local result
  result=$(print_value "(list (list 1) (maybe just (list 2 3)))")
  run_test "print deeply nested" "[[1], Just [2, 3]]" "$result"
}

# Test mplus with mixed type tags
test_mixed_tags() {
  start_test_section "Mixed type tags"

  # mplus requires both values to have the same type tag
  mplus "$NOTHING" "$EMPTY_LIST" >/dev/null 2>&1
  run_test "mplus with mixed tags" "$ERR_TAG_MISMATCH" "$?"

  mplus "$EMPTY_LIST" "(either right 5)" >/dev/null 2>&1
  run_test "mplus with list and either" "$ERR_TAG_MISMATCH" "$?"
}

# Main function to run all tests
run_nesting_tests() {
  local file_name="$1"
  print_test_header "Testing nesting of monadic values" "$file_name"

  test_same_type_nesting
  test_cross_type_nesting
  test_nested_printing
  test_mixed_tags

  print_test_summary "Nesting of monadic values"
}

# Run the tests if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_nesting_tests "$0"
fi
