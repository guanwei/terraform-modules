# AliCloud ECS Module

Terraform module which creates ECS instance(s) in Alicloud VPC.

## Usage

### Create a ECS instance with eip and run ansible locally

```terraform
module "tf-instance" {
  source = "github.com/guanwei/terraform-modules//alicloud/ecs-instance"

  name           = "ecs_instance"
  image_id       = "centos_7_06_64_20G_alibase_20190711.vhd"
  key_name       = "for-ecs-instance-module"
  vpc_id         = "vpc-wqrw3c423"
  cpu_core_count = 1
  memory_size    = 2
  security_group_rules = [
    {
      type        = "ingress"
      ip_protocol = "tcp"
      nic_type    = "intranet"
      policy      = "accept"
      port_range  = "22/22"
      priority    = 1
      cidr_ip     = "0.0.0.0/0"
    },
  ]
  eip = {
    bandwidth = 100
  }
  sleep_time    = 60
  playbook_file = "playbook.yml"
  playbook_extra_vars = {
    key = "value"
  }
}
```

### Create a ECS instance without eip and run ansible on ansible server

```terraform
module "tf-instance" {
  source = "github.com/guanwei/terraform-modules//alicloud/ecs-instance"

  name           = "ecs_instance"
  image_id       = "centos_7_06_64_20G_alibase_20190711.vhd"
  key_name       = "for-ecs-instance-module"
  vpc_id         = "vpc-wqrw3c423"
  cpu_core_count = 1
  memory_size    = 2
  security_group_rules = [
    {
      type        = "ingress"
      ip_protocol = "tcp"
      nic_type    = "intranet"
      policy      = "accept"
      port_range  = "22/22"
      priority    = 1
      cidr_ip     = "0.0.0.0/0"
    },
  ]
  sleep_time = 60
  ansible_server = {
    host        = "10.10.0.1"
    user        = "ansible"
    private_key = "${file('~/.ssh/ansible_private_key')}"
  }
  playbook_file = "playbook.yml"
  playbook_extra_vars = {
    key = "value"
  }
}
```

## Authors

Created and maintained by Edward Guan <285006386@qq.com>.

## Reference

* [Terraform-Provider-Alicloud Github](https://github.com/terraform-providers/terraform-provider-alicloud)
* [Terraform-Provider-Alicloud Release](https://releases.hashicorp.com/terraform-provider-alicloud/)
* [Terraform-Provider-Alicloud Docs](https://www.terraform.io/docs/providers/alicloud/index.html)