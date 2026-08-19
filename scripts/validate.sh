#!/usr/bin/env bash
# Validate every manifest and component in this plugin.
# Usage: ./scripts/validate.sh
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v claude >/dev/null 2>&1; then
  echo "error: the 'claude' CLI is required. See https://claude.com/claude-code" >&2
  exit 1
fi

fail=0
for target in \
  "." \
  ".claude-plugin/plugin.json" \
  "./skills" \
  "./agents"
do
  echo "── validating ${target}"
  claude plugin validate "${target}" --strict || fail=1
done

if [ "${fail}" -ne 0 ]; then
  echo "✘ validation failed" >&2
  exit 1
fi

echo "✔ all manifests and components valid"
