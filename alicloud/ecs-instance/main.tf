terraform {
  required_version = ">= 0.12"
}

data "alicloud_vpcs" "default" {
  name_regex = "${var.vpc_name_regex}"
  status     = "Available"
}

data "alicloud_instance_types" "default" {
  instance_type_family = "${var.instance_type_family}"
  cpu_core_count       = "${var.cpu_core_count}"
  memory_size          = "${var.memory_size}"
}

data "alicloud_zones" "default" {
  available_resource_creation = "VSwitch"
  available_instance_type     = "${data.alicloud_instance_types.default.instance_types.0.id}"
}

data "alicloud_vswitches" "default" {
  name_regex = "${var.vswitch_name_regex}"
  zone_id    = "${data.alicloud_zones.default.zones.0.id}"
  vpc_id     = "${var.vpc_id == "" ? data.alicloud_vpcs.default.vpcs.0.id : var.vpc_id}"
}

data "alicloud_images" "default" {
  most_recent = true
  owners      = "${var.image_owners}"
  name_regex  = "${var.image_name_regex}"
}

resource "alicloud_security_group" "default" {
  name   = "${var.name}"
  vpc_id = "${var.vpc_id == "" ? data.alicloud_vpcs.default.vpcs.0.id : var.vpc_id}"
}

resource "alicloud_security_group_rule" "default" {
  count             = "${length(var.security_group_rules)}"
  type              = "${lookup(var.security_group_rules[count.index], "type", null)}"
  ip_protocol       = "${lookup(var.security_group_rules[count.index], "ip_protocol", null)}"
  nic_type          = "${lookup(var.security_group_rules[count.index], "nic_type", "internet")}"
  policy            = "${lookup(var.security_group_rules[count.index], "policy", "accept")}"
  port_range        = "${lookup(var.security_group_rules[count.index], "port_range", "-1/-1")}"
  priority          = "${lookup(var.security_group_rules[count.index], "priority", "1")}"
  security_group_id = "${alicloud_security_group.default.id}"
  cidr_ip           = "${lookup(var.security_group_rules[count.index], "cidr_ip", "0.0.0.0/0")}"
}

resource "alicloud_instance" "default" {
  count         = "${var.instance_count}"
  image_id      = "${var.image_id == "" ? data.alicloud_images.default.images.0.id : var.image_id}"
  instance_type = "${var.instance_type == "" ? data.alicloud_instance_types.default.instance_types.0.id : var.instance_type}"
  instance_name = "${var.instance_count > 1 || var.use_num_suffix ? format("%s-%d", var.name, count.index + 1) : var.name}"

  role_name       = "${var.role_name}"
  security_groups = ["${alicloud_security_group.default.id}"]

  vswitch_id = "${var.vswitch_id == "" ? data.alicloud_vswitches.default.vswitches.0.id : var.vswitch_id}"
  private_ip = "${length(var.private_ips) > 0 ? element(var.private_ips, count.index) : var.private_ip}"

  internet_charge_type       = "${var.internet_charge_type}"
  internet_max_bandwidth_out = "${length(var.eip) == 0 ? var.internet_max_bandwidth_out : 0}"

  password = "${var.password}"
  key_name = "${var.key_name}"

  instance_charge_type = "${var.instance_charge_type}"
  system_disk_category = "${var.system_disk_category}"

  dynamic "data_disks" {
    for_each = "${var.data_disks}"
    content {
      name                 = "${var.name}"
      size                 = "${lookup(data_disks.value, "size", null)}"
      category             = "${lookup(data_disks.value, "category", "cloud_efficiency")}"
      encrypted            = "${lookup(data_disks.value, "encrypted", false)}"
      delete_with_instance = "${lookup(data_disks.value, "delete_with_instance", true)}"
    }
  }

  tags        = "${var.tags}"
  volume_tags = "${var.volume_tags}"

  user_data = "${var.user_data_file == "" ? var.user_data : file(var.user_data_file)}"

  provisioner "local-exec" {
    command = "sleep ${var.sleep_time}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "alicloud_eip" "default" {
  count                = "${length(var.eip) == 0 ? 0 : var.instance_count}"
  bandwidth            = "${lookup(var.eip, "bandwidth", 5)}"
  internet_charge_type = "${lookup(var.eip, "internet_charge_type", "PayByTraffic")}"
  instance_charge_type = "${lookup(var.eip, "instance_charge_type", "PostPaid")}"
  isp                  = "${lookup(var.eip, "isp", "BGP")}"
}

resource "alicloud_eip_association" "default" {
  count         = "${length(var.eip) == 0 ? 0 : var.instance_count}"
  allocation_id = "${element(alicloud_eip.default.*.id, count.index)}"
  instance_id   = "${element(alicloud_instance.default.*.id, count.index)}"
}

locals {
  public_ips         = "${length(var.eip) == 0 ? alicloud_instance.default.*.public_ip : alicloud_eip.default.*.ip_address}"
  private_ips        = "${alicloud_instance.default.*.private_ip}"
  ansible_hosts      = "${length(local.public_ips[0]) == 0 ? local.private_ips : local.public_ips}"
  ansible_roles_path = "${var.ansible_roles_path == "" && var.ansible_playbook_file != "" ? "${dirname(var.ansible_playbook_file)}/roles" : var.ansible_roles_path}"
}

resource "null_resource" "ansible_with_password" {
  count = "${var.ansible_playbook_file != "" && var.key_name == "" && length(var.ansible_server) == 0 ? 1 : 0}"
  provisioner "local-exec" {
    command = <<EOF
      touch ~/.ssh/known_hosts
      export IFS=","
      ansible_hosts="${join(",", local.ansible_hosts)}"
      for ansible_host in $ansible_hosts; do
        ssh-keygen -R $ansible_host
      done
    EOF
  }
  provisioner "local-exec" {
    command = "ansible-playbook --flush-cache -i '${join(",", local.ansible_hosts)},' -u '${var.username}' -e 'ansible_password=\"${var.password}\"' --extra-vars='${jsonencode(var.ansible_playbook_extra_vars)}' ${var.ansible_playbook_file}"
    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
      ANSIBLE_ROLES_PATH        = "${local.ansible_roles_path}"
    }
  }

  triggers = {
    instance_ids                = "${join(",", alicloud_instance.default.*.id)}"
    ansible_playbook_extra_vars = "${jsonencode(var.ansible_playbook_extra_vars)}"
    ansible_playbook_file_sha1  = "${sha1(file(var.ansible_playbook_file))}"
  }

  depends_on = ["alicloud_eip_association.default"]
}

