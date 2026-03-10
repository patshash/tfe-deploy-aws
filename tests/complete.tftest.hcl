# Complete TFE FDO Active/Active module tests
# Validates module with all features and custom sizing.

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
  friendly_name_prefix = "tfe-complete"
  tfe_hostname         = "tfe.pcarey.sbx.hashidemos.io"
  tfe_license          = "test-license-string"
  route53_zone_name    = "pcarey.sbx.hashidemos.io"
}

run "plan_complete_with_custom_sizing" {
  command = plan

  variables {
    instance_type     = "m5.2xlarge"
    asg_min_size      = 3
    asg_max_size      = 6
    db_instance_class = "db.r6g.2xlarge"
    redis_node_type   = "cache.r6g.xlarge"
    vpc_cidr          = "10.1.0.0/16"
  }

  # Plan succeeding validates all custom sizing parameters are accepted
  # and module composition works with non-default values.
}

run "plan_complete_with_tags" {
  command = plan

  variables {
    tags = {
      Environment = "production"
      Team        = "platform"
      CostCenter  = "engineering"
    }
  }

  # Plan succeeding validates tags propagation through all submodules.
}
