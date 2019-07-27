output "instance_ids" {
  value = "${alicloud_instance.default.*.id}"
}

output "image_ids" {
  value = "${alicloud_instance.default.*.image_id}"
}

output "instance_names" {
  value = "${alicloud_instance.default.*.instance_name}"
}

output "instance_types" {
  value = "${alicloud_instance.default.*.instance_type}"
}

output "role_names" {
  value = "${alicloud_instance.default.*.role_name}"
}

output "security_groups" {
  value = "${alicloud_instance.default.*.security_groups}"
}

output "vswitch_ids" {
  value = "${alicloud_instance.default.*.vswitch_id}"
}

output "tags" {
  value = "${alicloud_instance.default.*.tags}"
}

output "volume_tags" {
  value = "${alicloud_instance.default.*.volume_tags}"
}

output "host_names" {
  value = "${alicloud_instance.default.*.host_name}"
}

output "public_ips" {
  value = "${alicloud_instance.default.*.public_ip}"
}

output "private_ips" {
  value = "${alicloud_instance.default.*.private_ip}"
}

output "data_disks" {
  value = "${alicloud_instance.default.*.data_disks}"
}