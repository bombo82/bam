#!/bin/bash

# Test file for test_utils.bash
# This script tests the utility functions used for testing

# shellcheck disable=SC2001 # ANSI stripping needs a regex character class; ${var//} cannot express it
# Source the test utilities
# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$(dirname "${BASH_SOURCE[0]}")/test_utils.bash"

# We'll use these variables to track our own test results
UTILS_TEST_PASSED=0
UTILS_TEST_FAILED=0

# Test the run_test function
test_run_test() {
  start_test_section "Run test function"

  # Reset counters before testing
  TEST_COUNT=0
  PASSED_COUNT=0
  FAILED_COUNT=0

  # Test run_test with passing test
  # We'll redirect the output to a temporary file to check it later
  local temp_file
  temp_file=$(mktemp)
  run_test "Sample passing test" "expected" "expected" >"$temp_file" 2>&1
  local output
  output=$(<"$temp_file")
  rm "$temp_file"

  # Check if output contains "PASSED"
  if [[ "$output" == *"PASSED"* ]]; then
    print_passed_test_result "run_test correctly identifies passing tests"
    UTILS_TEST_PASSED=$((UTILS_TEST_PASSED + 1))
  else
    print_failed_test_result "run_test correctly identifies passing tests" "output to contain 'PASSED'" "$output"
    UTILS_TEST_FAILED=$((UTILS_TEST_FAILED + 1))
  fi

  # Test run_test with failing test
  # We'll redirect the output to a temporary file to check it later
  local temp_file
  temp_file=$(mktemp)
  run_test "Sample failing test" "expected" "actual" >"$temp_file" 2>&1
  local output
  output=$(<"$temp_file")
  rm "$temp_file"

  # Check if output contains "FAILED" and failure details
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

  # Check if PASSED_COUNT is incremented correctly
  if [ "$PASSED_COUNT" -eq 1 ]; then
    print_passed_test_result "run_test correctly increments PASSED_COUNT"
    UTILS_TEST_PASSED=$((UTILS_TEST_PASSED + 1))
  else
    print_failed_test_result "run_test correctly increments PASSED_COUNT" "PASSED_COUNT to be 1" "$PASSED_COUNT"
    UTILS_TEST_FAILED=$((UTILS_TEST_FAILED + 1))
  fi

  # Check if FAILED_COUNT is incremented correctly
  if [ "$FAILED_COUNT" -eq 1 ]; then
    print_passed_test_result "run_test correctly increments FAILED_COUNT"
    UTILS_TEST_PASSED=$((UTILS_TEST_PASSED + 1))
  else
    print_failed_test_result "run_test correctly increments FAILED_COUNT" "FAILED_COUNT to be 1" "$FAILED_COUNT"
    UTILS_TEST_FAILED=$((UTILS_TEST_FAILED + 1))
  fi
}

# Test the print_separator function
test_print_separator() {
  start_test_section "Print separator function"

  # Capture output of print_separator and remove color codes
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

# Test the print_test_header function
test_print_test_header() {
  start_test_section "Print test header function"

  # Capture output of print_test_header and remove color codes
  local temp_file
  temp_file=$(mktemp)
  print_test_header "Test Header Title" >"$temp_file"
  local output
  output=$(cat "$temp_file" | sed 's/\x1b\[[0-9;]*m//g')
  rm "$temp_file"

  # Check if output contains the expected header format
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

# Test the print_test_summary function
test_print_test_summary() {
  start_test_section "Print test summary function"

  # Reset counters for this test
  TEST_COUNT=5
  PASSED_COUNT=5
  FAILED_COUNT=0

  # We need to use a different approach to capture both output and return value
  # Create a temporary file for the output
  local temp_file
  temp_file=$(mktemp)

  # Run the function and capture its return value
  print_test_summary "All Passing Tests" >"$temp_file"
  local return_value=$?

  # Read the output from the temporary file
  local output
  output=$(<"$temp_file")
  # Remove color codes
  output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')

  # Remove the temporary file
  rm "$temp_file"

  # Check if output contains success message
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

  # Reset counters for failing test
  TEST_COUNT=5
  PASSED_COUNT=3
  FAILED_COUNT=2

  # We need to use a different approach to capture both output and return value
  # Create a temporary file for the output
  local temp_file
  temp_file=$(mktemp)

  # Run the function and capture its return value
  print_test_summary "Some Failing Tests" >"$temp_file"
  local return_value=$?

  # Read the output from the temporary file
  local output
  output=$(<"$temp_file")
  # Remove color codes
  output=$(echo "$output" | sed 's/\x1b\[[0-9;]*m//g')

  # Remove the temporary file
  rm "$temp_file"

  # Check if output contains failure message
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

# Main function to run all tests
run_test_utils_tests() {
  local file_name="$1"
  print_test_header "Testing the testing utils" "$file_name"

  # Run all tests
  test_run_test
  test_print_separator
  test_print_test_header
  test_print_test_summary

  # Calculate pass percentage
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

# Run the tests if this script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  run_test_utils_tests "$0"
  exit $?
fi
