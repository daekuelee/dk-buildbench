#!/usr/bin/env bash
# 사용: ./ask.sh research|evals|review
# 새 컨텍스트의 Codex 가 roles/<역할>.md 하나로 답한다. 읽기 전용이라 파일을 고치지 못한다.
# 답은 docs/roles/<역할>-<시각>.md 에 남는다. 채택은 내가 정하고 worklog 에 한 줄 쓴다.
# review 는 verify.sh 를 이 터미널(샌드박스 밖)에서 먼저 돌려 결과를 붙인다. 서버를 띄워 둔다.
# 시험장 codex 가 -o 를 모르면: codex exec -s read-only "$(cat roles/review.md)" > docs/roles/review.md
set -eu
R=$1; OUT=docs/roles/$R-$(date +%H%M).md; mkdir -p docs/roles
git rev-parse --git-dir >/dev/null 2>&1 || { echo "git 저장소가 아니다. git init 먼저."; exit 1; }
if [ "$R" = review ] && [ -x ./verify.sh ]; then
  ./verify.sh 2>&1 | codex exec -s read-only -o "$OUT" "$(cat roles/$R.md)"
else
  codex exec -s read-only -o "$OUT" "$(cat roles/$R.md)"
fi
echo "→ $OUT"
