# Basic TFE FDO Active/Active module tests
# Validates module logic with mock providers (unit tests).

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["ap-southeast-2a", "ap-southeast-2b", "ap-southeast-2c"]
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_region" {
    defaults = {
      id   = "ap-southeast-2"
      name = "ap-southeast-2"
    }
  }

  mock_data "aws_route53_zone" {
    defaults = {
      zone_id = "Z1234567890"
    }
  }

  mock_data "aws_ami" {
    defaults = {
      id = "ami-mock12345"
    }
  }
}

mock_provider "random" {}

variables {
  friendly_name_prefix = "tfe-test"
  tfe_hostname         = "tfe.pcarey.sbx.hashidemos.io"
  tfe_license          = "test-license-string"
  route53_zone_name    = "pcarey.sbx.hashidemos.io"
}

run "validates_prefix_format" {
  command = plan

  variables {
    friendly_name_prefix = "INVALID_PREFIX!"
  }

  expect_failures = [var.friendly_name_prefix]
}

run "validates_asg_min_size" {
  command = plan

  variables {
    asg_min_size = 1
  }

  expect_failures = [var.asg_min_size]
}

run "plan_with_defaults" {
  command = plan

  # Plan succeeding with mock providers validates module composition,
  # type constraints, and resource graph correctness.
}

run "plan_custom_vpc_cidr" {
  command = plan

  variables {
    vpc_cidr = "10.1.0.0/16"
  }
}
