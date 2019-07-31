data aws_ami "server" {
  owners = ["${var.ami_owner}"]

  filter {
    name = "name"
    values = ["${var.ami_name}"]
  }
}
