"""Feed synthetic commands to shell-gotchas-guard.sh and compare its verdict with the expected one.

Usage: python3 -I claude/hooks/shell-gotchas-guard.test.py
Exits non-zero when any verdict differs.
"""
import json
import pathlib
import subprocess
import sys

HOOK = pathlib.Path(__file__).with_name("shell-gotchas-guard.sh")

CASES = [
    ("deny", "B=origin/main; git show $B:app/x.rb"),
    ("deny", 'git show "$H:app/services/x.py" | head'),
    ("deny", "for c in a b; do git show $c:uv.lock; done"),
    ("allow", 'git show "${B}:app/x.rb"'),
    ("allow", "echo $PATH:/usr/local/bin"),
    ("allow", "awk -F: '{print $1:$2}' f"),
    ("allow", "echo \"host=$HOST:8080\""),
    ("deny", "echo '[{\"reply_to\": \"c_1\", \"body\": \"a\\nb\"}]' | crit comment --json"),
    ("deny", "echo '[\n  {\"reply_to\": \"r_1\", \"body\": \"x\\n\\ny\"}\n]' | crit comment --json --author 'Claude Code'"),
    ("allow", "printf '%s\\n' '[{\"body\": \"a\\nb\"}]' | crit comment --json"),
    ("allow", "echo 'line1\\nline2'"),
    ("allow", "echo '{\"a\": 1}' | jq ."),
    ("deny", "timeout 300 go test ./..."),
    ("deny", "cd app && timeout 60 docker compose run --rm app pytest"),
    ("allow", "docker compose run --rm app timeout 60 pytest"),
    ("allow", "go test -timeout 300s ./..."),
    ("allow", "grep -rn 'timeout 30' app/"),
    ("deny", "sed -n 1,5p f | cat -A"),
    ("deny", "cat -A ~/.zprofile"),
    ("allow", "cat -vet f"),
    ("allow", "docker compose exec app cat -A /etc/hosts"),
    ("allow", "grep -n 'cat -A' notes.md"),
    ("deny", 'rm -rf "$SP/fixture"'),
    ("deny", 'W="$TMPDIR/x" && rm -rf "$W" 2>/dev/null; mkdir -p "$W"'),
    ("deny", "rm -f a.txt"),
    ("deny", "rm a.txt -r"),
    ("deny", "rm --force a.txt"),
    ("deny", "for d in a b; do rm -r $d; done"),
    ("allow", "rm a.txt b/"),
    ("allow", "rm a.txt; ls -l"),
    ("allow", "rm -v a.md b.md"),
    ("allow", "rm -v -- a.md"),
    ("allow", "rm $(find . -maxdepth 1 -name 'x.*')"),
    ("allow", "git rm --cached x"),
    ("allow", "docker compose run --rm app pytest"),
    ("allow", "docker run --rm img sh -c 'apk add x\nrm -f /usr/share/a.crt'"),
    ("allow", "grep -n 'rm -rf' notes.md"),
    ("deny", "cat a.md; echo ===; cat b.md"),
    ("deny", "echo ======"),
    ("deny", 'a=x; [ "$a" == x ] && echo ok'),
    ("allow", 'echo "==="; echo \'=====\''),
    ("allow", 'a=x; [ "$a" = x ] && echo ok'),
    ("allow", '[[ $a == x ]] && echo ok'),
    ("allow", "(( n == 3 )) && echo ok"),
    ("allow", "X=1 make; git log --format=%h"),
    ("allow", "awk '$1 == 3' f"),
    ("deny", "git fetch -q origin && git rev-parse --short HEAD origin/GR-1"),
    ("deny", "git rev-parse --short $B $H; echo"),
    ("allow", "git rev-parse --short HEAD 2>/dev/null"),
    ("allow", "echo base=$(git rev-parse --short $B) main=$(git rev-parse --short origin/main)"),
    ("allow", "git rev-parse HEAD origin/main"),
    ("allow", "git rev-parse --show-toplevel"),
    ("deny", 'git grep -n "def logined?" -A3 -- app/models'),
    ("deny", "git grep -n 'scope :has_device' -A2 -- app/models/user.rb"),
    ("allow", 'git grep -n -A4 "def logged_in?" -- app'),
    ("allow", "git grep -n -A 3 'x' -- app"),
    ("allow", "git grep -n -e foo -e bar -- app"),
    ("allow", "git grep -c '' main feature/a -- src"),
    ("allow", "git grep -n foo HEAD~1 -- app"),
    ("allow", "grep -n foo -A3 f.txt"),
    ("deny", "grep -rn 'def foo' --include=*.rb app | head"),
    ("deny", "cd app && grep -rln Foo --include=*.go --include=*.json ."),
    ("deny", "git for-each-ref --format=%(refname:short) refs/heads"),
    ("deny", "grep -rn --exclude-dir=node_* foo ."),
    ("deny", "grep -rn has_job_apply? app/models"),
    ("deny", "git grep -n -e user_already_do? -- app"),
    ("allow", "grep -rn 'def foo' --include='*.rb' app"),
    ("allow", 'grep -rn foo --include="*.go" .'),
    ("allow", "grep -rn foo --include=\\*.rb ."),
    ("allow", "git for-each-ref --format='%(refname:short)' refs/heads"),
    ("allow", "grep -rn 'has_job_apply?' app/models"),
    ("allow", "ls *.md docs/*.md"),
    ("allow", "go test -run=TestFoo ./..."),
    ("allow", "git log --since=$(date +%F) --format=%h"),
    ("allow", "echo --x=${arr[1]}"),
    ("allow", "curl -s 'https://x.test/a?b=1'"),
    ("allow", "X=*.rb; arr=(a b)"),
    ("allow", "# how does it look in transcripts?\ngrep -c . f"),
]

bad = 0
for want, cmd in CASES:
    p = subprocess.run(["bash", str(HOOK)], input=json.dumps({"tool_input": {"command": cmd}}),
                       capture_output=True, text=True)
    got = "deny" if '"deny"' in p.stdout else "allow"
    if got != want or p.stderr:
        bad += 1
        print(f"NG want={want} got={got} {cmd!r}" + (f" stderr={p.stderr.strip()!r}" if p.stderr else ""))
print(f"{len(CASES) - bad}/{len(CASES)} ok")
sys.exit(1 if bad else 0)
