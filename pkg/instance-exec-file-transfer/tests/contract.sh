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
#   7. 远端写入安全边界：root/symlink/realpath 校验、marker+SHA 覆盖前置、
#      完整分片序号校验、同目录临时文件 + 原子 mv
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

# 所有子模块的 main.tf / 模板文件（不含根 main.tf，根仅作分流）
MAIN_TFS="modules/direct/main.tf modules/chunked/main.tf"

# ---------------------------------------------------------------------------
# 1. sensitive 声明：content / private_key / password（根模块入口校验）
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
# 2. 所有 exec 资源禁用 stdout/stderr 保存（遍历子模块 main.tf）
# ---------------------------------------------------------------------------
exec_resources_no_store() {
  local exec_count=0
  local stdout_false=0
  local stderr_false=0
  for f in ${MAIN_TFS}; do
    exec_count=$((exec_count + $(grep -c 'resource "qiniu_compute_instance_exec"' "$f" || true)))
    stdout_false=$((stdout_false + $(grep -c 'store_stdout[[:space:]]*=[[:space:]]*false' "$f" || true)))
    stderr_false=$((stderr_false + $(grep -c 'store_stderr[[:space:]]*=[[:space:]]*false' "$f" || true)))
  done
  [ "${exec_count}" -ge 1 ] || return 1
  [ "${exec_count}" -eq "${stdout_false}" ] || return 1
  [ "${exec_count}" -eq "${stderr_false}" ] || return 1
}

check "所有 qiniu_compute_instance_exec 均禁用 stdout/stderr 保存" exec_resources_no_store

# ---------------------------------------------------------------------------
# 3~5. 根模块入口变量校验
# ---------------------------------------------------------------------------
sha256_validation_present() {
  grep -q 'content_sha256' variables.tf && \
    grep -qE 'can\(regex\("\^\[0-9a-f\]\{64\}\$"[,)]' variables.tf
}

check "content_sha256 声明 64 位小写十六进制校验" sha256_validation_present

target_path_validation_present() {
  grep -q 'target_path' variables.tf && \
    grep -qE 'startswith\(var\.target_path, "/"\)' variables.tf
}

check "target_path 声明绝对路径校验" target_path_validation_present

file_mode_validation_present() {
  grep -q 'file_mode' variables.tf && \
    grep -qE 'can\(regex\("\^\[0-7\]\{4\}\$"[,)]' variables.tf
}

check "file_mode 声明 4 位八进制校验" file_mode_validation_present

# ---------------------------------------------------------------------------
# 6. chunk 命令的 payload 内嵌点为安全字符集（规避 shell 注入）
# ---------------------------------------------------------------------------
chunk_payload_quoted() {
  grep -qE "printf '%s' '\$\{payload\}'" modules/chunked/templates/chunk.sh.tftpl ||
    grep -qF "printf '%s' '\${payload}'" modules/chunked/templates/chunk.sh.tftpl
}

check "chunk 命令 payload 以单引号内嵌" chunk_payload_quoted

# ---------------------------------------------------------------------------
# 7. 远端写入安全边界（issue #58 Task 2）
# ---------------------------------------------------------------------------
chunk_distinct_part_files() {
  grep -q 'part.\${index}' modules/chunked/templates/chunk.sh.tftpl && \
    grep -q 'mv -f "\$D/part.\${index}.tmp" "\$D/part.\${index}"' modules/chunked/templates/chunk.sh.tftpl
}

check "chunk 写入独立 part 文件（不追加同一文件）" chunk_distinct_part_files

security_guard_present() {
  grep -q 'stat -c %U' modules/direct/templates/publish.sh.tftpl && \
    grep -q 'realpath -m' modules/direct/templates/publish.sh.tftpl && \
    grep -q '! -L ' modules/direct/templates/publish.sh.tftpl && \
    grep -q 'stat -c %U' modules/chunked/templates/prepare.sh.tftpl
}

check "远端命令校验 root 所有/非 symlink/realpath" security_guard_present

# staging root 必须是 root 所有、非 symlink、realpath 一致（direct 与 chunked 一致）
staging_root_guard_present() {
  grep -q 'stat -c %U "\$R"' modules/direct/templates/publish.sh.tftpl && \
    grep -q 'realpath -m "\$R"' modules/direct/templates/publish.sh.tftpl && \
    grep -q '! -L "\$R"' modules/direct/templates/publish.sh.tftpl && \
    grep -q 'stat -c %U "\$R"' modules/chunked/templates/prepare.sh.tftpl
}

check "staging root 校验 root 所有/非 symlink/realpath" staging_root_guard_present

unmanaged_target_rejected() {
  grep -q 'sha256sum -c -' modules/direct/templates/publish.sh.tftpl && \
    grep -q 'cat "\$D/marker"' modules/chunked/templates/prepare.sh.tftpl
}

check "目标已存在时仅覆盖 marker+SHA 匹配的受管文件" unmanaged_target_rejected

finalize_sequence_check() {
  grep -q 'ls "\$D"/part.\*' modules/chunked/templates/finalize.sh.tftpl && \
    grep -q '\[ -f "\$D/part.\$p" \]' modules/chunked/templates/finalize.sh.tftpl
}

check "finalize 校验完整分片序号" finalize_sequence_check

atomic_publish_present() {
  grep -q 'qiniu-pub' modules/direct/templates/publish.sh.tftpl && \
    grep -q 'qiniu-finalize' modules/chunked/templates/finalize.sh.tftpl && \
    grep -q 'mv -f' modules/direct/templates/publish.sh.tftpl && \
    grep -q 'mv -f' modules/chunked/templates/finalize.sh.tftpl
}

check "目标发布采用同目录临时文件 + 原子 mv" atomic_publish_present

# ---------------------------------------------------------------------------
echo
if [ "${failures}" -eq 0 ]; then
  echo "static contract: all checks passed"
  exit 0
else
  echo "static contract: ${failures} check(s) FAILED" >&2
  exit 1
fi