#!/bin/bash
#
# Install Git Hooks for MedSecure
# This script installs pre-commit hooks for local security scanning
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GIT_HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

echo "🔧 Installing Git Hooks for MedSecure..."
echo ""

# Check if .git directory exists
if [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo "❌ Error: Not a git repository. Please run from the project root."
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p "$GIT_HOOKS_DIR"

# ============================================
# PRE-COMMIT HOOK - Secret Detection
# ============================================
echo "📝 Creating pre-commit hook (Gitleaks)..."

cat > "$GIT_HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash
#
# Pre-commit hook for MedSecure
# Scans for secrets before allowing commit
#

set -e

echo "🔍 Running Gitleaks secret detection..."

# Check if Gitleaks is installed
if ! command -v gitleaks &> /dev/null; then
    echo ""
    echo "⚠️  WARNING: Gitleaks is not installed!"
    echo "    Secrets will not be detected locally."
    echo ""
    echo "To install Gitleaks:"
    echo "  - macOS: brew install gitleaks"
    echo "  - Linux: Download from https://github.com/gitleaks/gitleaks/releases"
    echo "  - Windows: choco install gitleaks (or download binary)"
    echo ""
    echo "Skipping secret detection..."
    exit 0
fi

# Run Gitleaks on staged files
if gitleaks protect --staged --verbose --no-banner 2>&1; then
    echo "✅ No secrets detected!"
    exit 0
else
    echo ""
    echo "❌ SECRETS DETECTED!"
    echo ""
    echo "Gitleaks found potential secrets in your staged files."
    echo ""
    echo "Options:"
    echo "  1. Remove the secrets and commit again"
    echo "  2. Add false positives to .gitleaks.toml allowlist"
    echo "  3. Use git commit --no-verify (NOT RECOMMENDED for HDS compliance)"
    echo ""
    echo "For HDS compliance, secrets must NOT be committed to the repository."
    echo ""
    exit 1
fi
EOF

chmod +x "$GIT_HOOKS_DIR/pre-commit"
echo "✅ Pre-commit hook installed"

# ============================================
# COMMIT-MSG HOOK - Commit Message Validation
# ============================================
echo "📝 Creating commit-msg hook..."

cat > "$GIT_HOOKS_DIR/commit-msg" << 'EOF'
#!/bin/bash
#
# Commit-msg hook for MedSecure
# Validates commit message format
#

COMMIT_MSG_FILE=$1
COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")

# Skip if merge commit
if grep -q "^Merge" "$COMMIT_MSG_FILE"; then
    exit 0
fi

# Check commit message format
# Expected: type(scope): subject
# Examples:
#   feat(auth): add OAuth2 authentication
#   fix(api): resolve null reference in patient controller
#   docs(readme): update deployment instructions

PATTERN="^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?: .{10,}"

if ! echo "$COMMIT_MSG" | grep -qE "$PATTERN"; then
    echo ""
    echo "❌ Invalid commit message format!"
    echo ""
    echo "Expected format: type(scope): subject"
    echo ""
    echo "Types:"
    echo "  feat:     New feature"
    echo "  fix:      Bug fix"
    echo "  docs:     Documentation changes"
    echo "  style:    Code style changes (formatting, etc.)"
    echo "  refactor: Code refactoring"
    echo "  test:     Adding or updating tests"
    echo "  chore:    Maintenance tasks"
    echo "  perf:     Performance improvements"
    echo "  ci:       CI/CD changes"
    echo "  build:    Build system changes"
    echo "  revert:   Revert previous commit"
    echo ""
    echo "Examples:"
    echo "  feat(auth): add OAuth2 authentication"
    echo "  fix(api): resolve null reference in patient controller"
    echo "  docs(readme): update deployment instructions"
    echo ""
    echo "Your message: $COMMIT_MSG"
    echo ""
    exit 1
fi

echo "✅ Commit message format validated"
EOF

chmod +x "$GIT_HOOKS_DIR/commit-msg"
echo "✅ Commit-msg hook installed"

# ============================================
# PRE-PUSH HOOK - Run local tests
# ============================================
echo "📝 Creating pre-push hook..."

cat > "$GIT_HOOKS_DIR/pre-push" << 'EOF'
#!/bin/bash
#
# Pre-push hook for MedSecure
# Runs unit tests before allowing push
#

set -e

echo "🧪 Running unit tests before push..."

# Check if .NET SDK is installed
if ! command -v dotnet &> /dev/null; then
    echo "⚠️  .NET SDK not found. Skipping tests."
    exit 0
fi

# Find test projects
TEST_PROJECTS=$(find . -name "*Tests.csproj" -o -name "*Test.csproj" 2>/dev/null)

if [ -z "$TEST_PROJECTS" ]; then
    echo "⚠️  No test projects found. Skipping tests."
    exit 0
fi

# Run tests
if dotnet test --no-build --verbosity quiet; then
    echo "✅ All tests passed!"
    exit 0
else
    echo ""
    echo "❌ TESTS FAILED!"
    echo ""
    echo "Please fix failing tests before pushing."
    echo "Use 'git push --no-verify' to skip tests (NOT RECOMMENDED)"
    echo ""
    exit 1
fi
EOF

chmod +x "$GIT_HOOKS_DIR/pre-push"
echo "✅ Pre-push hook installed"

echo ""
echo "🎉 Git hooks installed successfully!"
echo ""
echo "Installed hooks:"
echo "  ✓ pre-commit  - Gitleaks secret detection"
echo "  ✓ commit-msg  - Commit message format validation"
echo "  ✓ pre-push    - Run unit tests before push"
echo ""
echo "To bypass hooks (NOT RECOMMENDED for HDS compliance):"
echo "  git commit --no-verify"
echo "  git push --no-verify"
echo ""
echo "For HDS compliance, all commits should pass security checks."
echo ""
