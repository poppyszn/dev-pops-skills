data "aws_ssm_parameter" "ecs_ami" {
  name = var.ami_ssm_parameter_name
}

# Instance role: lets the ECS agent register with the cluster, and allows
# Session Manager access so no SSH port is needed.
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
  name               = "${var.name}-ecs-instance-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name}-ecs-instance-profile"
  role = aws_iam_role.instance.name

  tags = var.tags
}

resource "aws_launch_template" "ecs" {
  name_prefix            = "${var.name}-ecs-"
  image_id               = data.aws_ssm_parameter.ecs_ami.value
  instance_type          = var.instance_type
  vpc_security_group_ids = var.vpc_security_group_ids
  update_default_version = true

  iam_instance_profile {
    arn = aws_iam_instance_profile.instance.arn
  }

  user_data = base64encode(<<-EOT
    #!/bin/bash
    echo "ECS_CLUSTER=${var.cluster_name}" >> /etc/ecs/ecs.config
  EOT
  )

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      encrypted             = var.root_block_device_encrypted
      volume_size           = var.root_block_device_volume_size
      volume_type           = var.root_block_device_volume_type
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-ecs-instance" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(var.tags, { Name = "${var.name}-ecs-instance" })
  }

  tags = var.tags
}

resource "aws_autoscaling_group" "ecs" {
  name                  = "${var.name}-ecs-asg"
  min_size              = var.min_size
  max_size              = var.max_size
  vpc_zone_identifier   = var.subnet_ids
  health_check_type     = "EC2"
  protect_from_scale_in = true # required for managed termination protection

  launch_template {
    id      = aws_launch_template.ecs.id
    version = aws_launch_template.ecs.latest_version
  }

  # Added by ECS when the ASG is attached to a capacity provider; declared here
  # so Terraform does not remove it.
  tag {
    key                 = "AmazonECSManaged"
    value               = true
    propagate_at_launch = true
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-ecs-instance"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  # ECS managed scaling owns the desired capacity once the capacity provider is attached.
  lifecycle {
    ignore_changes = [desired_capacity]
  }
}
