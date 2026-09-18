#!/usr/bin/env bash
set -e

REPO_DIR="$HOME/OpenFrontIO"
UPSTREAM_REPO="OpenFrontIO/OpenFrontIO"
MODEL="${AIDER_MODEL:-gemini/gemini-2.5-flash}"

cd "$REPO_DIR"

DEFAULT_BRANCH=$(git symbolic-ref refs/remotes/origin/HEAD 2> /dev/null | sed 's@^refs/remotes/origin/@@')
if [ -z "$DEFAULT_BRANCH" ]; then
    if git show-ref --verify --quiet refs/heads/main; then
        DEFAULT_BRANCH="main"
    else
        DEFAULT_BRANCH="master"
    fi
fi

echo "==> Using base branch: $DEFAULT_BRANCH"
git checkout "$DEFAULT_BRANCH" || true
git checkout -- .gitignore 2> /dev/null || true
git pull origin "$DEFAULT_BRANCH" || true

# Target selection
if [ -n "$1" ]; then
    FILE="$1"
    LINE="${2:-1}"
    DESC=$(sed -n "${LINE}p" "$FILE" | sed 's/^[[:space:]]*\/\/[[:space:]]*//')
    [ -z "$DESC" ] && DESC="Resolve issue in $FILE around line$LINE"
else
    echo "==> Scanning for candidate TODO targets..."
    CANDIDATE=$(git grep -inE "(TODO|FIXME):" src/ | python3 -c "import sys, random; lines=sys.stdin.readlines(); sys.stdout.write(random.choice(lines)) if lines else None")

    if [ -z "$CANDIDATE" ]; then
        echo "No TODOs found. Specify a file directly: ./hunt_pr.sh src/client/Utils.ts"
        exit 1
    fi

    FILE=$(echo "$CANDIDATE" | cut -d: -f1)
    LINE=$(echo "$CANDIDATE" | cut -d: -f2)
    DESC=$(echo "$CANDIDATE" | cut -d: -f3- | sed 's/^[[:space:]]*\/\/[[:space:]]*//')
fi

SLUG=$(echo "$FILE" | sed 's/[^a-zA-Z0-9]/-/g' | tr '[:upper:]' '[:lower:]' | cut -c 1-24)
BRANCH_NAME="fix/auto-$SLUG-$LINE"

echo "=================================================="
echo "Target:  $FILE (line$LINE)"
echo "Task:    $DESC"
echo "Model:   $MODEL"
echo "Branch:  $BRANCH_NAME"
echo "=================================================="

git checkout -B "$BRANCH_NAME"

PROMPT="Resolve the task in $FILE around line$LINE:
Task: $DESC

Requirements:
- Make the minimal deterministic change necessary.
- Do not modify unrelated lines, formatting, or comments.
- Do not touch .gitignore.
- Ensure 'npx tsc --noEmit' passes with zero errors."

echo "==> AI Agent running modifications & verification..."
aider \
    --model "$MODEL" \
    --file "$FILE" \
    --map-tokens 0 \
    --message "$PROMPT" \
    --test-cmd "npx tsc --noEmit" \
    --auto-test \
    --yes-always \
    --no-auto-commits

# Revert any sneaky edits to .gitignore so it never leaks into the PR
git checkout -- .gitignore 2> /dev/null || true

echo ""
echo "=================================================="
echo "               CODE DIFF REVIEW                   "
echo "=================================================="
git diff --word-diff=color

# Abort if no code changes occurred in the targeted file
if git diff --quiet "$FILE"; then
    echo "==> No changes were made to $FILE. Aborting without PR."
    git checkout "$DEFAULT_BRANCH"
    git branch -D "$BRANCH_NAME"
    exit 0
fi

echo ""
read -p "Do you approve this fix? Push to origin and open PR? (y/N): " APPROVE

if [[ "$APPROVE" =~ ^[Yy]$ ]]; then
    COMMIT_MSG="fix($(basename "$FILE" .ts)): resolve ${DESC:0:50}"
    git add "$FILE"
    git commit -m "$COMMIT_MSG"
    git push -u origin "$BRANCH_NAME"

    gh pr create \
        --repo "$UPSTREAM_REPO" \
        --base "$DEFAULT_BRANCH" \
        --head "$(gh api user --jq .login):$BRANCH_NAME" \
        --title "$COMMIT_MSG" \
        --body "Automated targeted fix for \`$FILE\` around line $LINE: \`$DESC\`. Verified locally via TypeScript validation."

    echo "==> PR opened on upstream repository."
    git checkout "$DEFAULT_BRANCH"
else
    echo "==> Discarding changes and removing branch..."
    git checkout "$DEFAULT_BRANCH"
    git branch -D "$BRANCH_NAME"
fi

sleep 5
