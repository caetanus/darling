#!/bin/bash
# OSXER NIB (runtime probe): execute only in Darling, via this script.
set -euo pipefail
case "$(uname -s)" in Darwin) ;; *) echo 'Run inside Darling' >&2; exit 1;; esac
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ "${1:-}" == --self-test ]]; then
    exec "$source_dir/probe" --self-test "$source_dir/fixtures"
fi
if [[ $# -lt 1 ]]; then
    echo 'usage: run.sh /path/to/file.nib|/path/to/file.storyboardc [identifier]' >&2
    exit 2
fi
exec "$source_dir/probe" "$@"
