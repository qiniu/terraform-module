nginx_test() { "${NGINX_BIN:-nginx}" -t; }
nginx_systemctl() { "${SYSTEMCTL_BIN:-systemctl}" "$@"; }

snapshot_nginx_path() {
  nginx_snapshot_path="$1" nginx_snapshot_name="$2"
  if [ -L "$nginx_snapshot_path" ]; then
    printf '%s\n' symlink > "$nginx_backup_dir/$nginx_snapshot_name.kind"
    readlink "$nginx_snapshot_path" > "$nginx_backup_dir/$nginx_snapshot_name.target"
  elif [ -e "$nginx_snapshot_path" ]; then
    [ ! -d "$nginx_snapshot_path" ] || { echo "refusing unexpected Nginx directory: $nginx_snapshot_path" >&2; return 1; }
    printf '%s\n' file > "$nginx_backup_dir/$nginx_snapshot_name.kind"
    cp -a "$nginx_snapshot_path" "$nginx_backup_dir/$nginx_snapshot_name.file"
  else
    printf '%s\n' absent > "$nginx_backup_dir/$nginx_snapshot_name.kind"
  fi
}
restore_nginx_path() {
  nginx_restore_path="$1" nginx_restore_name="$2"
  rm -f "$nginx_restore_path" || return 1
  case "$(cat "$nginx_backup_dir/$nginx_restore_name.kind")" in
    absent) ;;
    file) cp -a "$nginx_backup_dir/$nginx_restore_name.file" "$nginx_restore_path" ;;
    symlink) ln -s "$(cat "$nginx_backup_dir/$nginx_restore_name.target")" "$nginx_restore_path" ;;
    *) return 1 ;;
  esac
}
restore_nginx_candidate() {
  restore_nginx_path "$nginx_auth_dest" auth &&
    restore_nginx_path "$nginx_config_dest" config &&
    restore_nginx_path "$nginx_enabled_dest" enabled
}
snapshot_nginx_candidate() {
  snapshot_nginx_path "$nginx_auth_dest" auth &&
    snapshot_nginx_path "$nginx_config_dest" config &&
    snapshot_nginx_path "$nginx_enabled_dest" enabled
}
apply_nginx_candidate() {
  nginx_changed=false
  if [ ! -f "$nginx_auth_dest" ] || ! cmp -s "$auth_tmp" "$nginx_auth_dest"; then
    install_nginx_candidate_file "$auth_tmp" "$nginx_auth_dest" root www-data 0640 || return 1
    nginx_changed=true
  fi
  if [ ! -f "$nginx_config_dest" ] || ! cmp -s "$nginx_tmp" "$nginx_config_dest"; then
    install_nginx_candidate_file "$nginx_tmp" "$nginx_config_dest" root root 0644 || return 1
    nginx_changed=true
  fi
  if [ ! -L "$nginx_enabled_dest" ] || [ "$(readlink "$nginx_enabled_dest" 2>/dev/null || true)" != "$nginx_config_dest" ]; then
    ln -sfn "$nginx_config_dest" "$nginx_enabled_dest" || return 1
    nginx_changed=true
  fi
}
install_nginx_candidate_file() {
  nginx_candidate_source="$1" nginx_candidate_dest="$2" nginx_candidate_owner="$3" nginx_candidate_group="$4" nginx_candidate_mode="$5"
  nginx_candidate_dir="$(dirname "$nginx_candidate_dest")"
  nginx_candidate_tmp="$(mktemp "$nginx_candidate_dir/.deepseek-harness.XXXXXX")" || return 1
  if ! install -o "$nginx_candidate_owner" -g "$nginx_candidate_group" -m "$nginx_candidate_mode" "$nginx_candidate_source" "$nginx_candidate_tmp"; then
    rm -f "$nginx_candidate_tmp"
    return 1
  fi
  if ! mv -f "$nginx_candidate_tmp" "$nginx_candidate_dest"; then
    rm -f "$nginx_candidate_tmp"
    return 1
  fi
}
activate_nginx_candidate() {
  nginx_systemctl is-enabled --quiet nginx || nginx_systemctl enable nginx || return 1
  if nginx_systemctl is-active --quiet nginx; then
    [ "$nginx_changed" != true ] || nginx_systemctl reload nginx
  else
    nginx_systemctl restart nginx
  fi
}
commit_nginx_candidate() {
  snapshot_nginx_candidate || return 1
  if ! apply_nginx_candidate || ! nginx_test || ! activate_nginx_candidate; then
    restore_nginx_candidate || return 1
    nginx_test || return 1
    return 1
  fi
}
