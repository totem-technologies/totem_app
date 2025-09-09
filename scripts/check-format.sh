#!/usr/bin/env sh

# Check dart formatting for staged files only
# Works on Windows (Git Bash), macOS, and Linux

set -u

echo "Checking dart formatting..."
# Check if dart is available
if ! command -v dart >/dev/null 2>&1; then
    echo "Warning: dart command not found. Skipping format check."
    exit 0
fi

# Get list of staged .dart files
# Use --diff-filter to include Added, Copied, Modified, and Renamed files
STAGED_DART_FILES=$(git diff --cached --name-only --diff-filter=ACMR | grep '\.dart$' 2>/dev/null || true)

# If no dart files are staged, exit successfully
if [ -z "${STAGED_DART_FILES}" ]; then
    echo "No .dart file changes to check"
    exit 0
fi

echo "Checking formatting for staged .dart files..."

# Count files for display
FILE_COUNT=$(echo "${STAGED_DART_FILES}" | wc -l | tr -d ' ')
echo "Found ${FILE_COUNT} staged .dart file(s)"

# Run dart format check on each file
# We process files one by one for better portability
FORMAT_NEEDED=0
for file in ${STAGED_DART_FILES}; do
    if [ -f "${file}" ]; then
        dart format --set-exit-if-changed "${file}" >/dev/null 2>&1 || FORMAT_NEEDED=1
    fi
done

if [ "${FORMAT_NEEDED}" -eq 1 ]; then
    echo "❌ Code formatting issues detected in staged files!"
    echo ""
    echo "Files to format:"
    for file in ${STAGED_DART_FILES}; do
        echo "  ${file}"
    done
    echo ""
    echo "Please stage new changes and commit again."
    echo ""
    exit 1
else
    echo "✅ Code formatting check passed"
    exit 0
fi
