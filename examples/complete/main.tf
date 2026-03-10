module "tfe" {
  source = "../.."

  # Required
  friendly_name_prefix = "tfe-complete"
  tfe_hostname         = "tfe.pcarey.sbx.hashidemos.io"
  tfe_license          = var.tfe_license
  route53_zone_name    = "pcarey.sbx.hashidemos.io"

  # Networking
  vpc_cidr = "10.1.0.0/16"

  # Compute
  instance_type = "m5.2xlarge"
  asg_min_size  = 2
  asg_max_size  = 5

  # Database
  db_instance_class = "db.r6g.2xlarge"

  # Redis
  redis_node_type = "cache.r6g.xlarge"

  # Tags
  tags = {
    Environment = "production"
    Application = "terraform-enterprise"
    Team        = "platform"
    CostCenter  = "engineering"
  }
}
