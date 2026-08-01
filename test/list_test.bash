#!/bin/bash

#
# BAM! Bourne Again Monad! A monad-like construct for bash.
# Copyright (C) 2026 Gianni Bombelli (bombo82) <bombo82@giannibombelli.it>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

# shellcheck disable=SC2329 # Test fixtures are invoked by name through bind/map
# Tests for the List monad implementation on the core value encoding

# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/../src/monad.bash" >/dev/null 2>&1
# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/test_utils.bash"

test_basic_functions() {
  start_test_section "Basic list monad functions"

  local result
  result=$(unit list 42)
  run_test "unit with value" "(list 42)" "$result"

  local result
  result=$(list_create 1 2 3)
  run_test "list_create with multiple values" "(list 1 2 3)" "$result"

  local result
  result=$(list_create)
  run_test "list_create with no values" "$EMPTY_LIST" "$result"

  local result
  result=$(list_create 42)
  run_test "list_create with one value" "(list 42)" "$result"

  local result
  result=$(list_create "a b" "")
  run_test "list_create with quoted atoms" '(list "a b" "")' "$result"

  # The pipe character is an ordinary atom, not a sentinel
  local result
  result=$(list_create "x|y")
  run_test "list_create with pipe character" "(list x|y)" "$result"

  # list_create embeds serialized monadic values (nesting)
  local result
  result=$(list_create "(maybe just 1)" 2)
  run_test "list_create with nested monadic value" "(list (maybe just 1) 2)" "$result"

  local result
  result=$(list_create "(list 1 2)" "(list 3)")
  run_test "list_create with nested lists" "(list (list 1 2) (list 3))" "$result"

  # Strict contract: unit wraps a single value and rejects multi-token input
  assert_contract_error "unit rejects multi-token input" "$ERR_UNIT_INPUT" unit list "1 2"

  assert_contract_error "unit rejects malformed input" "$ERR_UNIT_INPUT" unit list "(ciao"

  local result
  result=$(unit list "(maybe just 5)")
  run_test "unit with compound value" "(list (maybe just 5))" "$result"
}

test_bind_operations() {
  start_test_section "Bind operations"

  # A Kleisli arrow: a -> List b
  to_list() {
    local value="$1"
    list_create "$value" $((value + 1))
  }

  local result
  result=$(bind "(list 10)" to_list)
  run_test "bind with single value" "(list 10 11)" "$result"

  local result
  result=$(bind "$EMPTY_LIST" to_list)
  run_test "bind with EMPTY_LIST" "$EMPTY_LIST" "$result"

  local result
  result=$(list_create 1 2 3)
  result=$(bind "$result" to_list)
  run_test "bind with list" "(list 1 2 2 3 3 4)" "$result"

  local result
  result=$(bind "(list 5)" to_list)
  run_test "bind with function returning list" "(list 5 6)" "$result"

  local result
  result=$(list_create 1 2)
  result=$(bind "$result" to_list)
  run_test "bind with list and function returning list" "(list 1 2 2 3)" "$result"

  local result
  result=$(bind "(list 10)" to_list)
  result=$(bind "$result" to_list)
  run_test "chain of binds" "(list 10 11 11 12)" "$result"

  # Strict contract: bind rejects a plain scalar function (not a Kleisli arrow)
  double() {
    local value="$1"
    echo $((value * 2))
  }
  bind "(list 10)" double >/dev/null 2>&1
  run_test "bind rejects scalar function" "$ERR_JOIN_FLAT" "$?"

  # Parse errors propagate through bind with their specific code
  bind '(list "a' double >/dev/null 2>&1
  run_test "bind propagates quote error" "$ERR_PARSE_QUOTE" "$?"

  bind "(list 1" double >/dev/null 2>&1
  run_test "bind propagates parens error" "$ERR_PARSE_PARENS" "$?"
}

test_map_and_filter() {
  start_test_section "Map and filter"

  double() {
    local value="$1"
    echo $((value * 2))
  }

  is_even() {
    local value="$1"
    return $((value % 2))
  }

  local result
  result=$(list_create 1 2 3)
  result=$(map "$result" double)
  run_test "map" "(list 2 4 6)" "$result"

  local result
  result=$(map "$EMPTY_LIST" double)
  run_test "map with EMPTY_LIST" "$EMPTY_LIST" "$result"

  local result
  result=$(list_create 1 2 3 4 5 6)
  result=$(list_filter "$result" is_even)
  run_test "list_filter" "(list 2 4 6)" "$result"

  local result
  result=$(list_filter "$EMPTY_LIST" is_even)
  run_test "list_filter with EMPTY_LIST" "$EMPTY_LIST" "$result"

  # list_filter propagates error statuses (>= 10) from the predicate
  failing_predicate() {
    return "$ERR_CONTRACT"
  }
  list_filter "$(list_create 1 2 3)" failing_predicate >/dev/null 2>&1
  run_test "list_filter propagates predicate error" "$ERR_CONTRACT" "$?"

  # list_filter fails with a dispatch error on an unknown predicate name
  list_filter "$(list_create 1 2 3)" this_function_does_not_exist >/dev/null 2>&1
  run_test "list_filter with unknown predicate" "$ERR_UNKNOWN_FUNCTION" "$?"

  # map fails with a dispatch error on an unknown function name
  map "$(list_create 1 2 3)" this_function_does_not_exist >/dev/null 2>&1
  run_test "map with unknown function" "$ERR_UNKNOWN_FUNCTION" "$?"
}

