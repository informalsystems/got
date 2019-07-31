output "public_ip" {
  value = "${aws_instance.server.public_ip}"
}
