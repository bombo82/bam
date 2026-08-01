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
# Core value encoding for the BAM! (Bourne Again Monad!) project
#
# Monadic values are serialized as s-expression-like strings:
#   (maybe nothing)  (maybe just V)
#   (list)           (list V1 V2 ... Vn)
#   (either left V)  (either right V)
# where V is itself any value (atom or monadic value), so values nest freely.
#
# Atoms are bare when they contain no whitespace, parentheses, double quotes
# or backslashes (e.g. 5, NOTHING, x|y); otherwise they are quoted with the
# escapes \\, \" and \n (e.g. "hello world", "" for the empty string).
#
# Serialized values never contain raw newlines, so accessors can safely emit
# one value per line. The unescape of atoms happens only when printing.
#
# This file uses only Bash builtins: no external dependencies.
#

# ---------------------------------------------------------------------------
# Error status codes (two digits: tens = category, units = specific error)
# Predicates (is_* functions) always use 0/1; statuses >= 10 are errors.
# The round numbers (10/20/30) are the category fallbacks.
# ---------------------------------------------------------------------------

# shellcheck disable=SC2034 # Public API registry: constants are used by the other modules
# Category 1X: parse/encoding errors
ERR_PARSE=10          # generic malformed value (category fallback)
ERR_PARSE_PARENS=11   # unbalanced parentheses
ERR_PARSE_QUOTE=12    # unterminated quote
ERR_PARSE_NOT_EXPR=13 # not a parenthesized expression

# Category 2X: monadic contract violations
ERR_CONTRACT=20  # generic contract violation (category fallback)
ERR_JOIN_FLAT=21 # join on a non-nested (flat) value — also reported
# when bind is used with a non-Kleisli (scalar) function
ERR_JOIN_TAG=22   # join on a value nested under a different tag
ERR_UNIT_INPUT=24 # unit with multi-token or malformed input
ERR_WRONG_TAG=25  # accessor used on a value of a different monad type

# Category 3X: dispatch/registration errors
ERR_DISPATCH=30         # generic dispatch error (category fallback)
ERR_UNKNOWN_TYPE=31     # unregistered type tag
ERR_TAG_MISMATCH=32     # mplus with mismatched type tags
ERR_UNKNOWN_FUNCTION=33 # function name not found (not declared)

