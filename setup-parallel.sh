#!/usr/bin/env bash
# 사용: bash /과제/경로/setup-parallel.sh main|files|--headless [MODEL [EFFORT]]
# 모델을 생략하면 현재 Codex 설정을 따른다. Codex 세션 밖의 셸에서 실행한다.
set -u

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
SELF="$ROOT/$(basename -- "${BASH_SOURCE[0]}")"
cd -- "$ROOT" || exit 1

status() {
  printf '%s\n' "$2" > "$1.tmp"
  mv -- "$1.tmp" "$1"
}

# 별도 프로세스로 남아 메인 세션 종료와 무관하게 자료 보고를 마친다.
if [[ ${1:-} == --worker ]]; then
  RUN=${2:?}; MODEL=${3:-}; EFFORT=${4:-}
  case "$RUN" in "$ROOT"/docs/roles/setup-*) ;; *) exit 2 ;; esac
  mkdir "$RUN/materials.lock" 2>/dev/null || { printf '이 실행의 자료 담당은 이미 시작됐습니다.\n' >&2; exit 2; }
  status "$RUN/materials.status" running
  options=(-C "$ROOT")
  [[ -n "$MODEL" ]] && options+=(-m "$MODEL")
  [[ -n "$EFFORT" ]] && options+=(-c "model_reasoning_effort=\"$EFFORT\"")
  worker_child=''
  stop_worker() {
    [[ -n "$worker_child" ]] && kill "$worker_child" 2>/dev/null || true
    status "$RUN/materials.status" interrupted
    exit 130
  }
  trap stop_worker INT TERM
  codex exec "${options[@]}" -s read-only --json \
    -o "$RUN/materials.pending.md" - \
    < "$RUN/materials-prompt.txt" > "$RUN/worker.jsonl" 2> "$RUN/worker.stderr" &
  worker_child=$!
  wait "$worker_child"
  result=$?
  if [[ $result == 0 && -s "$RUN/materials.pending.md" ]]; then
    mv -- "$RUN/materials.pending.md" "$RUN/materials.md"
    status "$RUN/materials.status" complete
  else
    [[ $result == 0 ]] && result=1
    status "$RUN/materials.status" "failed:$result"
  fi
  exit "$result"
fi

MODE=main
case ${1:-} in
  main|files) MODE=$1; shift ;;
  --headless) MODE=headless; shift ;;
esac
if [[ ${1:-} == --help || $# -gt 2 || ${1:-} == --* ]]; then
  printf '사용: bash /과제/경로/setup-parallel.sh main|files|--headless [MODEL [EFFORT]]\n'
  [[ ${1:-} == --help ]] && exit 0
  exit 2
fi
MODEL=${1:-}; EFFORT=${2:-}
if [[ -n "$EFFORT" && ! "$EFFORT" =~ ^[a-z]+$ ]]; then
  printf 'effort 값은 Codex에서 지원하는 영문 설정값이어야 합니다.\n' >&2
  exit 2
fi
for file in README.md AGENTS.md docs/state.md roles/materials.md .agents/skills/setup/SKILL.md; do
  [[ -f "$file" ]] || { printf '설치된 과제 폴더가 아닙니다: %s 없음\n' "$file" >&2; exit 1; }
done
command -v codex >/dev/null || { printf 'codex 명령을 찾을 수 없습니다.\n' >&2; exit 1; }
git rev-parse --git-dir >/dev/null 2>&1 || { printf '과제 폴더에 git 저장소가 없습니다.\n' >&2; exit 1; }
mkdir -p docs/roles
if [[ "$MODE" == files ]]; then
  [[ -f docs/roles/setup-active ]] || { printf '먼저 다른 터미널에서 setup-parallel.sh main을 실행하세요.\n' >&2; exit 1; }
  IFS= read -r RUN < docs/roles/setup-active
  case "$RUN" in "$ROOT"/docs/roles/setup-*) ;; *) printf '현재 과제의 자료 실행 경로가 아닙니다. main을 새로 시작하세요.\n' >&2; exit 1 ;; esac
  [[ -d "$RUN" && -f "$RUN/materials-prompt.txt" ]] || { printf '자료 실행 기록이 없습니다. main을 먼저 실행하세요.\n' >&2; exit 1; }
  [[ -n "$MODEL" ]] || IFS= read -r MODEL < "$RUN/model"
  [[ -n "$EFFORT" ]] || IFS= read -r EFFORT < "$RUN/effort"
  printf '작업 폴더: %s\n자료 보고: %s/materials.md\n' "$ROOT" "$RUN"
  bash "$SELF" --worker "$RUN" "$MODEL" "$EFFORT"
  result=$?
  [[ -f "$RUN/materials.md" ]] && cat "$RUN/materials.md"
  printf '\n자료 상태: %s/materials.status\n' "$RUN"
  exit "$result"
