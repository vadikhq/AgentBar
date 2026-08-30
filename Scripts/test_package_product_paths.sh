#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
source "$ROOT/Scripts/package_product_paths.sh"

TEMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/agentbar-package-paths.XXXXXX")
trap 'rm -rf "$TEMP_DIR"' EXIT

NATIVE_DIR="$TEMP_DIR/.build/arm64-apple-macosx/release"
SWIFTBUILD_DIR="$TEMP_DIR/.build/out/Products/Release"
STAGE_ROOT="$TEMP_DIR/.build/package-products/release"
mkdir -p "$NATIVE_DIR/AgentBar.dSYM" "$SWIFTBUILD_DIR/Sparkle.framework" "$SWIFTBUILD_DIR/AgentBar.dSYM"
touch "$NATIVE_DIR/AgentBar" "$SWIFTBUILD_DIR/AgentBar"

native=$(agentbar_require_product_file "$NATIVE_DIR" AgentBar arm64)
[[ "$native" == "$NATIVE_DIR/AgentBar" ]]

swiftbuild=$(agentbar_require_product_file "$SWIFTBUILD_DIR" AgentBar arm64)
[[ "$swiftbuild" == "$SWIFTBUILD_DIR/AgentBar" ]]

framework=$(agentbar_require_product_directory "$SWIFTBUILD_DIR" Sparkle.framework packaging)
[[ "$framework" == "$SWIFTBUILD_DIR/Sparkle.framework" ]]

dsym=$(agentbar_require_product_directory "$SWIFTBUILD_DIR" AgentBar.dSYM release)
[[ "$dsym" == "$SWIFTBUILD_DIR/AgentBar.dSYM" ]]

resolved=$(agentbar_resolve_staged_or_reported_file "$STAGE_ROOT" "$SWIFTBUILD_DIR" AgentBar arm64)
[[ "$resolved" == "$SWIFTBUILD_DIR/AgentBar" ]]

resolved_dsym=$(agentbar_resolve_dsym_path "$STAGE_ROOT" "$SWIFTBUILD_DIR" AgentBar arm64)
[[ "$resolved_dsym" == "$SWIFTBUILD_DIR/AgentBar.dSYM" ]]

mkdir -p "$STAGE_ROOT/arm64/AgentBar.dSYM"
touch "$STAGE_ROOT/arm64/AgentBar"
staged=$(agentbar_resolve_staged_or_reported_file "$STAGE_ROOT" "$SWIFTBUILD_DIR" AgentBar arm64)
[[ "$staged" == "$STAGE_ROOT/arm64/AgentBar" ]]
staged_dsym=$(agentbar_resolve_dsym_path "$STAGE_ROOT" "$SWIFTBUILD_DIR" AgentBar arm64)
[[ "$staged_dsym" == "$STAGE_ROOT/arm64/AgentBar.dSYM" ]]

rm -rf "$STAGE_ROOT"
rm "$SWIFTBUILD_DIR/AgentBar"
if agentbar_resolve_staged_or_reported_file "$STAGE_ROOT" "$SWIFTBUILD_DIR" AgentBar arm64 \
  2>"$TEMP_DIR/missing-file.log"; then
  echo "ERROR: Missing reported product unexpectedly fell back to legacy output." >&2
  exit 1
fi
grep -Fq "$SWIFTBUILD_DIR/AgentBar" "$TEMP_DIR/missing-file.log"

rm -rf "$SWIFTBUILD_DIR/Sparkle.framework"
if agentbar_require_product_directory "$SWIFTBUILD_DIR" Sparkle.framework packaging \
  2>"$TEMP_DIR/missing-directory.log"; then
  echo "ERROR: Missing reported framework was accepted." >&2
  exit 1
fi
grep -Fq "$SWIFTBUILD_DIR/Sparkle.framework" "$TEMP_DIR/missing-directory.log"

rm -rf "$SWIFTBUILD_DIR/AgentBar.dSYM"
if agentbar_resolve_dsym_path "$STAGE_ROOT" "$SWIFTBUILD_DIR" AgentBar arm64 \
  2>"$TEMP_DIR/missing-dsym.log"; then
  echo "ERROR: Missing reported dSYM unexpectedly fell back to legacy output." >&2
  exit 1
fi
grep -Fq "$SWIFTBUILD_DIR/AgentBar.dSYM" "$TEMP_DIR/missing-dsym.log"

swift() {
  [[ "$*" == "build --show-bin-path -c release --arch arm64" ]]
  printf '%s\n' "$SWIFTBUILD_DIR"
}
reported=$(agentbar_swiftpm_bin_path release arm64)
[[ "$reported" == "$SWIFTBUILD_DIR" ]]

swift() {
  return 23
}
if agentbar_swiftpm_bin_path release arm64 2>"$TEMP_DIR/query.log"; then
  echo "ERROR: SwiftPM bin-path query failure was ignored." >&2
  exit 1
fi
grep -Fq "SwiftPM failed to report" "$TEMP_DIR/query.log"

swift() {
  return 0
}
if agentbar_swiftpm_bin_path release arm64 2>"$TEMP_DIR/empty.log"; then
  echo "ERROR: Empty SwiftPM bin path was accepted." >&2
  exit 1
fi
grep -Fq "SwiftPM reported an empty" "$TEMP_DIR/empty.log"

echo "Package product path tests passed."
