data "template_cloudinit_config" "userdata" {
  gzip = true
  base64_encode = true
  part {
    content = <<EOF
#!/bin/sh
echo '{{ .CACERT }}' | tr '$' '\n' >> /etc/ssl/certs/ca-bundle.crt
EOF
  }
}
