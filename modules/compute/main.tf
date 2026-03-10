#------------------------------------------------------
# AMI lookup — latest Amazon Linux 2023
#------------------------------------------------------
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

#------------------------------------------------------
# ACM Certificate
#------------------------------------------------------
data "aws_route53_zone" "this" {
  name = var.route53_zone_name
}

resource "aws_acm_certificate" "this" {
  domain_name       = var.tfe_hostname
  validation_method = "DNS"

  tags = merge(var.tags, {
    Name = "${var.friendly_name_prefix}-tfe-cert"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = tolist(aws_acm_certificate.this.domain_validation_options)[0].resource_record_name
  type    = tolist(aws_acm_certificate.this.domain_validation_options)[0].resource_record_type
  ttl     = 60
  records = [tolist(aws_acm_certificate.this.domain_validation_options)[0].resource_record_value]

  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [aws_route53_record.cert_validation.fqdn]
}

#------------------------------------------------------
# Application Load Balancer (internal)
#------------------------------------------------------
resource "aws_lb" "this" {
  name_prefix        = "tfe-"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  drop_invalid_header_fields = true
  enable_deletion_protection = var.enable_deletion_protection

  tags = merge(var.tags, {
    Name = "${var.friendly_name_prefix}-tfe-alb"
  })
}

resource "aws_lb_target_group" "tfe" {
  name_prefix = "tfe-"
  port        = 443
  protocol    = "HTTPS"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    protocol            = "HTTPS"
    path                = "/_health_check"
    port                = "traffic-port"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    matcher             = "200"
  }

  tags = merge(var.tags, {
    Name = "${var.friendly_name_prefix}-tfe-tg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.this.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tfe.arn
  }

  tags = var.tags
}

#------------------------------------------------------
# Route53 DNS Record
#------------------------------------------------------
resource "aws_route53_record" "tfe" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = var.tfe_hostname
  type    = "A"

  alias {
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
    evaluate_target_health = true
  }
}

#------------------------------------------------------
# Launch Template
#------------------------------------------------------
resource "aws_launch_template" "tfe" {
  name_prefix   = "${var.friendly_name_prefix}-tfe-"
  image_id      = data.aws_ami.al2023.id
  instance_type = var.instance_type
  user_data     = var.tfe_user_data

  iam_instance_profile {
    name = var.iam_instance_profile_name
  }

  vpc_security_group_ids = [var.tfe_security_group_id]

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 50
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_key_arn
      delete_on_termination = true
    }
  }

  # Docker data volume
  block_device_mappings {
    device_name = "/dev/xvdb"

    ebs {
      volume_size           = 100
      volume_type           = "gp3"
      encrypted             = true
      kms_key_id            = var.kms_key_arn
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(var.tags, {
      Name = "${var.friendly_name_prefix}-tfe"
    })
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(var.tags, {
      Name = "${var.friendly_name_prefix}-tfe"
    })
  }

  tags = merge(var.tags, {
    Name = "${var.friendly_name_prefix}-tfe-lt"
  })

  lifecycle {
    create_before_destroy = true
  }
}

#------------------------------------------------------
# Auto Scaling Group
#------------------------------------------------------
resource "aws_autoscaling_group" "tfe" {
  name_prefix         = "${var.friendly_name_prefix}-tfe-"
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_min_size
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.tfe.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 900
  wait_for_capacity_timeout = "20m"

  launch_template {
    id      = aws_launch_template.tfe.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 600
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.friendly_name_prefix}-tfe"
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

  lifecycle {
    create_before_destroy = true
  }
}

#------------------------------------------------------
# CloudWatch Log Group for TFE
#------------------------------------------------------
resource "aws_cloudwatch_log_group" "tfe" {
  name              = "/aws/tfe/${var.friendly_name_prefix}"
  retention_in_days = 30

  tags = var.tags
}
