#!/usr/bin/env bash
set -e

UPSTREAM="openfrontio/OpenFrontIO"
MY_USER="LoSt543215543"
BRANCH="test/client-utils-coverage"

echo "==> 1. Checking GitHub fork name..."
# Rename openfront-mobile to OpenFrontIO if needed so GitHub API resolves the namespace
gh repo rename OpenFrontIO --repo "$MY_USER/openfront-mobile" --yes 2> /dev/null || true

# If no fork exists named OpenFrontIO, create it cleanly
gh repo fork "$UPSTREAM" --clone=false 2> /dev/null || true

echo "==> 2. Syncing remote and pushing branch..."
git remote set-url origin "https://github.com/$MY_USER/OpenFrontIO.git" 2> /dev/null || git remote add origin "https://github.com/$MY_USER/OpenFrontIO.git"
git push -u origin "$BRANCH" --force

echo "==> 3. Submitting Pull Request directly via REST API..."
PR_PAYLOAD=$(
    cat << JSON
{
  "title": "test(client): add unit test coverage for Utils helper functions",
  "head": "$MY_USER:$BRANCH",
  "base": "main",
  "body": "### Summary\n- Adds comprehensive Vitest unit test coverage for pure utility helpers in \`src/client/Utils.ts\` (\`normaliseMapKey\`, \`renderDuration\`, \`renderTroops\`, \`formatPercentage\`, and \`formatKeyForDisplay\`).\n- Covers edge cases including zero bounds, negative bounds, localization duration keys, and 3-significant-digit troop formatting.\n- Leaves source game code untouched.\n\n### Test plan\n- \`npx vitest run tests/ClientUtils.test.ts\` — 42 passed (42)\n- \`npx tsc --noEmit\` — clean (0 errors)\n- \`npm run lint\` — clean"
}
JSON
)

PR_URL=$(curl -s -X POST \
    -H "Authorization: token $(gh auth token)" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/repos/$UPSTREAM/pulls \
    -d "$PR_PAYLOAD" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('html_url') or data.get('message', ''))")

echo "==> Result: $PR_URL"
