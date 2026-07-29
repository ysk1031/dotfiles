#!/usr/bin/env bash
# 引き継ぎ doc の §0「現在地」を裏取りし、doc の置き場所候補を洗い出す。
# ハッシュや status を捏造しないよう、実際の git 出力をまとめて出す。
# 使い方: bash collect_state.sh [直近ログ件数=10]
set -uo pipefail

N="${1:-10}"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -n "${ROOT}" ]; then
  cd "${ROOT}"
  echo "=== repo root ==="
  echo "${ROOT}"
  echo
  echo "=== branch ==="
  git branch --show-current
  echo
  echo "=== recent log (${N}) ==="
  git log --oneline -"${N}"
  echo
  echo "=== working tree (status --short) ==="
  if [ -z "$(git status --short)" ]; then
    echo "(クリーン: 未コミットの変更なし)"
  else
    git status --short
  fi
  echo
  echo "=== uncommitted changes vs HEAD (diff --stat) ==="
  if git diff --stat HEAD | grep -q .; then
    git diff --stat HEAD
  else
    echo "(追跡ファイルに未コミット差分なし)"
  fi
  echo
else
  echo "(git リポジトリではありません — §0 の git パートは省略)"
  echo
fi

# 以下は doc の置き場所を既存の慣習に合わせるための材料。
# 出力が膨らんで context を食い返さないよう head で打ち切る。
echo "=== existing handoff/summary docs ==="
find . -type f -name '*.md' \
  \( -iname '*handoff*' -o -iname '*summary*' -o -iname '*引き継ぎ*' \) \
  -not -path '*/node_modules/*' 2>/dev/null | head -30
echo
echo "=== candidate doc directories ==="
find . -type d \( -name docs -o -name summary -o -name handoff \) \
  -not -path '*/node_modules/*' 2>/dev/null | head -30
