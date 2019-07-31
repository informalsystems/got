{{ range counter .whitewalkers }}
module whitewalker{{.}} {
  source = "terraform-templates-modules-0a1/server"
  region = "{{ left (index $.whitewalkers_zones .) (sub (len (index $.whitewalkers_zones .)) 1) }}"
  availability_zone = "{{ index $.whitewalkers_zones . }}"
  ami_owner = "{{ $.AMI_OWNER }}"
  ami_name = "{{ $.AMI_NAME }}"
  instance_type = "{{ $.instance_type }}"
  role = "whitewalker"
  id = "{{ . }}"
  nightking_hostname = "{{ $.NIGHTKING_HOSTNAME }}"
  nightking_public_ip = "{{ $.NIGHTKING_IP }}"
  nightking_private_ip = "{{ $.NIGHTKING_PRIVATE_IP }}"
  nightking_seed_node_id = "{{ $.NIGHTKING_SEED_NODE_ID}}"
  telegraf = "{{ $.INFLUX_TELEGRAF_PASSWORD }}"
  experiments = "{{ $.XP }}"
  user_data_base64_rendered = "${data.template_cloudinit_config.userdata.rendered}"
}
{{end}}
