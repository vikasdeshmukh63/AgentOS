#!/usr/bin/env bash
set -eu
printf 'unexpected worker invocation\n' >>"${AGENTOS_FIXTURE_WORKER_LOG:?missing worker log}"
exit 97
