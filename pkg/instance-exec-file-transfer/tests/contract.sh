#!/usr/bin/env bash
# ============================================================================
# instance-exec-file-transfer 模块静态契约检查
# ============================================================================
# 检查项（对应 issue #58 的目标与安全边界）：
#   1. content / private_key / password 变量必须声明为 sensitive
#   2. 所有 qiniu_compute_instance_exec 资源必须禁用 stdout/stderr 保存
#   3. content_sha256 必须校验为 64 位小写十六进制 SHA-256
#   4. target_path 必须校验为绝对路径（拒绝相对路径）
#   5. file_mode 必须校验为 4 位八进制
#   6. chunk 命令不得包含敏感载荷之外的 shell 注入面（payload 为安全字符集）
# 运行方式：在模块根目录执行 tests/contract.sh；退出码 0 表示契约全部满足。
# ============================================================================
set -euo pipefail

cd "$(dirname "$0")/.."

failures=0

check() {
  local desc="$1"
  shift
  if "$@"; then
    echo "PASS: ${desc}"
  else
    echo "FAIL: ${desc}"
    failures=$((failures + 1))
  fi
}

# ---------------------------------------------------------------------------
# 1. sensitive 声明：content / private_key / password
# ---------------------------------------------------------------------------
var_is_sensitive() {
  local name="$1"
  awk -v name="$name" '
    $0 ~ "^variable \"" name "\" \\{ *$" { in_var = 1; next }
    in_var && /^[[:space:]]*\\}/ { in_var = 0 }
    in_var && /sensitive[[:space:]]*=[[:space:]]*true/ { found = 1 }
    END { exit found ? 0 : 1 }
  ' variables.tf
}

check "variable content 声明为 sensitive" var_is_sensitive content
check "variable private_key 声明为 sensitive" var_is_sensitive private_key
check "variable password 声明为 sensitive" var_is_sensitive password

# ---------------------------------------------------------------------------
# 2. 所有 exec 资源禁用 stdout/stderr 保存
# ---------------------------------------------------------------------------
exec_resources_no_store() {
  local exec_count
  local stdout_false
  local stderr_false
  exec_count=$(grep -c 'resource "qiniu_compute_instance_exec"' main.tf)
  [ "${exec_count}" -ge 1 ] || return 1
  stdout_false=$(grep -c 'store_stdout[[:space:]]*=[[:space:]]*false' main.tf)
  stderr_false=$(grep -c 'store_stderr[[:space:]]*=[[:space:]]*false' main.tf)
  [ "${exec_count}" -eq "${stdout_false}" ] || return 1
  [ "${exec_count}" -eq "${stderr_false}" ] || return 1
}

check "所有 qiniu_compute_instance_exec 均 store_stdout = false" exec_resources_no_store
check "所有 qiniu_compute_instance_exec 均 store_stderr = false" exec_resources_no_store

# ---------------------------------------------------------------------------
# 3. content_sha256 校验为 64 位小写十六进制
# ---------------------------------------------------------------------------
sha256_validation_present() {
  grep -q 'content_sha256' variables.tf && \
    grep -qE 'can\(regex\("\^\[0-9a-f\]\{64\}\$"[,)]' variables.tf
}

check "content_sha256 声明 64 位小写十六进制校验" sha256_validation_present

# ---------------------------------------------------------------------------
# 4. target_path 校验为绝对路径（拒绝相对路径）
# ---------------------------------------------------------------------------
target_path_validation_present() {
  grep -q 'target_path' variables.tf && \
    grep -qE 'startswith\(var\.target_path, "/"\)' variables.tf
}

check "target_path 声明绝对路径校验" target_path_validation_present

# ---------------------------------------------------------------------------
# 5. file_mode 校验为 4 位八进制
# ---------------------------------------------------------------------------
file_mode_validation_present() {
  grep -q 'file_mode' variables.tf && \
    grep -qE 'can\(regex\("\^\[0-7\]\{4\}\$"[,)]' variables.tf
}

check "file_mode 声明 4 位八进制校验" file_mode_validation_present

# ---------------------------------------------------------------------------
# 6. chunk 命令的 payload 内嵌点为安全字符集（规避 shell 注入）
#    chunk 命令模板中 payload 由单引号包裹，payload 本身来自无换行 ASCII base64，
#    因此不含单引号、换行等注入面；此处要求模板中存在单引号包裹的 payload 占位。
# ---------------------------------------------------------------------------
chunk_payload_quoted() {
  grep -qE "printf '%s' '__PAYLOAD__'" main.tf
}

check "chunk 命令 payload 以单引号内嵌" chunk_payload_quoted

# ---------------------------------------------------------------------------
echo
if [ "${failures}" -eq 0 ]; then
  echo "static contract: all checks passed"
  exit 0
else
  echo "static contract: ${failures} check(s) FAILED" >&2
  exit 1
fi