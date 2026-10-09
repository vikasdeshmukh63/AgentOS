#!/usr/bin/env bash
set -u

: "${AGENTOS_FIXTURE_REAL_GIT:?missing real git path}"
: "${AGENTOS_FIXTURE_GIT_LOG:?missing wrapper log path}"

mode="${AGENTOS_FIXTURE_CRASH_MODE:-normal}"
is_push=0
refspec=""
for arg in "$@"; do
  if [[ "$arg" == "push" ]]; then
    is_push=1
  fi
  if [[ "$arg" == *":refs/heads/"* ]]; then
    refspec="$arg"
  fi
done

printf 'CALL\tpid=%s\tpgid=%s\t' "$$" "$(ps -o pgid= -p $$ | tr -d ' ')" >>"$AGENTOS_FIXTURE_GIT_LOG"
printf '%q ' "$@" >>"$AGENTOS_FIXTURE_GIT_LOG"
printf '\n' >>"$AGENTOS_FIXTURE_GIT_LOG"

if [[ "$is_push" -eq 1 && "$mode" == "before_push" ]]; then
  printf '%s\n' "$$" >"${AGENTOS_FIXTURE_EVENT:?missing event path}.pid"
  : >"$AGENTOS_FIXTURE_EVENT"
  while :; do sleep 1; done
fi

"$AGENTOS_FIXTURE_REAL_GIT" "$@"
status=$?

if [[ "$is_push" -eq 1 && "$status" -eq 0 ]]; then
  printf 'PUSH_SUCCESS\t%s\n' "$refspec" >>"$AGENTOS_FIXTURE_GIT_LOG"
  if [[ "$mode" == "after_push" ]]; then
    printf '%s\n' "$$" >"${AGENTOS_FIXTURE_EVENT:?missing event path}.pid"
    : >"$AGENTOS_FIXTURE_EVENT"
    while :; do sleep 1; done
  fi
fi

exit "$status"

