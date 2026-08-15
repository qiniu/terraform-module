#!/usr/bin/env bash
set -euo pipefail

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$test_dir/.." && pwd)"
terraform_dir="$test_dir/terraform"
generated_dir="$test_dir/generated"

# Reuse apps/ci-runner/single/env.sh and never echo its credential values.
credential_file="$project_dir/../../ci-runner/single/env.sh"
source "$credential_file"
: "${QINIU_ACCESS_KEY:?missing QINIU_ACCESS_KEY}"
: "${QINIU_SECRET_KEY:?missing QINIU_SECRET_KEY}"
: "${QINIU_REGION_ID:?missing QINIU_REGION_ID}"

for command in terraform jq openssl; do
  command -v "$command" >/dev/null 2>&1 || {
    printf 'missing required command: %s\n' "$command" >&2
    exit 1
  }
done

cd -- "$terraform_dir"
terraform init
terraform apply -auto-approve
outputs_json="$(terraform output -json)"

ssh_endpoint="$(jq -er '.ssh_endpoint.value' <<<"$outputs_json")"
private_key="$(jq -er '.deployment_private_key.value' <<<"$outputs_json")"
public_authority="$(jq -er '.public_authority.value' <<<"$outputs_json")"
preview_public_authorities="$(jq -ce '.preview_public_authorities.value' <<<"$outputs_json")"
code_server_public_authority="$(jq -er '.code_server_public_authority.value' <<<"$outputs_json")"
ssh_host="${ssh_endpoint%:*}"
ssh_port="${ssh_endpoint##*:}"

umask 077
mkdir -p "$generated_dir"
key_file="$generated_dir/id_ed25519"
inventory_file="$generated_dir/hosts.yml"
environment_file="$generated_dir/deployment.env"
printf '%s\n' "$private_key" > "$key_file"
chmod 600 "$key_file"

cat > "$inventory_file" <<EOF
all:
  children:
    deepseek_harness:
      hosts:
        qiniu_test:
          ansible_host: $ssh_host
          ansible_port: $ssh_port
          ansible_user: root
          ansible_ssh_private_key_file: $key_file
EOF
chmod 600 "$inventory_file"

web_password="$(openssl rand -hex 24)"
code_server_password="$(openssl rand -hex 32)"
cat > "$environment_file" <<EOF
export DSH_PUBLIC_AUTHORITY='$public_authority'
export DSH_PREVIEW_COUNT='1'
export DSH_PREVIEW_PUBLIC_AUTHORITIES='$preview_public_authorities'
export DSH_CODE_SERVER_PUBLIC_AUTHORITY='$code_server_public_authority'
export DSH_WEB_PASSWORD='$web_password'
export DSH_CODE_SERVER_PASSWORD='$code_server_password'
export DSH_WEB_USERNAME='admin'
EOF
chmod 600 "$environment_file"

printf 'Qiniu test VM ready. Run tests/test-idempotence.sh next.\n'
