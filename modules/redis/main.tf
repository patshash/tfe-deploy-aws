resource "random_password" "redis_auth" {
  length  = 32
  special = false
}

resource "aws_secretsmanager_secret" "redis_auth" {
  name_prefix = "${var.friendly_name_prefix}-tfe-redis-auth-"

  tags = merge(var.tags, {
    Name = "${var.friendly_name_prefix}-tfe-redis-auth"
  })
}

resource "aws_secretsmanager_secret_version" "redis_auth" {
  secret_id     = aws_secretsmanager_secret.redis_auth.id
  secret_string = random_password.redis_auth.result
}

resource "aws_elasticache_replication_group" "this" {
  replication_group_id = "${var.friendly_name_prefix}-tfe"
  description          = "TFE Active/Active Redis cluster"

  engine               = "redis"
  engine_version       = var.redis_engine_version
  node_type            = var.redis_node_type
  num_cache_clusters   = 2
  port                 = 6379
  parameter_group_name = "default.redis7"

  subnet_group_name  = var.subnet_group_name
  security_group_ids = var.security_group_ids

  # High Availability
  automatic_failover_enabled = true
  multi_az_enabled           = true

  # Encryption
  at_rest_encryption_enabled = true
  kms_key_id                 = var.kms_key_arn
  transit_encryption_enabled = true
  auth_token                 = random_password.redis_auth.result

  # Maintenance
  maintenance_window         = "sun:05:00-sun:06:00"
  snapshot_retention_limit   = 7
  snapshot_window            = "02:00-03:00"
  auto_minor_version_upgrade = true
  apply_immediately          = false

  tags = merge(var.tags, {
    Name = "${var.friendly_name_prefix}-tfe-redis"
  })
}
