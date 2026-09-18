#!/usr/bin/env bash
set -e

UPSTREAM="openfrontio/OpenFrontIO"
MY_USER="LoSt543215543"
NEW_BRANCH="client-utils-tests"

echo "==> 1. Renaming local branch to avoid 'test/' directory conflict..."
git branch -m "$NEW_BRANCH" \vert{}\vert{} git checkout -B "$NEW_BRANCH" 2> /dev/null

echo "==> 2. Pointing remote to primary fork (LoSt543215543/OpenFrontIO)..."
git remote set-url origin "https://github.com/$MY_USER/OpenFrontIO.git"

echo "==> 3. Pushing branch to primary fork..."
git push -u origin "$NEW_BRANCH" --force

echo "==> 4. Submitting Pull Request upstream..."
gh pr create \
    --repo "$UPSTREAM" \
    --base main \
    --head "$MY_USER:$NEW_BRANCH" \
    --title "test(client): add unit test coverage for Utils helper functions" \
    --body "$(
        cat << 'PR_BODY'
### Summary
- Adds comprehensive Vitest unit test coverage for pure utility helpers in `src/client/Utils.ts` (`normaliseMapKey`, `renderDuration`, `renderTroops`, `formatPercentage`, and `formatKeyForDisplay`).
- Covers edge cases including negative bounds, zero values, duration localization tokens, and 3-significant-digit troop counts.
- Zero modifications to source game code.

### Test plan
- `npx vitest run tests/ClientUtils.test.ts` — 42 passed (42)
- `npx tsc --noEmit` — clean (0 errors)
- `npm run lint` — clean
PR_BODY
    )"

echo "==> Pull Request successfully submitted."
