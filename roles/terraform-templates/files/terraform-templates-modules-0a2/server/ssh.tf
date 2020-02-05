resource aws_key_pair server {
  key_name = "${var.role}${var.id}-${var.namestamp}-ssh"
  public_key = "${var.ssh_key}"
}
