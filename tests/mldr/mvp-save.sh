#!/usr/bin/env bash
# OSXER MVP (native runner): invoke through the workspace RAM/lock wrapper.
set -euo pipefail
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
: "${OSXER_TEST_DIR:?Set OSXER_TEST_DIR to a disk-backed workspace build directory}"
test_dir=$(mktemp -d "$OSXER_TEST_DIR/mvp-native.XXXXXX")
trap 'rm -rf -- "$test_dir"' EXIT # Only the directory created above.
export TMPDIR="$test_dir" CCACHE_DISABLE=1
"${CC:-cc}" -std=c11 -O0 -Wall -Wextra -Werror \
    -I"$source_dir/src/startup/mldr" -I"$source_dir/src/external/darlingserver/src" \
    "$source_dir/tests/mldr/mvp-save.c" -o "$test_dir/probe"
cd "$test_dir"
./probe
