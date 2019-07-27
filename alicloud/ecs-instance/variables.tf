variable "consul_address" {
  type    = string
  default = "127.0.0.1:8500"
}

variable "vpc_id" {
  type    = string
  default = ""
}

variable "vpc_name_regex" {
  type    = string
  default = ".*"
}

variable "vswitch_id" {
  type    = string
  default = ""
}

variable "instance_type" {
  type    = string
  default = ""
}

variable "instance_type_family" {
  type    = string
  default = "ecs.t5"
}

variable "cpu_core_count" {
  type    = number
  default = 1
}

variable "memory_size" {
  type    = number
  default = 2
}

variable "name" {
  type = string
}

variable "security_group_rules" {
  type = list(map(string))
  default = [
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
}

variable "instance_count" {
  type    = number
  default = 1
}

variable "image_id" {
  type    = string
  default = ""
}

variable "image_name_regex" {
  type    = string
  default = "^centos_7.*_64"
}

variable "use_num_suffix" {
  type    = bool
  default = false
}

variable "private_ip" {
  type    = string
  default = ""
}

variable "private_ips" {
  type    = list(string)
  default = []
}

variable "internet_charge_type" {
  type    = string
  default = "PayByTraffic"
}

variable "internet_max_bandwidth_out" {
  type    = number
  default = 0
}

variable "username" {
  type    = string
  default = "root"
}

variable "password" {
  type    = string
  default = ""
}

variable "key_name" {
  type    = string
  default = ""
}

variable "private_key_path" {
  type    = string
  default = ""
}

variable "role_name" {
  type    = string
  default = ""
}

variable "instance_charge_type" {
  type    = string
  default = "PostPaid"
}

variable "system_disk_category" {
  type    = string
  default = "cloud_efficiency"
}

variable "data_disks" {
  type    = list(map(string))
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "volume_tags" {
  type    = map(string)
  default = {}
}

variable "user_data_file" {
  type    = string
  default = ""
}

variable "playbook_file" {
  type    = string
  default = ""
}

# variable "consul_datacenter" {
#   type    = string
#   default = "dc1"
# }

# variable "consul_services" {
#   type    = list
#   default = []
# }