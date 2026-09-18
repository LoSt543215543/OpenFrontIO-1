#!/usr/bin/env bash
set -e

UPSTREAM="OpenFrontIO/OpenFrontIO"
MY_USER="LoSt543215543"
PROMPT="$1"

if [ -z "$PROMPT" ]; then
    echo "Usage: ./agent_flow.sh \"<bug description or approved issue #>\""
    exit 1
fi

BRANCH_NAME="fix/$(date +%s)"
git checkout main
git pull upstream main --ff-only 2> /dev/null || git pull origin main
git checkout -b "$BRANCH_NAME"

echo "==> 1. Running Aider to implement scoped fix..."
aider --message "$PROMPT. IMPORTANT: Keep total diff under 45 lines if possible. Do not edit untargeted files." --yes-always

echo "==> 2. Verifying test and lint suites..."
npx vitest run
npx tsc --noEmit
npm run lint

# Calculate total added/removed lines against upstream/main
DIFF_LINES=$(git diff upstream/main | grep -c '^[+-][^+-]' || true)
echo "Total diff line count: $DIFF_LINES"

echo "==> 3. Committing changes..."
git add -u
git commit -m "fix: $PROMPT"

echo ""
echo "----- Diff to be submitted -----"
git diff upstream/main
echo "---------------------------------"
echo "Total diff line count: $DIFF_LINES"
echo ""
read -p "Do you approve this fix? Push and open PR? (y/N): " APPROVE
if [[ ! "$APPROVE" =~ ^[Yy]$ ]]; then
    echo "==> Discarded. Branch left local, nothing pushed."
    exit 0
fi

git push -u origin "$BRANCH_NAME" --force

# Routing Gate: Under 50 lines vs Over 50 lines
if [ "$DIFF_LINES" -le 48 ]; then
    echo "==> [Direct Track] Diff <= 50 lines. Bypassing issue assignment..."
    gh pr create \
        --repo "$UPSTREAM" \
        --base main \
        --head "$MY_USER:$BRANCH_NAME" \
        --title "fix: $PROMPT" \
        --body "### Summary
- $PROMPT
- Unsolicited patch strictly <= 50 lines (Diff: $DIFF_LINES lines).

### Test plan
- All tests pass locally. Lint clean."
    echo "==> Direct PR created successfully."

else
    echo "==> [Gated Track] Diff > 50 lines ($DIFF_LINES lines). Filing issue first..."
    ISSUE_URL=$(gh issue create \
        --repo "$UPSTREAM" \
        --title "fix: $PROMPT" \
        --body "### Description\n$PROMPT\n\nProposed patch touches $DIFF_LINES lines. Requesting approval and assignment.")
    ISSUE_NUM=$(echo "$ISSUE_URL" | grep -oE '[0-9]+$')

    echo "Issue filed: #$ISSUE_NUM. Polling for 'approved' label and assignment..."
    while true; do
        DATA=$(gh issue view "$ISSUE_NUM" --repo "$UPSTREAM" --json assignees,labels)
        ASSIGNED=$(echo "$DATA" | jq --arg u "$MY_USER" '.assignees | map(.login) | contains([$u])')
        APPROVED=$(echo "$DATA" | jq '.labels | map(.name) | contains(["approved"])')

        if [ "$ASSIGNED" = "true" ] && [ "$APPROVED" = "true" ]; then
            break
        fi
        sleep 30
    done

    gh pr create \
        --repo "$UPSTREAM" \
        --base main \
        --head "$MY_USER:$BRANCH_NAME" \
        --title "fix: $PROMPT (fixes #$ISSUE_NUM)" \
        --body "Fixes #$ISSUE_NUM\n\n### Summary\n- $PROMPT\n\n### Test plan\n- Unit tests passing."
    echo "==> Assigned PR submitted successfully."
fi
