// Todo: Restrict stark/whitewalker server AWS access
data "aws_iam_policy_document" "ec2_permissions" {
  statement {
    sid = "ec2read"

    effect = "Allow"

    actions = [
      "ec2:Describe*",
    ]

    resources = [
      "*",
    ]
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

resource "aws_iam_role" "ec2_permissions" {
  name                  = "${var.role}${var.id}-self-read-role"
  assume_role_policy    = "${data.aws_iam_policy_document.ec2_assume.json}"
  force_detach_policies = true
}

resource "aws_iam_policy" "ec2_permissions" {
  policy     = "${data.aws_iam_policy_document.ec2_permissions.json}"
  name       = "${var.role}${var.id}-self-read-policy"
}

resource aws_iam_role_policy_attachment server {
  policy_arn = "${aws_iam_policy.ec2_permissions.arn}"
  role       = "${aws_iam_role.ec2_permissions.name}"
}

resource aws_iam_instance_profile server {
  name = "${aws_iam_role.ec2_permissions.name}"
  role = "${aws_iam_role.ec2_permissions.name}"
}
