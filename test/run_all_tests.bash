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
# run_all_tests.bash
#
# Main test runner for the BAM! (Bourne Again Monad!) project
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
#

# Resolve the directory of this script, so the runner works from anywhere
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Source the test utilities for colors and formatting
# shellcheck source=/dev/null # Dynamic path resolved at runtime; cannot be followed statically
source "$SCRIPT_DIR/test_utils.bash"

TOTAL_TEST_SUITES=0
PASSED_TEST_SUITES=0
FAILED_TEST_SUITES=0

# Runs a test file from its own directory and updates the suite counters
# Usage: run_test_file TEST_FILE
run_test_file() {
  local test_file="$1"

  echo -e "\n"

  local test_dir
  test_dir=$(dirname "$test_file")
  local test_filename
  test_filename=$(basename "$test_file")

  pushd "$test_dir" >/dev/null || return 1
  bash "./$test_filename"
  local result=$?
  popd >/dev/null || return 1

  TOTAL_TEST_SUITES=$((TOTAL_TEST_SUITES + 1))
  if [ $result -eq 0 ]; then
    PASSED_TEST_SUITES=$((PASSED_TEST_SUITES + 1))
  else
    FAILED_TEST_SUITES=$((FAILED_TEST_SUITES + 1))
  fi

  return $result
}

print_test_header "BASH-MONAD: RUNNING ALL TESTS"

run_test_file "$SCRIPT_DIR/test_utils_test.bash"

# All remaining suites except test_utils (already run), in alphabetical order
monad_test_files=$(find "$SCRIPT_DIR" -name "*_test.bash" | grep -v "test_utils" | sort)

for test_file in $monad_test_files; do
  run_test_file "$test_file"
done

PASS_PERCENTAGE=0
if [ $TOTAL_TEST_SUITES -gt 0 ]; then
  PASS_PERCENTAGE=$(((PASSED_TEST_SUITES * 100) / TOTAL_TEST_SUITES))
fi

echo -e "\n"
print_test_header "TEST SUITE SUMMARY" "$0"
echo -e "Total test suites: ${BOLD}$TOTAL_TEST_SUITES${RESET}"
echo -e "Passed test suites: ${GREEN}$PASSED_TEST_SUITES${RESET} (${PASS_PERCENTAGE}%)"
echo -e "Failed test suites: ${RED}$FAILED_TEST_SUITES${RESET}"
echo -e "${BLUE}--------------------------------------------------${RESET}"

if [ $FAILED_TEST_SUITES -eq 0 ]; then
  echo -e "${GREEN}${BOLD}🎉 All test suites passed!${RESET}"
  exit 0
else
  echo -e "${RED}${BOLD}❌ Some test suites failed.${RESET}"
  exit 1
fi
