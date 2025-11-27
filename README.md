# 七牛 Terraform 预设模板

## 基于本地 Terraform 运行

### 安装 Qiniu Provider

> 由于当前的七牛 Provider 暂未发布到 registry.terraform.io 平台, 故无法实现在线自动安装，需要手动下载插件二进制并拷贝到指定目录下。

- [darwin_arm64](http://srz5669lx.hn-bkt.clouddn.com/terraformprovider/registry.terraform.io/hashicorp/qiniu/1.0.0/darwin_arm64/terraform-provider-qiniu)
- [darwin_amd64](http://srz5669lx.hn-bkt.clouddn.com/terraformprovider/registry.terraform.io/hashicorp/qiniu/1.0.0/darwin_amd64/terraform-provider-qiniu)
- [linux_arm64](http://srz5669lx.hn-bkt.clouddn.com/terraformprovider/registry.terraform.io/hashicorp/qiniu/1.0.0/linux_arm64/terraform-provider-qiniu)
- [linux_amd64](http://srz5669lx.hn-bkt.clouddn.com/terraformprovider/registry.terraform.io/hashicorp/qiniu/1.0.0/linux_amd64/terraform-provider-qiniu)

编写本地配置文件，默认配置文件路径在`$HOME/.terraformrc`下

```hcl
// 全局插件缓存本地目录
plugin_cache_dir = "/home/zzq/.terraform.d/plugin-cache"

provider_installation {
  // 本地文件系统镜像源，qiniu 插件目前需要使用这种方式安装，需要将插件拷贝到指定镜像目录中
  filesystem_mirror {
    path    = "/home/zzq/.terraform.d/plugin-mirror"
    include = ["registry.terraform.io/hashicorp/qiniu"]
  }
  // 官方镜像源，需要排除 qiniu 插件的安装
  direct {
    exclude = ["registry.terraform.io/hashicorp/qiniu"]
  }
}
```

将插件复制到配置文件中配置的对应目录下，比如一个示例的目录结构如下：

```text
➜  .terraform.d tree
.
├── checkpoint_cache
├── checkpoint_signature
├── plugin-cache
└── plugin-mirror
    └── registry.terraform.io
        └── hashicorp
            └── qiniu
                └── 1.0.0
                    └── linux_amd64
                        └── terraform-provider-qiniu
```

### 运行相应的 Terraform Module

设置环境变量

```sh
# Qiniu 账户的AK/SK
export QINIU_ACCESS_KEY="QINIU_ACCESS_KEY"
export QINIU_SECRET_KEY="<QINIU_SECRET_KEY>"
# 要操作的资源默认的区域ID
export QINIU_REGION_ID="ap-southeast-1"
```

#### 一键部署单实例 MySQL 应用

```bash
cd mysql/standalone
terraform init
terraform apply
# 之后将要交互式输入各个tf模板参数，绝大部分参数都有默认值，这里只必填一个密码即可
```

操作界面如下：

```text
➜  standalone git:(main) ✗ terraform apply
var.mysql_password
  MySQL password

  Enter a value:

data.qiniu_compute_images.available_official_images: Reading...
data.qiniu_compute_images.available_official_images: Read complete after 0s

Terraform used the selected providers to generate the following execution plan. Resource
actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # qiniu_compute_instance.mysql_primary_node will be created
  + resource "qiniu_compute_instance" "mysql_primary_node" {
      + cost_charge_type     = "PostPaid"
      + cpu                  = (known after apply)
      + created_at           = (known after apply)
      + description          = (known after apply)
      + id                   = (known after apply)
      + image_id             = "68007b52495c899e195a1e15"
      + image_name           = (known after apply)
      + instance_type        = "ecs.t1.c1m2"
      + memory               = (known after apply)
      + name                 = (known after apply)
      + password             = (sensitive value)
      + private_ip_addresses = (known after apply)
      + public_ip_addresses  = (known after apply)
      + region_id            = (known after apply)
      + region_name          = (known after apply)
      + state                = "Running"
      + system_disk_id       = (known after apply)
      + system_disk_size     = 20
      + system_disk_type     = "local.ssd"
      + user_data            = (sensitive value)
    }

  # random_password.mysql_instance_password will be created
  + resource "random_password" "mysql_instance_password" {
      + bcrypt_hash = (sensitive value)
      + id          = (known after apply)
      + length      = 16
      + lower       = true
      + min_lower   = 0
      + min_numeric = 0
      + min_special = 0
      + min_upper   = 0
      + number      = true
      + numeric     = true
      + result      = (sensitive value)
      + special     = true
      + upper       = true
    }

  # random_string.resource_suffix will be created
  + resource "random_string" "resource_suffix" {
      + id          = (known after apply)
      + length      = 6
      + lower       = true
      + min_lower   = 0
      + min_numeric = 0
      + min_special = 0
      + min_upper   = 0
      + number      = true
      + numeric     = true
      + result      = (known after apply)
      + special     = false
      + upper       = false
    }

Plan: 3 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + mysql_primary_endpoint = (known after apply)

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

random_string.resource_suffix: Creating...
random_password.mysql_instance_password: Creating...
random_string.resource_suffix: Creation complete after 0s [id=93wsze]
random_password.mysql_instance_password: Creation complete after 0s [id=none]
qiniu_compute_instance.mysql_primary_node: Creating...
qiniu_compute_instance.mysql_primary_node: Still creating... [00m10s elapsed]
qiniu_compute_instance.mysql_primary_node: Still creating... [00m20s elapsed]
qiniu_compute_instance.mysql_primary_node: Still creating... [00m30s elapsed]
qiniu_compute_instance.mysql_primary_node: Still creating... [00m40s elapsed]
qiniu_compute_instance.mysql_primary_node: Creation complete after 41s [id=i-69281ce0e3108870683f3b35]

Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

mysql_primary_endpoint = "10.198.1.44:3306"
```

> Tips: 也可以同目录创建一个 `.tfvars.json` 后缀结尾的 json 文件，里面放入所有 `variables.tf`中定义的变量值作为输入，apply 时将自动读取。

其他一些常用操作：

```bash
# 销毁所有已创建资源
terraform destroy
# 查看资源变更计划
terraform plan
# 导出资源变更计划文件
terraform plan -out="tfplan"
# 基于资源变更计划文件进行apply变更
terraform apply "tfplan"
```

## 基于七牛资源栈在线运行

TODO
