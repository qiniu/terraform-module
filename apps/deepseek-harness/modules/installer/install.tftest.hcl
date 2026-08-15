variables {
  dsh_version                  = "0.1.2"
  node_version                 = "22.17.0"
  dsh_port                     = 13000
  proxy_port                   = 8443
  public_authority             = "dsh.example.test"
  preview_count                = 1
  preview_ports                = [30080, 30081, 30082, 30083]
  preview_public_authorities   = ["preview.example.test"]
  code_server_version          = "4.132.0"
  code_server_port             = 3086
  code_server_proxy_port       = 3087
  code_server_public_authority = "code.example.test"
  web_username                 = "admin"
  web_password                 = "plain-password-must-not-leak"
  code_server_password         = "Code-server-safe-1234"
}

run "renders_pinned_runtime_and_service" {
  command = plan

  assert {
    condition = (
      startswith(nonsensitive(output.install_command), "#!/usr/bin/env bash\nset -euo pipefail") &&
      strcontains(nonsensitive(output.install_command), "umask 077") &&
      strcontains(nonsensitive(output.install_command), "node-v22.17.0-$${node_arch}.tar.xz") &&
      strcontains(nonsensitive(output.install_command), "https://nodejs.org/dist/v22.17.0") &&
      strcontains(nonsensitive(output.install_command), "SHASUMS256.txt") &&
      !strcontains(nonsensitive(output.install_command), "SHA256SUMS") &&
      strcontains(nonsensitive(output.install_command), "$2 == archive") &&
      strcontains(nonsensitive(output.install_command), "test -s \"$work_dir/SHASUMS256.txt.exact\"") &&
      strcontains(nonsensitive(output.install_command), "sha256sum -c SHASUMS256.txt.exact") &&
      strcontains(nonsensitive(output.install_command), "! runuser -u dsh -- test -x \"$node_prefix/bin/node\"") &&
      strcontains(nonsensitive(output.install_command), "tar --no-same-owner -xJf \"$work_dir/$archive\"") &&
      strcontains(nonsensitive(output.install_command), "chmod -R u=rwX,go=rX \"$node_prefix.new\"") &&
      length(regexall("chmod -R u=rwX,go=rX[^\\n]+node_prefix\\.new[\\s\\S]*mv[^\\n]+node_prefix\\.new[^\\n]+node_prefix", nonsensitive(output.install_command))) > 0 &&
      !strcontains(nonsensitive(output.install_command), "chown -R dsh:dsh \"$node_prefix.new\"") &&
      strcontains(nonsensitive(output.install_command), "x86_64)") &&
      strcontains(nonsensitive(output.install_command), "node_arch=\"linux-x64\"") &&
      strcontains(nonsensitive(output.install_command), "aarch64)") &&
      strcontains(nonsensitive(output.install_command), "node_arch=\"linux-arm64\"")
    )
    error_message = "安装命令必须固定 Node 版本，验证官方 SHASUMS256.txt，并支持 x86_64/aarch64。"
  }

  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "ca-certificates curl xz-utils nginx apache2-utils bubblewrap git build-essential python3") &&
      strcontains(nonsensitive(output.install_command), "retry 5 apt-get update") &&
      strcontains(nonsensitive(output.install_command), "sleep \"$attempt\"") &&
      strcontains(nonsensitive(output.install_command), "useradd") &&
      strcontains(nonsensitive(output.install_command), "--home-dir /home/dsh") &&
      strcontains(nonsensitive(output.install_command), "--shell /bin/bash") &&
      strcontains(nonsensitive(output.install_command), "passwd --lock dsh") &&
      strcontains(nonsensitive(output.install_command), "/home/dsh/.dsh") &&
      strcontains(nonsensitive(output.install_command), "/home/dsh/workspace") &&
      strcontains(nonsensitive(output.install_command), "/home/dsh/.npm") &&
      strcontains(nonsensitive(output.install_command), "install -d -o dsh -g dsh -m 0700 /home/dsh/.dsh /home/dsh/.npm") &&
      strcontains(nonsensitive(output.install_command), "install -d -o dsh -g dsh -m 0750 /home/dsh/workspace")
    )
    error_message = "安装命令必须按要求安装依赖并创建锁定密码的 dsh 用户及目录。"
  }

  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "@deepseek-ai/dsh@0.1.2") &&
      strcontains(nonsensitive(output.install_command), "npm_config_cache=/home/dsh/.npm") &&
      strcontains(nonsensitive(output.install_command), "User=dsh") &&
      strcontains(nonsensitive(output.install_command), "Group=dsh") &&
      strcontains(nonsensitive(output.install_command), "WorkingDirectory=/home/dsh/workspace") &&
      strcontains(nonsensitive(output.install_command), "--offline") &&
      strcontains(nonsensitive(output.install_command), "--port 13000") &&
      strcontains(nonsensitive(output.install_command), "--trusted-host dsh.example.test")
    )
    error_message = "安装命令必须在线预热固定 dsh 版本，并以 dsh 用户离线启动固定版本。"
  }
}

