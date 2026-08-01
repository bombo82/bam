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

#
# Generic monad laws tests through the uniform monad API
#
# This file verifies, for every registered monad type (MONAD_TYPES):
# - the three monad laws (left identity, right identity, associativity)
# - the two functor laws (identity, composition)
# - the functor-monad consistency laws
# - the MonadPlus laws, with the flavour appropriate to each type:
#   "choice" monads (List) satisfy left distribution,
#   "failure" monads (Maybe, Either) satisfy left catch instead
#
# All fixtures are built through the uniform API (unit, mzero, bind, map,
# join, mplus), so the only per-type input is the type name itself.
#

# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/../src/monad.bash" >/dev/null 2>&1
# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/test_utils.bash"

# The type currently under test (set by run_laws_for_type)
LAWS_TYPE=""

# ---------------------------------------------------------------------------
# Generic fixtures (built through the uniform API)
# ---------------------------------------------------------------------------

# Plain functions (a -> b), type-agnostic, for the functor laws
law_identity() {
  local value="$1"
  echo "$value"
}

law_add_one() {
  local value="$1"
  echo $((value + 1))
}

law_double() {
  local value="$1"
  echo $((value * 2))
}

# The composition of law_add_one and law_double
law_add_one_then_double() {
  local value="$1"
  echo $(((value + 1) * 2))
}

# Kleisli functions (a -> M b) for the type under test
law_kleisli_inc() {
  local value="$1"
  unit "$LAWS_TYPE" $((value + 1))
}

law_kleisli_double() {
  local value="$1"
  unit "$LAWS_TYPE" $((value * 2))
}

# Partial Kleisli function: fails (mzero) for input 0
law_kleisli_partial() {
  local value="$1"
  if [ "$value" -eq 0 ]; then
    mzero "$LAWS_TYPE"
  else
    unit "$LAWS_TYPE" $((value / 2))
  fi
}

# Unary return for the right identity law
law_wrap() {
  local value="$1"
  unit "$LAWS_TYPE" "$value"
}

# return . law_add_one, for the consistency law
law_return_add_one() {
  local value="$1"
  unit "$LAWS_TYPE" $((value + 1))
}

# Lambda (\x -> f x >>= g) for the associativity law
law_lambda_inc_then_double() {
  local value="$1"
  bind "$(law_kleisli_inc "$value")" law_kleisli_double
}

# Lambda where f fails mid-chain
law_lambda_partial_then_double() {
  local value="$1"
  bind "$(law_kleisli_partial "$value")" law_kleisli_double
}

# A plain scalar function: NOT a Kleisli arrow (a -> M b)
law_scalar() {
  local value="$1"
  echo $((value * 2))
}

# A function returning a value of a different (unknown) monad type
law_wrong_monad() {
  echo "(unknown 1)"
}

# Asserts a law as semantic equality (via value_equal) between the two sides
# Usage: assert_law NAME EXPECTED ACTUAL
assert_law() {
  local name="$1"
  local expected="$2"
  local actual="$3"

  _value_equal "$expected" "$actual"
  run_test "$name" "0" "$?"
}

# ---------------------------------------------------------------------------
# Generic laws harness
# ---------------------------------------------------------------------------

