#!/bin/bash
# OSXER APPS (regression): run this script only inside Darling; no /tmp files.
set -euo pipefail
case "$(uname -s)" in Darwin) ;; *) echo 'Run inside Darling' >&2; exit 1;; esac
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# A writable workspace directory is required; the installed tests may be read-only.
: "${OSXER_TEST_WORKDIR:?Set OSXER_TEST_WORKDIR to a writable non-/tmp workspace}"
case "$OSXER_TEST_WORKDIR" in /tmp|/tmp/*|/private/tmp|/private/tmp/*) exit 1;; esac
scratch=$(mktemp -d "$OSXER_TEST_WORKDIR/app-gaps.XXXXXX")
trap 'rm -r -- "$scratch"' EXIT
"$source_dir/probe" "$scratch"
