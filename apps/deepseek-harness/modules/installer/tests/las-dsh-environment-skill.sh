#!/usr/bin/env bash
set -euo pipefail

module_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
installer="$module_dir/templates/las-dsh-environment-skill.py"
skill_template="$module_dir/templates/las-dsh-environment.SKILL.md.tftpl"
test_root="$(mktemp -d)"
trap 'rm -rf "$test_root"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }
expect_fail() {
  if "$@" >/dev/null 2>&1; then
    fail "expected failure: $*"
  fi
}
mode() { stat -c '%a' "$1"; }
owner() { stat -c '%u:%g' "$1"; }
fingerprint() {
  if [ -d "$1" ]; then
    (
      cd "$1"
      find . -printf '%y:%m:%u:%g:%p\n' | sort
      find . -type f -exec sha256sum {} \; | sort
    )
  else
    printf '%s:%s:%s\n' "$(cat "$1")" "$(mode "$1")" "$(owner "$1")"
  fi
}

test -f "$installer" || fail "missing safe skill installer"
test -f "$skill_template" || fail "missing skill template"

run_installer() {
  mkdir -p "$test_root/home"
  DSH_HOME="$test_root/home/.dsh" \
  DSH_SKILL_OWNER="$(id -u):$(id -g)" \
  python3 "$installer" --skill-file "$1"
}

run_injected() {
  mkdir -p "$test_root/home"
  DSH_HOME="$test_root/home/.dsh" \
  DSH_SKILL_OWNER="$(id -u):$(id -g)" \
  DSH_SKILL_TEST_FAIL_AT="$1" \
  python3 "$installer" --skill-file "$2"
}

run_short_write() {
  mkdir -p "$test_root/home"
  DSH_HOME="$test_root/home/.dsh" \
  DSH_SKILL_OWNER="$(id -u):$(id -g)" \
  DSH_SKILL_TEST_MAX_WRITE=1 \
  python3 "$installer" --skill-file "$1"
}

skill_one="$test_root/skill-one.md"
skill_two="$test_root/skill-two.md"
printf '%s\n' 'first skill' > "$skill_one"
printf '%s\n' 'second skill' > "$skill_two"

run_installer "$skill_one"
bundle="$test_root/home/.agents/skills/las-dsh-environment"
managed="$bundle/SKILL.md"
test "$(cat "$managed")" = 'first skill' || fail "first install content"
test "$(mode "$test_root/home/.agents")" = 700 || fail ".agents mode"
test "$(mode "$test_root/home/.agents/skills")" = 700 || fail "skills mode"
test "$(mode "$bundle")" = 700 || fail "bundle mode"
test "$(mode "$managed")" = 600 || fail "skill mode"
test "$(owner "$managed")" = "$(id -u):$(id -g)" || fail "skill owner"
for directory in "$test_root/home/.agents" "$test_root/home/.agents/skills" "$bundle"; do
  test "$(owner "$directory")" = "$(id -u):$(id -g)" || fail "directory owner"
done

mkdir -p "$test_root/home/.agents/skills/other-skill"
printf '%s\n' sentinel > "$test_root/home/.agents/skills/other-skill/SKILL.md"
printf '%s\n' resource > "$bundle/keep.txt"
sibling_before="$(fingerprint "$test_root/home/.agents/skills/other-skill")"
resource_before="$(fingerprint "$bundle/keep.txt")"
before_mtime="$(stat -c '%Y' "$managed")"
sleep 1
run_installer "$skill_one"
test "$(stat -c '%Y' "$managed")" = "$before_mtime" || fail "unchanged content replaced"
test "$(fingerprint "$bundle/keep.txt")" = "$resource_before" || fail "bundle resource changed"
test "$(fingerprint "$test_root/home/.agents/skills/other-skill")" = "$sibling_before" || fail "other skill changed"

chmod 0755 "$test_root/home/.agents" "$test_root/home/.agents/skills" "$bundle"
chmod 0644 "$managed"
run_installer "$skill_one"
test "$(mode "$test_root/home/.agents")" = 700 || fail ".agents mode not corrected"
test "$(mode "$test_root/home/.agents/skills")" = 700 || fail "skills mode not corrected"
test "$(mode "$bundle")" = 700 || fail "bundle mode not corrected"
test "$(mode "$managed")" = 600 || fail "skill mode not corrected"
test "$(stat -c '%Y' "$managed")" = "$before_mtime" || fail "mode correction replaced unchanged skill"
for directory in "$test_root/home/.agents" "$test_root/home/.agents/skills" "$bundle"; do
  test "$(owner "$directory")" = "$(id -u):$(id -g)" || fail "directory owner not corrected"