run "validates_existing_dsh_user_security" {
  command = plan

  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "groupadd --system dsh") &&
      strcontains(nonsensitive(output.install_command), "useradd --system") &&
      strcontains(nonsensitive(output.install_command), "SYS_UID_MAX") &&
      strcontains(nonsensitive(output.install_command), "sys_uid_max=999") &&
      strcontains(nonsensitive(output.install_command), "dsh_gid") &&
      strcontains(nonsensitive(output.install_command), "[ \"$dsh_gid\" -eq 0 ]") &&
      strcontains(nonsensitive(output.install_command), "[ \"$dsh_gid\" -gt \"$sys_gid_max\" ]") &&
      strcontains(nonsensitive(output.install_command), "getent passwd dsh") &&
      strcontains(nonsensitive(output.install_command), "id -gn dsh") &&
      strcontains(nonsensitive(output.install_command), "!= \"dsh\"") &&
      strcontains(nonsensitive(output.install_command), "!= \"/home/dsh\"") &&
      strcontains(nonsensitive(output.install_command), "!= \"/bin/bash\"") &&
      strcontains(nonsensitive(output.install_command), "sudo|admin|wheel") &&
      strcontains(nonsensitive(output.install_command), "unsafe existing dsh user") &&
      strcontains(nonsensitive(output.install_command), "passwd --lock dsh")
    )
    error_message = "既有 dsh 用户必须通过 system UID、主组、home、shell 和特权组安全校验后才可锁定密码。"
  }
}

run "renders_failure_runtime_and_proxy_details" {
  command = plan

  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "*)\n    echo \"unsupported architecture: $(uname -m)\" >&2\n    false") &&
      strcontains(nonsensitive(output.install_command), "Environment=HOME=/home/dsh") &&
      strcontains(nonsensitive(output.install_command), "Environment=PATH=/opt/node-v22.17.0/bin:/usr/local/bin:/usr/bin:/bin") &&
      strcontains(nonsensitive(output.install_command), "Environment=npm_config_cache=/home/dsh/.npm") &&
      strcontains(nonsensitive(output.install_command), "Restart=on-failure")
    )
    error_message = "安装命令必须拒绝不支持的架构，并完整渲染 systemd 运行环境及失败重启策略。"
  }

  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "retry 5 runuser -u dsh -- env HOME=/home/dsh npm_config_cache=/home/dsh/.npm") &&
      strcontains(nonsensitive(output.install_command), "/bin/bash -c 'cd /home/dsh/workspace && exec /usr/local/bin/npm exec") &&
      strcontains(nonsensitive(output.install_command), "--yes --package=\"@deepseek-ai/dsh@0.1.2\" -- dsh --version'")
    )
    error_message = "固定版本 dsh 必须由 dsh 用户携带 HOME 和 npm cache 环境在线预热。"
  }

  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "proxy_read_timeout 3600s") &&
      strcontains(nonsensitive(output.install_command), "proxy_send_timeout 3600s")
    )
    error_message = "Nginx 必须为 SSE 和长请求设置 read/send timeout。"
  }
}

