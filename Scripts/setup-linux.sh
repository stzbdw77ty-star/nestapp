#!/usr/bin/env bash
set -euo pipefail
# The SHA-256 is pinned to the official artifact verified against the Swift 6 release signature.
repo_dir="$(cd "$(dirname "$0")/.." && pwd)"
toolchain_root=/workspace/toolchains
toolchain_dir="$toolchain_root/swift-6.0.3-RELEASE-ubuntu24.04"
if [[ ! -x "$toolchain_dir/usr/bin/swift" ]]; then
  mkdir -p "$toolchain_root/swift-download"
  artifact="$toolchain_root/swift-download/swift.tar.gz"
  curl --fail --location --retry 3 https://download.swift.org/swift-6.0.3-release/ubuntu2404/swift-6.0.3-RELEASE/swift-6.0.3-RELEASE-ubuntu24.04.tar.gz -o "$artifact"
  echo "33e923609f6d89ee455af0a017ae4941ce16878c4940882cbf6a1656de294e8b  $artifact" | sha256sum --check
  tar -xzf "$artifact" -C "$toolchain_root"
fi
export PATH="$toolchain_dir/usr/bin:$PATH"
export CLANG_MODULE_CACHE_PATH=/workspace/.cache/clang
export SWIFTPM_MODULECACHE_OVERRIDE=/workspace/.cache/clang
export XDG_CACHE_HOME=/workspace/.cache
mkdir -p "$CLANG_MODULE_CACHE_PATH" /workspace/.cache/swiftpm /workspace/.swiftpm/configuration /workspace/.swiftpm/security
cd "$repo_dir"
swift test --cache-path /workspace/.cache/swiftpm --config-path /workspace/.swiftpm/configuration --security-path /workspace/.swiftpm/security -j 4
