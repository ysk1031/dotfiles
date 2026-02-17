---
name: fix-ci
description: Diagnose and fix failed GitHub Actions workflow runs on the current branch. Use when CI is failing and the user wants to identify and fix the cause.
allowed-tools: Task, AskUserQuestion, Bash
argument-hint: [run-id or workflow-name]
---

# CI Failure Diagnosis & Fix Skill

Diagnose failed GitHub Actions workflow runs, identify the root cause, propose a fix plan, and implement it — with user confirmation at each step.

## Instructions

### Phase 1: Data Collection (use Task with Bash subagent)

Call the Task tool with:
- subagent_type: "Bash"
- description: "collect CI failure logs"
- prompt: Include the subagent prompt below, replacing $ARGUMENTS with actual arguments

The subagent will return collected failure data (or an error/status).

#### Subagent Prompt Template

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

---

### Phase 2: Hypothesis Formation (use Task with general-purpose subagent)

If Phase 1 returned an error status (`GH_AUTH_REQUIRED`, `NO_REPO`, `NO_REMOTE`, `NO_FAILED_RUNS`, `RUN_NOT_FOUND`), display the message to the user and stop. Do NOT proceed to Phase 2.

Call the Task tool with:
- subagent_type: "general-purpose"
- description: "analyze CI failure cause"
- prompt: Include the subagent prompt below, with Phase 1 data embedded

#### Subagent Prompt Template

You are a CI failure analyst. Analyze the following GitHub Actions failure data and form a hypothesis about the root cause.

**CI Failure Data**:
<paste entire Phase 1 output here>

**Additional context from user** (if any, from a retry with hint):
<paste user hint here, or "None">

**Step 1: Error Pattern Analysis**

Analyze the failure logs and classify the error into one of these categories:
- BUILD_ERROR: Compilation or build failure
- TEST_FAILURE: Test assertion or test execution failure
- LINT_ERROR: Linting or formatting violation
- DEPENDENCY_ERROR: Missing or incompatible dependency
- ENV_CONFIG_ERROR: Environment variable or configuration issue
- WORKFLOW_ERROR: GitHub Actions workflow YAML issue
- TIMEOUT: Job or step timeout
- FLAKY: Intermittent/non-deterministic failure (race condition, network, etc.)
- OTHER: None of the above

**Step 2: Codebase Investigation**

Based on error messages, investigate the codebase:
- Search for file paths and line numbers mentioned in the error logs using Read, Grep, and Glob
- Check if the error references specific functions or modules
- Look at recent changes: run `git diff HEAD~3..HEAD -- <affected-files>` via Bash to see if recent commits caused the issue

**Step 3: Flaky Test Detection**

If the error looks like a timeout, race condition, or network-related intermittent failure:
- Set CONFIDENCE to LOW
- Note that a re-run might resolve it

**Step 4: Multiple Job Failure Analysis**

If multiple jobs failed:
- Determine if failures are independent (different root causes) or cascading (one root cause)
- If independent, form separate hypotheses for each
- If cascading, identify the root cause

**Step 5: Form Hypothesis**

Return in this format:
```
STATUS: OK
CATEGORY: <failure category from Step 1>
HYPOTHESIS: <1-3 sentence explanation of the root cause in Japanese>
EVIDENCE:
- <evidence 1>
- <evidence 2>
- <evidence 3>
AFFECTED_FILES:
- <file path 1>
- <file path 2>
CONFIDENCE: <HIGH/MEDIUM/LOW>
SUGGESTED_ACTION: <brief description of what needs to change>
```

If the cause cannot be determined:
```
STATUS: UNCLEAR
PARTIAL_ANALYSIS: <what you could determine in Japanese>
EVIDENCE:
- <evidence 1>
POSSIBLE_CAUSES:
- <possible cause 1>
- <possible cause 2>
```

---

### Phase 3: User Confirmation of Hypothesis (main agent)

**STATUS: OK from Phase 2**:

Display the hypothesis to the user in a clear format:

```
## CI失敗の診断結果

**ワークフロー**: <workflow name>
**カテゴリ**: <category>
**確信度**: <confidence>

### 原因の仮説
<hypothesis>

### 根拠
<evidence list>

### 影響ファイル
<affected files list>
```

If CONFIDENCE is LOW and CATEGORY is FLAKY or TIMEOUT, add a note:
"この失敗はフレーキーテスト（非決定的な失敗）の可能性があります。再実行で解決する場合があります。"

Use AskUserQuestion:
- question: "この診断結果に基づいて修正プランを作成しますか？"
- header: "Diagnosis"
- options:
  1. label: "修正プランを作成", description: "この仮説に基づいて修正プランを作成します"
  2. label: "ヒントを追加して再分析", description: "追加情報を提供して再分析します（Otherで入力）"
  3. label: "キャンセル", description: "診断を終了します"

**If "修正プランを作成"**: Proceed to Phase 4
**If "ヒントを追加して再分析"**: User provides additional context via "Other". Re-run Phase 2 with the original Phase 1 data PLUS user's hint. Do NOT re-run Phase 1.
**If "キャンセル"**: Print "CI診断を終了しました。" and stop.

