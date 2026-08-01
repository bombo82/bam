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
# Examples of using the List monad through the uniform monad API
# (unit, bind, map, join, mzero, mplus, print_value work with any monad type)
#
# Each example prints the commands that produce the result (prefixed with $),
# followed by the output of each command.
#

# Source the uniform monad API (also sources the List monad implementation)
# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/../src/monad.bash"

# Prints "$ <command>", executes it, stores the output in `result` and shows it
# Usage: run COMMAND [ARGS...]
run() {
  echo "\$ $*"
  result=$("$@")
  echo "$result"
}

# Square a number
# Usage: square VALUE
square() {
  local value="$1"
  echo $((value * value))
}

# Get the divisors of a number (mzero if none)
# Usage: get_divisors VALUE
get_divisors() {
  local value="$1"
  local divisors=()

  for ((i = 1; i <= value; i++)); do
    if ((value % i == 0)); then
      divisors+=("$i")
    fi
  done

  if [ ${#divisors[@]} -eq 0 ]; then
    mzero list
  else
    list_create "${divisors[@]}"
  fi
}

# Check if a number is even
# Predicate convention: 0 = true, 1 = false, >= 10 = error (propagated by list_filter)
# Usage: is_even VALUE
is_even() {
  local value="$1"
  if [[ ! "$value" =~ ^-?[0-9]+$ ]]; then
    echo "is_even: expected a numeric value, got: $value" >&2
    return "$ERR_CONTRACT"
  fi
  return $((value % 2))
}

# Check if a number is odd
# Usage: is_odd VALUE
is_odd() {
  local value="$1"
  if [[ ! "$value" =~ ^-?[0-9]+$ ]]; then
    echo "is_odd: expected a numeric value, got: $value" >&2
    return "$ERR_CONTRACT"
  fi
  return $(((value + 1) % 2))
}

echo "Example 1: Wrapping a value with unit"
run unit list 10
run print_value "$result"

echo -e "\nExample 2: Creating a list"
run list_create 1 2 3 4 5
run print_value "$result"

echo -e "\nExample 3: Mapping a function over a list"
run list_create 1 2 3 4 5
run map "$result" square
run print_value "$result"

echo -e "\nExample 4: Filtering a list"
run list_create 1 2 3 4 5 6 7 8 9 10
run list_filter "$result" is_even
run print_value "$result"

echo -e "\nExample 5: Concatenating lists with mplus"
run list_create 1 2 3
list1="$result"
run list_create 4 5 6
list2="$result"
run mplus "$list1" "$list2"
run print_value "$result"

echo -e "\nExample 6: Binding a function that returns a list"
run list_create 6 12 18
run bind "$result" get_divisors
run print_value "$result"

echo -e "\nExample 7: Chaining map and filter"
run list_create 1 2 3 4 5
run map "$result" square
run list_filter "$result" is_even
run print_value "$result"

echo -e "\nExample 8: Complex chain of operations"
run list_create 1 2 3 4 5 6 7 8 9 10
run list_filter "$result" is_odd
run bind "$result" get_divisors
run list_filter "$result" is_even
run print_value "$result"

echo -e "\nExample 9: Flattening a list of lists with join"
run join "(list (list 1 2) (list 3) (list 4 5 6))"
run print_value "$result"
