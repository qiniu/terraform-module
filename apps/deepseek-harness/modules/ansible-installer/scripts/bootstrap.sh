#!/usr/bin/env bash
set -euo pipefail
umask 077

[ "$#" -eq 1 ] || {
  printf '%s\n' 'expected extra vars' >&2
  exit 2
}

uv_version=0.12.5
extra_vars_base64="$1"
installer_root=/opt/las-dsh-installer
project_dir="${installer_root}/project"
uv_bin_dir=/opt/las-dsh-installer/bin
uv_link_dir=/usr/local/bin
extra_vars_file="$(mktemp)"

cleanup() {
  rm -f -- "${extra_vars_file}"
}
trap cleanup EXIT

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

[ "${EUID}" -eq 0 ] || fail 'must run as root'
[ -r /etc/os-release ] || fail 'unsupported operating system'
. /etc/os-release
[ "${ID}" = ubuntu ] || fail 'unsupported operating system'

required_packages=(ca-certificates curl)
missing_packages=()
for package in "${required_packages[@]}"; do
  dpkg-query -W -f='${db:Status-Status}' "${package}" 2>/dev/null | grep -qx installed || missing_packages+=("${package}")
done

retry() {
  local attempts="$1"
  shift
  local attempt=1
  until "$@"; do
    [ "${attempt}" -ge "${attempts}" ] && return 1
    sleep "${attempt}"
    attempt=$((attempt + 1))
  done
}

if [ "${#missing_packages[@]}" -gt 0 ]; then
  retry 5 apt-get update
  retry 5 apt-get install -y --no-install-recommends "${missing_packages[@]}"
fi

for command in curl base64 sha256sum; do
  command -v "${command}" >/dev/null || fail "missing required bootstrap command: ${command}"
done

install -d -o root -g root -m 0755 "${uv_bin_dir}" "${uv_link_dir}"
if [ ! -x "${uv_bin_dir}/uv" ] ||
  [ ! -x "${uv_bin_dir}/uvx" ] ||
  ! "${uv_bin_dir}/uv" --version | grep -Eq "^uv ${uv_version}( |$)"; then
  export UV_VERSION="${uv_version}"
  export UV_UNMANAGED_INSTALL="${uv_bin_dir}"
  curl --fail --location --retry 5 --retry-all-errors https://astral.sh/uv/install.sh | sh
fi
"${uv_bin_dir}/uv" --version | grep -Eq "^uv ${uv_version}( |$)" || fail 'installed uv version does not match requested version'
for executable in uv uvx; do
  [ -x "${uv_bin_dir}/${executable}" ] || fail "installed uv is missing ${executable}"
  ln -sfn "${uv_bin_dir}/${executable}" "${uv_link_dir}/${executable}"
done

[ -f "${project_dir}/ansible.cfg" ] || fail 'Ansible runtime is missing ansible.cfg'
[ -f "${project_dir}/playbooks/site.yml" ] || fail 'Ansible runtime is missing playbook'
[ -f "${project_dir}/pyproject.toml" ] || fail 'Ansible runtime is missing pyproject.toml'

printf '%s' "${extra_vars_base64}" | base64 --decode >"${extra_vars_file}"
chmod 600 "${extra_vars_file}"
install -d -o root -g root -m 0755 /var/cache/las-dsh-installer/uv

cd "${project_dir}"
export UV_PROJECT_ENVIRONMENT=/opt/las-dsh-installer/.venv
export UV_CACHE_DIR=/var/cache/las-dsh-installer/uv
ansible_venv_marker="${UV_PROJECT_ENVIRONMENT}/.las-dsh-requirements-sha256"
ansible_venv_requirements_sha256="$(sha256sum pyproject.toml uv.lock | sha256sum | awk '{print $1}')"
# Ansible modules run as dsh in some roles, so its root-managed interpreter must be traversable.
umask 022
if [ ! -x "${UV_PROJECT_ENVIRONMENT}/bin/ansible-playbook" ] ||
  [ ! -f "${ansible_venv_marker}" ] ||
  ! grep -qx "${ansible_venv_requirements_sha256}" "${ansible_venv_marker}"; then
  "${uv_bin_dir}/uv" sync --locked
  printf '%s\n' "${ansible_venv_requirements_sha256}" >"${ansible_venv_marker}"
fi
chmod 0755 "${UV_PROJECT_ENVIRONMENT}" "${UV_PROJECT_ENVIRONMENT}/bin"
find "${UV_PROJECT_ENVIRONMENT}" -type d -exec chmod 0755 {} +
find "${UV_PROJECT_ENVIRONMENT}" -type f -exec chmod 0644 {} +
find "${UV_PROJECT_ENVIRONMENT}/bin" -type f -exec chmod 0755 {} +
"${uv_bin_dir}/uv" run --locked ansible-playbook -i inventory/default playbooks/site.yml --extra-vars "@${extra_vars_file}" --extra-vars "uv_version=${uv_version}" --extra-vars "dsh_ansible_venv_dir=${UV_PROJECT_ENVIRONMENT}"
