#!/bin/bash
# Setup script for git hooks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Setting up git hooks..."

# Copy pre-commit hook
cp "$SCRIPT_DIR/pre-commit-template.sh" "$PROJECT_ROOT/.git/hooks/pre-commit"
chmod +x "$PROJECT_ROOT/.git/hooks/pre-commit"

echo "✓ Pre-commit hook installed"
echo ""
echo "To disable temporarily, use: git commit --no-verify"
