#!/usr/bin/env bash
set -euo pipefail
reader_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
reader_test_dir="$(mktemp -d "${TMPDIR:-/tmp}/reresearch-chrome-tests.XXXXXX")"
trap 'rm -rf "$reader_test_dir"' EXIT
swiftc -swift-version 5 \
  "$reader_repo_root/ios/Reresearch/ReaderChromeMotion.swift" \
  "$reader_repo_root/ios/Tests/ReaderChromeTrackingTests.swift" \
  -o "$reader_test_dir/reader-chrome-checks"
"$reader_test_dir/reader-chrome-checks"
