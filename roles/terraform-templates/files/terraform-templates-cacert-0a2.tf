data "template_cloudinit_config" "userdata" {
  gzip = true
  base64_encode = true
  part {
    content = <<EOF
#!/bin/sh
echo '{{ .CACERT }}' > /var/log/nightking/ca.crt
cat /var/log/nightking/ca.crt | tr '$' '\n' >> /etc/ssl/certs/ca-bundle.crt
echo '{{ .POOL_KEY }}' | tr '$' '\n' > /var/log/nightking/cache/pool.key
chmod 400 /var/log/nightking/cache/pool.key
touch /var/log/nightking/flag/user-data-finished
EOF
  }
}