resource "null_resource" "remote_ansible_with_password" {
  count = "${var.ansible_playbook_file != "" && var.key_name == "" && length(var.ansible_server) > 0 ? 1 : 0}"
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/.ansible/roles/",
    ]
  }
  provisioner "file" {
    source      = "${var.ansible_playbook_file}"
    destination = "/tmp/"
  }
  provisioner "file" {
    source      = "${local.ansible_roles_path}/"
    destination = "~/.ansible/roles/"
  }
  provisioner "remote-exec" {
    inline = [
      "touch ~/.ssh/known_hosts",
      "export IFS=','",
      "ansible_hosts='${join(",", local.ansible_hosts)}'",
      "for ansible_host in $$ansible_hosts; do",
      "ssh-keygen -R $$ansible_host",
      "done",
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "export ANSIBLE_HOST_KEY_CHECKING=False",
      "ansible-playbook --flush-cache -i '${join(",", local.ansible_hosts)},' -u '${var.username}' -e 'ansible_password=\"${var.password}\"' --extra-vars='${jsonencode(var.ansible_playbook_extra_vars)}' /tmp/${basename(var.ansible_playbook_file)}",
    ]
  }

  connection {
    type        = "ssh"
    user        = "${lookup(var.ansible_server, "user", "root")}"
    password    = "${lookup(var.ansible_server, "password", null)}"
    private_key = "${lookup(var.ansible_server, "private_key", null)}"
    host        = "${lookup(var.ansible_server, "host", null)}"
    port        = "${lookup(var.ansible_server, "port", 22)}"
    timeout     = "${lookup(var.ansible_server, "timeout", null)}"
  }

  triggers = {
    instance_ids                = "${join(",", alicloud_instance.default.*.id)}"
    ansible_playbook_extra_vars = "${jsonencode(var.ansible_playbook_extra_vars)}"
    ansible_playbook_file_sha1  = "${sha1(file(var.ansible_playbook_file))}"
  }

  depends_on = ["alicloud_eip_association.default"]
}

resource "null_resource" "ansible_with_key" {
  count = "${var.ansible_playbook_file != "" && var.key_name != "" && length(var.ansible_server) == 0 ? 1 : 0}"
  provisioner "local-exec" {
    command = <<EOF
      touch ~/.ssh/known_hosts
      export IFS=","
      ansible_hosts="${join(",", local.ansible_hosts)}"
      for ansible_host in $ansible_hosts; do
        ssh-keygen -R $ansible_host
      done
    EOF
  }
  provisioner "local-exec" {
    command = "ansible-playbook --flush-cache -i '${join(",", local.ansible_hosts)},' -u '${var.username}' --private-key='${var.private_key_path}' --extra-vars='${jsonencode(var.ansible_playbook_extra_vars)}' ${var.ansible_playbook_file}"
    environment = {
      ANSIBLE_HOST_KEY_CHECKING = "False"
      ANSIBLE_ROLES_PATH        = "${local.ansible_roles_path}"
    }
  }

  triggers = {
    instance_ids                = "${join(",", alicloud_instance.default.*.id)}"
    ansible_playbook_extra_vars = "${jsonencode(var.ansible_playbook_extra_vars)}"
    ansible_playbook_file_sha1  = "${sha1(file(var.ansible_playbook_file))}"
  }

  depends_on = ["alicloud_eip_association.default"]
}

