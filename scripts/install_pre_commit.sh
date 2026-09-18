#!/usr/bin/env bash
# ==============================================================================
# RexOne Pre-Commit Hook Installer
# Configures local git hooks to run all safety & quality checks before commit.
# ==============================================================================

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

GIT_DIR=$(git -C "${REPO_ROOT}" rev-parse --git-dir 2>/dev/null || true)
if [ -z "$GIT_DIR" ]; then
  echo -e "${RED}❌ Error: Not a git repository at ${REPO_ROOT}.${NC}"
  exit 1
fi

HOOKS_DIR="${REPO_ROOT}/${GIT_DIR}/hooks"
PRE_COMMIT_HOOK="${HOOKS_DIR}/pre-commit"

mkdir -p "${HOOKS_DIR}"

cat << 'EOF' > "${PRE_COMMIT_HOOK}"
#!/usr/bin/env bash
# ==============================================================================
# Auto-generated RexOne Pre-Commit Hook
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🛡️  Running RexOne Pre-Commit Quality & Security Gates...${NC}"

# 1. Check for uncommitted secrets and .env files
if [ -f "./scripts/check_secrets.sh" ]; then
  echo -e "   → [1/2] Scanning for secrets and uncommitted .env files..."
  ./scripts/check_secrets.sh
fi

# 2. Check locale parity & message service integrity
if [ -f "./scripts/check_locales.sh" ]; then
  echo -e "   → [2/2] Checking locale parity & translation constants..."
  ./scripts/check_locales.sh
fi

echo -e "${GREEN}✅ All pre-commit checks passed cleanly! Proceeding with commit.${NC}"
exit 0
EOF

chmod +x "${PRE_COMMIT_HOOK}"

echo -e "${GREEN}======================================================================${NC}"
echo -e "${GREEN}  ✅ Successfully installed pre-commit hook at:${NC}"
echo -e "     ${PRE_COMMIT_HOOK}"
echo -e "${GREEN}  Checks configured:${NC}"
echo -e "     1. Secret Scanner (blocks real .env files and live API keys)"
echo -e "     2. Locale & MessageService Integrity Checker"
echo -e "${GREEN}======================================================================${NC}"
