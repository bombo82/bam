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

# Tests for the uniform monad API: tag-based dispatch of the generic
# monad operations (unit, bind, map, join, mzero, mplus)

# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/../src/monad.bash" >/dev/null 2>&1
# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/test_utils.bash"

test_unit() {
  start_test_section "Unit function"

  local result
  result=$(unit either 5)
  run_test "unit with registered type" "(either right 5)" "$result"

  unit unknown 5 >/dev/null 2>&1
  run_test "unit with unknown type" "$ERR_UNKNOWN_TYPE" "$?"
}

test_bind() {
  start_test_section "Bind function"

  double_either() {
    local value="$1"
    either_right $((value * 2))
  }

  local result
  result=$(bind "(either right 10)" double_either)
  run_test "bind with right value" "(either right 20)" "$result"

  local result
  result=$(bind "(either left error)" double_either)
  run_test "bind with left value" "(either left error)" "$result"

  bind "(unknown 5)" double_either >/dev/null 2>&1
  run_test "bind with unknown tag" "$ERR_UNKNOWN_TYPE" "$?"
}

test_map() {
  start_test_section "Map function"

  double() {
    local value="$1"
    echo $((value * 2))
  }

  local result
  result=$(map "(either right 10)" double)
  run_test "map with right value" "(either right 20)" "$result"

  local result
  result=$(map "(either left error)" double)
  run_test "map with left value" "(either left error)" "$result"

  map "(unknown 5)" double >/dev/null 2>&1
  run_test "map with unknown tag" "$ERR_UNKNOWN_TYPE" "$?"
}

test_join() {
  start_test_section "Join function"

  local result
  result=$(join "(either right (either right 5))")
  run_test "join nested right" "(either right 5)" "$result"

  local result
  result=$(join "(either right (either left error))")
  run_test "join right of left" "(either left error)" "$result"

  join "(unknown 5)" >/dev/null 2>&1
  run_test "join with unknown tag" "$ERR_UNKNOWN_TYPE" "$?"
}

test_monadplus() {
  start_test_section "Mzero and mplus"

  local result
  result=$(mzero either)
  run_test "mzero" '(either left "")' "$result"

  mzero unknown >/dev/null 2>&1
  run_test "mzero with unknown type" "$ERR_UNKNOWN_TYPE" "$?"

  local result
  result=$(mplus "(either left e)" "(either right 2)")
  run_test "mplus left then right" "(either right 2)" "$result"

  local result
  result=$(mplus "(either right 1)" "(either right 2)")
  run_test "mplus first right wins" "(either right 1)" "$result"
}

test_monadplus_flavor() {
  start_test_section "MonadPlus flavor registration"

  local result
  result=$(_monadplus_flavor list)
  run_test "flavor of list" "distribution" "$result"

  local result
  result=$(_monadplus_flavor maybe)
  run_test "flavor of maybe" "catch" "$result"

  local result
  result=$(_monadplus_flavor either)
  run_test "flavor of either" "catch" "$result"

  _monadplus_flavor unknown >/dev/null 2>&1
  run_test "flavor of unknown type" "$ERR_UNKNOWN_TYPE" "$?"
}

test_error_propagation() {
  start_test_section "Error propagation through the dispatcher"

  identity() {
    local value="$1"
    echo "$value"
  }

  # Parse errors propagate through bind/map/join/mplus with their code
  bind '(list "a' identity >/dev/null 2>&1
  run_test "bind propagates quote error" "$ERR_PARSE_QUOTE" "$?"

  bind "(list 1" identity >/dev/null 2>&1
  run_test "bind propagates parens error" "$ERR_PARSE_PARENS" "$?"

  map '(list "a' identity >/dev/null 2>&1
  run_test "map propagates quote error" "$ERR_PARSE_QUOTE" "$?"

  join '(list "a' >/dev/null 2>&1
  run_test "join propagates quote error" "$ERR_PARSE_QUOTE" "$?"

  mplus '(list "a' "(list 1)" >/dev/null 2>&1
  run_test "mplus propagates quote error" "$ERR_PARSE_QUOTE" "$?"

  # Accepted classification: a malformed value whose head is readable but
  # unregistered is reported as an unknown type tag by the dispatcher
  bind "(ciao" identity >/dev/null 2>&1
  run_test "bind with readable unknown head reports unknown type" "$ERR_UNKNOWN_TYPE" "$?"

  # bind/map fail with a dispatch error on an unknown function name
  bind "(either right 10)" this_function_does_not_exist >/dev/null 2>&1
  run_test "bind with unknown function" "$ERR_UNKNOWN_FUNCTION" "$?"

  map "(either right 10)" this_function_does_not_exist >/dev/null 2>&1
  run_test "map with unknown function" "$ERR_UNKNOWN_FUNCTION" "$?"

  mplus "(foo 1)" "(foo 2)" >/dev/null 2>&1
  run_test "mplus with unknown tag" "$ERR_UNKNOWN_TYPE" "$?"
}

run_monad_api_tests() {
  local file_name="$1"
  print_test_header "Testing the uniform monad API" "$file_name"

  test_unit
  test_bind
  test_map
  test_join
  test_monadplus
  test_monadplus_flavor
  test_error_propagation

  print_test_summary "Uniform monad API"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_monad_api_tests "$0"
fi
