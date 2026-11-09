#!/usr/bin/env bash
# OSXER LLVMPIPE (regression runner): use the workspace RAM monitor.
set -euo pipefail
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
: "${OSXER_TEST_DIR:?Set OSXER_TEST_DIR to a disk-backed workspace build directory}"
test_dir=$(mktemp -d "$OSXER_TEST_DIR/llvmpipe-native.XXXXXX")
trap 'rm -rf -- "$test_dir"' EXIT # Only this runner's own directory.
export TMPDIR="$test_dir" CCACHE_DISABLE=1
native="$source_dir/src/startup/mldr/elfcalls"
indium="$source_dir/src/external/metal/deps/indium"
for identity in 22 23; do
    printf 'RUNTIME_%s { global: *; };\n' "$identity" > "$test_dir/runtime$identity.map"
    g++ -std=c++17 -fPIC -shared -fgnu-unique -DRUNTIME_ID="$identity" \
        "$source_dir/tests/mldr/llvmpipe-runtime.cpp" -pthread \
        -Wl,--version-script="$test_dir/runtime$identity.map" -o "$test_dir/runtime$identity.so"
done
cc -std=c11 -Wall -Wextra -Werror -c "$native/native_dlopen.c" -o "$test_dir/native_dlopen.o"
g++ -std=c++17 -Wall -Wextra -Werror -Wno-deprecated-declarations -DDARLING \
    "-DHOST_LLVM_LIBNAME=\"$test_dir/runtime22.so\"" \
    -I"$native" -I"$indium/private-include" -I"$indium/include" \
    "$source_dir/tests/mldr/llvmpipe-isolation.cpp" \
    "$indium/src/iridium/dynamic-llvm.cpp" "$test_dir/native_dlopen.o" \
    -ldl -pthread -o "$test_dir/probe"
"$test_dir/probe" "$test_dir/runtime23.so" "$test_dir/runtime22.so"
# Keep the pre-existing failure contract: LLVM version mismatch returns false.
g++ -shared -fPIC "$indium/test/dynamic-llvm-mismatch/fake-llvm.cpp" -o "$test_dir/mismatch.so"
g++ -std=c++17 -Wall -Wextra -Werror -Wno-deprecated-declarations -DDARLING \
    "-DHOST_LLVM_LIBNAME=\"$test_dir/mismatch.so\"" \
    -I"$native" -I"$indium/private-include" -I"$indium/include" \
    "$source_dir/tests/mldr/llvmpipe-isolation.cpp" \
    "$indium/src/iridium/dynamic-llvm.cpp" "$test_dir/native_dlopen.o" \
    -ldl -pthread -o "$test_dir/private-mismatch"
"$test_dir/private-mismatch"
g++ -std=c++17 -Wno-deprecated-declarations "-DHOST_LLVM_LIBNAME=\"$test_dir/mismatch.so\"" \
    -I"$indium/private-include" -I"$indium/include" \
    "$indium/test/dynamic-llvm-mismatch/dynamic-llvm-mismatch.cpp" \
    "$indium/src/iridium/dynamic-llvm.cpp" -ldl -pthread -o "$test_dir/mismatch"
"$test_dir/mismatch"