done

before_inode="$(stat -c '%d:%i' "$managed")"
run_installer "$skill_two"
test "$(cat "$managed")" = 'second skill' || fail "changed content not installed"
test "$(mode "$managed")" = 600 || fail "changed file mode"
test "$(stat -c '%d:%i' "$managed")" != "$before_inode" || fail "changed skill was not atomically replaced"

for failure in fchmod write-after-short; do
  expect_fail run_injected "$failure" "$skill_one"
  test -z "$(find "$bundle" -maxdepth 1 -name '.SKILL.md.tmp.*' -print)" || fail "$failure left a temporary file"
  test "$(cat "$managed")" = 'second skill' || fail "$failure changed managed skill"
done
run_short_write "$skill_one"
test "$(cat "$managed")" = 'first skill' || fail "short write was not completed"

for component in agents skills las-dsh-environment; do
  case "$component" in
    agents) bad="$test_root/bad-agents"; link="$test_root/home/.agents" ;;
    skills) bad="$test_root/bad-skills"; link="$test_root/home/.agents/skills" ;;
    las-dsh-environment) bad="$test_root/bad-bundle"; link="$test_root/home/.agents/skills/las-dsh-environment" ;;
  esac
  rm -rf "$test_root/home/.agents"
  case "$component" in
    skills) mkdir -p "$test_root/home/.agents" ;;
    las-dsh-environment) mkdir -p "$test_root/home/.agents/skills" ;;
  esac
  mkdir "$bad"
  printf '%s\n' external > "$bad/sentinel"
  chmod 0750 "$bad"
  before="$(fingerprint "$bad")"
  ln -s "$bad" "$link"
  expect_fail run_installer "$skill_one"
  after="$(fingerprint "$bad")"
  test "$after" = "$before" || fail "$component symlink target changed"
done

rm -rf "$test_root/home/.agents"
mkdir -p "$test_root/home/.agents/skills/las-dsh-environment"
bad="$test_root/bad-file"
printf '%s\n' external > "$bad"
before="$(fingerprint "$bad")"
ln -s "$bad" "$test_root/home/.agents/skills/las-dsh-environment/SKILL.md"
expect_fail run_installer "$skill_one"
test "$(fingerprint "$bad")" = "$before" || fail "skill-file symlink target changed"

rm -rf "$test_root/home/.agents"
mkdir -p "$test_root/home/.agents/skills/las-dsh-environment"
bad="$test_root/hardlink-source"
printf '%s\n' external > "$bad"
chmod 0644 "$bad"
ln "$bad" "$test_root/home/.agents/skills/las-dsh-environment/SKILL.md"
before="$(fingerprint "$bad")"
expect_fail run_installer "$skill_one"
test "$(fingerprint "$bad")" = "$before" || fail "hardlink target changed"

for component in agents skills las-dsh-environment skill-file; do
  rm -rf "$test_root/home/.agents"
  case "$component" in
    agents) bad="$test_root/home/.agents" ;;
    skills) mkdir -p "$test_root/home/.agents"; bad="$test_root/home/.agents/skills" ;;
    las-dsh-environment) mkdir -p "$test_root/home/.agents/skills"; bad="$test_root/home/.agents/skills/las-dsh-environment" ;;
    skill-file) mkdir -p "$test_root/home/.agents/skills/las-dsh-environment"; bad="$test_root/home/.agents/skills/las-dsh-environment/SKILL.md" ;;
  esac
  if [ "$component" = skill-file ]; then
    mkdir "$bad"
  else
    printf '%s\n' unexpected > "$bad"
  fi
  before="$(mode "$bad"):$(owner "$bad")"
  expect_fail run_installer "$skill_one"
  after="$(mode "$bad"):$(owner "$bad")"
  test "$after" = "$before" || fail "$component unexpected type changed"
done

echo 'PASS: deployment environment skill installer'
