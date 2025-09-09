#!/usr/bin/env bash

# Check dart formatting for staged files only
set -o nounset
set -o pipefail

# Check if dart is available
if ! command -v dart &> /dev/null; then
    echo "Warning: dart command not found. Skipping format check."
    exit 0
fi

# Get list of staged .dart files
STAGED_DART_FILES=$(git diff --cached --name-only --diff-filter=ACMR | grep '\.dart$' || true)

# If no dart files are staged, exit successfully
if [ -z "${STAGED_DART_FILES}" ]; then
    echo "No .dart file changes to check"
    exit 0
fi

echo "Checking formatting for staged .dart files..."

# Convert newline-separated list to space-separated for dart format
FILES_TO_CHECK=$(echo "${STAGED_DART_FILES}" | tr '\n' ' ')

# Run dart format check on staged files only
dart format --set-exit-if-changed ${FILES_TO_CHECK} > /dev/null 2>&1
FORMAT_EXIT_CODE=$?

if [ "${FORMAT_EXIT_CODE}" -eq 1 ]; then
    echo "❌ Code formatting issues detected in staged files!"
    echo ""
    echo "Files with formatting issues:"
    echo "${STAGED_DART_FILES}"
    echo ""
    echo "Please stage new changes and commit again."
    echo ""
    exit 1
elif [ "${FORMAT_EXIT_CODE}" -eq 0 ]; then
    echo "✅ Code formatting check passed"
    exit 0
else
    echo "Warning: dart format returned unexpected exit code: ${FORMAT_EXIT_CODE}"
    exit 0
fi