# Runs all the laws for a registered type
# Usage: run_laws_for_type TYPE
run_laws_for_type() {
  LAWS_TYPE="$1"
  local type="$1"
  local empty_value
  empty_value=$(mzero "$type")

  start_test_section "Left identity for $type (uniform API)"

  echo -e "Law: ${BOLD}return a >>= f is the same as f a${RESET}"

  local value=5
  local left_side
  left_side=$(bind "$(unit "$type" "$value")" law_kleisli_inc)
  local right_side
  right_side=$(law_kleisli_inc $value)
  assert_law "$type: left identity" "$right_side" "$left_side"

  value=8
  left_side=$(bind "$(unit "$type" "$value")" law_kleisli_partial)
  right_side=$(law_kleisli_partial $value)
  assert_law "$type: left identity with partial function (success)" "$right_side" "$left_side"

  value=0
  left_side=$(bind "$(unit "$type" "$value")" law_kleisli_partial)
  right_side=$(law_kleisli_partial $value)
  assert_law "$type: left identity with partial function (failure)" "$right_side" "$left_side"

  start_test_section "Right identity for $type (uniform API)"

  echo -e "Law: ${BOLD}m >>= return is the same as m${RESET}"

  local monad_value
  monad_value=$(unit "$type" 10)
  left_side=$(bind "$monad_value" law_wrap)
  right_side="$monad_value"
  assert_law "$type: right identity with value" "$right_side" "$left_side"

  monad_value="$empty_value"
  left_side=$(bind "$monad_value" law_wrap)
  right_side="$monad_value"
  assert_law "$type: right identity with empty value" "$right_side" "$left_side"

  start_test_section "Associativity for $type (uniform API)"

  echo -e "Law: ${BOLD}(m >>= f) >>= g is the same as m >>= (\\x -> f x >>= g)${RESET}"

  monad_value=$(unit "$type" 5)
  left_side=$(bind "$(bind "$monad_value" law_kleisli_inc)" law_kleisli_double)
  right_side=$(bind "$monad_value" law_lambda_inc_then_double)
  assert_law "$type: associativity with value" "$right_side" "$left_side"

  monad_value="$empty_value"
  left_side=$(bind "$(bind "$monad_value" law_kleisli_inc)" law_kleisli_double)
  right_side=$(bind "$monad_value" law_lambda_inc_then_double)
  assert_law "$type: associativity with empty value" "$right_side" "$left_side"

  monad_value=$(unit "$type" 0)
  left_side=$(bind "$(bind "$monad_value" law_kleisli_partial)" law_kleisli_double)
  right_side=$(bind "$monad_value" law_lambda_partial_then_double)
  assert_law "$type: associativity with mid-chain failure" "$right_side" "$left_side"

  start_test_section "Functor laws for $type (uniform API)"

  echo -e "Law: ${BOLD}fmap id m is the same as m${RESET}"

  monad_value=$(unit "$type" 5)
  left_side=$(map "$monad_value" law_identity)
  right_side="$monad_value"
  assert_law "$type: functor identity with value" "$right_side" "$left_side"

  monad_value="$empty_value"
  left_side=$(map "$monad_value" law_identity)
  right_side="$monad_value"
  assert_law "$type: functor identity with empty value" "$right_side" "$left_side"

  echo -e "Law: ${BOLD}fmap (f . g) m is the same as fmap f (fmap g m)${RESET}"

  monad_value=$(unit "$type" 5)
  left_side=$(map "$monad_value" law_add_one_then_double)
  right_side=$(map "$(map "$monad_value" law_add_one)" law_double)
  assert_law "$type: functor composition with value" "$right_side" "$left_side"

  monad_value="$empty_value"
  left_side=$(map "$monad_value" law_add_one_then_double)
  right_side=$(map "$(map "$monad_value" law_add_one)" law_double)
  assert_law "$type: functor composition with empty value" "$right_side" "$left_side"

  start_test_section "Functor-monad consistency for $type (uniform API)"

  echo -e "Law: ${BOLD}fmap f m is the same as m >>= (return . f)${RESET}"

  monad_value=$(unit "$type" 5)
  left_side=$(map "$monad_value" law_add_one)
  right_side=$(bind "$monad_value" law_return_add_one)
  assert_law "$type: consistency fmap/bind with value" "$right_side" "$left_side"

  monad_value="$empty_value"
  left_side=$(map "$monad_value" law_add_one)
  right_side=$(bind "$monad_value" law_return_add_one)
  assert_law "$type: consistency fmap/bind with empty value" "$right_side" "$left_side"

  echo -e "Law: ${BOLD}m >>= f is the same as join (fmap f m)${RESET}"

  monad_value=$(unit "$type" 5)
  left_side=$(bind "$monad_value" law_kleisli_inc)
  right_side=$(join "$(map "$monad_value" law_kleisli_inc)")
  assert_law "$type: consistency bind/join with value" "$right_side" "$left_side"

  monad_value="$empty_value"
  left_side=$(bind "$monad_value" law_kleisli_inc)
  right_side=$(join "$(map "$monad_value" law_kleisli_inc)")
  assert_law "$type: consistency bind/join with empty value" "$right_side" "$left_side"

  start_test_section "MonadPlus laws for $type (uniform API)"

  echo -e "Law: ${BOLD}mzero ⊕ m is the same as m, and m ⊕ mzero is the same as m${RESET}"

  monad_value=$(unit "$type" 5)
  left_side=$(mplus "$empty_value" "$monad_value")
  right_side="$monad_value"
  assert_law "$type: MonadPlus left identity" "$right_side" "$left_side"

  left_side=$(mplus "$monad_value" "$empty_value")
  right_side="$monad_value"
  assert_law "$type: MonadPlus right identity" "$right_side" "$left_side"

  echo -e "Law: ${BOLD}(m ⊕ n) ⊕ p is the same as m ⊕ (n ⊕ p)${RESET}"

  local value_n
  value_n=$(unit "$type" 7)
  local value_p
  value_p=$(unit "$type" 9)

  left_side=$(mplus "$(mplus "$monad_value" "$value_n")" "$value_p")
  right_side=$(mplus "$monad_value" "$(mplus "$value_n" "$value_p")")
  assert_law "$type: MonadPlus associativity with values" "$right_side" "$left_side"

  left_side=$(mplus "$(mplus "$empty_value" "$value_n")" "$value_p")
  right_side=$(mplus "$empty_value" "$(mplus "$value_n" "$value_p")")
  assert_law "$type: MonadPlus associativity with empty value" "$right_side" "$left_side"

  echo -e "Law: ${BOLD}mzero >>= f is the same as mzero${RESET}"

  left_side=$(bind "$empty_value" law_kleisli_inc)
  right_side="$empty_value"
  assert_law "$type: MonadPlus left zero" "$right_side" "$left_side"

  # The fourth law depends on the MonadPlus flavour of the type
  if [ "$(_monadplus_flavor "$type")" = "distribution" ]; then
    echo -e "Law: ${BOLD}(m ⊕ n) >>= f is the same as (m >>= f) ⊕ (n >>= f)${RESET}"

    left_side=$(bind "$(mplus "$monad_value" "$value_n")" law_kleisli_inc)
    right_side=$(mplus "$(bind "$monad_value" law_kleisli_inc)" "$(bind "$value_n" law_kleisli_inc)")
    assert_law "$type: MonadPlus left distribution" "$right_side" "$left_side"
  else
    echo -e "Law: ${BOLD}return a ⊕ m is the same as return a${RESET}"

    left_side=$(mplus "$monad_value" "$value_n")
    right_side="$monad_value"
    assert_law "$type: MonadPlus left catch with value" "$right_side" "$left_side"

    left_side=$(mplus "$monad_value" "$empty_value")
    right_side="$monad_value"
    assert_law "$type: MonadPlus left catch with empty value" "$right_side" "$left_side"
  fi

  start_test_section "Strictness contract for $type (uniform API)"

  echo -e "Law: ${BOLD}join requires M (M a); it fails on M a${RESET}"

  monad_value=$(unit "$type" 5)
  join "$monad_value" >/dev/null 2>&1
  run_test "$type: join on a flat value fails" "$ERR_JOIN_FLAT" "$?"

  echo -e "Law: ${BOLD}bind requires f :: a -> M b; a scalar function fails${RESET}"

  bind "$monad_value" law_scalar >/dev/null 2>&1
  run_test "$type: bind with scalar function fails" "$ERR_JOIN_FLAT" "$?"

  echo -e "Law: ${BOLD}bind requires f to return the same monad type${RESET}"

  bind "$monad_value" law_wrong_monad >/dev/null 2>&1
  run_test "$type: bind with wrong monad type fails" "$ERR_JOIN_TAG" "$?"

  # The strict contract does not affect map with plain functions
  left_side=$(map "$monad_value" law_scalar)
  right_side=$(unit "$type" 10)
  run_test "$type: map with scalar function still works" "$right_side" "$left_side"
}

run_generic_laws_tests() {
  local file_name="$1"
  print_test_header "Testing monad laws through the uniform API" "$file_name"

  local type
  for type in "${MONAD_TYPES[@]}"; do
    run_laws_for_type "$type"
  done

  print_test_summary "Generic monad laws"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_generic_laws_tests "$0"
fi
