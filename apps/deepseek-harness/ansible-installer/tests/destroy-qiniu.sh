#!/usr/bin/env bash
set -euo pipefail

test_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_dir="$(cd -- "$test_dir/.." && pwd)"
terraform_dir="$test_dir/terraform"
credential_file="$project_dir/../../ci-runner/single/env.sh"

source "$credential_file"
: "${QINIU_ACCESS_KEY:?missing QINIU_ACCESS_KEY}"
: "${QINIU_SECRET_KEY:?missing QINIU_SECRET_KEY}"
: "${QINIU_REGION_ID:?missing QINIU_REGION_ID}"

cd -- "$terraform_dir"
terraform destroy -auto-approve
