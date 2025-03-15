# Workspace Versioning via GitHub

## Goal
The goal of this repository is to implement workspace versioning through GitHub, leveraging Git for:
1. efficient and detailed change tracking
2. cost efficiency
3. privacy
4. rapid implementation without specialized software knowledge
5. and improved collaboration i.e through ticket systems or leveraging Github issues

## Benefits
- **Privacy and Security:** Local storage option ensures complete control over data.
- **Cost Efficiency:** Minimal additional hardware required.
- **Ease of Adoption:** Uses familiar GitHub workflows, reducing training overhead.
- **Detailed Versioning:** Granular tracking of changes.

## Storage Options (by [giftless](https://github.com/datopian/giftless "giftless"))
Choose between:
- Amazon S3 Storage
- Google Cloud Storage
- Local File Storage
- Microsoft Azure Storage

# Setup Requirements
## Prerequisites
- GitHub account
- Docker (for Giftless)
- Amazon AWS Account + IAM User

### Amazon AWS Account 
1. Create AWS S3 Bucket in your desired region (default settings suffice)
2. Create AWS IAM user
3. Create or add [IAM Policy](#iam-policy) (adjust to your AWS S3 bucket)
4. Create Access Key by modifing the recently created IAM user 

<a name="iam-policy">IAM Policy Example</a>
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::YOUR_AWS_S3_BUCKET"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::YOUR_AWS_S3_BUCKET/*"
            ]
        }
    ]
}
```

IAM Example Policy to restrict access to sub-folder in your S3 bucket
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::YOUR_AWS_S3_BUCKET"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject"
            ],
            "Resource": [
                "arn:aws:s3:::YOUR_AWS_S3_BUCKET/YOUR_SUB_FOLDER//*"
            ]
        }
    ]
}
```


## Installation & Setup

