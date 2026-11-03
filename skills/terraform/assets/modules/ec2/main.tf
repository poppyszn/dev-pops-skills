data "aws_ssm_parameter" "ami" {
  name = var.ami_ssm_parameter_name
}

# Instance role: allows Session Manager access so no SSH port or key pair is needed.
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${var.name}-instance-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name}-instance-profile"
  role = aws_iam_role.instance.name

  tags = var.tags
}

resource "aws_instance" "instance" {
  ami                    = data.aws_ssm_parameter.ami.value
  instance_type          = var.instance_type
  vpc_security_group_ids = var.vpc_security_group_ids
  iam_instance_profile   = aws_iam_instance_profile.instance.name

  root_block_device {
    encrypted   = var.root_block_device_encrypted
    volume_size = var.root_block_device_volume_size
    volume_type = var.root_block_device_volume_type
  }

  # IMDSv2 only. The hop limit is how far the token response may travel: 1
  # reaches the host, but a container behind Docker's bridge is one hop further,
  # so its AWS SDK cannot get the instance role's credentials. A host that runs
  # containers needs 2.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = var.metadata_hop_limit
  }

  user_data = var.user_data

  tags = var.tags

  # The AMI parameter moves with every Canonical release; replacing a running
  # instance for that should be a deliberate choice, not a side effect of a plan.
  # User data runs once, on first boot: editing it later would stop a running
  # host to change an attribute that does nothing, so it is ignored after create.
  lifecycle {
    ignore_changes = [ami, user_data]
  }
}

# A fixed public address survives a stop/start, so DNS records can point at it.
resource "aws_eip" "instance" {
  count = var.elastic_ip ? 1 : 0

  domain = "vpc"

  tags = merge(var.tags, { Name = var.name })
}

resource "aws_eip_association" "instance" {
  count = var.elastic_ip ? 1 : 0

  instance_id   = aws_instance.instance.id
  allocation_id = aws_eip.instance[0].id
}
