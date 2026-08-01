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
# Uniform monad API for the BAM! (Bourne Again Monad!) project
#
# Generic monad operations that dispatch on the type tag embedded in each
# value (see core/value.bash for the encoding). These functions work with any
# registered monad type, with no type-specific prefixes:
#
#   unit TYPE VALUE      - wraps a value in the monad of the given type
#   map VALUE F [ARGS]   - applies a plain function to the value(s) inside
#   join VALUE           - flattens a nested monadic value
#   bind VALUE F [ARGS]  - chains an operation on a monadic value
#   mzero TYPE           - the empty element of a MonadPlus type
#   mplus VALUE1 VALUE2  - combines two values of the same MonadPlus type
#   print_value VALUE    - human-readable printing (defined in value.bash)
#

# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/value.bash"
# Source the registered monad types
MONAD_TYPES=(either list maybe)
for tag in "${MONAD_TYPES[@]}"; do
  # shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
  source "$(dirname "${BASH_SOURCE[0]}")/${tag}.bash"
done

# The MonadPlus flavour of each registered type, as tag:flavour entries:
# "distribution" for choice monads (List satisfies left distribution),
# "catch" for failure monads (Maybe and Either satisfy left catch instead)
MONADPLUS_FLAVORS=(either:catch list:distribution maybe:catch)

_is_monad_type() {
  local type="$1"

  local t
  for t in "${MONAD_TYPES[@]}"; do
    if [ "$t" = "$type" ]; then
      return 0
    fi
  done
  return 1
}

_require_monad_type() {
  local value="$1"

  local tag
  tag=$(_value_kind "$value") || return $?
  if ! _is_monad_type "$tag"; then
    echo "require_monad_type: expected a monad type value, got: $value" >&2
    return "$ERR_UNKNOWN_TYPE"
  fi
  return 0
}

_monadplus_flavor() {
  local type="$1"

  local entry
  for entry in "${MONADPLUS_FLAVORS[@]}"; do
    if [ "${entry%%:*}" = "$type" ]; then
      echo "${entry##*:}"
      return 0
    fi
  done
  return "$ERR_UNKNOWN_TYPE"
}

# Unit function (return in Haskell; named unit because return is a Bash keyword)
# Wraps a value in the monad of the given type
# Usage: unit TYPE VALUE
unit() {
  local type="$1"
  local value="$2"

  if ! _is_monad_type "$type"; then
    return "$ERR_UNKNOWN_TYPE"
  fi
  if ! _is_value "$value"; then
    echo "unit: expected a single serialized value, got: $value" >&2
    return "$ERR_UNIT_INPUT"
  fi

  "_${type}_unit" "$value"
}

# Map function (fmap in Haskell)
# Applies a plain function to the value(s) inside a monadic value.
# Its result is embedded as-is only if it is a well-formed compound value
# (e.g. a monadic value returned by a Kleisli function used through bind); any
# other result is serialized as an atom — including the empty string, which
# becomes the empty atom "".
# Usage: map MONAD_VALUE FUNCTION [ARGS...]
map() {
  local value="$1"
  local func="$2"
  shift 2

  _require_monad_type "$value" || return $?
  _require_function "$func" || return $?

  local tag
  tag=$(_value_kind "$value")
  "_${tag}_map" "$value" "$func" "$@"
}

# Join function (μ)
# Flattens a nested monadic value of any registered type
# Usage: join MONAD_VALUE
join() {
  local value="$1"

  _require_monad_type "$value" || return $?

  local tag
  tag=$(_value_kind "$value")
  "_${tag}_join" "$value"
}

# Bind function (>>= in Haskell)
# Chains operations on monadic values of any registered type
# Usage: bind MONAD_VALUE FUNCTION [ARGS...]
bind() {
  local value="$1"
  local func="$2"
  shift 2

  _require_monad_type "$value" || return $?
  _require_function "$func" || return $?

  local tag
  tag=$(_value_kind "$value")
  local mapped
  mapped=$("_${tag}_map" "$value" "$func" "$@") || return $?
  "_${tag}_join" "$mapped"
}

# Mzero: the empty element of a MonadPlus type
# Usage: mzero TYPE
mzero() {
  local type="$1"

  if ! _is_monad_type "$type"; then
    return "$ERR_UNKNOWN_TYPE"
  fi

  "_${type}_mzero"
}

# Mplus: combines two monadic values of the same MonadPlus type
# Fails if the two values have different type tags
# Usage: mplus MONAD_VALUE1 MONAD_VALUE2
mplus() {
  local value1="$1"
  local value2="$2"

  _require_monad_type "$value1" || return $?
  _require_monad_type "$value2" || return $?

  local tag1 tag2
  tag1=$(_value_kind "$value1")
  tag2=$(_value_kind "$value2")
  if [ "$tag1" != "$tag2" ]; then
    return "$ERR_TAG_MISMATCH"
  fi

  "_${tag1}_mplus" "$value1" "$value2"
}
