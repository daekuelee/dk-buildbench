# 하네스 v0.2 시작 안내

이 폴더는 특정 과제의 답이 아닌 일반 하네스다. 공통 지침·스킬·toolkit·빈 작업 기록·검증 실행기를 함께 유지한다.

## 사용 위치

- 기존 메인에 덮어쓰지 않는다. 별도 작업 폴더에 이 폴더의 내용을 배치한 뒤 현재 과제 README·자료를 별도로 둔다.
- 과제 자료 없이 하네스 설명·선택 흐름만 모의할 수도 있다. 이 경우 앱 구현은 시작하지 않는다.
- 새 세션에서 이 폴더의 AGENTS.md와 관련 스킬 지침을 실제로 읽었는지 확인한다. 다른 폴더의 스킬이 선택되거나 기존 세션에 이전 지침이 남아 있다면 적용 경로부터 맞춘다.
- 배치만으로 설치·의존성 설치·모델 호출을 시작하지 않는다. 자동 설치기는 없으며 선택적 실행기는 직접 호출할 때만 동작한다. 실행 모델과 환경은 실제 세션에서 확인한다.

## 제한된 작업 환경에 가져갈 때

- 현재 안내에서 공개 자료 반입·로컬 업로드·외부 전송·AI 사용 시점을 구분한다. 로컬에서 준비했다는 사실만으로 반입이 허용되지는 않는다. 실제 공개된 경로와 버전을 확인한다.
- 제공 과제의 README·기존 지침·작업 기록을 덮어쓰지 않는다. 내려받은 하네스 위치와 실제 작업 루트, 적용할 지침·스킬 경로를 구분한다. 스킬이 자동 인식됐다고 가정하지 않는다.
- 제공된 AI·모델·권한 범위를 확인한다. 선택적 ask.sh·setup-parallel.sh는 현재 설정을 물려받거나 지정한 모델을 호출할 수 있다. 보조 실행까지 같은 허용 범위인지 확인하기 전에는 호출하지 않는다. 개인 인증·플랫폼 설정 변경으로 차단을 우회하지 않는다.
- 병렬 호출은 필수가 아니다. 호출 수·응답 대기·토큰·메모리 부담을 고려하고 한 세션으로도 진행할 수 있다.
- 후속 독립 답변에서 AI가 금지된다면 prep은 그 전에 마친다. 금지 단계의 문항·답안 작성에는 사용하지 않는다.

반입·배치가 끝났다는 것과 모델이 지침을 따르는 것은 다르다. 적용 경로를 읽고 작은 요청으로 동작을 확인한 뒤 과제 작업으로 들어간다.

## 공개 후 처음 배치하는 명령

`dk-buildbench` 저장소 루트에 이 kit의 내용이 공개된 뒤 사용한다. **제공 IDE의 과제 작업 폴더에서, Codex 세션 밖의 Bash 터미널**에 붙인다. 이 세션처럼 Codex 샌드박스가 `.agents`·`.git`을 읽기 전용으로 두면 스킬 배치·저장소 초기화가 막힐 수 있기 때문이다. 관리자가 막은 권한을 우회하라는 뜻은 아니다.

기존 파일은 `--skip-old-files`로 보존한다. 아래는 첫 배치용이며 기존 하네스의 업그레이드 명령이 아니다. 핵심 파일이 이미 있고 공개본과 다르면 보존한 채 중단한다. 나머지 기존 파일도 자동 갱신되지 않으므로 충돌은 내용을 비교해 해결한다. `git init`은 Git 프로그램 설치가 아니라 현재 작업 폴더가 아직 저장소가 아닐 때의 초기화다.

```bash
(
  set -euo pipefail
  kit_checkout=$(mktemp -d)
  git clone --depth 1 https://github.com/daekuelee/dk-buildbench.git "$kit_checkout/repo"
  tar -C "$kit_checkout/repo" --exclude=.git -cf - . |
    tar --skip-old-files -xf -
  git rev-parse --git-dir >/dev/null 2>&1 || git init -q

  for file in AGENTS.md .gitattributes verify.sh verify-cases.sh \
    .agents/skills/{setup,research,explain,jarvis}/SKILL.md; do
    if ! cmp -s "$kit_checkout/repo/$file" "$file"; then
      printf '배치 확인 필요: %s (기존 파일 보존 또는 누락)\n' "$file" >&2
      exit 1
    fi
  done

  verify_status=0
  verify_output=$(bash verify.sh 2>&1) || verify_status=$?
  printf '%s\n' "$verify_output"
  if [[ "$verify_status" != 2 || "$verify_output" != *'검사 없음:'* ]]; then
    printf '예상한 빈 검사 상태가 아닙니다. 위 오류·검사 결과를 확인하세요.\n' >&2
    exit 1
  fi
  printf '첫 배치와 빈 검사 상태를 확인했습니다. 새 Codex 세션을 엽니다.\n'
  codex
)
```

`검사 없음:`과 종료 2는 실행기가 동작하고 등록 검사가 비어 있다는 뜻이며 앱 통과가 아니다. 새 Codex에서 실제로 읽은 AGENTS·스킬 경로를 확인한다. 공개 저장소 접근과 시험 환경에서의 인식은 로컬 배치 검사만으로 확인되지 않는다.

## 검증 실행기

`bash verify.sh`는 현재 과제의 `verify-cases.sh`를 실행한다. 등록 검사가 없으면 종료 2이며 성공이 아니다. 검사 기대값·출처·범위는 docs/evals.md에 먼저 연결한다. 실행별 실제 결과는 docs/verification에 남는다.

새 검사는 `check_command "검사 ID와 이름" 명령 인자...` 형태로 등록한다. 명령에는 필요한 값만 출력하며 키·개인정보를 로그에 넣지 않는다. 신뢰한 로컬 셸 문자열의 기존 check 형식도 지원하지만 외부 입력으로 셸 문자열을 만들지 않는다.

## 이해 도구

setup·research·explain·jarvis는 목적에 맞춰 사용한다. toolkit은 분야와 현재 빈 곳에 맞는 카드만 읽는다. 중요한 선택·결과 수용에서 적용을 확인하며 단순 응답마다 시험하지 않는다. 상세 설명은 explain/references/depth.md 기준으로 필요한 깊이를 선택한다.

모델이 지침을 준수하는지와 사람의 이해가 좋아지는지는 실제 모의로 확인해야 한다. 스킬 형식·스크립트 자동 검사 통과가 그 효과를 보장하지 않는다.