run "renders_idempotent_change_detection" {
  command = plan

  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "[ \"$(cat \"$node_version_file\")\" != \"22.17.0\" ]") &&
      length(regexall("node_version_file[^\\n]+22\\.17\\.0[^\\n]+then[\\s\\S]*changed=true", nonsensitive(output.install_command))) > 0 &&
      strcontains(nonsensitive(output.install_command), "[ \"$(cat \"$dsh_cache_version_file\")\" != \"0.1.2\" ]") &&
      length(regexall("dsh_cache_version_file[^\\n]+0\\.1\\.2[^\\n]+then[\\s\\S]{0,600}changed=true", nonsensitive(output.install_command))) > 0
    )
    error_message = "Node 与 dsh npm cache 必须按版本差异更新并标记 changed。"
  }

  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "cmp -s \"$unit_tmp\" /etc/systemd/system/deepseek-harness.service") &&
      length(regexall("cmp -s[^\\n]+deepseek-harness\\.service[^\\n]+then[\\s\\S]{0,300}changed=true", nonsensitive(output.install_command))) > 0 &&
      strcontains(nonsensitive(output.install_command), "apply_nginx_candidate()") &&
      strcontains(nonsensitive(output.install_command), "cmp -s \"$auth_tmp\" \"$nginx_auth_dest\"") &&
      strcontains(nonsensitive(output.install_command), "cmp -s \"$nginx_tmp\" \"$nginx_config_dest\"")
    )
    error_message = "systemd、认证文件与 Nginx 配置必须使用 cmp 检测变化并标记对应 changed 状态。"
  }

  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "if [ \"$changed\" = true ] || ! systemctl is-active --quiet deepseek-harness.service; then") &&
      strcontains(nonsensitive(output.install_command), "nginx_systemctl is-active --quiet nginx") &&
      strcontains(nonsensitive(output.install_command), "[ \"$nginx_changed\" != true ] || nginx_systemctl reload nginx") &&
      strcontains(nonsensitive(output.install_command), "nginx_systemctl restart nginx")
    )
    error_message = "版本或配置变化必须通过 changed 分支触发对应服务重启或重载。"
  }

  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "readlink \"$nginx_enabled_dest\"") &&
      strcontains(nonsensitive(output.install_command), "nginx_changed=true") &&
      strcontains(nonsensitive(output.install_command), "systemctl is-enabled --quiet deepseek-harness.service") &&
      strcontains(nonsensitive(output.install_command), "nginx_systemctl is-enabled --quiet nginx") &&
      length(regexall("systemctl enable deepseek-harness\\.service[\\s\\S]*if [^\\n]+changed[^\\n]+then", nonsensitive(output.install_command))) > 0 &&
      strcontains(nonsensitive(output.install_command), "nginx_systemctl enable nginx")
    )
    error_message = "安装命令必须修复 sites-enabled 链接及服务 enabled 漂移，enable 不得仅依赖 changed 重启分支。"
  }
}

