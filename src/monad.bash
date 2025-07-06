#!/bin/bash

# Uniform monad API for the Bash-Monad project
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

# Source the core value encoding (provides _value_kind, print_value, ERR_* codes, etc.)
# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/value.bash"
# Source the registered monad types
# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/either.bash"
# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/list.bash"
# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/maybe.bash"

# The registered monad types, space-separated
MONAD_TYPES="either list maybe"

# The MonadPlus flavour of each registered type, as tag:flavour entries:
# "distribution" for choice monads (List satisfies left distribution),
# "catch" for failure monads (Maybe and Either satisfy left catch instead)
MONADPLUS_FLAVORS="either:catch list:distribution maybe:catch"

_is_monad_type() {
  local type="$1"
  case " $MONAD_TYPES " in
  *" $type "*) return 0 ;;
  *) return 1 ;;
  esac
}

_require_monad_type() {
  local value="$1"

  local tag
  tag=$(_value_kind "$value") || return $?
  if ! _is_monad_type "$tag"; then
    echo "require_monad_type: expected a monad type value, got: $value" >&2
    return "$ERR_UNKNOWN_TYPE"
  fi
}

_monadplus_flavor() {
  local type="$1"
  local entry

  for entry in $MONADPLUS_FLAVORS; do
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
