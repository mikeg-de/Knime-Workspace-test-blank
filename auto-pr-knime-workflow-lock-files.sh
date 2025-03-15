#!/bin/bash
set -euo pipefail

# Auto-update KNIME .knimeLock Files via Git Commit
# -------------------------------------------------

DELIM="|"
LOCK_EXT=".knimeLock"
AUTO_COMMIT_PREFIX="Auto-update .knimeLock files"

# Detect Git executable
GIT_EXE=$(command -v git)
if [[ -z "$GIT_EXE" ]]; then
  echo "[ERROR] Git executable not found."
  exit 1
fi

# Move to repository root
REPO_ROOT=$($GIT_EXE rev-parse --show-toplevel)
cd "$REPO_ROOT" || { echo "[ERROR] Cannot access repo: $REPO_ROOT"; exit 1; }
REPO_NAME=$(basename "$REPO_ROOT")

# Wait until Git index is unlocked
wait_for_git_lock() {
  while [ -f ".git/index.lock" ]; do
    echo "[WAIT] Git index.lock detected, waiting..."
    sleep 1
  done
}

# Pretty print workflows for debugging
pretty_print_list() {
  local header="$1"; shift
  local items=("$@")
  echo "$header"
  if [ "${#items[@]}" -eq 0 ]; then
    echo "  (none)"
  else
    for item in "${items[@]}"; do
      echo "  - $item"
    done
  fi
}

# Main loop
declare -A locked_workflows unlocked_workflows

echo ""
echo "Monitoring .knimeLock changes in repository: $REPO_NAME"
echo ""

while true; do
  echo ""
  echo "--------------------------------------------"
  echo "Checking for .knimeLock file changes..."
  echo "--------------------------------------------"

  wait_for_git_lock

  CURRENT_BRANCH=$($GIT_EXE rev-parse --abbrev-ref HEAD)
  echo "Current branch: $CURRENT_BRANCH"

  STATUS_OUTPUT=$($GIT_EXE status --porcelain -- "*${LOCK_EXT}" || true)

  if [ -z "$STATUS_OUTPUT" ]; then
    echo "No .knimeLock changes detected. Sleeping for 10 seconds..."
    sleep 10
    continue
  fi

  echo ""
  echo "Detected .knimeLock changes:"
  echo "$STATUS_OUTPUT"
  echo ""

  # Retrieve previous state
  LAST_COMMIT_MSG=$($GIT_EXE log -1 --pretty=%B || "")
  if [[ "$LAST_COMMIT_MSG" =~ LOCKED=(.*)\|\|UNLOCKED=(.*) ]]; then
    locked_workflows=()
    unlocked_workflows=()
    IFS="$DELIM" read -ra locked_arr <<< "${BASH_REMATCH[1]}"
    IFS="$DELIM" read -ra unlocked_arr <<< "${BASH_REMATCH[2]}"
    for wf in "${locked_arr[@]}"; do locked_workflows["$wf"]=1; done
    for wf in "${unlocked_arr[@]}"; do unlocked_workflows["$wf"]=1; done
  else
    locked_workflows=()
    unlocked_workflows=()
    echo "No previous state found. Starting fresh."
  fi

  # Process new changes
  newly_locked=()
  newly_unlocked=()

  while IFS= read -r line; do
    status_code=$(echo "$line" | cut -c1-2 | tr -d ' ')
    file=$(echo "$line" | cut -c4- | sed 's/^"//; s/"$//')
    workflow=$(basename "$(dirname "$file")")
    [ "$workflow" = "." ] && workflow="$REPO_NAME"

    if [ "$status_code" = "D" ]; then
      unset locked_workflows["$workflow"]
      unlocked_workflows["$workflow"]=1
      newly_unlocked+=("$workflow")
    else
      unset unlocked_workflows["$workflow"]
      locked_workflows["$workflow"]=1
      newly_locked+=("$workflow")
    fi
  done <<< "$STATUS_OUTPUT"

  # Debugging output
  pretty_print_list "Newly Locked Workflows:" "${newly_locked[@]}"
  pretty_print_list "Newly Unlocked Workflows:" "${newly_unlocked[@]}"

  # Build state token
  locked_str=$(printf "%s${DELIM}" "${!locked_workflows[@]}")
  unlocked_str=$(printf "%s${DELIM}" "${!unlocked_workflows[@]}")

  locked_str=${locked_str%${DELIM}}
  unlocked_str=${unlocked_str%${DELIM}}

  state_token="LOCKED=${locked_str}||UNLOCKED=${unlocked_str}"
  commit_message="${AUTO_COMMIT_PREFIX}\n${state_token}"

  echo ""
  echo "State token for commit:"
  echo "$state_token"
  echo ""

  # Stage files
  mapfile -t files_to_stage < <($GIT_EXE status --porcelain -- "*${LOCK_EXT}" | cut -c4- | sed 's/^"//; s/"$//')
  if [ ${#files_to_stage[@]} -eq 0 ]; then
    echo "No files staged. Sleeping for 10 seconds..."
    sleep 10
    continue
  fi

  echo "Staging files:"
  for file in "${files_to_stage[@]}"; do
    echo "  - $file"
  done
  $GIT_EXE add "${files_to_stage[@]}"

  # Commit if there are staged changes
  if ! $GIT_EXE diff --cached --quiet -- "*${LOCK_EXT}"; then
    if [[ "$LAST_COMMIT_MSG" == "${AUTO_COMMIT_PREFIX}"* ]]; then
      echo "Amending previous commit."
      $GIT_EXE commit --amend --allow-empty -m "$(echo -e "$commit_message")"
      echo "Pushing amended commit."
      $GIT_EXE push origin "$CURRENT_BRANCH" --force-with-lease
    else
      echo "Creating new commit."
      $GIT_EXE commit -m "$(echo -e "$commit_message")"
      echo "Pushing new commit."
      $GIT_EXE push origin "$CURRENT_BRANCH"
    fi
    echo "Commit and push completed."
  else
    echo "No changes to commit."
  fi

  echo "Iteration complete. Sleeping for 10 seconds..."
  sleep 10
done