run "renders_authenticated_nginx_and_health_checks" {
  command = plan

  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "listen 0.0.0.0:8443") &&
      strcontains(nonsensitive(output.install_command), "auth_basic") &&
      strcontains(nonsensitive(output.install_command), "auth_basic_user_file") &&
      strcontains(nonsensitive(output.install_command), "web_username=\"admin\"") &&
      strcontains(nonsensitive(output.install_command), "proxy_pass http://127.0.0.1:13000") &&
      strcontains(nonsensitive(output.install_command), "proxy_set_header Host 127.0.0.1:13000") &&
      !strcontains(nonsensitive(output.install_command), "proxy_set_header Host $host") &&
      strcontains(nonsensitive(output.install_command), "proxy_set_header X-Forwarded-Host $http_x_forwarded_host") &&
      strcontains(nonsensitive(output.install_command), "proxy_set_header X-Forwarded-Proto $http_x_forwarded_proto") &&
      strcontains(nonsensitive(output.install_command), "map_hash_bucket_size 512") &&
      length(regexall("map_hash_bucket_size 512;[\\s\\S]*map \\$http_origin", nonsensitive(output.install_command))) > 0 &&
      strcontains(nonsensitive(output.install_command), "map $http_origin $dsh_origin_allowed") &&
      strcontains(nonsensitive(output.install_command), "\"https://dsh.example.test\" 1") &&
      strcontains(nonsensitive(output.install_command), "map $http_sec_fetch_site $dsh_fetch_site_allowed") &&
      strcontains(nonsensitive(output.install_command), "\"cross-site\" 0") &&
      strcontains(nonsensitive(output.install_command), "if ($dsh_origin_allowed = 0)") &&
      strcontains(nonsensitive(output.install_command), "if ($dsh_fetch_site_allowed = 0)") &&
      strcontains(nonsensitive(output.install_command), "return 403") &&
      strcontains(nonsensitive(output.install_command), "proxy_set_header Origin \"http://127.0.0.1:13000\"") &&
      strcontains(nonsensitive(output.install_command), "proxy_set_header Sec-Fetch-Site \"same-origin\"") &&
      !strcontains(nonsensitive(output.install_command), "proxy_set_header Origin \"\"") &&
      !strcontains(nonsensitive(output.install_command), "proxy_set_header Sec-Fetch-Site \"\"") &&
      strcontains(nonsensitive(output.install_command), "proxy_set_header Upgrade $http_upgrade") &&
      strcontains(nonsensitive(output.install_command), "proxy_set_header Connection $connection_upgrade") &&
      strcontains(nonsensitive(output.install_command), "proxy_buffering off") &&
      strcontains(nonsensitive(output.install_command), "install_nginx_candidate_file \"$auth_tmp\" \"$nginx_auth_dest\" root www-data 0640") &&
      strcontains(nonsensitive(output.install_command), "nginx_test()") &&
      strcontains(nonsensitive(output.install_command), "commit_nginx_candidate")
    )
    error_message = "安装命令必须渲染带 Basic Auth、转发头和长请求支持的 Nginx 反代。"
  }

  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "systemctl is-active --quiet deepseek-harness.service") &&
      strcontains(nonsensitive(output.install_command), "http://127.0.0.1:13000/") &&
      strcontains(nonsensitive(output.install_command), "dsh_http_code=") &&
      strcontains(nonsensitive(output.install_command), "2??)") &&
      !strcontains(nonsensitive(output.install_command), "curl --fail --silent --max-time 2 http://127.0.0.1:13000/") &&
      strcontains(nonsensitive(output.install_command), "401") &&
      strcontains(nonsensitive(output.install_command), "systemctl status deepseek-harness.service") &&
      strcontains(nonsensitive(output.install_command), "journalctl -u deepseek-harness.service") &&
      strcontains(nonsensitive(output.install_command), "systemctl status nginx") &&
      strcontains(nonsensitive(output.install_command), "journalctl -u nginx")
    )
    error_message = "安装命令必须包含服务、回环首页、Nginx 401 两层健康检查及失败日志。"
  }


  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "if [ \"$changed\" = true ] || ! systemctl is-active --quiet deepseek-harness.service; then") &&
      strcontains(nonsensitive(output.install_command), "nginx_systemctl is-active --quiet nginx") &&
      !strcontains(nonsensitive(output.install_command), "systemctl restart deepseek-harness.service\nsystemctl restart deepseek-harness.service")
    )
    error_message = "服务必须仅在配置变化或未运行时重启，未变化且健康时不得无谓重启。"
  }
}

run "does_not_render_preview_nginx" {
  command = plan

  assert {
    condition = (
      !strcontains(nonsensitive(output.install_command), "listen 0.0.0.0:30080") &&
      !strcontains(nonsensitive(output.install_command), "proxy_pass http://127.0.0.1:30080") &&
      strcontains(nonsensitive(output.install_command), "map $http_upgrade $connection_upgrade") &&
      strcontains(nonsensitive(output.install_command), "proxy_set_header Connection $connection_upgrade") &&
      strcontains(nonsensitive(output.install_command), "X-Forwarded-Proto $http_x_forwarded_proto") &&
      strcontains(nonsensitive(output.install_command), "nginx_backup_dir=") &&
      strcontains(nonsensitive(output.install_command), "restore_nginx_candidate")
    )
    error_message = "Preview 不应再渲染 Nginx server。"
  }
}

