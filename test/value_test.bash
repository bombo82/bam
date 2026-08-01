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

# Tests for the core value encoding: atom serialization, s-expression
# parsing, and the recursive value printer

# shellcheck disable=SC2329 # Some helpers are exercised only through sourced modules
# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/../src/monad.bash" >/dev/null 2>&1
# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/test_utils.bash"

test_atom_round_trip() {
  start_test_section "Atom round-trip"

  # Bare atoms: no escaping needed
  local result
  result=$(_atom_from_string "5")
  run_test "atom_from_string with simple value" "5" "$result"

  local result
  result=$(_atom_from_string "NOTHING")
  run_test "atom_from_string with NOTHING-like payload" "NOTHING" "$result"

  local result
  result=$(_atom_from_string "x|y")
  run_test "atom_from_string with pipe character" "x|y" "$result"

  local result
  result=$(_atom_from_string "*")
  run_test "atom_from_string with glob character" "*" "$result"

  # Quoted atoms
  local result
  result=$(_atom_from_string "hello world")
  run_test "atom_from_string with space" '"hello world"' "$result"

  local result
  result=$(_atom_from_string "")
  run_test "atom_from_string with empty string" '""' "$result"

  local result
  result=$(_atom_from_string 'a"b')
  run_test "atom_from_string with double quote" '"a\"b"' "$result"

  local result
  result=$(_atom_from_string 'a\b')
  run_test "atom_from_string with backslash" '"a\\b"' "$result"

  local result
  result=$(_atom_from_string "a(b)c")
  run_test "atom_from_string with parentheses" '"a(b)c"' "$result"

  # Round-trips: atom_to_string . atom_from_string = identity
  local original="5"
  local result
  result=$(_atom_to_string "$(_atom_from_string "$original")")
  run_test "round-trip simple value" "$original" "$result"

  local original="hello world"
  local result
  result=$(_atom_to_string "$(_atom_from_string "$original")")
  run_test "round-trip value with space" "$original" "$result"

  local original=""
  local result
  result=$(_atom_to_string "$(_atom_from_string "$original")")
  run_test "round-trip empty string" "$original" "$result"

  local original='a"b\c(d)e|f*g'
  local result
  result=$(_atom_to_string "$(_atom_from_string "$original")")
  run_test "round-trip special characters" "$original" "$result"

  local original=$'line1\nline2'
  local result
  result=$(_atom_to_string "$(_atom_from_string "$original")")
  run_test "round-trip newline" "$original" "$result"
}

test_sexpr_parsing() {
  start_test_section "S-expression parsing"

  local result
  result=$(_sexpr_head "(maybe nothing)")
  run_test "sexpr_head maybe" "maybe" "$result"

  local result
  result=$(_sexpr_head "(list)")
  run_test "sexpr_head empty list" "list" "$result"

  local result
  result=$(_sexpr_head "(either right 42)")
  run_test "sexpr_head either" "either" "$result"

  local result
  result=$(_sexpr_parts "(maybe just 5)")
  run_test "sexpr_parts flat" $'maybe\njust\n5' "$result"

  # sexpr_parts preserves nested sub-expressions as single parts
  local result
  result=$(_sexpr_parts "(list 1 (list 2 3) 4)")
  run_test "sexpr_parts nested" $'list\n1\n(list 2 3)\n4' "$result"

  # sexpr_parts keeps quoted atoms with spaces as single parts
  local result
  result=$(_sexpr_parts '(list "a b" c)')
  run_test "sexpr_parts quoted atom with space" $'list\n"a b"\nc' "$result"

  # Empty list: head only, no children
  local result
  result=$(_sexpr_parts "(list)")
  run_test "sexpr_parts empty list" "list" "$result"

  local result
  result=$(_sexpr_children "(list 1 2 3)")
  run_test "sexpr_children flat list" $'1\n2\n3' "$result"

  local result
  result=$(_sexpr_children "(list)")
  run_test "sexpr_children empty list" "" "$result"

  # sexpr_children returns all parts after the head, including constructor
  # keywords such as "just"
  local result
  result=$(_sexpr_children "(maybe just (list 1 2))")
  run_test "sexpr_children nested" $'just\n(list 1 2)' "$result"

  local result
  result=$(_value_kind "5")
  run_test "value_kind atom" "atom" "$result"

  local result
  result=$(_value_kind '"a b"')
  run_test "value_kind quoted atom" "atom" "$result"

  local result
  result=$(_value_kind "(list 1 2)")
  run_test "value_kind list" "list" "$result"
}

