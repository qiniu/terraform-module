#!/usr/bin/env bash
set -euo pipefail

package='@deepseek-ai/dsh@0.1.0-rc.6'
cache_dir="$(mktemp -d)"
trap 'rm -rf "$cache_dir"' EXIT

echo "ONLINE prewarm $package"
npm_config_cache="$cache_dir" timeout 300s npm exec --yes --package="$package" -- dsh --version >/dev/null
echo "OFFLINE verify $package"
npm_config_cache="$cache_dir" timeout 30s npx --offline --yes "$package" --version >/dev/null
echo "PASS offline cache contains runnable $package"