### 1. Docker & Giftless
- Install [Docker](https://www.docker.com/pricing/).
- Clone Giftless:
```bash
git clone https://github.com/datopian/giftless.git
```

### 2. Configure Giftless
Create these files in the root of your Giftless directory:
- `.env` with AWS credentials:
```env
AWS_ACCESS_KEY_ID=YOUR_IAM_ACCESSKEY
AWS_SECRET_ACCESS_KEY=YOUR_IAM_SECRET_KEY
AWS_DEFAULT_REGION=REGION_OF_YOUR_BUCKET
GIFTLESS_S3_BUCKET=NAME_OF_YOU_BUCKET
```

- Giftless configuration (`giftless.yaml`):
```yaml
DEBUG: true

AUTH_PROVIDERS:
  - giftless.auth.allow_anon:read_write

TRANSFER_ADAPTERS:
  basic:
    factory: giftless.transfer.basic_external:factory
    options:
      storage_class: giftless.storage.amazon_s3:AmazonS3Storage
      storage_options:
        aws_access_key_id: ${AWS_ACCESS_KEY_ID}
        aws_secret_access_key: ${AWS_SECRET_ACCESS_KEY}
        aws_region: ${AWS_DEFAULT_REGION}
        bucket_name: NAME_OF_YOU_BUCKET
```
> Note
> There seems to be a [bug](https://github.com/datopian/giftless/issues/185) when trying to access the bucket name through a env-variable

Details about transfer-adapters found in the [giftless docs](https://giftless.datopian.com/en/latest/configuration.html?highlight=debug)

#### Run Giftless via Docker:
Windows Powershell (start with admin priviledges)
```bash
docker run --rm -it -p 8080:8080 `
-v PATH_TO_GIFTLESS\giftless.yaml:/app/giftless.yaml `
--env-file PATH_TO_GIFTLESS\.env `
-e GIFTLESS_CONFIG_FILE=/app/giftless.yaml `
-e UWSGI_MODULE=giftless.wsgi_entrypoint `
-e UWSGI_CALLABLE=app `
--name giftless `
datopian/giftless --http 0.0.0.0:8080 `
--processes 4 --threads 4 `
--thunder-lock `
--buffer-size 65535
```

### 3. Git Configuration
Configure Git globally for consistency:
```bash
git config --system core.autocrlf false
git config --global core.autocrlf false
git config --local core.autocrlf false
git config --global core.longpaths true

git config --global fetch.pruneTags false
git config --global bufferLargeFileThreshold 50M
```
> Note
> Settings chosen by considering cross platform compatibility and factoring in possible misconfigurations during setup

Details - Unix LF vs Windows CRLF Line Endings
Read
* https://stackoverflow.com/questions/1967370/git-replacing-lf-with-crlf
* https://stackoverflow.com/questions/7156694/git-how-to-renormalize-line-endings-in-all-files-in-all-revisions

Addition - Upon error "detected dubious ownership"
`git config --global --add safe.directory PATH_TO_YOUR_REPO`

### 4. Repository Configuration
Add these files in your KNIME workspace root:

- `.gitignore`: Customizable based on needs, e.g.:
```plaintext
# Knime Metadata in Root
/.metadata/

# OS X
.DS_Store
._*

# Windows
Thumbs.db

# Exclude all .log files
**/knime.log

# Example to exclude specifc wokflow
#**/XX - Backup Knime Workspace/

#####
# Ignore all data, only upload node settings
# Uncomment below options
#####

# Exclude files named .savedWithData
#.savedWithData

# Exclude all .zip files
#*.zip

# Exclude all .gz files
#*.gz

# Exclude files or folders that match the pattern "port_*"
#**/port_*

# Exclude any internal directories
#**/internal/

# Exclude any filestore directories
#**/filestore/

# Exclude any internalTables directories
#**/internalTables/

# Exclude the data directory
#**/data/

# Exclude test data
#**/.artifacts/
```

- `.lfsconfig`:
```plaintext
[lfs]
	url = http://127.0.0.1:8080/your-repo-name
```

- `.gitattributes`:
```plaintext
**/data/** filter=lfs diff=lfs merge=lfs -text
**/filestore/** filter=lfs diff=lfs merge=lfs -text
**/internal/** filter=lfs diff=lfs merge=lfs -text
**/port_*/** filter=lfs diff=lfs merge=lfs -text
```

## Auto Commit and Push via Script
Automate tracking `.knimeLock` changes by:

1. Create shell script in the root of your Knime Workspace: .
2. Configure automatic execution via your Git client (e.g., Sourcetree).

1. Create file `auto-pr-knime-workflow-lock-files.sh` in Knime Workspace root
2. Create Custom Action in Sourcetree: Tools > Options > Custom Actions: Add 
	* Name: Commit and Push Knime Lock Files
	* Enable
		* Open in a separate window
		* Show Full Output
		* Run command silently
	* Script to run: C:\Users\YOUR_USER_NAME\AppData\Local\Atlassian\SourceTree\git_local\bin\bash.exe
	* Parameters `-c "cd $REPO && ./auto-pr-knime-workflow-lock-files.sh"`
	* Save and exit options menu
3. Click: Actions > Custom Actions: Select the newly created action to run it

### Shell Script to automatically commit and push with amend

```bash
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
```

## Recommendations
### Sourcetree 
- **Git to default Auth Method** Tools > Options > Authentication: Click on your Git Hub account and select "Set as default"
- **Auto-Update:** Enable “Refresh when application is not in focus.”
- **Performance:** Disable diff for large files (Tools > Options > Diff).

## Knime
- Save raw data, i.e. downloads, on a separte drive or folder outside of your Knime Workspace

## Repository Maintenance
Shell examples or custom actions to:
- [ ] Test on unix systems
- [ ] Maintain LFS Storage via Custom Action
- [ ] Establish new baseline via hard reset using a custom action
- [ ] Add cost example
- [ ] Test running [giftless via python](https://giftless.datopian.com/en/latest/quickstart.html) to mitigate Docker expenses for commercia use
- [ ] Check [bfg repo cleaner](https://github.com/rtyley/bfg-repo-cleaner)
- [ ] Check [git filter repo](https://github.com/newren/git-filter-repo)
- [ ] Add images to README
- [ ] Check why Custom Action to Auto-PR does not execute after cancelling it once
- [ ] Create custom action to stage only data or node settings (Request by [HaveF](https://forum.knime.com/u/HaveF))

## FAQ
### Resolve "dubious ownership" warnings (i.e. on Windows using exFAT):
```bash
git config --global --add safe.directory PATH_TO_YOUR_REPO
```

### Do not upload any data, only upload the settings
Use this gitignore
```plaintext
# Knime Metadata in Root
/.metadata/

# OS X
.DS_Store
._*

# Windows
Thumbs.db

# Exclude all .log files
**/knime.log

# Example to exclude specifc wokflow
#**/XX - Backup Knime Workspace/

#####
# Ignore all data, only upload node settings
# Uncomment below options
#####

# Exclude files named .savedWithData
.savedWithData

# Exclude all .zip files
*.zip

# Exclude all .gz files
*.gz

# Exclude files or folders that match the pattern "port_*"
**/port_*

# Exclude any internal directories
**/internal/

# Exclude any filestore directories
**/filestore/

# Exclude any internalTables directories
**/internalTables/

# Exclude the data directory
**/data/

# Exclude test data
**/.artifacts/
```

### LFS: Add files / folder to LFS afterwards
1. Ensure all changes were pushed
```shell
git add .
git commit -m "Temporary commit before migrating to Git LFS"
```

OR

```shell
git stash
```

2. Initiate LFS migrate
```shell
git lfs migrate import --include="**/EXAMPLE_FOLDER/**"
```

3. Optional: Restore if stash approach in step 1 was chosen
```shell
git stash pop
```

4. Rewrite Git history
```shell
git push --force-with-lease origin <branch-name>
```
> [!NOTE]
> `--force-with-lease` ensures your local branch matches the remote branch state you're overwriting. Preventing conflict if someone else pushed new commits after you last fetched.

5. Execute maintenance tasks
- Removes obsolete history references.
- Reduces repository size significantly.
- Prune unnecessary local LFS objects from cache

```shell
git reflog expire --expire=now --all
git gc --prune=now --aggressive
git lfs prune
```
