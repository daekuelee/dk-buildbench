#!/usr/bin/env bash
# 등록: verify-cases.sh. 기대값·출처·범위: docs/evals.md.
# 키·개인정보를 검사 출력에 넣지 않는다. 로그는 실행별 로컬 보관이다.
set -uo pipefail
umask 077
VERIFY_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P) || exit 3
cd -- "$VERIFY_ROOT" || exit 3
BASE=${BASE:-http://localhost:8000}
VERIFY_CASES_FILE=${VERIFY_CASES_FILE:-$VERIFY_ROOT/verify-cases.sh}
VERIFY_LOG_ROOT=${VERIFY_LOG_ROOT:-$VERIFY_ROOT/docs/verification}
mkdir -p -- "$VERIFY_LOG_ROOT" || exit 3
VERIFY_RUN=$(mktemp -d "$VERIFY_LOG_ROOT/run-$(date +%Y%m%d-%H%M%S)-XXXXXX") || exit 3
PASS=0; FAIL=0; CHECK_COUNT=0
printf 'id\tresult\texit_code\tname\n' > "$VERIFY_RUN/summary.tsv" || exit 3

check_command() {
  local name=${1:-unnamed}; shift || true
  local id code safe_name
  CHECK_COUNT=$((CHECK_COUNT + 1)); printf -v id '%03d' "$CHECK_COUNT"
  if (( $# == 0 )); then
    printf 'check_command requires a command\n' > "$VERIFY_RUN/$id.stderr"
    : > "$VERIFY_RUN/$id.stdout"; code=2
  elif (set -o pipefail; "$@") > "$VERIFY_RUN/$id.stdout" 2> "$VERIFY_RUN/$id.stderr"; then
    code=0
  else
    code=$?
  fi
  printf '%s\n' "$code" > "$VERIFY_RUN/$id.exit" || exit 3
  safe_name=${name//$'\n'/ }; safe_name=${safe_name//$'\r'/ }; safe_name=${safe_name//$'\t'/ }
  if (( code == 0 )); then
    PASS=$((PASS + 1))
    printf '%s\tPASS\t%s\t%s\n' "$id" "$code" "$safe_name" >> "$VERIFY_RUN/summary.tsv" || exit 3
    printf 'PASS %s %s\n' "$id" "$safe_name"
  else
    FAIL=$((FAIL + 1))
    printf '%s\tFAIL\t%s\t%s\n' "$id" "$code" "$safe_name" >> "$VERIFY_RUN/summary.tsv" || exit 3
    printf 'FAIL %s %s (exit %s)\n' "$id" "$safe_name" "$code"
  fi
  return 0
}

# 기존 check 이름 "셸 문자열" 지원. 신뢰한 로컬 검사만 전달한다.
_verify_shell() { eval "$1"; }
check() {
  local name=${1:-unnamed}; shift || true
  if (( $# == 0 )); then check_command "$name"; else check_command "$name" _verify_shell "$*"; fi
}
if [[ ! -f "$VERIFY_CASES_FILE" ]]; then
  printf '검사 등록 파일 없음: %s\n' "$VERIFY_CASES_FILE" >&2; exit 3
fi
if source "$VERIFY_CASES_FILE"; then :; else
  printf '검사 등록 파일 실행 오류. 실행 기록: %s\n' "$VERIFY_RUN" >&2; exit 3
fi
printf 'PASS=%s FAIL=%s\n실행 기록: %s\n' "$PASS" "$FAIL" "$VERIFY_RUN"
if (( CHECK_COUNT == 0 )); then
  printf '검사 없음: 성공 조건에 필요한 검사를 먼저 정한다.\n'; exit 2
fi
(( FAIL == 0 ))
