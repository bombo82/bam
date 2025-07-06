#!/bin/bash

# Either monad-specific API for the Bash-Monad project
#
# Specific monad operations by type. These functions work only with a single
# registered monad type and require a type_specific prefix:
#
#   either_left VALUE      - wraps a value in a Left (failure)
#   either_right VALUE     - wraps a value in a Right (success)
#   either_is_left VALUE   - checks whether a value is a Left (returns 0/1)
#   either_is_right VALUE  - checks whether a value is a Right (returns 0/1)
#   either_unwrap VALUE    - extracts the payload of an Either value

# Implementation of an Either monad on the core value encoding
#
# Values: (either left V) represents a failure carrying information V
#         (either right V) represents a successful result V
# where V may be a raw string (automatically serialized by the constructors)
# or an already-serialized value (atom or compound for nesting).
# either_left/either_right accept raw strings or serialized values (similar
# to list_create); unit remains strict and requires pre-serialized input.
#
# This file contains the basic monad functions

# Wraps a value in a Left (failure with information). Accepts either a raw
# string (serialized automatically via atom_from_string if needed) or an
# already-serialized value (bare atom, quoted atom or compound).
# Usage: either_left VALUE
either_left() {
  local value="$1"

  if ! _is_value "$value"; then
    value=$(_atom_from_string "$value")
  fi

  echo "(either left $value)"
}

# Wraps a value in a Right (success). Accepts either a raw string
# (serialized automatically via atom_from_string if needed) or an
# already-serialized value (bare atom, quoted atom or compound).
# Usage: either_right VALUE
either_right() {
  local value="$1"

  if ! _is_value "$value"; then
    value=$(_atom_from_string "$value")
  fi

  echo "(either right $value)"
}

# Checks whether a value is a Left (returns exit status 0/1)
# Usage: either_is_left EITHER_VALUE
either_is_left() {
  local either_value="$1"

  _require_kind "$either_value" either || return $?
  _sexpr_load_parts "$either_value" || return $?

  [ "${PARTS[0]}" = "either" ] && [ "${PARTS[1]}" = "left" ]
}

# Checks whether a value is a Right (returns exit status 0/1)
# Usage: either_is_right EITHER_VALUE
either_is_right() {
  local either_value="$1"

  _require_kind "$either_value" either || return $?
  _sexpr_load_parts "$either_value" || return $?

  [ "${PARTS[0]}" = "either" ] && [ "${PARTS[1]}" = "right" ]
}

# Extracts the payload of an Either value (Left or Right)
# Usage: either_unwrap EITHER_VALUE
either_unwrap() {
  local either_value="$1"

  _require_kind "$either_value" either || return $?
  _sexpr_load_parts "$either_value" || return $?

  echo "${PARTS[2]}"
}

_either_unit() {
  local value="$1"

  either_right "$value"
}

_either_map() {
  local either_value="$1"
  local func="$2"
  shift 2

  if either_is_left "$either_value"; then
    echo "$either_value"
    return
  fi

  local payload result
  payload=$(either_unwrap "$either_value") || return $?
  result=$($func "$(_decode_value "$payload")" "$@")

  either_right "$result"
}

# Internal helper for join function (μ), the flattening operation of the monad
# Flattens a nested Either: Right (Right x) -> Right x, Right (Left e) -> Left e
# A Left is propagated unchanged.
# Strict contract: fails (non-zero status) if a Right payload is not an Either
_either_join() {
  local either_value="$1"

  if either_is_left "$either_value"; then
    echo "$either_value"
    return
  fi

  local inner
  inner=$(either_unwrap "$either_value") || return $?

  local inner_kind
  inner_kind=$(_value_kind "$inner")
  if [ "$inner_kind" = "either" ]; then
    echo "$inner"
  elif [ "$inner_kind" = "atom" ]; then
    echo "either_join: expected a nested Either value, got: $either_value" >&2
    return "$ERR_JOIN_FLAT"
  else
    echo "either_join: nested value has a different tag: $either_value" >&2
    return "$ERR_JOIN_TAG"
  fi
}

_either_mzero() {
  either_left ""
}

# Internal helper for mplus function (mplus of the MonadPlus structure)
# Left-biased choice: returns the first Right argument
_either_mplus() {
  local either_value1="$1"
  local either_value2="$2"

  if either_is_left "$either_value1"; then
    echo "$either_value2"
  else
    echo "$either_value1"
  fi
}

_either_print_value() {
  local value="$1"

  _sexpr_load_parts "$value" || return $?
  if [ "${PARTS[1]}" = "left" ]; then
    echo "Left $(print_value "${PARTS[2]}")"
  else
    echo "Right $(print_value "${PARTS[2]}")"
  fi
}
