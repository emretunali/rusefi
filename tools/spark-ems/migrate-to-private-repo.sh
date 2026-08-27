#!/usr/bin/env bash
#
# Spark EMS - one-time migration from the public rusEFI fork to a private repo.
#
# WHY THIS EXISTS
#   GitHub does not allow a fork of a public repository to be made private.
#   The supported workaround is to push a full mirror into a fresh private repo
#   that is not a fork. This script performs that mirror push.
#
# BEFORE RUNNING
#   1. Create an EMPTY private repository on GitHub.
#      Do NOT initialize it with a README, .gitignore or licence - the mirror
#      push must be the first thing that lands in it.
#   2. Make sure you can authenticate to it (gh auth / SSH key / PAT).
#
# USAGE
#   tools/spark-ems/migrate-to-private-repo.sh git@github.com:emretunali/spark-ems-amiral.git
#
set -euo pipefail

TARGET_URL="${1:-}"
if [ -z "$TARGET_URL" ]; then
	echo "usage: $0 <private-repo-git-url>" >&2
	exit 1
fi

SOURCE_URL="${SPARK_EMS_SOURCE_URL:-https://github.com/emretunali/rusefi.git}"
WORKDIR="${SPARK_EMS_MIRROR_DIR:-$(mktemp -d)}/rusefi-mirror.git"

echo "==> source : $SOURCE_URL"
echo "==> target : $TARGET_URL"
echo "==> workdir: $WORKDIR"
echo

read -r -p "This pushes ALL branches and tags into $TARGET_URL. Continue? [y/N] " reply
case "$reply" in
	[yY]*) ;;
	*) echo "aborted"; exit 1 ;;
esac

echo "==> cloning bare mirror"
git clone --bare "$SOURCE_URL" "$WORKDIR"

cd "$WORKDIR"

echo "==> pushing mirror"
git push --mirror "$TARGET_URL"

cat <<EOF

Mirror complete.

Post-migration checklist:
  1. Confirm on GitHub that the new repo is Private and has all branches/tags.
  2. In your working clone, repoint origin and rename the product branch to 'main'
     (sync-upstream.sh defaults to 'main'; anything else needs SPARK_EMS_MAIN_BRANCH):
       git remote set-url origin $TARGET_URL
       git branch -m master main
       git push -u origin main
     Then set 'main' as the default branch in the GitHub repo settings and delete the
     old 'master' ref: git push origin --delete master
  3. Add the upstream remote for syncing (sync-upstream.sh does this too):
       git remote add upstream https://github.com/rusefi/rusefi
  4. Re-enable the Actions workflows you actually want; upstream ships ~30 of
     them and most build boards we do not care about.
  5. Decide what happens to the old public fork: delete it, or keep it purely
     as a read-only upstream mirror. Do NOT push Amiral work to it.
  6. Remove the temporary mirror clone: rm -rf "$WORKDIR"

Note: the new repo is not a GitHub fork, so the "N commits behind" banner is
gone. Upstream tracking is handled by tools/spark-ems/sync-upstream.sh instead.
EOF
