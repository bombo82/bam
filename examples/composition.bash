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
# Examples of composition and nesting with the uniform monad API
#
# Composition: chaining Kleisli functions (a -> M b) into pipelines, and the
# List monad as a comprehension (cartesian product via nested binds).
# Nesting: monadic values containing other monadic values, of the same type
# (Maybe (Maybe a), List (List a)) and of different types (List (Maybe a),
# Maybe (List a), Either e (List a)).
#
# Each example prints the commands that produce the result (prefixed with $),
# followed by the output of each command.
#

# shellcheck disable=SC2329 # Helper functions are invoked by name through bind/map
# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/../src/monad.bash"

# Prints "$ <command>", executes it, stores the output in `result` and shows it
# Usage: run COMMAND [ARGS...]
run() {
  echo "\$ $*"
  result=$("$@")
  echo "$result"
}

echo "=== COMPOSITION ==="

echo -e "\nExample 1: A validation pipeline (Maybe)"
# Each stage takes a plain value and returns a Maybe value (Kleisli arrow)

# Accepts only positive numbers
require_positive() {
  local value="$1"
  if [ "$value" -gt 0 ]; then
    unit maybe "$value"
  else
    mzero maybe
  fi
}

# Accepts only even numbers
require_even() {
  local value="$1"
  if [ $((value % 2)) -eq 0 ]; then
    unit maybe "$value"
  else
    mzero maybe
  fi
}

halve() {
  local value="$1"
  unit maybe $((value / 2))
}

echo "# require_positive, require_even, halve: Kleisli functions a -> Maybe a"

# A valid input flows through the whole pipeline
run unit maybe 12
run bind "$result" require_positive
run bind "$result" require_even
run bind "$result" halve
run print_value "$result"

echo "-- an invalid input is rejected by require_even and skips the rest --"
run unit maybe 7
run bind "$result" require_positive
run bind "$result" require_even
run bind "$result" halve
run print_value "$result"

echo -e "\nExample 2: The List monad as a comprehension (cartesian product)"
# Binding a function that itself binds produces all combinations,
# just like a list comprehension or a nested for loop

run list_create 1 2
numbers="$result"
run list_create a b
letters="$result"

pair_with() {
  local x="$1"
  make_pair() {
    local y="$1"
    # Like `return (x, y)` in Haskell: the pair is wrapped with unit, so that
    # join flattens only the monadic layer and preserves the pair itself
    unit list "$(list_create "$x" "$y")"
  }
  bind "$letters" make_pair
}

echo "# pair_with x = bind \$letters (\\y -> unit list (list_create \$x \$y))"
run bind "$numbers" pair_with
run print_value "$result"

echo -e "\nExample 3: bind is join . map"
increment_maybe() {
  local value="$1"
  unit maybe $((value + 1))
}
echo "# increment_maybe() { unit maybe \$((\$1 + 1)); }"

run unit maybe 10
m="$result"
run bind "$m" increment_maybe
via_bind="$result"
run map "$m" increment_maybe
run join "$result"
via_join="$result"
echo "bind:       $(print_value "$via_bind")"
echo "join . map: $(print_value "$via_join")"

echo -e "\n=== NESTING (same type) ==="

echo -e "\nExample 4: Just Nothing is distinct from Nothing"
# In the structured encoding, a nested Maybe is a real, distinct value
run mzero maybe
nothing_value="$result"
just_nothing="(maybe just $nothing_value)"
echo "\$ just_nothing=\"(maybe just $nothing_value)\""
echo "\$ print_value \"\$just_nothing\""
print_value "$just_nothing"
echo "\$ print_value \"\$nothing_value\""
print_value "$nothing_value"
run join "$just_nothing"
run print_value "$result"

echo -e "\nExample 5: A list of lists, flattened with join"
nested_list="(list (list 1 2) (list 3) (list))"
echo "\$ print_value \"$nested_list\""
print_value "$nested_list"
run join "$nested_list"
run print_value "$result"

echo -e "\n=== NESTING (different types) ==="

echo -e "\nExample 6: A list of Maybes (List (Maybe Int))"
# Each element carries its own type tag, so bind can apply a function
# that itself operates on the inner Maybe
list_of_maybes="(list $(unit maybe 1) $(mzero maybe) $(unit maybe 3))"
echo "\$ list_of_maybes=\"$list_of_maybes\""
echo "\$ print_value \"\$list_of_maybes\""
print_value "$list_of_maybes"

square() {
  local value="$1"
  echo $((value * value))
}
map_inner_maybe() {
  local inner="$1"
  map "$inner" square
}

echo "# map_inner_maybe() { map \"\$1\" square; }"
echo "-- map, not bind: the function returns Maybe values, which become elements --"
run map "$list_of_maybes" map_inner_maybe
run print_value "$result"

echo -e "\nExample 7: A Maybe of a List (Maybe (List Int))"
run list_create 1 2 3
run unit maybe "$result"
maybe_of_list="$result"
echo "\$ print_value \"\$maybe_of_list\""
print_value "$maybe_of_list"

double() {
  local value="$1"
  echo $((value * 2))
}
double_inner_list() {
  local inner="$1"
  map "$inner" double
}

echo "# double_inner_list() { map \"\$1\" double; }"
echo "-- map, not bind: the function returns the mapped inner list, not a Maybe --"
run map "$maybe_of_list" double_inner_list
run print_value "$result"

echo -e "\nExample 8: An Either carrying a List (Either String (List Int))"
# A computation that succeeds with a collection, or fails with a message
fetch_divisors() {
  local value="$1"
  if [ "$value" -le 0 ]; then
    either_left "expected a positive number"
  else
    local divisors=()
    for ((i = 1; i <= value; i++)); do
      if ((value % i == 0)); then
        divisors+=("$i")
      fi
    done
    unit either "$(list_create "${divisors[@]}")"
  fi
}

echo "# fetch_divisors: returns Right (list of divisors) or Left (message)"
run fetch_divisors 6
run print_value "$result"
run fetch_divisors -3
run print_value "$result"

echo "-- the list inside a Right can be transformed by mapping the inner list --"
run fetch_divisors 6
run map "$result" double_inner_list
run print_value "$result"
