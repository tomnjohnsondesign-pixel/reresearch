#!/usr/bin/env bash
set -euo pipefail
brand_repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
brand_test_dir="$(mktemp -d "${TMPDIR:-/tmp}/reresearch-brand-tests.XXXXXX")"
trap 'rm -rf "$brand_test_dir"' EXIT
swiftc -swift-version 5 \
  "$brand_repo_root/ios/Reresearch/BrandPalette.swift" \
  "$brand_repo_root/ios/Tests/BrandColourFlowTests.swift" \
  -o "$brand_test_dir/brand-flow-checks"
"$brand_test_dir/brand-flow-checks"
