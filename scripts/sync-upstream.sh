#!/usr/bin/env bash
# Bring the jarod branch up to date with upstream, then push it to our fork.
#
# Run by hand, or from `omarchy update` through the post-update hook
# (~/.config/omarchy/hooks/post-update.d/workspace-display-sync).
#
# Our changes are one commit on top of upstream main. If upstream moved, we
# rebase that commit onto it. If the rebase conflicts, we undo it and stop, so
# the branch is never left half-rebased. Fix it by hand with:
#   git rebase origin/main
set -euo pipefail

PLUGIN_DIR=${WORKSPACE_DISPLAY_DIR:-$HOME/.config/omarchy/plugins/jarod.workspace-display}
BRANCH=jarod

cd "$PLUGIN_DIR"

# Never rebase over uncommitted edits.
if [[ -n $(git status --porcelain) ]]; then
  echo "workspace-display sync: uncommitted changes in $PLUGIN_DIR, skipping" >&2
  exit 1
fi

git fetch --quiet origin
git fetch --quiet fork

git checkout --quiet "$BRANCH"

if ! git rebase --quiet origin/main; then
  git rebase --abort
  echo "workspace-display sync: rebase onto origin/main conflicts, branch left unchanged." >&2
  echo "workspace-display sync: resolve with: cd $PLUGIN_DIR && git rebase origin/main" >&2
  exit 1
fi

# Keep our fork's branch and main in step with what we just built.
git push --quiet --force-with-lease fork "$BRANCH"
git push --quiet fork origin/main:refs/heads/main

echo "workspace-display sync: $BRANCH is $(git rev-parse --short HEAD), mirrored to fork."
