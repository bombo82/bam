#!/bin/bash

# Examples of using the Maybe monad through the uniform monad API
# (unit, bind, map, mzero, mplus, print_value work with any monad type)
#
# Each example prints the commands that produce the result (prefixed with $),
# followed by the output of each command.

# Source the uniform monad API (also sources the Maybe monad implementation)
# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/../src/monad.bash"

# Prints "$ <command>", executes it, stores the output in `result` and shows it
# Usage: run COMMAND [ARGS...]
run() {
  echo "\$ $*"
  result=$("$@")
  echo "$result"
}

# Example functions that work with the Maybe monad

# Safely divide two numbers, returns Nothing if division by zero
# Usage: safe_divide NUMERATOR DENOMINATOR
safe_divide() {
  local numerator="$1"
  local denominator="$2"

  if [ "$denominator" -eq 0 ]; then
    mzero maybe # Return Nothing
  else
    local result
    result=$(echo "scale=2; $numerator / $denominator" | bc)
    unit maybe "$result"
  fi
}

# Safely add a number to a value
# Usage: add_maybe VALUE NUMBER
add_maybe() {
  local first_addend="$1"
  local second_addend="$2"

  local result
  result=$(echo "$first_addend + $second_addend" | bc)
  unit maybe "$result"
}

# Safely multiply a value by a number
# Usage: multiply_maybe VALUE NUMBER
multiply_maybe() {
  local multiplicand="$1"
  local multiplier="$2"

  local result
  result=$(echo "$multiplicand * $multiplier" | bc)
  unit maybe "$result"
}

# Example usage

echo "Example 1: Wrapping a value with unit"
run unit maybe 10
run print_value "$result"

echo -e "\nExample 2: The empty value (mzero)"
run mzero maybe
run print_value "$result"

echo -e "\nExample 3: Safe division"
run safe_divide 10 2
run print_value "$result"

echo -e "\nExample 4: Safe division by zero (returns Nothing)"
run safe_divide 10 0
run print_value "$result"

echo -e "\nExample 5: Chaining operations with bind"
# Start with 10, add 5, then multiply by 2
run unit maybe 10
run bind "$result" add_maybe 5
run bind "$result" multiply_maybe 2
run print_value "$result"

echo -e "\nExample 6: Chaining operations with a Nothing value (short-circuits)"
run mzero maybe
run bind "$result" add_maybe 5
run bind "$result" multiply_maybe 2
run print_value "$result"

echo -e "\nExample 7: Complex chain with potential failure"
# Start with 10, divide by 2, add 5, divide by 0 (fails), multiply by 3
run unit maybe 10
run bind "$result" safe_divide 2
run bind "$result" add_maybe 5
run bind "$result" safe_divide 0
run bind "$result" multiply_maybe 3
run print_value "$result"

echo -e "\nExample 8: Mapping a plain function with map"
echo "# double() { echo \$((\$1 * 2)); }"
double() {
  local value="$1"
  echo $((value * 2))
}
run map "$(unit maybe 10)" double
run print_value "$result"

echo -e "\nExample 9: Fallback with mplus (the first present value wins)"
run safe_divide 10 0
run mplus "$result" "$(unit maybe 42)"
run print_value "$result"