resource "null_resource" "remote_ansible_with_key" {
  count = "${var.ansible_playbook_file != "" && var.key_name != "" && length(var.ansible_server) > 0 ? 1 : 0}"
  provisioner "remote-exec" {
    inline = [
      "mkdir -p ~/.ansible/roles/",
    ]
  }
  provisioner "file" {
    source      = "${var.private_key_path}"
    destination = "/tmp/${basename(var.private_key_path)}"
  }
  provisioner "file" {
    source      = "${var.ansible_playbook_file}"
    destination = "/tmp/${basename(var.ansible_playbook_file)}"
  }
  provisioner "file" {
    source      = "${local.ansible_roles_path}/"
    destination = "~/.ansible/roles/"
  }
  provisioner "remote-exec" {
    inline = [
      "touch ~/.ssh/known_hosts",
      "export IFS=','",
      "ansible_hosts='${join(",", local.ansible_hosts)}'",
      "for ansible_host in $ansible_hosts; do",
      "  ssh-keygen -R $ansible_host",
      "done",
    ]
  }
  provisioner "remote-exec" {
    inline = [
      "export ANSIBLE_HOST_KEY_CHECKING=False",
      "chmod 0600 /tmp/${basename(var.private_key_path)}",
      "ansible-playbook --flush-cache -i '${join(",", local.ansible_hosts)},' -u '${var.username}' --private-key='/tmp/${basename(var.private_key_path)}' --extra-vars='${jsonencode(var.ansible_playbook_extra_vars)}' /tmp/${basename(var.ansible_playbook_file)}",
    ]
  }

  connection {
    type        = "ssh"
    user        = "${lookup(var.ansible_server, "user", "root")}"
    password    = "${lookup(var.ansible_server, "password", null)}"
    private_key = "${lookup(var.ansible_server, "private_key", null)}"
    host        = "${lookup(var.ansible_server, "host", null)}"
    port        = "${lookup(var.ansible_server, "port", 22)}"
    timeout     = "${lookup(var.ansible_server, "timeout", null)}"
  }

  triggers = {
    instance_ids                = "${join(",", alicloud_instance.default.*.id)}"
    ansible_playbook_extra_vars = "${jsonencode(var.ansible_playbook_extra_vars)}"
    ansible_playbook_file_sha1  = "${sha1(file(var.ansible_playbook_file))}"
  }

  depends_on = ["alicloud_eip_association.default"]
}

## BUG: Currently consul module has issue，once service registered on consul，will auto deregister soon.

# data "consul_nodes" "default" {
#   query_options {
#     datacenter = "${var.consul_datacenter}"
#   }
# }

# resource "consul_service" "default" {
#   count      = "${length(var.consul_services) * var.instance_count}"
#   name       = "${var.consul_services[count.index % length(var.consul_services)]["name_prefix"]}-${replace(alicloud_instance.default.*.private_ip[floor(count.index / length(var.consul_services))], ".", "-")}"
#   node       = "${data.consul_nodes.default.node_names[0]}"
#   address    = "${alicloud_instance.default.*.private_ip[floor(count.index / length(var.consul_services))]}"
#   port       = "${lookup(var.consul_services[count.index % length(var.consul_services)], "port", 80)}"
#   tags       = "${lookup(var.consul_services[count.index % length(var.consul_services)], "tags", [])}"

#   dynamic "check" {
#     for_each = "${lookup(var.consul_services[count.index % length(var.consul_services)], "check", null) != null ? [var.consul_services[count.index % length(var.consul_services)]["check"]] : []}"
#     content {
#       check_id                          = "${lookup(check.value, "check_id", null)}"
#       name                              = "${lookup(check.value, "name", null)}"
#       status                            = "${lookup(check.value, "status", "critical")}"
#       tcp                               = "${lookup(check.value, "tcp", null)}"
#       http                              = "${lookup(check.value, "http_path", null) != null ? "${lookup(check.value, "http_protocol", "http")}://${alicloud_instance.default.*.private_ip[floor(count.index / length(var.consul_services))]}:${lookup(var.consul_services[count.index % length(var.consul_services)], "port", 80)}${check.value["http_path"]}" : null}"
#       tls_skip_verify                   = "${lookup(check.value, "tls_skip_verify", false)}"
#       method                            = "${lookup(check.value, "method", "GET")}"
#       interval                          = "${lookup(check.value, "interval", null)}"
#       timeout                           = "${lookup(check.value, "timeout", "1s")}"
#       deregister_critical_service_after = "${lookup(check.value, "deregister_critical_service_after", "30s")}"

#       dynamic "header" {
#         for_each = "${lookup(check.value, "header", [])}"
#         content {
#           name  = "${lookup(header.value, "name", null)}"
#           value = "${lookup(header.value, "value", null)}"
#         }
#       }
#     }
#   }

#   depends_on = [
#     "null_resource.ansible_with_password",
#     "null_resource.ansible_with_key"
#   ]
# }