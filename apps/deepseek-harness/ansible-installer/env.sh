#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${BASH_SOURCE:-}" ]]; then
  dsh_env_file="${BASH_SOURCE[0]}"
else
  dsh_env_file="${(%):-%N}"
fi

dsh_ansible_dir="$(cd -- "$(dirname -- "$dsh_env_file")" && pwd)"
dsh_uv_dir="$dsh_ansible_dir/.tools/uv"
dsh_uv_bin="$dsh_uv_dir/uv"

if [[ ! -x "$dsh_uv_bin" ]]; then
  mkdir -p "$dsh_uv_dir"
  curl --fail --location --silent --show-error https://astral.sh/uv/install.sh |
    env UV_UNMANAGED_INSTALL="$dsh_uv_dir" sh
fi

if [[ ! -x "$dsh_uv_bin" ]]; then
  printf 'uv installation failed: %s\n' "$dsh_uv_bin" >&2
  return 1 2>/dev/null || exit 1
fi

export PATH="$dsh_uv_dir:$PATH"
