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
# Examples of using the Either monad through the uniform monad API
# (unit, bind, map, mzero, mplus, print_value work with any monad type)
# Unlike Maybe, Either carries information about the failure in its Left value.
#
# Each example prints the commands that produce the result (prefixed with $),
# followed by the output of each command.
#

# Source the uniform monad API (also sources the Either monad implementation)
# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/../src/monad.bash"

# Prints "$ <command>", executes it, stores the output in `result` and shows it
# Usage: run COMMAND [ARGS...]
run() {
  echo "\$ $*"
  result=$("$@")
  echo "$result"
}

# Safely divide two numbers, returns Left with an error message if division by zero
# Usage: safe_divide NUMERATOR DENOMINATOR
safe_divide() {
  local numerator="$1"
  local denominator="$2"

  if [ "$denominator" -eq 0 ]; then
    either_left "division by zero"
  else
    unit either $((numerator / denominator))
  fi
}

# Add a number to a value
# Usage: add_either VALUE NUMBER
add_either() {
  local value="$1"
  local addend="$2"

  unit either $((value + addend))
}

# Multiply a value by a number
# Usage: multiply_either VALUE NUMBER
multiply_either() {
  local value="$1"
  local multiplier="$2"

  unit either $((value * multiplier))
}

echo "Example 1: Wrapping a value with unit"
run unit either 10
run print_value "$result"

echo -e "\nExample 2: Safe division"
run safe_divide 10 2
run print_value "$result"

echo -e "\nExample 3: Safe division by zero (returns Left with an error message)"
run safe_divide 10 0
run print_value "$result"

echo -e "\nExample 4: Chaining operations with bind"
run unit either 10
run bind "$result" add_either 5
run bind "$result" multiply_either 2
run print_value "$result"

echo -e "\nExample 5: Chaining operations with a Left value (short-circuits)"
run safe_divide 10 0
run bind "$result" add_either 5
run bind "$result" multiply_either 2
run print_value "$result"

echo -e "\nExample 6: Mapping a plain function with map"
echo "# double() { echo \$((\$1 * 2)); }"
double() {
  local value="$1"
  echo $((value * 2))
}
run map "$(unit either 10)" double
run print_value "$result"

echo -e "\nExample 7: Fallback with mplus (the first Right wins)"
run safe_divide 10 0
run mplus "$result" "$(unit either 42)"
run print_value "$result"

echo -e "\nExample 8: Extracting the error message from a Left"
run safe_divide 10 0
if either_is_left "$result"; then
  run either_unwrap "$result"
  # either_unwrap returns the serialized (quoted) atom; decoding requires the internal helper
  run _atom_to_string "$result"
  echo "Error: $result"
fi
