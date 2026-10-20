#!/usr/bin/env bash
# Bring the jarod branch up to date with upstream, then push it to our fork.
#
# Run by hand, or from `omarchy update` through the post-update hook
# (~/.config/omarchy/hooks/post-update.d/workspace-display-sync).
#
# Our changes are commits on top of upstream main. If upstream moved, we
# rebase that commit onto it. If the rebase conflicts, we undo it and stop, so
# the branch is never left half-rebased. Fix it by hand with:
#   git rebase origin/main
#
# The omarchy-4.5 branch (Omarchy 4.5's per-monitor workspace blocks) sits on
# top of jarod and is rebased with it, but stays local. It's what the live
# plugin runs once Omarchy 4.5 is installed, until it's merged into jarod.
set -euo pipefail

PLUGIN_DIR=${WORKSPACE_DISPLAY_DIR:-$HOME/.config/omarchy/plugins/jarod.workspace-display}
BRANCH=jarod
NEXT=omarchy-4.5

cd "$PLUGIN_DIR"

# Never rebase over uncommitted edits.
if [[ -n $(git status --porcelain) ]]; then
  echo "workspace-display sync: uncommitted changes in $PLUGIN_DIR, skipping" >&2
  exit 1
fi

start=$(git branch --show-current)

git fetch --quiet origin
git fetch --quiet fork

git checkout --quiet "$BRANCH"
before=$(git rev-parse HEAD)

if ! git rebase --quiet origin/main; then
  git rebase --abort
  echo "workspace-display sync: rebase onto origin/main conflicts, branch left unchanged." >&2
  echo "workspace-display sync: resolve with: cd $PLUGIN_DIR && git rebase origin/main" >&2
  exit 1
fi

# Our fork's main carries our work too, so both get the rebased branch.
git push --quiet --force-with-lease fork "$BRANCH"
git push --quiet --force-with-lease=main:fork/main fork "$BRANCH:main"

echo "workspace-display sync: $BRANCH is $(git rev-parse --short HEAD), pushed to fork $BRANCH and main."

git rev-parse --verify --quiet "refs/heads/$NEXT" >/dev/null || exit 0

if ! git rebase --quiet --onto "$BRANCH" "$before" "$NEXT"; then
  git rebase --abort
  git checkout --quiet "$BRANCH"
  echo "workspace-display sync: rebasing $NEXT onto $BRANCH conflicts, $NEXT left unchanged." >&2
  echo "workspace-display sync: resolve with: cd $PLUGIN_DIR && git rebase --onto $BRANCH $before $NEXT" >&2
  exit 1
fi

# Stay on $NEXT if it was checked out, or once Omarchy 4.5 is installed.
if [[ $start == "$NEXT" || -f ${OMARCHY_PATH:-/usr/share/omarchy}/default/hypr/monitor-workspaces.lua ]]; then
  echo "workspace-display sync: $NEXT is $(git rev-parse --short HEAD), checked out (local only)."
else
  git checkout --quiet "$BRANCH"
fi
