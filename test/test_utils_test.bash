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

# Tests for the shared test utilities in test_utils.bash

# shellcheck disable=SC2001 # ANSI stripping needs a regex character class; ${var//} cannot express it
# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/test_utils.bash"

# This suite keeps its own counters, independent of the harness counters it
# resets while testing them
UTILS_TEST_PASSED=0
UTILS_TEST_FAILED=0

test_run_test() {
  start_test_section "Run test function"

  # Start from known counter values
  TEST_COUNT=0
  PASSED_COUNT=0
  FAILED_COUNT=0

  # Capture output in a temp file to inspect what run_test prints
  local temp_file
  temp_file=$(mktemp)
  run_test "Sample passing test" "expected" "expected" >"$temp_file" 2>&1
  local output
  output=$(<"$temp_file")
  rm "$temp_file"

  if [[ "$output" == *"PASSED"* ]]; then
    print_passed_test_result "run_test correctly identifies passing tests"
    UTILS_TEST_PASSED=$((UTILS_TEST_PASSED + 1))
  else
    print_failed_test_result "run_test correctly identifies passing tests" "output to contain 'PASSED'" "$output"
    UTILS_TEST_FAILED=$((UTILS_TEST_FAILED + 1))
  fi

  local temp_file
  temp_file=$(mktemp)
  run_test "Sample failing test" "expected" "actual" >"$temp_file" 2>&1
  local output
  output=$(<"$temp_file")
  rm "$temp_file"

  if [[ "$output" == *"FAILED"* && "$output" == *"Expected:"* && "$output" == *"Actual:"* ]]; then
    print_passed_test_result "run_test correctly identifies failing tests"
    UTILS_TEST_PASSED=$((UTILS_TEST_PASSED + 1))
  else
    print_failed_test_result "run_test correctly identifies failing tests" "output to contain 'FAILED'" "$output"
    UTILS_TEST_FAILED=$((UTILS_TEST_FAILED + 1))
  fi

  # Check if TEST_COUNT is incremented correctly
  if [ "$TEST_COUNT" -eq 2 ]; then
    print_passed_test_result "run_test correctly increments TEST_COUNT"
    UTILS_TEST_PASSED=$((UTILS_TEST_PASSED + 1))
  else
    print_failed_test_result "run_test correctly increments TEST_COUNT" "TEST_COUNT to be 2" "$TEST_COUNT"
    UTILS_TEST_FAILED=$((UTILS_TEST_FAILED + 1))
  fi

  if [ "$PASSED_COUNT" -eq 1 ]; then
    print_passed_test_result "run_test correctly increments PASSED_COUNT"
    UTILS_TEST_PASSED=$((UTILS_TEST_PASSED + 1))
  else
    print_failed_test_result "run_test correctly increments PASSED_COUNT" "PASSED_COUNT to be 1" "$PASSED_COUNT"
    UTILS_TEST_FAILED=$((UTILS_TEST_FAILED + 1))
  fi

  if [ "$FAILED_COUNT" -eq 1 ]; then
    print_passed_test_result "run_test correctly increments FAILED_COUNT"
    UTILS_TEST_PASSED=$((UTILS_TEST_PASSED + 1))
  else
    print_failed_test_result "run_test correctly increments FAILED_COUNT" "FAILED_COUNT to be 1" "$FAILED_COUNT"
    UTILS_TEST_FAILED=$((UTILS_TEST_FAILED + 1))
  fi
}

test_print_separator() {
  start_test_section "Print separator function"

  # Strip ANSI codes before comparing
  local output
  output=$(print_separator | sed 's/\x1b\[[0-9;]*m//g')
  local expected="----------------------------------------"

  if [ "$output" = "$expected" ]; then
    echo "✓ print_separator outputs correct separator - PASSED"
    UTILS_TEST_PASSED=$((UTILS_TEST_PASSED + 1))
  else
    echo "✗ print_separator outputs correct separator - FAILED"
    echo "  Expected: '$expected'"
    echo "  Actual: '$output'"
    UTILS_TEST_FAILED=$((UTILS_TEST_FAILED + 1))
  fi
}

