# =============================================================================
# Application Load Balancer
# =============================================================================
resource "aws_lb" "this" {
  name               = var.name
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = var.security_group_ids
  subnets            = var.subnet_ids

  enable_deletion_protection = var.enable_deletion_protection
  enable_http2               = true
  idle_timeout               = var.idle_timeout

  access_logs {
    bucket  = var.access_logs_bucket
    prefix  = var.access_logs_prefix
    enabled = var.enable_access_logs
  }

  tags = merge(var.tags, {
    Name = var.name
  })
}

# =============================================================================
# Target Groups
# =============================================================================
resource "aws_lb_target_group" "this" {
  for_each = var.target_groups

  name        = each.value.name
  port        = each.value.port
  protocol    = each.value.protocol
  vpc_id      = var.vpc_id
  target_type = each.value.target_type

  health_check {
    enabled             = true
    healthy_threshold   = each.value.health_check.healthy_threshold
    unhealthy_threshold = each.value.health_check.unhealthy_threshold
    timeout             = each.value.health_check.timeout
    interval            = each.value.health_check.interval
    path                = each.value.health_check.path
    port                = each.value.health_check.port
    protocol            = each.value.health_check.protocol
    matcher             = each.value.health_check.matcher
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = each.value.stickiness_duration
    enabled         = each.value.stickiness_enabled
  }

  tags = merge(var.tags, {
    Name = each.value.name
  })
}

# =============================================================================
# Target Group Attachments
# =============================================================================
resource "aws_lb_target_group_attachment" "this" {
  for_each = var.target_group_attachments

  target_group_arn = aws_lb_target_group.this[each.value.target_group_key].arn
  target_id        = each.value.target_id
  port             = each.value.port
}

# =============================================================================
# HTTP Listener (Redirect to HTTPS)
# =============================================================================
resource "aws_lb_listener" "http" {
  count = var.create_http_listener ? 1 : 0

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

  tags = merge(var.tags, {
    Name = "${var.name}-http"
  })
}

# =============================================================================
# HTTPS Listener
# =============================================================================
resource "aws_lb_listener" "https" {
  count = var.create_https_listener ? 1 : 0

  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = var.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "404: Page Not Found"
      status_code  = "404"
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name}-https"
  })
}

# =============================================================================
# Additional HTTPS Certificates (for multiple domains)
# =============================================================================
resource "aws_lb_listener_certificate" "additional" {
  for_each = var.additional_certificates

  listener_arn    = aws_lb_listener.https[0].arn
  certificate_arn = each.value
}

# =============================================================================
# Listener Rules (Path-based routing)
# =============================================================================
resource "aws_lb_listener_rule" "https_rules" {
  for_each = var.create_https_listener ? var.listener_rules : {}

  listener_arn = aws_lb_listener.https[0].arn
  priority     = each.value.priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this[each.value.target_group_key].arn
  }

  dynamic "condition" {
    for_each = each.value.host_headers != null ? [1] : []
    content {
      host_header {
        values = each.value.host_headers
      }
    }
  }

  dynamic "condition" {
    for_each = each.value.path_patterns != null ? [1] : []
    content {
      path_pattern {
        values = each.value.path_patterns
      }
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name}-rule-${each.key}"
  })
}
