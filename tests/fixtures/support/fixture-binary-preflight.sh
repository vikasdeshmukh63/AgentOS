#!/usr/bin/env bash

fixture_binary_freshness_diagnostic() {
  local agentos_bin="$1"
  local missing_ids="$2"
  printf '%s\n' \
    "fixture capability preflight failed" \
    "target binary: $agentos_bin" \
    "missing required fixture id(s): $missing_ids" \
    "The target AgentOS build artifact may be older than the source fixture registry." \
    "Run cargo clean -p agentos, rebuild with cargo build --bin agentos, confirm with $agentos_bin eval fixtures --list --json, then retry. Fixture body was not started." >&2
}

preflight_fixture_binary() {
  if [[ "$#" -lt 2 ]]; then
    printf 'usage: preflight_fixture_binary <agentos-bin> <required-fixture-id>...\n' >&2
    return 64
  fi

  local agentos_bin="$1"
  shift
  local required_ids=("$@")
  local scratch
  scratch="$(mktemp -d "${TMPDIR:-/tmp}/agentos-fixture-preflight.XXXXXX")"
  local catalog="$scratch/catalog.json"
  local probe_error="$scratch/probe.err"

  if ! "$agentos_bin" eval fixtures --list --json >"$catalog" 2>"$probe_error"; then
    fixture_binary_freshness_diagnostic "$agentos_bin" "${required_ids[*]}"
    rm -rf "$scratch"
    return 1
  fi

  local missing
  if ! missing="$(python3 - "$catalog" "${required_ids[@]}" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    supported = set(json.load(handle)["fixture_ids"])
print(" ".join(fixture_id for fixture_id in sys.argv[2:] if fixture_id not in supported))
PY
  )"; then
    fixture_binary_freshness_diagnostic "$agentos_bin" "${required_ids[*]}"
    rm -rf "$scratch"
    return 1
  fi

  rm -rf "$scratch"
  if [[ -n "$missing" ]]; then
    fixture_binary_freshness_diagnostic "$agentos_bin" "$missing"
    return 1
  fi
}