test_print_test_header() {
  start_test_section "Print test header function"

  local temp_file
  temp_file=$(mktemp)
  print_test_header "Test Header Title" >"$temp_file"
  local output
  output=$(cat "$temp_file" | sed 's/\x1b\[[0-9;]*m//g')
  rm "$temp_file"

  if [[ "$output" == *"=================================================="* &&
    "$output" == *"Test Header Title"* &&
    "$output" == *"=================================================="* ]]; then
    echo "✓ print_test_header outputs correct header format - PASSED"
    UTILS_TEST_PASSED=$((UTILS_TEST_PASSED + 1))
  else
    echo "✗ print_test_header outputs correct header format - FAILED"
    echo "  Expected header format with title and separator lines"
    echo "  Actual output: $output"
    UTILS_TEST_FAILED=$((UTILS_TEST_FAILED + 1))
  fi
}

test_print_test_summary() {
  start_test_section "Print test summary function"

  TEST_COUNT=5
  PASSED_COUNT=5
  FAILED_COUNT=0

  local temp_file
  temp_file=$(mktemp)

  print_test_summary "All Passing Tests" >"$temp_file"
  local return_value=$?

  local output
  output=$(<"$temp_file")
  output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')

  rm "$temp_file"

  if [[ "$output" == *"All tests passed"* && $return_value -eq 0 ]]; then
    echo "✓ print_test_summary correctly reports all tests passing - PASSED"
    UTILS_TEST_PASSED=$((UTILS_TEST_PASSED + 1))
  else
    echo "✗ print_test_summary correctly reports all tests passing - FAILED"
    echo "  Expected output to contain success message and return 0"
    echo "  Actual output: $output"
    echo "  Return value: $return_value"
    UTILS_TEST_FAILED=$((UTILS_TEST_FAILED + 1))
  fi

  # Reset counters for the failing case
  TEST_COUNT=5
  PASSED_COUNT=3
  FAILED_COUNT=2

  local temp_file
  temp_file=$(mktemp)

  print_test_summary "Some Failing Tests" >"$temp_file"
  local return_value=$?

  local output
  output=$(<"$temp_file")
  output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')

  rm "$temp_file"

  if [[ "$output" == *"Some tests failed"* && $return_value -eq 1 ]]; then
    echo "✓ print_test_summary correctly reports some tests failing - PASSED"
    UTILS_TEST_PASSED=$((UTILS_TEST_PASSED + 1))
  else
    echo "✗ print_test_summary correctly reports some tests failing - FAILED"
    echo "  Expected output to contain failure message and return 1"
    echo "  Actual output: $output"
    echo "  Return value: $return_value"
    UTILS_TEST_FAILED=$((UTILS_TEST_FAILED + 1))
  fi
}

run_test_utils_tests() {
  local file_name="$1"
  print_test_header "Testing the testing utils" "$file_name"

  test_run_test
  test_print_separator
  test_print_test_header
  test_print_test_summary

  UTILS_PASS_PERCENTAGE=0
  if [ $((UTILS_TEST_PASSED + UTILS_TEST_FAILED)) -gt 0 ]; then
    UTILS_PASS_PERCENTAGE=$(((UTILS_TEST_PASSED * 100) / (UTILS_TEST_PASSED + UTILS_TEST_FAILED)))
  fi

  echo -e "\n${BLUE}==================================================${RESET}"
  echo -e "${BOLD}${YELLOW}Test Utils Test Summary${RESET}"
  echo -e "${BLUE}==================================================${RESET}"
  echo -e "Total tests: ${BOLD}$((UTILS_TEST_PASSED + UTILS_TEST_FAILED))${RESET}"
  echo -e "Passed: ${GREEN}$UTILS_TEST_PASSED${RESET} (${UTILS_PASS_PERCENTAGE}%)"
  echo -e "Failed: ${RED}$UTILS_TEST_FAILED${RESET}"
  echo -e "${BLUE}--------------------------------------------------${RESET}"

  if [ $UTILS_TEST_FAILED -eq 0 ]; then
    echo -e "${GREEN}${BOLD}🎉 All tests for test_utils.bash passed!${RESET}"
    return 0
  else
    echo -e "${RED}${BOLD}❌ Some tests for test_utils.bash failed.${RESET}"
    echo -e "${RED}Check the output above for details.${RESET}"
    return 1
  fi
}

# Run the tests if this script is executed directly, propagating its exit code
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_test_utils_tests "$0"
  exit $?
fi
