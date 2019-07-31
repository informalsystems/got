variable nightking-experiments {
  description = "Comma-separated list of experiments to run"
  type        = "string"
  default     = "xp0"
}

variable nightking-ami {
  description = "AWS AMI to use"
  type        = "string"
}

variable user-ip {
  description = "IP of the executing user so the user can log in to the web interface and SSH"
  type        = "string"
}

variable default-password {
  description = "Change the default password on the Grafana server from 'admin' to something else."
  type        = "string"
  default     = "notverysecurepassword"
}

variable debug {
  description = "Set this to '1', to enable troubleshooting mode. This will keep all the infrastructure around after execution."
  type        = "string"
  default     = ""
}

provider aws {
  region = "us-east-1"
}

resource aws_key_pair nightking {
  key_name   = "nightking-greg"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDY1d1L3iKHbv1Ivn2zYxdmaohSFwHb4l1lUp+yso1fhvRxJ0NqxLM34vmyRvwNwbukdRSiC84QbQ9Bxl4TuU3H+Gbxs1xfhVIhyRrHwEp8hp6U1pfuG29NtzUwViRxvHKv/HF7sLcA/1ks9ZD0prqP6UkDkivcrlV4iXVEcRCsuhoWYqnOiq93SPTMY5S0CA1jt69+zz07K+QN/TUrgua3TROlWksdGuv35zcf7TIWZIkEElK7HCe6EnhLq3hEe5XgqGIuzDMh/D1rPZ5mBq+YPc1x9f+Y+NPm08UD1WS3OJzPNvHYHYwx6mVnrlwN3AyK5+d7wsSv6fNA2vGqAz/5 greg"
}

resource aws_security_group nightking {
  name = "nightking-security-group"

  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = ["${var.user-ip}/32"]
  }

  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["${var.user-ip}/32"]
    description = "Nginx web server port"
  }

  ingress {
    from_port   = 443
    protocol    = "tcp"
    to_port     = 443
    cidr_blocks = ["${var.user-ip}/32"]
    description = "Grafana web server TLS port"
  }

  ingress {
    from_port   = 8086
    protocol    = "tcp"
    to_port     = 8086
    cidr_blocks = ["0.0.0.0/0"]
    description = "InfluxDB TLS port"
  }

  ingress {
    from_port   = 26656
    protocol    = "tcp"
    to_port     = 26656
    cidr_blocks = ["0.0.0.0/0"]
    description = "Tendermint P2P port"
  }

  ingress {
    from_port   = 26670
    protocol    = "tcp"
    to_port     = 26670
    cidr_blocks = ["0.0.0.0/0"]
    description = "tm-load-test master port"
  }

  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data aws_iam_policy_document "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }

    effect = "Allow"
  }
}

data "aws_iam_policy_document" "ec2_permissions" {
  statement {
    sid = "ec2fullaccess"

    effect = "Allow"

    actions = [
      "ec2:*",
      "iam:*",
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_iam_role" "ec2_permissions" {
  name                  = "nightking-ec2-permissions-role"
  assume_role_policy    = "${data.aws_iam_policy_document.ec2_assume.json}"
  force_detach_policies = true
}

resource "aws_iam_policy" "ec2_permissions" {
  policy = "${data.aws_iam_policy_document.ec2_permissions.json}"
  name   = "nightking-ec2-permissions-policy"
}

resource aws_iam_role_policy_attachment nightking {
  policy_arn = "${aws_iam_policy.ec2_permissions.arn}"
  role       = "${aws_iam_role.ec2_permissions.name}"
}

resource aws_iam_instance_profile nightking {
  name = "${aws_iam_role.ec2_permissions.name}"
  role = "${aws_iam_role.ec2_permissions.name}"
}

resource aws_instance nightking {
  ami                         = "${var.nightking-ami}"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.nightking.name}"
  security_groups             = ["${aws_security_group.nightking.name}"]
  key_name                    = "${aws_key_pair.nightking.key_name}"

  root_block_device {
    volume_size           = "8"
    delete_on_termination = true
  }

  tags {
    Name        = "nightking"
    role        = "nightking"
    experiments = "${var.nightking-experiments}"
    debug       = "${var.debug}"
    password    = "${var.default-password}"
  }
}

output nightking {
  value = "${aws_instance.nightking.public_dns}"
}