run "renders_code_server_release_service_and_proxy" {
  command = plan

  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "code-server-4.132.0-linux-amd64.tar.gz") &&
      strcontains(nonsensitive(output.install_command), "a38d26f4cb81f768feddff79e2937fd3f39c83d3da8be3da7225e1087e62e4ed") &&
      strcontains(nonsensitive(output.install_command), "ade569a677d1c04ee66ef153382b7e15bf261f955407663c7ddc6b87f9ee29fc") &&
      strcontains(nonsensitive(output.install_command), "sha256sum -c") &&
      strcontains(nonsensitive(output.install_command), "bind-addr: 127.0.0.1:3086") &&
      strcontains(nonsensitive(output.install_command), "auth: password") &&
      strcontains(nonsensitive(output.install_command), "cert: false") &&
      strcontains(nonsensitive(output.install_command), "Environment=DSH_HOME=/home/dsh/.dsh") &&
      strcontains(nonsensitive(output.install_command), "ExecStart=/usr/local/bin/code-server") &&
      strcontains(nonsensitive(output.install_command), "listen 0.0.0.0:3087") &&
      strcontains(nonsensitive(output.install_command), "proxy_pass http://127.0.0.1:3086") &&
      strcontains(nonsensitive(output.install_command), "proxy_set_header Host code.example.test") &&
      strcontains(nonsensitive(output.install_command), "code_server_http_code=") &&
      strcontains(nonsensitive(output.install_command), "code_server_proxy_http_code=") &&
      strcontains(nonsensitive(output.install_command), "401:401|401:302|302:401|302:302")
    )
    error_message = "必须固定校验 code-server release，并渲染独立配置、systemd 和 3087 代理健康检查。"
  }
}

run "keeps_password_secret" {
  command = plan

  assert {
    condition = (
      output.install_command == sensitive(output.install_command) &&
      !strcontains(nonsensitive(output.install_command), var.web_password) &&
      strcontains(nonsensitive(output.install_command), base64encode(var.web_password)) &&
      !strcontains(nonsensitive(output.install_command), var.code_server_password) &&
      strcontains(nonsensitive(output.install_command), base64encode(var.code_server_password)) &&
      strcontains(nonsensitive(output.install_command), var.web_username)
    )
    error_message = "install_command 必须敏感，且仅可包含密码的 Base64 形式，不得出现明文密码。"
  }
}

run "rejects_invalid_dsh_version" {
  command = plan
  variables {
    dsh_version = "latest; touch /tmp/pwned"
  }
  expect_failures = [var.dsh_version]
}

run "rejects_invalid_node_version" {
  command = plan
  variables {
    node_version = "22.17.0/../../bad"
  }
  expect_failures = [var.node_version]
}

run "rejects_invalid_public_authority" {
  command = plan
  variables {
    public_authority = "host; shutdown -h now"
  }
  expect_failures = [var.public_authority]
}

run "rejects_out_of_range_authority_port" {
  command = plan
  variables {
    public_authority = "dsh.example.test:70000"
  }
  expect_failures = [var.public_authority]
}

run "rejects_overlong_authority_host" {
  command = plan
  variables {
    public_authority = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.cccccccccccccccccccccccccccccccccccccccccccccccccc.dddddddddddddddddddddddddddddddddddddddddddddddddd.eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee.ffffffffffffffffffffffffffffffffffffffffffffffffff"
  }
  expect_failures = [var.public_authority]
}

run "accepts_rc_version_and_authority_port" {
  command = plan
  variables {
    dsh_version      = "0.1.0-rc.6"
    public_authority = "dsh.example.test:8443"
  }

  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "@deepseek-ai/dsh@0.1.0-rc.6") &&
      strcontains(nonsensitive(output.install_command), "--trusted-host dsh.example.test:8443")
    )
    error_message = "合法的 npm rc 版本和 host:port authority 必须保持兼容。"
  }
}

run "renders_long_authority_map" {
  command = plan
  variables {
    public_authority = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.cccccccccccccccccccccccccccccccccccccccccccccccccc.dddddddddddddddddddddddddddddddddddddddddddddddddd:65535"
  }

  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "map_hash_bucket_size 512;") &&
      strcontains(nonsensitive(output.install_command), "\"https://aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.cccccccccccccccccccccccccccccccccccccccccccccccccc.dddddddddddddddddddddddddddddddddddddddddddddddddd:65535\" 1;")
    )
    error_message = "长 authority 必须能在 512 字节 map hash bucket 下精确渲染。"
  }
}

