#!/bin/bash
# Pre-commit hook template
# Copy to .git/hooks/pre-commit and make executable

echo "Running pre-commit checks..."

# Check if clang-format is available
if ! command -v clang-format &> /dev/null; then
    echo "Warning: clang-format not found. Skipping format check."
else
    # Format all staged C++ files (NUL-delimited to handle spaces in paths)
    formatted_any=false
    while IFS= read -r -d '' file; do
        case "$file" in
            *.cpp|*.h|*.hpp|*.cc)
                if [ "$formatted_any" = false ]; then
                    echo "Formatting C++ files..."
                    formatted_any=true
                fi
                clang-format -i "$file"
                git add "$file"
                ;;
        esac
    done < <(git diff --cached --name-only --diff-filter=ACM -z)
fi

echo "Pre-commit checks completed!"
exit 0
