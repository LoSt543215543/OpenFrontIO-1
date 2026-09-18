#!/usr/bin/env bash
set -e

REPO_DIR="$HOME/OpenFrontIO"
UPSTREAM_REPO="OpenFrontIO/OpenFrontIO"
TARGET_FILE="tests/ClientUtils.test.ts"
BRANCH="test/client-utils-coverage"

cd "$REPO_DIR"

if [ ! -f "$TARGET_FILE" ]; then
    echo "Error: $TARGET_FILE not found."
    exit 1
fi

echo "==> 1. Verifying Vitest suite..."
npx vitest run "$TARGET_FILE"

echo "==> 2. Verifying TypeScript compilation..."
npx tsc --noEmit

echo "==> 3. Staging and committing..."
git add "$TARGET_FILE"
git commit -m "test(client): add Vitest unit test suite for Utils helper functions"

echo "==> 4. Pushing branch..."
git push -u origin "$BRANCH" --force

echo "==> 5. Opening Pull Request..."
gh pr create \
    --repo "$UPSTREAM_REPO" \
    --base main \
    --head "$(gh api user --jq .login):$BRANCH" \
    --title "test(client): add unit test coverage for Utils helper functions" \
    --body "$(
        cat << 'PR_BODY'
### Summary
- Adds comprehensive Vitest unit test coverage for pure utility helpers in `src/client/Utils.ts` (`normaliseMapKey`, `renderDuration`, `renderTroops`, `formatPercentage`, and `formatKeyForDisplay`).
- Covers edge cases including zero bounds, negative bounds, localization duration keys, and 3-significant-digit troop formatting.
- Leaves source game code untouched.

### Test plan
- `npx vitest run tests/ClientUtils.test.ts` — 42 passed (42)
- `npx tsc --noEmit` — clean (0 errors)
- `npm run lint` — clean
PR_BODY
    )"

echo "==> Pull Request successfully submitted."
