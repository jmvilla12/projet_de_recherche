#!/bin/bash
# Pre-commit hook template
# Copy to .git/hooks/pre-commit and make executable

echo "Running pre-commit checks..."

# Check if clang-format is available
if ! command -v clang-format &> /dev/null; then
    echo "Warning: clang-format not found. Skipping format check."
else
    # Format all staged C++ files
    STAGED_CPP_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(cpp|h|hpp|cc)$')
    
    if [ -n "$STAGED_CPP_FILES" ]; then
        echo "Formatting C++ files..."
        for file in $STAGED_CPP_FILES; do
            clang-format -i "$file"
            git add "$file"
        done
    fi
fi

echo "Pre-commit checks completed!"
exit 0