run "rejects_invalid_web_username" {
  command = plan
  variables {
    web_username = "admin:$apr1$injected"
  }
  expect_failures = [var.web_username]
}

run "rejects_out_of_range_or_fractional_ports" {
  command = plan
  variables {
    dsh_port   = 65536
    proxy_port = 8443.5
  }
  expect_failures = [var.dsh_port, var.proxy_port]
}

run "rejects_invalid_preview_count" {
  command = plan
  variables { preview_count = 5 }
  expect_failures = [var.preview_count]
}

run "rejects_invalid_preview_ports" {
  command = plan
  variables { preview_ports = [30080, 30081, 30082] }
  expect_failures = [var.preview_ports]
}

run "renders_multiple_preview_slots" {
  command = plan
  variables {
    preview_count              = 4
    preview_public_authorities = ["one.example.test", "two.example.test", "three.example.test", "four.example.test"]
  }
  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "127.0.0.1:30080") &&
      strcontains(nonsensitive(output.install_command), "127.0.0.1:30083") &&
      strcontains(nonsensitive(output.install_command), "https://four.example.test")
    )
    error_message = "四个 Preview 槽位必须渲染各自的端口和地址。"
  }
}

run "renders_deployment_environment_skill" {
  command = plan

  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "name: las-dsh-environment") &&
      strcontains(nonsensitive(output.install_command), "disable-model-invocation: false") &&
      strcontains(nonsensitive(output.install_command), "开发、启动、调试网页或向用户提供网页预览时必须使用") &&
      strcontains(nonsensitive(output.install_command), "HOME=/home/dsh") &&
      strcontains(nonsensitive(output.install_command), "DSH_HOME=/home/dsh/.dsh") &&
      strcontains(nonsensitive(output.install_command), "/home/dsh/workspace") &&
      strcontains(nonsensitive(output.install_command), "LAS 云主机") &&
      strcontains(nonsensitive(output.install_command), "用户级 skill 目录") &&
      strcontains(nonsensitive(output.install_command), "Harness 应用：`127.0.0.1:3080`") &&
      strcontains(nonsensitive(output.install_command), "code-server：`127.0.0.1:3086`") &&
      strcontains(nonsensitive(output.install_command), "HTTPProxy 直接转发到用户应用") &&
      strcontains(nonsensitive(output.install_command), "WebSocket、HMR 或 SSE") &&
      strcontains(nonsensitive(output.install_command), "ss -ltnp") &&
      strcontains(nonsensitive(output.install_command), "systemctl --user status") &&
      strcontains(nonsensitive(output.install_command), "不适用 Harness Basic Auth") &&
      strcontains(nonsensitive(output.install_command), "https://dsh.example.test") &&
      strcontains(nonsensitive(output.install_command), "https://preview.example.test") &&
      strcontains(nonsensitive(output.install_command), "127.0.0.1:30080") &&
      strcontains(nonsensitive(output.install_command), "不要把开发服务绑定到 `0.0.0.0`") &&
      strcontains(nonsensitive(output.install_command), "密码、令牌、私钥、云凭据或其他敏感信息") &&
      strcontains(nonsensitive(output.install_command), "Environment=DSH_HOME=/home/dsh/.dsh") &&
      strcontains(nonsensitive(output.install_command), "O_NOFOLLOW") &&
      strcontains(nonsensitive(output.install_command), "os.replace(temporary, \"SKILL.md\"")
    )
    error_message = "安装命令必须安全安装可路由的 las-dsh-environment skill，并注入完整运行环境。"
  }
}

run "preview_authority_changes_skill_install_command" {
  command = plan
  variables { preview_public_authorities = ["other-preview.example.test"] }

  assert {
    condition = (
      strcontains(nonsensitive(output.install_command), "https://other-preview.example.test") &&
      !strcontains(nonsensitive(output.install_command), "https://preview.example.test")
    )
    error_message = "preview authority 变化必须改变包含 skill 正文的安装命令。"
  }
}

run "rejects_equal_ports" {
  command = plan
  variables {
    dsh_port   = 13000
    proxy_port = 13000
  }
  expect_failures = [output.install_command]
}