test_malformed_input() {
  start_test_section "Malformed input"

  _sexpr_parts "(list 1 2" >/dev/null 2>&1
  run_test "sexpr_parts unbalanced open paren" "$ERR_PARSE_PARENS" "$?"

  _sexpr_parts "(list 1))" >/dev/null 2>&1
  run_test "sexpr_parts unbalanced close paren" "$ERR_PARSE_PARENS" "$?"

  _sexpr_parts '(list "a)' >/dev/null 2>&1
  run_test "sexpr_parts unterminated quote" "$ERR_PARSE_QUOTE" "$?"

  _sexpr_parts "list 1 2" >/dev/null 2>&1
  run_test "sexpr_parts not an expression" "$ERR_PARSE_NOT_EXPR" "$?"

  _sexpr_head "atom" >/dev/null 2>&1
  run_test "sexpr_head on atom" "$ERR_PARSE_NOT_EXPR" "$?"
}

test_print_value() {
  start_test_section "Print value"

  local result
  result=$(print_value "5")
  run_test "print_value atom" "5" "$result"

  local result
  result=$(print_value '"hello world"')
  run_test "print_value quoted atom" '"hello world"' "$result"

  local result
  result=$(print_value "(maybe nothing)")
  run_test "print_value Nothing" "Nothing" "$result"

  local result
  result=$(print_value "(maybe just 5)")
  run_test "print_value Just" "Just 5" "$result"

  local result
  result=$(print_value "(maybe just (maybe nothing))")
  run_test "print_value nested maybe" "Just Nothing" "$result"

  local result
  result=$(print_value "(list)")
  run_test "print_value empty list" "[]" "$result"

  local result
  result=$(print_value "(list 1 2 3)")
  run_test "print_value list" "[1, 2, 3]" "$result"

  local result
  result=$(print_value "(list (list 1 2) (list 3))")
  run_test "print_value nested list" "[[1, 2], [3]]" "$result"

  local result
  result=$(print_value '(either left "division by zero")')
  run_test "print_value Left" 'Left "division by zero"' "$result"

  local result
  result=$(print_value "(either right 42)")
  run_test "print_value Right" "Right 42" "$result"

  local result
  result=$(print_value "(list (maybe just 1) (maybe nothing))")
  run_test "print_value list of maybes" "[Just 1, Nothing]" "$result"

  # print_value is injective: atoms that need quoting are printed in their
  # serialized (quoted) form, so different values never print identically
  local result
  result=$(print_value '"hello world"')
  run_test "print_value quoted atom is shown quoted" '"hello world"' "$result"

  local result
  result=$(print_value '(list "1, 2")')
  run_test "print_value list with comma atom" '["1, 2"]' "$result"

  local result
  result=$(print_value '(list "1, 2" 3)')
  run_test "print_value mixed quoted and bare atoms" '["1, 2", 3]' "$result"

  local result
  result=$(print_value '(list "")')
  run_test "print_value empty atom" '[""]' "$result"

  local result
  result=$(print_value '(maybe just "a b")')
  run_test "print_value Just with quoted atom" 'Just "a b"' "$result"

  local result
  result=$(print_value '(either left "division by zero")')
  run_test "print_value Left with quoted atom" 'Left "division by zero"' "$result"

  # print_value fails with a dispatch error on an unknown tag
  print_value "(foo 1)" >/dev/null 2>&1
  run_test "print_value with unknown tag" "$ERR_UNKNOWN_TYPE" "$?"
}

test_decode_and_compound() {
  start_test_section "Decode and compound helpers"

  local result
  result=$(_decode_value "5")
  run_test "decode_value bare atom" "5" "$result"

  local result
  result=$(_decode_value '"a b"')
  run_test "decode_value quoted atom" "a b" "$result"

  # decode_value passes compound values through unchanged
  local result
  result=$(_decode_value "(list 1 2)")
  run_test "decode_value compound" "(list 1 2)" "$result"

  # decode_value fails with a parse error on malformed compound input
  _decode_value "(ciao" >/dev/null 2>&1
  run_test "decode_value with malformed compound" "$ERR_PARSE_PARENS" "$?"

  _is_compound "(list 1 2)"
  run_test "is_compound with list" "0" "$?"

  _is_compound "(maybe nothing)"
  run_test "is_compound with maybe" "0" "$?"

  _is_compound "5"
  run_test "is_compound with bare atom" "1" "$?"

  _is_compound '"a b"'
  run_test "is_compound with quoted atom" "1" "$?"

  # A string that starts with ( but is not well-formed is not a compound value
  _is_compound "(ciao"
  run_test "is_compound with malformed expression" "1" "$?"
}

