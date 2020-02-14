{{ range counter .starks }}
module stark{{.}} {
  source = "terraform-templates-modules-0a2/server"
  region = "{{ left (index $.starks_zones .) (sub (len (index $.starks_zones .)) 1) }}"
  availability_zone = "{{ index $.starks_zones . }}"
  ami_owner = "{{ $.AMI_OWNER }}"
  ami_name = "{{ $.AMI_NAME }}"
  instance_type = "{{ $.instance_type }}"
  ssh_key = "{{ $.SSH_KEY }}"
  role = "stark"
  id = "{{ . }}"
  nightking_public_ip = "{{ $.NIGHTKING_IP }}"
  nightking_private_ip = "{{ $.NIGHTKING_PRIVATE_IP }}"
  nightking_seed_node_id = "{{ $.NIGHTKING_SEED_NODE_ID}}"
  telegraf = "{{ $.INFLUX_TELEGRAF_PASSWORD }}"
  experiments = "{{ $.XP }}"
  dev = "{{ $.DEV }}"
  nightking_host_key = "{{ $.NIGHTKING_HOST_KEY }}"
  user_data_base64_rendered = "${data.template_cloudinit_config.userdata.rendered}"
  namestamp = "{{ $.NIGHTKING_NAMESTAMP }}"
}

output "stark{{.}}" {
  value = "${module.stark{{.}}.public_ip}"
}

{{end}}