fi
RUN=$(mktemp -d "$ROOT/docs/roles/setup-$(date +%Y%m%d-%H%M%S)-XXXXXX") || exit 1
printf 'root=%s\nmodel=%s\neffort=%s\nmode=%s\n' "$ROOT" "${MODEL:-current-config}" "${EFFORT:-current-config}" "$MODE" > "$RUN/run.txt"
printf '%s\n' "$MODEL" > "$RUN/model"
printf '%s\n' "$EFFORT" > "$RUN/effort"
status "$RUN/materials.status" waiting
status "$RUN/main.status" running
{
  printf '$setup read files\n'
  cat roles/materials.md
  printf '\n작업 루트: %s\n이번 실행: %s\n' "$ROOT" "$RUN"
} > "$RUN/materials-prompt.txt"
{
  cat <<'PROMPT'
$setup read main
자료 담당은 별도 읽기 전용 세션으로 맡는다. 사용자에게 보여 주는 설명과 문서는 한국어로 쓴다.
README·기존 합의·자료 목록으로 큰 업무 흐름과 핵심 빈 곳부터 이해하고, 첫 질문·이유와 Q별 답변 칸을 먼저 전달한다. 자료 담당의 완료를 기다렸다가 첫 질문을 주지 않는다.
자료 본문 확인은 자료 담당이 맡는다. 같은 자료를 다시 전부 읽지 말고, 필요한 보고 근거만 국소 확인한다. 필요한 환경 확인과 메인 기록은 직접 맡는다. 파트너에게 보낼 질문은 큰 흐름·범위·성공 기준부터 좁혀 고른다.
자료 상태가 complete면 materials.md를 읽어 필요한 근거를 통합한다. waiting 또는 running이면 반복 조회·sleep으로 기다리지 말고 현재 read를 '자료 결과 대기'로 기록해 사용자에게 넘긴다. waiting이면 다른 터미널에서 setup-parallel.sh files를 실행하면 된다. 준비도를 완성하려고 근거를 만들지 않는다. failed 또는 interrupted면 한계를 보고하고 필요한 후속 확인을 제안한다.
사용자가 편집 중인 Q별 원문 영역을 다시 쓰지 않는다. 채팅으로 새 답·판단을 받으면 최신 기록을 읽고 원문 영역과 분리해 해당 Q에 즉시 연결한다. 자료 보고가 나중에 끝나도 자동으로 fill·후속 수정·구현을 실행하지 않는다. 이후 사용자의 fill 또는 이어가기 요청에서 최신 답과 보고를 함께 반영한다. 자료 보고는 관찰이며 파트너 답이나 사용자 결정으로 바꾸지 않는다.
PROMPT
  printf '\n작업 루트: %s\n자료 상태: %s/materials.status\n자료 보고: %s/materials.md\n자료 실행 기록: %s\n' "$ROOT" "$RUN" "$RUN" "$RUN"
} > "$RUN/main-prompt.txt"
status "$ROOT/docs/roles/setup-active" "$RUN"

# stdout을 메인 화면과 섞지 않고, 터미널이 끝나도 완료 결과를 보존한다.
WORKER_PID=''
if [[ "$MODE" == headless ]]; then
  nohup bash "$SELF" --worker "$RUN" "$MODEL" "$EFFORT" \
    > "$RUN/worker-launch.log" 2>&1 < /dev/null &
  WORKER_PID=$!
  printf '%s\n' "$WORKER_PID" > "$RUN/worker.pid"
fi
printf '작업 폴더: %s\n자료 상태: %s/materials.status\n자료 보고: %s/materials.md\n메인 기록: %s\n' "$ROOT" "$RUN" "$RUN" "$RUN"
stop_run() {
  [[ -n "$WORKER_PID" ]] && kill "$WORKER_PID" 2>/dev/null || true
  status "$RUN/main.status" interrupted
  exit 130
}
trap stop_run INT TERM
options=(-C "$ROOT")
[[ -n "$MODEL" ]] && options+=(-m "$MODEL")
[[ -n "$EFFORT" ]] && options+=(-c "model_reasoning_effort=\"$EFFORT\"")
if [[ "$MODE" == headless ]]; then
  codex exec "${options[@]}" -s workspace-write --json \
    -o "$RUN/main-response.md" - \
    < "$RUN/main-prompt.txt" > "$RUN/main.jsonl" 2> "$RUN/main.stderr"
else
  codex "${options[@]}" -s workspace-write "$(cat "$RUN/main-prompt.txt")"
fi
result=$?
status "$RUN/main.status" "exited:$result"
printf '\n메인 종료: %s. 자료 상태: %s/materials.status\n' "$result" "$RUN"
exit "$result"