**STATUS: UNCLEAR from Phase 2**:

Display the partial analysis:

```
## CI失敗の部分分析

原因を特定できませんでした。

### 判明していること
<partial analysis>

### 可能性のある原因
<possible causes>
```

Use AskUserQuestion:
- question: "原因を特定できませんでした。どうしますか？"
- header: "Diagnosis"
- options:
  1. label: "ヒントを追加して再分析", description: "追加情報を提供して再分析します（Otherで入力）"
  2. label: "ブラウザでログを確認", description: "GitHub Actionsのログをブラウザで開きます"
  3. label: "キャンセル", description: "診断を終了します"

**If "ヒントを追加して再分析"**: Re-run Phase 2 with hint
**If "ブラウザでログを確認"**: Run `gh run view <run-id> --web` via Bash, then print "CI診断を終了しました。" and stop.
**If "キャンセル"**: Print "CI診断を終了しました。" and stop.

---

### Phase 4: Fix Plan Creation (use Task with general-purpose subagent)

Call the Task tool with:
- subagent_type: "general-purpose"
- description: "create CI fix plan"
- prompt: Include the subagent prompt below

#### Subagent Prompt Template

You are a CI fix planner. Based on the approved hypothesis, create a concrete fix plan.

**Approved Hypothesis**:
CATEGORY: <category>
HYPOTHESIS: <hypothesis>
EVIDENCE: <evidence list>
AFFECTED_FILES: <file list>
SUGGESTED_ACTION: <action>

**CI Failure Data (from Phase 1)**:
<paste Phase 1 output>

**Step 1: Read Affected Files**

Read each affected file in full to understand the current code.

**Step 2: Determine Specific Changes**

For each file that needs modification:
- Identify exact lines or sections to change
- Determine what the new code should be
- Check for side effects or related files that might also need changes

**Step 3: Check for Related Files**

Look for:
- Test files related to changed source files
- Configuration files that might need updates
- Import/dependency changes needed

**Step 4: Plan Verification Steps**

Determine how the user can verify the fix locally before pushing.

**Step 5: Return Fix Plan**

Return in this format:
```
STATUS: OK
CHANGES:
1. FILE: <path>
   ACTION: <modify/create/delete>
   DESCRIPTION: <what to change and why, in Japanese>
   DETAIL: <specific code change description or diff-like snippet>
2. FILE: <path>
   ACTION: <modify/create/delete>
   DESCRIPTION: <what to change and why, in Japanese>
   DETAIL: <specific code change description or diff-like snippet>

VERIFICATION: <how to verify the fix locally, in Japanese>
```

If the fix is not straightforward or requires more information:
```
STATUS: NEEDS_INFO
QUESTION: <what additional information is needed, in Japanese>
```

---

### Phase 5: User Confirmation of Fix Plan (main agent)

**STATUS: NEEDS_INFO from Phase 4**: Display the question and use AskUserQuestion to get the answer, then re-run Phase 4 with the additional information.

**STATUS: OK from Phase 4**:

Display the fix plan in a clear format:

```
## 修正プラン

<for each change>
### <N>. `<file path>` (<action>)
<description>

```
<detail>
```

</for each>

### 検証方法
<verification>
```

Use AskUserQuestion:
- question: "この修正プランを適用しますか？"
- header: "Fix Plan"
- options:
  1. label: "適用する", description: "修正を実行します"
  2. label: "修正を指示", description: "プランを調整します（Otherで入力）"
  3. label: "キャンセル", description: "修正せずに終了します"

**If "適用する"**: Proceed to Phase 6
**If "修正を指示"**: User provides modification via "Other". Re-run Phase 4 with the original hypothesis + user's modification instructions.
**If "キャンセル"**: Print "修正をキャンセルしました。" and stop.

---

### Phase 6: Implementation (main agent)

Apply the approved fix plan directly (main agent uses Edit/Write tools, NOT a subagent):

1. For each change in the plan:
   - **modify**: Use Read to read the file, then use Edit to make the changes
   - **create**: Use Write to create the new file
   - **delete**: Use Bash `rm` to delete the file (confirm with user first)

2. After all changes are applied, show a summary:
   ```bash
   git diff --stat
   ```

3. Display completion message:

```
## 修正完了

<list of changed files>

### 検証方法
<verification steps>

### 次のステップ
- 検証方法に従ってローカルで動作確認してください
- 問題なければ `/commit` でコミットできます
- CIを再実行するには `git push` してください
```

**IMPORTANT**: Do NOT commit, push, or perform any git operations beyond `git diff --stat`. Leave that to the user.

---

### Rules

- ALWAYS display messages in Japanese
- NEVER commit or push changes — only apply file modifications
- NEVER skip user confirmation steps (Phase 3 and Phase 5)
- When retrying Phase 2 with a hint, reuse Phase 1 data — do NOT re-collect logs
- Log truncation threshold: 200 lines per job
- If `gh` commands fail with permission errors, suggest the user check their GitHub token permissions
- Keep subagent prompts focused — include only the data each subagent needs
- For FLAKY/TIMEOUT failures with LOW confidence, suggest re-running the workflow before attempting code fixes