# Serializes a plain string as an atom (bare or quoted, with escapes)
# Usage: _atom_from_string STRING
_atom_from_string() {
  local str="$1"

  if [ -n "$str" ] && [[ "$str" != *[[:space:]\(\)\"\\]* ]]; then
    echo "$str"
  else
    local escaped="${str//\\/\\\\}"
    escaped="${escaped//\"/\\\"}"
    escaped="${escaped//$'\n'/\\n}"
    echo "\"$escaped\""
  fi
}

# Converts a serialized atom back to the plain string it represents
# Usage: _atom_to_string ATOM
_atom_to_string() {
  local atom="$1"

  if [[ "$atom" != \"*\" ]]; then
    echo "$atom"
    return
  fi

  local inner="${atom:1:${#atom}-2}"
  local result=""
  local i ch next
  for ((i = 0; i < ${#inner}; i++)); do
    ch="${inner:i:1}"
    if [ "$ch" = "\\" ] && [ $((i + 1)) -lt ${#inner} ]; then
      next="${inner:i+1:1}"
      case "$next" in
      n)
        result+=$'\n'
        ;;
      \" | \\)
        result+="$next"
        ;;
      *)
        # Unknown escape: keep both characters literally
        result+="\\$next"
        ;;
      esac
      i=$((i + 1))
    else
      result+="$ch"
    fi
  done
  echo "$result"
}

# Checks whether a value contains an unterminated double-quoted string
# (odd count of unescaped double quotes). Used by the s-expression parser.
# Returns ERR_PARSE_QUOTE on error, 0 on success (no output).
# Usage: _sexpr_check_unterminated_quote VALUE
_sexpr_check_unterminated_quote() {
  local value="$1"
  local quote_count=0
  local i ch

  for ((i = 0; i < ${#value}; i++)); do
    ch="${value:i:1}"
    if [ "$ch" = "\\" ]; then
      i=$((i + 1)) # Skip the escaped character
    elif [ "$ch" = '"' ]; then
      quote_count=$((quote_count + 1))
    fi
  done
  if [ $((quote_count % 2)) -ne 0 ]; then
    return "$ERR_PARSE_QUOTE"
  fi
}

# Splits a parenthesized s-expression into its top-level parts (head included),
# one per line. Fails (empty output, non-zero status) on malformed input:
# unbalanced parentheses or unterminated quotes.
# Usage: _sexpr_parts VALUE
_sexpr_parts() {
  local value="$1"

  if [[ "$value" != \(* ]]; then
    return "$ERR_PARSE_NOT_EXPR"
  fi

  _sexpr_check_unterminated_quote "$value" || return $?

  if [[ "$value" != *\) ]]; then
    return "$ERR_PARSE_PARENS"
  fi

  local inner="${value:1:${#value}-2}"
  local depth=0
  local in_quote=false
  local escaped=false
  local current=""
  local i ch

  for ((i = 0; i < ${#inner}; i++)); do
    ch="${inner:i:1}"

    if $escaped; then
      current+="$ch"
      escaped=false
      continue
    fi

    if $in_quote; then
      if [ "$ch" = "\\" ]; then
        escaped=true
      elif [ "$ch" = '"' ]; then
        in_quote=false
      fi
      current+="$ch"
      continue
    fi

    case "$ch" in
    '"')
      in_quote=true
      current+="$ch"
      ;;
    '(')
      depth=$((depth + 1))
      current+="$ch"
      ;;
    ')')
      depth=$((depth - 1))
      if [ $depth -lt 0 ]; then
        return "$ERR_PARSE_PARENS"
      fi
      current+="$ch"
      ;;
    [[:space:]])
      if [ $depth -eq 0 ]; then
        if [ -n "$current" ]; then
          echo "$current"
          current=""
        fi
      else
        current+="$ch"
      fi
      ;;
    *)
      current+="$ch"
      ;;
    esac
  done

  if $in_quote; then
    return "$ERR_PARSE_QUOTE"
  fi
  if [ $depth -ne 0 ]; then
    return "$ERR_PARSE_PARENS"
  fi
  if [ -n "$current" ]; then
    echo "$current"
  fi
}

# Returns the head symbol of a parenthesized s-expression (maybe, list, either)
# Usage: _sexpr_head VALUE
_sexpr_head() {
  local value="$1"

  if [[ "$value" =~ ^\(([a-z]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    return "$ERR_PARSE_NOT_EXPR"
  fi
}

# Returns the children of a parenthesized s-expression (all parts after the
# head), one per line. Fails on malformed input, like sexpr_parts.
# Usage: _sexpr_children VALUE
_sexpr_children() {
  local value="$1"
  local out

  out=$(_sexpr_parts "$value") || return $?

  local parts=()
  if [ -n "$out" ]; then
    mapfile -t parts <<<"$out"
  fi

  if [ ${#parts[@]} -le 1 ]; then
    return 0 # no children
  fi

  local child
  for child in "${parts[@]:1}"; do
    echo "$child"
  done
}

# Loads the parts of a parenthesized s-expression into the global PARTS array.
# Returns the parser's error code on malformed input.
# Usage: _sexpr_load_parts VALUE
# Note: PARTS is deliberately global — Bash 4.0 has no namerefs to return
# arrays, and callers use the array immediately after the call.
_sexpr_load_parts() {
  local value="$1"
  local out

  PARTS=()
  out=$(_sexpr_parts "$value") || return $?
  if [ -n "$out" ]; then
    mapfile -t PARTS <<<"$out"
  fi
}

# Loads the children of a parenthesized s-expression into the global PARTS
# array. Returns the parser's error code on malformed input.
# Usage: _sexpr_load_children VALUE
# Note: see sexpr_load_parts for the global-array contract.
_sexpr_load_children() {
  local value="$1"
  local out

  PARTS=()
  out=$(_sexpr_children "$value") || return $?
  if [ -n "$out" ]; then
    mapfile -t PARTS <<<"$out"
  fi
}

# Normalizes a value to its canonical serialized form: atoms are bare whenever
# possible, parts are separated by single spaces, recursively. This is the form
# produced by the constructors. Fails with the parse error on malformed input.
# Usage: _value_normalize VALUE
_value_normalize() {
  local value="$1"
  local kind

  kind=$(_value_kind "$value") || return $?

  if [ "$kind" = "atom" ]; then
    _atom_from_string "$(_atom_to_string "$value")"
    return
  fi

  _sexpr_load_parts "$value" || return $?
  local result="(" first=true part normalized
  for part in "${PARTS[@]}"; do
    normalized=$(_value_normalize "$part") || return $?
    if $first; then
      result+="$normalized"
      first=false
    else
      result+=" $normalized"
    fi
  done
  result+=")"
  echo "$result"
}

# Semantic equality of two values, compared via their canonical forms:
# 0 if equal, 1 if different, a parse error code if either value is malformed
# Usage: _value_equal VALUE1 VALUE2
_value_equal() {
  local value1="$1"
  local value2="$2"
  local normalized1 normalized2

  normalized1=$(_value_normalize "$value1") || return $?
  normalized2=$(_value_normalize "$value2") || return $?

  [ "$normalized1" = "$normalized2" ]
}

# Returns the kind of a value: atom, or the head symbol of a compound value
# Usage: _value_kind VALUE
_value_kind() {
  local value="$1"

  if [[ "$value" == \(* ]]; then
    _sexpr_head "$value"
  else
    echo "atom"
  fi
}

# Checks whether a value is a well-formed compound value, i.e. a balanced
# parenthesized s-expression (returns exit status 0/1)
# Usage: _is_compound VALUE
_is_compound() {
  local value="$1"

  if [[ "$value" == \(* ]]; then
    _sexpr_parts "$value" >/dev/null 2>&1 && return 0
  fi
  return 1
}

# Checks whether a string is a single well-formed serialized value:
# a bare atom, a properly quoted atom, or a well-formed compound value
# (returns exit status 0/1)
# Usage: _is_value VALUE
_is_value() {
  local value="$1"

  if [[ "$value" == \(* ]]; then
    _is_compound "$value"
    return
  fi

  if [[ "$value" == \"* ]]; then
    # Quoted atom: the first unescaped " after the opening one must be
    # the very last character
    local i ch
    for ((i = 1; i < ${#value}; i++)); do
      ch="${value:i:1}"
      if [ "$ch" = "\\" ]; then
        i=$((i + 1)) # Skip the escaped character
      elif [ "$ch" = '"' ]; then
        [ $i -eq $((${#value} - 1)) ]
        return
      fi
    done
    return 1 # Unterminated quote
  fi

  # Bare atom: non-empty, no whitespace, parentheses, quotes or backslashes
  [ -n "$value" ] && [[ "$value" != *[[:space:]\(\)\"\\]* ]]
}

# Decodes a payload before passing it to a user function: atoms are
# unquoted/unescaped to their raw string, compound values pass through
# unchanged (serialized)
# Usage: _decode_value VALUE
_decode_value() {
  local value="$1"

  if [ "$(_value_kind "$value")" = "atom" ]; then
    _atom_to_string "$value"
  elif _is_compound "$value"; then
    echo "$value"
  else
    # Starts with ( but is not well-formed: report the parse error
    _sexpr_parts "$value" >/dev/null 2>&1 || return $?
  fi
}

# Validates that a value has the expected monad type tag.
# Returns 0 on match, ERR_WRONG_TAG on a different tag, or the parse error
# on malformed input.
# Usage: _require_kind VALUE EXPECTED_TAG
_require_kind() {
  local value="$1"
  local expected_tag="$2"
  local kind

  # A compound-looking value must be well-formed before its tag is read
  if [[ "$value" == \(* ]] && ! _is_compound "$value"; then
    _sexpr_parts "$value" >/dev/null 2>&1 || return $?
  fi

  kind=$(_value_kind "$value") || return $?
  if [ "$kind" != "$expected_tag" ]; then
    echo "require_kind: expected a $expected_tag value, got: $value" >&2
    return "$ERR_WRONG_TAG"
  fi
}

# Validates that a function name refers to a declared function.
# Returns 0 if declared, ERR_UNKNOWN_FUNCTION otherwise.
# Usage: _require_function FUNCTION_NAME
_require_function() {
  local func="$1"

  if ! declare -F "$func" >/dev/null; then
    echo "require_function: function not declared: $func" >&2
    return "$ERR_UNKNOWN_FUNCTION"
  fi
}

# Prints a value in a human-readable, injective form, recursively:
#   Nothing, Just 5, [1, 2], Left "err", Right 42
# Atoms that need quoting are shown in their serialized (quoted) form, so
# different values never print identically.
# Usage: print_value VALUE
print_value() {
  local value="$1"
  local kind
  kind=$(_value_kind "$value") || return $?

  case "$kind" in
  atom)
    local raw canonical
    raw=$(_atom_to_string "$value")
    canonical=$(_atom_from_string "$raw")
    if [ "$canonical" = "$raw" ]; then
      echo "$raw"
    else
      echo "$canonical"
    fi
    ;;
  *)
    if ! _is_monad_type "$kind"; then
      return "$ERR_UNKNOWN_TYPE"
    fi

    "_${kind}_print_value" "$value"
    ;;
  esac
}
