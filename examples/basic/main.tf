module "tfe" {
  source = "../.."

  friendly_name_prefix = "tfe-basic"
  tfe_hostname         = "tfe.pcarey.sbx.hashidemos.io"
  tfe_license          = var.tfe_license
  route53_zone_name    = "pcarey.sbx.hashidemos.io"

  tags = {
    Environment = "production"
    Application = "terraform-enterprise"
  }
}