test_monadplus_functions() {
  start_test_section "MonadPlus functions"

  local result
  result=$(mzero list)
  run_test "mzero" "$EMPTY_LIST" "$result"

  # mplus concatenates lists
  local list1
  list1=$(list_create 1 2 3)
  local list2
  list2=$(list_create 4 5 6)
  local result
  result=$(mplus "$list1" "$list2")
  run_test "mplus" "(list 1 2 3 4 5 6)" "$result"

  local result
  result=$(mplus "$EMPTY_LIST" "$(list_create 4 5 6)")
  run_test "mplus with first EMPTY_LIST" "(list 4 5 6)" "$result"

  local result
  result=$(mplus "$(list_create 1 2 3)" "$EMPTY_LIST")
  run_test "mplus with second EMPTY_LIST" "(list 1 2 3)" "$result"

  local result
  result=$(mplus "$EMPTY_LIST" "$EMPTY_LIST")
  run_test "mplus with both EMPTY_LIST" "$EMPTY_LIST" "$result"
}

test_edge_cases() {
  start_test_section "Edge cases"

  # Under the strict discipline the empty string is a first-class value
  # (the empty atom ""), not a failure
  returns_empty_string() {
    echo ""
  }

  identity() {
    local value="$1"
    echo "$value"
  }

  always_true() {
    return 0
  }

  local result
  result=$(list_create 1 2)
  result=$(map "$result" returns_empty_string)
  run_test "map with function returning empty string" '(list "" "")' "$result"

  local result
  result=$(list_create 1)
  result=$(map "$result" returns_empty_string)
  run_test "map with single value and function returning empty string" '(list "")' "$result"

  # Elements containing glob characters must be preserved literally
  local result
  result=$(list_create "*" "x")
  run_test "list_create with glob character" "(list * x)" "$result"

  local result
  result=$(map "$(list_create "*" "x")" identity)
  run_test "map with glob character in element" "(list * x)" "$result"

  to_singleton() {
    local value="$1"
    unit list "$(_atom_from_string "$value")"
  }
  local result
  result=$(bind "$(list_create "*")" to_singleton)
  run_test "bind with glob character in element" "(list *)" "$result"

  local result
  result=$(list_filter "$(list_create "*" "x")" always_true)
  run_test "list_filter with glob character in element" "(list * x)" "$result"

  # A function returning a raw string with spaces produces a single quoted
  # element, not two elements
  raw_spaces() {
    echo "hello world"
  }
  local result
  result=$(map "(list 1)" raw_spaces)
  run_test "map with raw result with spaces" '(list "hello world")' "$result"

  # The function receives the raw payload of a quoted atom element
  local result
  result=$(map '(list "a b")' identity)
  run_test "map identity with quoted atom" '(list "a b")' "$result"
}

test_join_function() {
  start_test_section "Join function"

  local result
  result=$(join "(list (list 1 2) (list 3))")
  run_test "join with nested lists" "(list 1 2 3)" "$result"

  # Strict contract: join on a flat list (elements are not lists) fails
  join "(list 1 2 3)" >/dev/null 2>&1
  run_test "join on a flat list fails" "$ERR_JOIN_FLAT" "$?"

  local result
  result=$(join "$EMPTY_LIST")
  run_test "join with EMPTY_LIST" "$EMPTY_LIST" "$result"

  # Strict contract: join fails if any element is not a list
  join "(list (list 1 2) 5)" >/dev/null 2>&1
  run_test "join with flat element fails" "$ERR_JOIN_FLAT" "$?"

  # Strict contract: join fails on elements nested under a different tag
  join "(list (list 1 2) (maybe just 1))" >/dev/null 2>&1
  run_test "join with different tag fails" "$ERR_JOIN_TAG" "$?"

  # A nested empty list contributes no elements
  local result
  result=$(join "(list (list))")
  run_test "join with nested empty list" "$EMPTY_LIST" "$result"
}

run_list_monad_tests() {
  local file_name="$1"

  print_test_header "Testing List monad functions" "$file_name"

  test_basic_functions
  test_bind_operations
  test_map_and_filter
  test_monadplus_functions
  test_edge_cases
  test_join_function

  print_test_summary "List monad functions"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_list_monad_tests "$0"
fi
