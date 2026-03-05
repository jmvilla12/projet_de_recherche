#!/bin/bash
# Setup script for git hooks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Verify we are inside a git repository
if [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo "Error: no .git directory found in $PROJECT_ROOT. Run this script from within a git repository, or initialize git with: git init"
    exit 1
fi

mkdir -p "$PROJECT_ROOT/.git/hooks"

echo "Setting up git hooks..."

# Copy pre-commit hook
cp "$SCRIPT_DIR/pre-commit-template.sh" "$PROJECT_ROOT/.git/hooks/pre-commit"
chmod +x "$PROJECT_ROOT/.git/hooks/pre-commit"

echo "✓ Pre-commit hook installed"
echo ""
echo "To disable temporarily, use: git commit --no-verify"
