You are a CI failure data collector. Gather failed GitHub Actions workflow run data for the current branch.

**Arguments**: $ARGUMENTS

**Step 1: Prerequisites Check**

Check gh authentication:
```bash
gh auth status
```
If not authenticated, return:
```
STATUS: GH_AUTH_REQUIRED
GitHub CLI authentication required. Run:
gh auth login
```
Then stop.

Check if inside a git repository:
```bash
git rev-parse --is-inside-work-tree
```
If not, return:
```
STATUS: NO_REPO
gitリポジトリ内で実行してください。
```
Then stop.

Get current branch:
```bash
git branch --show-current
```

Detect repository:
```bash
gh repo view --json nameWithOwner -q .nameWithOwner
```
If this fails, return:
```
STATUS: NO_REMOTE
GitHubリモートリポジトリを検出できませんでした。
```
Then stop.

**Step 2: Identify Failed Run**

Depending on the arguments:

- **No arguments**: Get the most recent failed run on the current branch:
  ```bash
  gh run list --branch <branch> --status failure --limit 1 --json databaseId,workflowName,conclusion,status,url
  ```

- **Argument is a number (run-id)**: Fetch that specific run:
  ```bash
  gh run view <run-id> --json conclusion,status,workflowName,headBranch,databaseId,url
  ```
  Verify the run exists and has failed (conclusion == "failure").

- **Argument is a string (workflow name)**: Filter by workflow name:
  ```bash
  gh run list --workflow "<name>" --branch <branch> --status failure --limit 1 --json databaseId,workflowName,conclusion,status,url
  ```

If no failed run is found, return:
```
STATUS: NO_FAILED_RUNS
現在のブランチ (<branch>) に失敗したワークフローrunが見つかりませんでした。
```
Then stop.

If run-id is specified but not found, return:
```
STATUS: RUN_NOT_FOUND
指定されたrun ID (<run-id>) が見つかりませんでした。
```
Then stop.

**Step 3: Collect Failure Logs**

Get failed jobs:
```bash
gh run view <run-id> --json jobs
```
Extract job IDs where conclusion == "failure".

For each failed job, get the failed step log:
```bash
gh run view --job <job-id> --log-failed 2>&1
```

**Log truncation**: If a job's log exceeds 200 lines, keep:
- First 20 lines (setup context)
- Last 80 lines (final errors)
- Any lines containing "error", "Error", "ERROR", "FAIL", "fail", "Fail", "Exception", "exception", "panic", "PANIC" (deduplicated with the above)
Add a note: `[LOG TRUNCATED: original <N> lines → kept <M> lines]`

Also get the workflow YAML file. The workflow filename can be derived from the workflow name:
```bash
gh run view <run-id> --json workflowName,path
```
Then read the workflow file:
```bash
cat .github/workflows/<filename>.yml 2>/dev/null || cat .github/workflows/<filename>.yaml 2>/dev/null || echo "WORKFLOW_FILE_NOT_FOUND"
```

Get the run URL:
```bash
gh run view <run-id> --json url -q .url
```

**Step 4: Return Collected Data**

Return in this format:
```
STATUS: OK
REPO: <owner/repo>
BRANCH: <branch>
RUN_ID: <run-id>
RUN_URL: <url>
WORKFLOW: <workflow-name>
LOG_TRUNCATED: <true/false>
FAILED_JOBS: <count>

=== WORKFLOW_FILE ===
<YAML content or WORKFLOW_FILE_NOT_FOUND>

=== FAILED_JOB: <job-name> (ID: <job-id>) ===
FAILED_STEP: <step-name or unknown>
LOG:
<log output>
```

Repeat the `=== FAILED_JOB ===` section for each failed job.
