#!/bin/bash

# run_all_tests.bash
#
# Main test runner for the Bash-Monad project
# This script runs all tests in the project in the following order:
# 1. First runs test_utils tests
# 2. Then runs all monad implementation tests in alphabetical order
#
# Usage (works from any directory):
#   bash test/run_all_tests.bash
#
# Exit codes:
#   0 - All test suites passed
#   1 - One or more test suites failed

# Resolve the directory of this script, so the runner works from anywhere
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Source the test utilities for colors and formatting
# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$SCRIPT_DIR/test_utils.bash"

# Set up variables to track overall test results
TOTAL_TEST_SUITES=0
PASSED_TEST_SUITES=0
FAILED_TEST_SUITES=0

# Function to run a test file and track results
run_test_file() {
  local test_file="$1"

  echo -e "\n"

  # Get the directory of the test file
  local test_dir
  test_dir=$(dirname "$test_file")
  local test_filename
  test_filename=$(basename "$test_file")

  # Change to the test directory and run the test
  pushd "$test_dir" >/dev/null || return 1
  bash "./$test_filename"
  local result=$?
  popd >/dev/null || return 1

  # Track results
  TOTAL_TEST_SUITES=$((TOTAL_TEST_SUITES + 1))
  if [ $result -eq 0 ]; then
    PASSED_TEST_SUITES=$((PASSED_TEST_SUITES + 1))
  else
    FAILED_TEST_SUITES=$((FAILED_TEST_SUITES + 1))
  fi

  return $result
}

# Print header
print_test_header "BASH-MONAD: RUNNING ALL TESTS"

# First run test_utils tests
run_test_file "$SCRIPT_DIR/test_utils_test.bash"

# Get all monad test files and sort them alphabetically
# We're excluding test_utils tests as they've already been run
monad_test_files=$(find "$SCRIPT_DIR" -name "*_test.bash" | grep -v "test_utils" | sort)

# Run each monad test file
for test_file in $monad_test_files; do
  run_test_file "$test_file"
done

# Calculate pass percentage
PASS_PERCENTAGE=0
if [ $TOTAL_TEST_SUITES -gt 0 ]; then
  PASS_PERCENTAGE=$(((PASSED_TEST_SUITES * 100) / TOTAL_TEST_SUITES))
fi

# Print summary
echo -e "\n"
print_test_header "TEST SUITE SUMMARY" "$0"
echo -e "Total test suites: ${BOLD}$TOTAL_TEST_SUITES${RESET}"
echo -e "Passed test suites: ${GREEN}$PASSED_TEST_SUITES${RESET} (${PASS_PERCENTAGE}%)"
echo -e "Failed test suites: ${RED}$FAILED_TEST_SUITES${RESET}"
echo -e "${BLUE}--------------------------------------------------${RESET}"

# Set exit code based on test results
if [ $FAILED_TEST_SUITES -eq 0 ]; then
  echo -e "${GREEN}${BOLD}🎉 All test suites passed!${RESET}"
  exit 0
else
  echo -e "${RED}${BOLD}❌ Some test suites failed.${RESET}"
  exit 1
fi
