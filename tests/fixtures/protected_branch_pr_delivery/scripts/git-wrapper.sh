#!/usr/bin/env bash
set -u

: "${AGENTOS_FIXTURE_REAL_GIT:?missing real git path}"
: "${AGENTOS_FIXTURE_GIT_LOG:?missing Git call log}"

for arg in "$@"; do
  case "$arg" in
    http://* | https://* | ssh://* | git@*)
      printf 'PUBLIC_REMOTE_REJECTED\t%s\n' "$arg" >>"$AGENTOS_FIXTURE_GIT_LOG"
      exit 96
      ;;
  esac
done

printf 'CALL\tpid=%s\tpgid=%s\t' "$$" "$(ps -o pgid= -p $$ | tr -d ' ')" \
  >>"$AGENTOS_FIXTURE_GIT_LOG"
printf '%q ' "$@" >>"$AGENTOS_FIXTURE_GIT_LOG"
printf '\n' >>"$AGENTOS_FIXTURE_GIT_LOG"

is_push=0
refspec=""
for arg in "$@"; do
  [[ "$arg" == "push" ]] && is_push=1
  [[ "$arg" == *":refs/heads/"* ]] && refspec="$arg"
done

mode="${AGENTOS_FIXTURE_CRASH_MODE:-normal}"
if [[ "$is_push" -eq 1 && "$refspec" == *":refs/heads/agentos/runs/"* \
  && "$mode" == "before_head_push" ]]; then
  printf '%s\n' "$$" >"${AGENTOS_FIXTURE_EVENT:?missing event path}.pid"
  : >"$AGENTOS_FIXTURE_EVENT"
  while :; do sleep 1; done
fi

"$AGENTOS_FIXTURE_REAL_GIT" "$@"
status=$?

if [[ "$is_push" -eq 1 && "$status" -eq 0 ]]; then
  printf 'PUSH_SUCCESS\t%s\n' "$refspec" >>"$AGENTOS_FIXTURE_GIT_LOG"
  if [[ "$refspec" == *":refs/heads/agentos/runs/"* \
    && "$mode" == "after_head_push" ]]; then
    printf '%s\n' "$$" >"${AGENTOS_FIXTURE_EVENT:?missing event path}.pid"
    : >"$AGENTOS_FIXTURE_EVENT"
    while :; do sleep 1; done
  fi
fi

exit "$status"
