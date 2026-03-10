data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

#------------------------------------------------------
# KMS Key (created if not provided)
#------------------------------------------------------
resource "aws_kms_key" "this" {
  count = var.kms_key_arn == null ? 1 : 0

  description             = "TFE encryption key for ${var.friendly_name_prefix}"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootAccount"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.friendly_name_prefix}-tfe-kms"
  })
}

resource "aws_kms_alias" "this" {
  count = var.kms_key_arn == null ? 1 : 0

  name          = "alias/${var.friendly_name_prefix}-tfe"
  target_key_id = aws_kms_key.this[0].key_id
}

#------------------------------------------------------
# Encryption password (generated if not provided)
#------------------------------------------------------
resource "random_password" "enc_password" {
  count = var.tfe_encryption_password == null ? 1 : 0

  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "enc_password" {
  name_prefix = "${var.friendly_name_prefix}-tfe-enc-password-"

  tags = merge(local.common_tags, {
    Name = "${var.friendly_name_prefix}-tfe-encryption-password"
  })
}

resource "aws_secretsmanager_secret_version" "enc_password" {
  secret_id     = aws_secretsmanager_secret.enc_password.id
  secret_string = local.tfe_encryption_password
}

#------------------------------------------------------
# IAM Role for TFE EC2 instances
#------------------------------------------------------
resource "aws_iam_role" "tfe" {
  name_prefix = "${var.friendly_name_prefix}-tfe-"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_instance_profile" "tfe" {
  name_prefix = "${var.friendly_name_prefix}-tfe-"
  role        = aws_iam_role.tfe.name

  tags = local.common_tags
}

# S3 access for TFE
resource "aws_iam_role_policy" "tfe_s3" {
  name = "${var.friendly_name_prefix}-tfe-s3"
  role = aws_iam_role.tfe.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:GetBucketVersioning",
        ]
        Resource = [
          module.object_storage.s3_bucket_arn,
          "${module.object_storage.s3_bucket_arn}/*",
        ]
      },
    ]
  })
}

# KMS access for TFE
resource "aws_iam_role_policy" "tfe_kms" {
  name = "${var.friendly_name_prefix}-tfe-kms"
  role = aws_iam_role.tfe.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "kms:Decrypt",
        "kms:Encrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey",
      ]
      Resource = [local.kms_key_arn]
    }]
  })
}

# CloudWatch Logs access for TFE
resource "aws_iam_role_policy" "tfe_cloudwatch" {
  name = "${var.friendly_name_prefix}-tfe-logs"
  role = aws_iam_role.tfe.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams",
      ]
      Resource = "arn:aws:logs:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:log-group:/aws/tfe/${var.friendly_name_prefix}:*"
    }]
  })
}

# Secrets Manager read access
resource "aws_iam_role_policy" "tfe_secrets" {
  name = "${var.friendly_name_prefix}-tfe-secrets"
  role = aws_iam_role.tfe.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue",
      ]
      Resource = [
        module.database.db_password_secret_arn,
        module.redis.redis_auth_secret_arn,
        aws_secretsmanager_secret.enc_password.arn,
      ]
    }]
  })
}

# SSM for instance management
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.tfe.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

#------------------------------------------------------
# Networking
#------------------------------------------------------
module "networking" {
  source = "./modules/networking"

  friendly_name_prefix = var.friendly_name_prefix
  vpc_cidr             = var.vpc_cidr
  tags                 = local.common_tags
}

#------------------------------------------------------
# Database (RDS PostgreSQL)
#------------------------------------------------------
module "database" {
  source = "./modules/database"

  friendly_name_prefix = var.friendly_name_prefix
  db_instance_class    = var.db_instance_class
  db_subnet_group_name = module.networking.db_subnet_group_name
  security_group_ids   = [module.networking.database_security_group_id]
  kms_key_arn          = local.kms_key_arn
  tags                 = local.common_tags
}

#------------------------------------------------------
# Redis (ElastiCache)
#------------------------------------------------------
module "redis" {
  source = "./modules/redis"

  friendly_name_prefix = var.friendly_name_prefix
  redis_node_type      = var.redis_node_type
  subnet_group_name    = module.networking.elasticache_subnet_group_name
  security_group_ids   = [module.networking.redis_security_group_id]
  kms_key_arn          = local.kms_key_arn
  tags                 = local.common_tags
}

#------------------------------------------------------
# Object Storage (S3)
#------------------------------------------------------
module "object_storage" {
  source = "./modules/object-storage"

  friendly_name_prefix = var.friendly_name_prefix
  kms_key_arn          = local.kms_key_arn
  tags                 = local.common_tags
}

#------------------------------------------------------
# Compute (ALB + ASG + ACM + Route53)
#------------------------------------------------------
module "compute" {
  source = "./modules/compute"

  friendly_name_prefix      = var.friendly_name_prefix
  vpc_id                    = module.networking.vpc_id
  private_subnet_ids        = module.networking.private_subnet_ids
  public_subnet_ids         = module.networking.public_subnet_ids
  alb_security_group_id     = module.networking.alb_security_group_id
  tfe_security_group_id     = module.networking.tfe_security_group_id
  instance_type             = var.instance_type
  asg_min_size              = var.asg_min_size
  asg_max_size              = var.asg_max_size
  tfe_hostname              = var.tfe_hostname
  route53_zone_name         = var.route53_zone_name
  tfe_user_data             = local.tfe_user_data
  iam_instance_profile_name = aws_iam_instance_profile.tfe.name
  kms_key_arn               = local.kms_key_arn
  tags                      = local.common_tags
}
