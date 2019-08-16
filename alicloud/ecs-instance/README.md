# AliCloud ECS Module

Terraform module which creates EC2 instance(s) in Alicloud VPC.

## Usage

You can use this in your terraform template with the following steps.

1. Adding a module resource to your template, e.g. `main.tf`

```terraform
module "tf-instance" {
    source = "git::git@code.aliyun.com:cdi-hsc/terraform-modules.git//alicloud/ecs-instance"

    name     = "ecs_instance"
    image_id = "centos_7_06_64_20G_alibase_20190711.vhd"
    key_name = "for-ecs-instance-module"
    vpc_id   = "vpc-wqrw3c423"
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

2. Setting `access_key` and `secret_key` values through environment variables:

- ALICLOUD_ACCESS_KEY
- ALICLOUD_SECRET_KEY

## Authors

Created and maintained by CDI HSC.

## Reference

* [Terraform-Provider-Alicloud Github](https://github.com/terraform-providers/terraform-provider-alicloud)
* [Terraform-Provider-Alicloud Release](https://releases.hashicorp.com/terraform-provider-alicloud/)
* [Terraform-Provider-Alicloud Docs](https://www.terraform.io/docs/providers/alicloud/index.html)