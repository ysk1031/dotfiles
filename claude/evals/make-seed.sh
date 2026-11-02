#!/bin/bash
# Creates the small repository that these eval files assume, for trigger-check's --seed-repo:
#   claude/evals/claude-md/{git-deny,sandbox-standalone,tmpdir-handoff,claude-dir-write,dotenv-shell}.json
#   claude/skills/{pr/evals/body-file,commit/evals/message-file}.json
# Usage: make-seed.sh <new-directory>
set -euo pipefail

dir=${1:?usage: make-seed.sh <new-directory>}
mkdir -p "$dir/src" "$dir/docs"
cd "$dir"
git init -q -b main
printf 'def main():\n    print("hello")\n' > src/app.py
printf 'def add(a, b):\n    return a + b\n' > src/util.py
printf '# sample app\n' > README.md
printf '# Guide\n\nUsage notes.\n' > docs/guide.md
git add src/app.py src/util.py README.md docs/guide.md
git commit -qm "initial commit"
