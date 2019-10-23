resource aws_key_pair server {
  key_name = "${var.role}${var.id}-ssh"
  public_key = "${var.ssh_key}"
}
