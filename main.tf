resource "aws_route53_zone" "this" {
  name = var.route53_zone_name
}

# -- Load balancer resources for fronting single and multi-AZ demo -- #

resource "aws_acm_certificate" "wildcard_cert" {
  domain_name       = "*.${var.route53_zone_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "wildcard_cert_dns" {
  name =  tolist(aws_acm_certificate.wildcard_cert.domain_validation_options)[0].resource_record_name
  records = [tolist(aws_acm_certificate.wildcard_cert.domain_validation_options)[0].resource_record_value]
  type = tolist(aws_acm_certificate.wildcard_cert.domain_validation_options)[0].resource_record_type
  zone_id = aws_route53_zone.this.zone_id
  ttl = 60
}

resource "aws_acm_certificate_validation" "wildcard_cert" {
  certificate_arn = aws_acm_certificate.wildcard_cert.arn
  validation_record_fqdns = [aws_route53_record.wildcard_cert_dns.fqdn]
}

resource "aws_lb" "this" {
  depends_on = [aws_acm_certificate_validation.wildcard_cert]

  name               = "summer-crabtacular"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for s in aws_subnet.this : s.id if s.tags.Tier == "public"]
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"

  certificate_arn = aws_acm_certificate.wildcard_cert.arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/html"
      status_code  = "200"
      message_body = "Hello, world!"
    }
  }
}

resource "aws_security_group" "alb" {
  name        = "summer-crabtacular-alb"
  description = "Security group for application load balancer"
  vpc_id      = aws_vpc.this.id

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "summer-crabtacular-alb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_ingress_http_public" {
  security_group_id = aws_security_group.alb.id

  from_port   = 80
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "TCP"
  to_port     = 80
}

resource "aws_vpc_security_group_ingress_rule" "alb_ingress_https_public" {
  security_group_id = aws_security_group.alb.id

  from_port   = 443
  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "TCP"
  to_port     = 443
}

resource "aws_vpc_security_group_egress_rule" "alb_egress_to_ec2" {
  security_group_id = aws_security_group.alb.id

  from_port                    = 80
  referenced_security_group_id = aws_security_group.ec2.id
  ip_protocol                  = "TCP"
  to_port                      = 80
}

# -- General EC2 related resources, applicable to both demos -- #

resource "aws_security_group" "ec2" {
  name        = "summer-crabtacular-ec2"
  description = "Security group for EC2 instances"
  vpc_id      = aws_vpc.this.id

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "nordevcon24-ec2"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ec2_ingress_from_alb" {
  security_group_id = aws_security_group.ec2.id

  from_port                    = 80
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "TCP"
  to_port                      = 80
}

resource "aws_vpc_security_group_egress_rule" "ec2_egress_to_internet" {
  security_group_id = aws_security_group.ec2.id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1"
}

# -- Creates resources relating to demo of single-AZ -- #

resource "aws_route53_record" "single_az" {
  name    = "single-az.${var.route53_zone_name}"
  type    = "A"
  zone_id = aws_route53_zone.this.id

  alias {
    evaluate_target_health = true
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
  }
}

resource "aws_lb_listener_rule" "single_az" {
  listener_arn = aws_lb_listener.https_listener.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.single_az.arn
  }

  condition {
    host_header {
      values = ["single-az.${var.route53_zone_name}"]
    }
  }
}

resource "aws_lb_target_group" "single_az" {
  name        = "summer-crabtacular-single-az-alb"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.this.id
}

resource "aws_lb_target_group_attachment" "single_az" {
  target_group_arn = aws_lb_target_group.single_az.arn
  target_id        = aws_instance.single_az_euw2a.id
  port             = 80
}

resource "aws_instance" "single_az_euw2a" {
  ami           = data.aws_ami.al2023.id
  instance_type = "t4g.nano"
  subnet_id     = aws_subnet.this["app-euw2a"].id

  associate_public_ip_address = false
  vpc_security_group_ids = [
    aws_security_group.ec2.id
  ]

  tags = {
    Name = "summer-crabtacular-single-az-euw2a"
  }

  user_data = templatefile("user_data.sh.tftpl", { pattern = "Single-AZ" })
}

# -- Creates resources relating to demo of multi-AZ -- #

resource "aws_route53_record" "multi_az" {
  name    = "multi-az.${var.route53_zone_name}"
  type    = "A"
  zone_id = aws_route53_zone.this.id

  alias {
    evaluate_target_health = true
    name                   = aws_lb.this.dns_name
    zone_id                = aws_lb.this.zone_id
  }
}

resource "aws_lb_listener_rule" "multi_az" {
  listener_arn = aws_lb_listener.https_listener.arn

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.multi_az.arn
  }

  condition {
    host_header {
      values = ["multi-az.${var.route53_zone_name}"]
    }
  }
}

resource "aws_lb_target_group" "multi_az" {
  name        = "summer-crabtacular-multi-az-alb"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"
  vpc_id      = aws_vpc.this.id
}

resource "aws_autoscaling_group" "multi_az" {
  name = "summer-crabtacular-multi-az"

  max_size         = 2
  desired_capacity = 2
  min_size         = 2

  health_check_type = "ELB"
  health_check_grace_period = 30

  launch_template {
    id = aws_launch_template.multi_az.id
  }

  vpc_zone_identifier = [for s in aws_subnet.this : s.id if s.tags.Tier == "app"]
}

resource "aws_autoscaling_attachment" "multi_az" {
  autoscaling_group_name = aws_autoscaling_group.multi_az.name
  lb_target_group_arn    = aws_lb_target_group.multi_az.arn
}

resource "aws_launch_template" "multi_az" {
  name = "summer-crabtacular-multi-az-launch-template"

  image_id               = data.aws_ami.al2023.id
  instance_type          = "t4g.nano"
  update_default_version = true

  network_interfaces {
    associate_public_ip_address = false
    security_groups = [
      aws_security_group.ec2.id
    ]
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "summer-crabtacular-multi-az"
    }
  }

  user_data = base64encode(templatefile("user_data.sh.tftpl", { pattern = "Multi-AZ" }))
}