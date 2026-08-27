#!/usr/bin/env bash
#
# Spark EMS - upstream rusEFI sync helper
#
# Creates a sync branch that merges an upstream rusEFI snapshot tag into our main
# branch. Does NOT push and does NOT resolve conflicts - that is the operator's
# (or the upstream-sync agent's) job. See docs/spark-ems/upstream-sync.md
#
# Usage:
#   tools/spark-ems/sync-upstream.sh              # merge the newest upstream tag
#   tools/spark-ems/sync-upstream.sh 2026-08-20   # merge a specific tag
#
set -euo pipefail

UPSTREAM_URL="https://github.com/rusefi/rusefi"
UPSTREAM_REMOTE="upstream"
MAIN_BRANCH="${SPARK_EMS_MAIN_BRANCH:-main}"

cd "$(git rev-parse --show-toplevel)"

# --- 1. make sure the upstream remote exists and is fetched -------------------
if ! git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1; then
	echo "==> adding remote '$UPSTREAM_REMOTE' -> $UPSTREAM_URL"
	git remote add "$UPSTREAM_REMOTE" "$UPSTREAM_URL"
fi

echo "==> fetching $UPSTREAM_REMOTE (tags included)"
for attempt in 1 2 3 4; do
	if git fetch "$UPSTREAM_REMOTE" --tags --prune; then
		break
	fi
	if [ "$attempt" = "4" ]; then
		echo "ERROR: could not fetch $UPSTREAM_REMOTE after 4 attempts" >&2
		exit 1
	fi
	delay=$((2 ** attempt))
	echo "    fetch failed, retrying in ${delay}s..."
	sleep "$delay"
done

# --- 2. pick the target tag ---------------------------------------------------
# rusEFI publishes daily snapshot tags named YYYY-MM-DD (no 'v' prefix) rather
# than semantic releases. Lexicographic sort on that format IS chronological.
# Older history also carries release_N / N.N.N_release tags - ignore those, the
# dated tags are the ones that track master.
if [ $# -ge 1 ]; then
	TARGET_TAG="$1"
	git rev-parse -q --verify "refs/tags/${TARGET_TAG}" >/dev/null \
		|| { echo "ERROR: unknown tag '$TARGET_TAG'" >&2; exit 1; }
else
	# NB: do NOT pipe into `head` here - under `set -o pipefail` the closed pipe
	# gives `git tag` a SIGPIPE and the whole script dies with status 141.
	DATED_TAGS=$(git tag --list '20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]' --sort=-refname)
	TARGET_TAG=${DATED_TAGS%%$'\n'*}
	[ -n "$TARGET_TAG" ] || { echo "ERROR: no upstream dated tags found - did 'git fetch upstream --tags' run?" >&2; exit 1; }
fi

BASE_TAG_FILE=".spark-ems-upstream-tag"
PREVIOUS_TAG=""
if [ -f "$BASE_TAG_FILE" ]; then
	PREVIOUS_TAG=$(tr -d '[:space:]' < "$BASE_TAG_FILE")
fi

echo "==> target upstream tag : $TARGET_TAG"
echo "==> previous synced tag : ${PREVIOUS_TAG:-<none recorded>}"

if [ "$TARGET_TAG" = "$PREVIOUS_TAG" ]; then
	echo "Already synced to $TARGET_TAG - nothing to do."
	exit 0
fi

# --- 3. create the sync branch off our main ----------------------------------
SYNC_BRANCH="sync/rusefi-${TARGET_TAG}"

git rev-parse -q --verify "refs/heads/${MAIN_BRANCH}" >/dev/null \
	|| { echo "ERROR: local branch '$MAIN_BRANCH' not found (set SPARK_EMS_MAIN_BRANCH)" >&2; exit 1; }

if git rev-parse -q --verify "refs/heads/${SYNC_BRANCH}" >/dev/null; then
	echo "ERROR: branch '$SYNC_BRANCH' already exists - delete it or sync a different tag" >&2
	exit 1
fi

echo "==> creating $SYNC_BRANCH from $MAIN_BRANCH"
git checkout -b "$SYNC_BRANCH" "$MAIN_BRANCH"

# --- 4. report what is about to land, THEN merge ------------------------------
echo
echo "=============================================================="
echo " Upstream changes landing in this sync"
echo "=============================================================="
git log --oneline "${PREVIOUS_TAG:+${PREVIOUS_TAG}..}${TARGET_TAG}" 2>/dev/null | head -60 || true
echo
echo "--- files touched under our seed board (port these by hand!) ---"
git diff --stat "${PREVIOUS_TAG:-${MAIN_BRANCH}}" "$TARGET_TAG" \
	-- firmware/config/boards/hellen/alphax-8chan \
	   firmware/config/boards/hellen/hellen_mm176_meta.h \
	   firmware/config/boards/hellen/hellen-common-mega176.mk \
	   firmware/config/boards/hellen/hellen-common176.mk \
	   firmware/config/boards/hellen/hellen-common.mk 2>/dev/null || true
echo "=============================================================="
echo

echo "==> merging $TARGET_TAG (no commit, no fast-forward)"
if git merge --no-commit --no-ff "$TARGET_TAG"; then
	echo "$TARGET_TAG" > "$BASE_TAG_FILE"
	git add "$BASE_TAG_FILE"
	echo
	echo "MERGE CLEAN. Next steps:"
	echo "  1. cd unit_tests && ./test.sh"
	echo "  2. firmware/config/boards/spark-ems/amiral/compile_amiral.sh"
	echo "  3. git commit  (message: 'Sync upstream rusEFI ${TARGET_TAG}')"
else
	echo
	echo "MERGE CONFLICTS. Conflicted paths:"
	git diff --name-only --diff-filter=U
	echo
	echo "Resolve, then: echo $TARGET_TAG > $BASE_TAG_FILE && git add $BASE_TAG_FILE && git commit"
	exit 2
fi
