#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GROUP_SIZE="${AGENTBAR_TEST_GROUP_SIZE:-12}"
SUITE_TIMEOUT="${AGENTBAR_TEST_SUITE_TIMEOUT:-180}"
RETRY_NON_TIMEOUT_FAILURES="${AGENTBAR_TEST_RETRY_NON_TIMEOUT_FAILURES:-1}"

cd "${ROOT_DIR}"

# Inherited by release-built tests and arbitrary CLI children as well as the test runner.
export AGENTBAR_TEST_CODEX_FILE_ISOLATION=1
unset AGENTBAR_TEST_CODEX_FILE_FIXTURES
export AGENTBAR_TEST_SESSION_FILE_ISOLATION=1

# Defense in depth: test processes also self-detect, but keep this explicit so runner changes cannot
# expose the user's login Keychain. Deliberate isolated Keychain tests must opt in by setting the allow flag.
if [[ "${AGENTBAR_ALLOW_TEST_KEYCHAIN_ACCESS:-}" != "1" ]]; then
  export AGENTBAR_SUPPRESS_TEST_KEYCHAIN_ACCESS=1
fi

ARGS=(
  --group-size "${GROUP_SIZE}"
  --timeout "${SUITE_TIMEOUT}"
)

case "${RETRY_NON_TIMEOUT_FAILURES}" in
  0) ARGS+=(--no-retry-non-timeout-failures) ;;
  1) ;;
  *)
    echo "AGENTBAR_TEST_RETRY_NON_TIMEOUT_FAILURES must be 0 or 1" >&2
    exit 2
    ;;
esac

if [[ -n "${AGENTBAR_TEST_SHARD_INDEX:-}" || -n "${AGENTBAR_TEST_SHARD_COUNT:-}" ]]; then
  ARGS+=(
    --shard-index "${AGENTBAR_TEST_SHARD_INDEX:?AGENTBAR_TEST_SHARD_COUNT requires AGENTBAR_TEST_SHARD_INDEX}"
    --shard-count "${AGENTBAR_TEST_SHARD_COUNT:?AGENTBAR_TEST_SHARD_INDEX requires AGENTBAR_TEST_SHARD_COUNT}"
  )
fi

exec python3 "${ROOT_DIR}/Scripts/ci_swift_test_by_suite.py" "${ARGS[@]}" "$@"