test_value_normalize() {
  start_test_section "Canonical normalization and semantic equality"

  # Atoms are canonicalized to the bare form whenever possible
  local result
  result=$(_value_normalize '"5"')
  run_test "value_normalize quoted-but-bareable atom" "5" "$result"

  local result
  result=$(_value_normalize '"a b"')
  run_test "value_normalize atom with space" '"a b"' "$result"

  # Compound values are re-emitted with single spaces, recursively
  local result
  result=$(_value_normalize "(list  1   2)")
  run_test "value_normalize extra whitespace" "(list 1 2)" "$result"

  local result
  result=$(_value_normalize '(maybe just "5")')
  run_test "value_normalize nested atom" "(maybe just 5)" "$result"

  local result
  result=$(_value_normalize '(list (list  "a b"  1) "5")')
  run_test "value_normalize nested compound" '(list (list "a b" 1) 5)' "$result"

  # Malformed input propagates the parse error
  _value_normalize "(list 1" >/dev/null 2>&1
  run_test "value_normalize malformed input" "$ERR_PARSE_PARENS" "$?"

  # value_equal: semantically equal values with different serializations
  _value_equal "(list 1 2)" "(list  1  2)"
  run_test "value_equal with whitespace difference" "0" "$?"

  _value_equal "5" '"5"'
  run_test "value_equal bare vs quoted atom" "0" "$?"

  _value_equal "(maybe just 5)" "(maybe just 6)"
  run_test "value_equal with different values" "1" "$?"

  # Malformed input returns the parse error, not "not equal"
  _value_equal "(list 1" "(list 1)"
  run_test "value_equal with malformed input" "$ERR_PARSE_PARENS" "$?"
}

test_require_helpers() {
  start_test_section "Boundary validation helpers"

  _require_kind "(maybe just 5)" maybe
  run_test "require_kind with matching tag" "0" "$?"

  _require_kind "(list 1)" maybe >/dev/null 2>&1
  run_test "require_kind with wrong tag" "$ERR_WRONG_TAG" "$?"

  _require_kind "(list 1" maybe >/dev/null 2>&1
  run_test "require_kind with malformed input" "$ERR_PARSE_PARENS" "$?"

  _require_function _require_kind
  run_test "require_function with existing function" "0" "$?"

  _require_function this_function_does_not_exist >/dev/null 2>&1
  run_test "require_function with unknown function" "$ERR_UNKNOWN_FUNCTION" "$?"
}

test_is_value() {
  start_test_section "Single-value validation"

  _is_value "5"
  run_test "is_value with bare atom" "0" "$?"

  _is_value '"a b"'
  run_test "is_value with quoted atom" "0" "$?"

  _is_value '""'
  run_test "is_value with empty quoted atom" "0" "$?"

  _is_value "(list 1 2)"
  run_test "is_value with compound value" "0" "$?"

  _is_value "(maybe just (list 1 2))"
  run_test "is_value with nested compound value" "0" "$?"

  # Invalid: multiple values or malformed input
  _is_value "1 2"
  run_test "is_value with two bare atoms" "1" "$?"

  _is_value '"a" "b"'
  run_test "is_value with two quoted atoms" "1" "$?"

  _is_value "(ciao"
  run_test "is_value with malformed expression" "1" "$?"

  _is_value '"unterminated'
  run_test "is_value with unterminated quote" "1" "$?"

  _is_value ""
  run_test "is_value with empty string" "1" "$?"
}

run_value_tests() {
  local file_name="$1"
  print_test_header "Testing core value encoding" "$file_name"

  test_atom_round_trip
  test_sexpr_parsing
  test_malformed_input
  test_print_value
  test_decode_and_compound
  test_is_value
  test_value_normalize
  test_require_helpers

  print_test_summary "Core value encoding"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_value_tests "$0"
fi
