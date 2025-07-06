#!/bin/bash

# Maybe monad-specific API for the Bash-Monad project
#
# Specific monad operations by type. These functions work only with a single
# registered monad type and require a type_specific prefix:
#
#   maybe_just VALUE       - wraps a value in a Just
#   maybe_unwrap VALUE     - extracts the payload of a Just value
#   maybe_is_nothing VALUE - checks whether a value is Nothing (returns 0/1)
#   maybe_is_just VALUE    - checks whether a value is a Just (returns 0/1)

# Implementation of a Maybe monad on the core value encoding
#
# Values: (maybe nothing) represents the absence of a value;
#         (maybe just V) represents a present value V, where V may be a raw
#         string (automatically serialized by maybe_just) or an already-serialized
#         value (atom or compound for nesting). maybe_just accepts raw strings
#         or serialized values (similar to list_create/either_left); unit remains
#         strict and requires pre-serialized input.
#
# This file contains the basic monad functions

# Constant for the absence of a value (Nothing in Haskell)
NOTHING="(maybe nothing)"

# Wraps a value in a Just. Accepts either a raw string (serialized automatically
# via atom_from_string if needed) or an already-serialized value (bare atom,
# quoted atom or compound).
# Usage: maybe_just VALUE
maybe_just() {
  local value="$1"

  if ! _is_value "$value"; then
    value=$(_atom_from_string "$value")
  fi

  echo "(maybe just $value)"
}

# Checks whether a value is Nothing (returns exit status 0/1)
# Usage: maybe_is_nothing MAYBE_VALUE
maybe_is_nothing() {
  local maybe_value="$1"

  _require_kind "$maybe_value" maybe || return $?

  [ "$maybe_value" = "$NOTHING" ]
}

# Checks whether a value is a Just (returns exit status 0/1)
# Usage: maybe_is_just MAYBE_VALUE
maybe_is_just() {
  local maybe_value="$1"

  _require_kind "$maybe_value" maybe || return $?
  _sexpr_load_parts "$maybe_value" || return $?

  [ "${PARTS[1]}" = "just" ]
}

# Extracts the payload of a Just value
# Usage: maybe_unwrap MAYBE_VALUE
maybe_unwrap() {
  local maybe_value="$1"

  _require_kind "$maybe_value" maybe || return $?
  _sexpr_load_parts "$maybe_value" || return $?

  echo "${PARTS[2]}"
}

_maybe_unit() {
  local value="$1"

  echo "(maybe just $value)"
}

_maybe_map() {
  local maybe_value="$1"
  local func="$2"
  shift 2

  if maybe_is_nothing "$maybe_value"; then
    echo "$NOTHING"
    return
  fi

  local payload result
  payload=$(maybe_unwrap "$maybe_value") || return $?
  result=$($func "$(_decode_value "$payload")" "$@")

  maybe_just "$result"
}

# Internal helper for join function (μ), the flattening operation of the monad
# Flattens a nested Maybe: Just (Just x) -> Just x, Just Nothing -> Nothing
# Strict contract: fails (non-zero status) if the payload is not a Maybe value
_maybe_join() {
  local maybe_value="$1"

  if maybe_is_nothing "$maybe_value"; then
    echo "$NOTHING"
    return
  fi

  local inner
  inner=$(maybe_unwrap "$maybe_value") || return $?

  local inner_kind
  inner_kind=$(_value_kind "$inner")
  if [ "$inner_kind" = "maybe" ]; then
    echo "$inner"
  elif [ "$inner_kind" = "atom" ]; then
    echo "maybe_join: expected a nested Maybe value, got: $maybe_value" >&2
    return "$ERR_JOIN_FLAT"
  else
    echo "maybe_join: nested value has a different tag: $maybe_value" >&2
    return "$ERR_JOIN_TAG"
  fi
}

_maybe_mzero() {
  echo "$NOTHING"
}

# Internal helper for mplus function (mplus of the MonadPlus structure)
# Left-biased choice: returns the first argument that is not Nothing
_maybe_mplus() {
  local maybe_value1="$1"
  local maybe_value2="$2"

  if maybe_is_nothing "$maybe_value1"; then
    echo "$maybe_value2"
  else
    echo "$maybe_value1"
  fi
}

_maybe_print_value() {
  local value="$1"

  _sexpr_load_parts "$value" || return $?
  if [ "${PARTS[1]}" = "just" ]; then
    echo "Just $(print_value "${PARTS[2]}")"
  else
    echo "Nothing"
  fi
}
