#!/bin/bash

# List monad-specific API for the Bash-Monad project
#
# Specific monad operations by type. These functions work only with a single
# registered monad type and require a type_specific prefix:
#
#   list_create VALUE1 VALUE2 ... VALUEN - create a list from multiple values
#   list_filter  - filters the elements of a list based on a predicate function

# Implementation of a List monad on the core value encoding
#
# Values: (list) for the empty list, (list V1 V2 ... Vn) otherwise, where
# each Vi is any serialized value (atom or monadic value), so lists can
# contain other monadic values (nesting).
#
# This file contains the basic list monad functions

# Constant for the empty list
EMPTY_LIST="(list)"

# Creates a list from multiple values
# Each argument is embedded as-is if it is a well-formed compound value
# (e.g. a nested monadic value), otherwise it is serialized as an atom
# Usage: list_create VALUE1 VALUE2 ... VALUEN
list_create() {
  if [ $# -eq 0 ]; then
    echo "$EMPTY_LIST"
    return
  fi

  local result="(list"
  local item
  for item in "$@"; do
    if _is_compound "$item"; then
      result+=" $item"
    else
      result+=" $(_atom_from_string "$item")"
    fi
  done
  result+=")"
  echo "$result"
}

# Filters the elements of a list based on a predicate function
# Usage: list_filter LIST PREDICATE_FUNCTION [ARGS...]
list_filter() {
  local list="$1"
  local predicate="$2"
  shift 2

  _require_kind "$list" list || return $?
  _require_function "$predicate" || return $?

  _sexpr_load_children "$list" || return $?

  local result="(list"
  local child pred_status
  for child in "${PARTS[@]}"; do
    $predicate "$child" "$@"
    pred_status=$?
    # Convention: 0 = true, 1 = false, >= 10 = error (propagated)
    if [ "$pred_status" -ge 10 ]; then
      return "$pred_status"
    elif [ "$pred_status" -eq 0 ]; then
      result+=" $child"
    fi
  done
  result+=")"
  echo "$result"
}

_list_unit() {
  local value="$1"

  echo "(list $value)"
}

_list_map() {
  local list="$1"
  local func="$2"
  shift 2

  _sexpr_load_children "$list" || return $?

  local result="(list"
  local child func_result
  for child in "${PARTS[@]}"; do
    func_result=$($func "$(_decode_value "$child")" "$@")
    if _is_compound "$func_result"; then
      result+=" $func_result"
    else
      result+=" $(_atom_from_string "$func_result")"
    fi
  done
  result+=")"
  echo "$result"
}

# Internal helper for join function (μ), the flattening operation of the monad
# Concatenates the elements of a list of lists
# Strict contract: fails (non-zero status) if any element is not a list
_list_join() {
  local list="$1"

  _sexpr_load_children "$list" || return $?

  local result="(list"
  local child sub child_kind
  local outer_parts=("${PARTS[@]}")
  for child in "${outer_parts[@]}"; do
    child_kind=$(_value_kind "$child")
    if [ "$child_kind" = "list" ]; then
      _sexpr_load_children "$child" || return $?
      for sub in "${PARTS[@]}"; do
        result+=" $sub"
      done
    elif [ "$child_kind" = "atom" ]; then
      echo "list_join: expected a list of lists, got element: $child" >&2
      return "$ERR_JOIN_FLAT"
    else
      echo "list_join: nested element has a different tag: $child" >&2
      return "$ERR_JOIN_TAG"
    fi
  done
  result+=")"
  echo "$result"
}

_list_mzero() {
  echo "$EMPTY_LIST"
}

# Internal helper for mplus function (mplus of the MonadPlus structure)
# Concatenates two lists
_list_mplus() {
  local list1="$1"
  local list2="$2"

  local result="(list"
  local list child
  for list in "$list1" "$list2"; do
    _sexpr_load_children "$list" || return $?
    for child in "${PARTS[@]}"; do
      result+=" $child"
    done
  done
  result+=")"
  echo "$result"
}

_list_print_value() {
  local value="$1"

  _sexpr_load_children "$value" || return $?
  local result="["
  local first=true
  local child
  for child in "${PARTS[@]}"; do
    if $first; then
      result+="$(print_value "$child")"
      first=false
    else
      result+=", $(print_value "$child")"
    fi
  done
  result+="]"
  echo "$result"
}
