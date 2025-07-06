#!/bin/bash

# Utility functions for testing
# This file contains common functions used across test files

# Global variables for test tracking
TEST_COUNT=0
PASSED_COUNT=0
FAILED_COUNT=0
SECTION_COUNT=0

# ANSI color codes for better readability
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

# Function to run a test and track results
run_test() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"

  TEST_COUNT=$((TEST_COUNT + 1))

  if [ "$expected" = "$actual" ]; then
    print_passed_test_result "$test_name"
    PASSED_COUNT=$((PASSED_COUNT + 1))
  else
    print_failed_test_result "$test_name" "$expected" "$actual"
    FAILED_COUNT=$((FAILED_COUNT + 1))
  fi
}

# Function to print a passed test result
print_passed_test_result() {
  local test_name="$1"
  echo -e "${GREEN}✓${RESET} ${test_name} - ${GREEN}PASSED${RESET}"
}

# Function to print a failed test result
print_failed_test_result() {
  local test_name="$1"
  local expected="$2"
  local actual="$3"

  echo -e "${RED}✗${RESET} ${test_name} - ${RED}FAILED${RESET}"
  echo -e "  ${BOLD}Expected:${RESET} '${expected}'"
  echo -e "  ${BOLD}Actual:${RESET}   '${actual}'"
}

# Function to print a separator line
print_separator() {
  echo -e "${BLUE}----------------------------------------${RESET}"
}

# Function to start a new test section with a title
start_test_section() {
  local section_title="$1"

  SECTION_COUNT=$((SECTION_COUNT + 1))

  echo -e "\n${YELLOW}${BOLD}Section $SECTION_COUNT: $section_title${RESET}"
  print_separator
}

# Function to print a test header
print_test_header() {
  local title="$1"
  local file_name="$2"

  echo -e "${BLUE}==================================================${RESET}"
  echo -e "${BOLD}${YELLOW}$title${RESET}"
  echo -e "${BLUE}File: ${RESET}${BOLD}$file_name${RESET}"
  echo -e "${BLUE}==================================================${RESET}"
}

# Function to print test summary with detailed statistics
print_test_summary() {
  local title="$1"
  local pass_percentage=0

  if [ $TEST_COUNT -gt 0 ]; then
    pass_percentage=$(((PASSED_COUNT * 100) / TEST_COUNT))
  fi

  echo -e "\n${BLUE}==================================================${RESET}"
  echo -e "${BOLD}Test Summary for ${YELLOW}$title${RESET}:"
  echo -e "${BLUE}--------------------------------------------------${RESET}"
  echo -e "Total tests: ${BOLD}$TEST_COUNT${RESET}"
  echo -e "Passed: ${GREEN}$PASSED_COUNT${RESET} (${pass_percentage}%)"
  echo -e "Failed: ${RED}$FAILED_COUNT${RESET}"
  echo -e "${BLUE}--------------------------------------------------${RESET}"

  if [ $FAILED_COUNT -eq 0 ]; then
    echo -e "${GREEN}${BOLD}🎉 All tests passed!${RESET}"
    return 0
  else
    echo -e "${RED}${BOLD}❌ Some tests failed.${RESET}"
    return 1
  fi
}

# Asserts that invoking COMMAND fails with a specific contract or parse error
# status code (e.g. ERR_WRONG_TAG, ERR_PARSE_PARENS). Suppresses stdout/stderr
# and checks the exit status via run_test.
# Usage: assert_contract_error TEST_NAME EXPECTED_CODE COMMAND [ARGS...]
assert_contract_error() {
  local test_name="$1"
  local expected="$2"
  shift 2

  "$@" >/dev/null 2>&1
  run_test "$test_name" "$expected" "$?"
}
