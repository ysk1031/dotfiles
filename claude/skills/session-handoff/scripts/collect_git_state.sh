#!/usr/bin/env bash
# 引き継ぎ doc の §0「現在地」を裏取りするための git 状態収集。
# ハッシュや status を捏造しないよう、実際の git 出力をまとめて出す。
# 使い方: bash collect_git_state.sh [直近ログ件数=10]
set -uo pipefail

N="${1:-10}"

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "${ROOT}" ]; then
  echo "(git リポジトリではありません — §0 の git パートは省略)"
  exit 0
fi
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
