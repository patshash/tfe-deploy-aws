# Terraform Enterprise FDO Active/Active on AWS — Specification

## Module Purpose

This module deploys HashiCorp Terraform Enterprise (TFE) on AWS using the Flexible Deployment Options (FDO) Docker runtime in Active/Active high-availability mode. It provisions all required AWS infrastructure: networking, compute, data stores, load balancing, DNS, and TLS — producing a production-ready TFE deployment accessible via AWS Direct Connect.

## Architecture Overview

- **VPC**: 3-AZ VPC with public and private subnets, NAT Gateways for outbound internet (online license mode)
- **Compute**: EC2 instances in an Auto Scaling Group (min 2) running TFE FDO Docker containers
- **Database**: RDS PostgreSQL (Multi-AZ, KMS-encrypted)
- **Cache**: ElastiCache Redis replication group (Multi-AZ, encrypted in-transit + at-rest) — required for Active/Active
- **Storage**: S3 bucket (SSE-KMS, versioning, public access blocked)
- **Load Balancer**: Internal ALB (accessible via Direct Connect)
- **DNS/TLS**: ACM certificate + Route53 record in `pcarey.sbx.hashidemos.io`

## User Scenarios

### US-1: Basic Active/Active Deployment
A platform engineer provides a TFE license, hostname, and Route53 zone. The module creates all infrastructure and deploys TFE in Active/Active mode with secure defaults.

### US-2: Complete Deployment with Custom Configuration
A platform engineer customizes instance types, database sizing, Redis configuration, CIDR ranges, and tagging for a production environment.

## Functional Requirements

### Networking
- **FR-01**: Module creates a VPC with configurable CIDR (default `10.0.0.0/16`)
- **FR-02**: Module creates public subnets (for ALB and NAT Gateways) and private subnets (for TFE, RDS, Redis) across 3 AZs
- **FR-03**: Module creates NAT Gateways for outbound internet access (required for online license mode)
- **FR-04**: Module creates an internal ALB in public subnets for Direct Connect accessibility

### Compute
- **FR-05**: Module creates an ASG with minimum 2 EC2 instances running TFE FDO Docker containers
- **FR-06**: EC2 instances use a launch template with cloud-init user data that installs Docker and starts TFE
- **FR-07**: EC2 instances are deployed in private subnets
- **FR-08**: Instance type defaults to `m5.xlarge` (configurable)
- **FR-09**: EC2 instances have an IAM instance profile with least-privilege permissions for S3, KMS, and CloudWatch

### Data Tier
- **FR-10**: Module creates an RDS PostgreSQL 16 instance in Multi-AZ mode with KMS encryption at rest
- **FR-11**: Module creates an ElastiCache Redis 7.x replication group with Multi-AZ, automatic failover, encryption in-transit (TLS) and at-rest
- **FR-12**: Module creates an S3 bucket with SSE-KMS encryption, versioning, and all public access blocked
- **FR-13**: Database credentials are generated and stored in AWS Secrets Manager

### DNS & TLS
- **FR-14**: Module creates an ACM certificate for the TFE hostname, validated via Route53 DNS
- **FR-15**: Module creates a Route53 alias record pointing to the ALB

### Security
- **FR-16**: All data stores are encrypted at rest using a KMS CMK (configurable or module-created)
- **FR-17**: All inter-service communication is encrypted in transit (TLS)
- **FR-18**: Security groups follow least-privilege: ALB accepts 443 only, TFE accepts from ALB only, RDS/Redis accept from TFE only
- **FR-19**: S3 bucket policy denies non-SSL requests
- **FR-20**: No resources have public IP addresses except the ALB (internal ALB, no public IPs)
- **FR-21**: VPC Flow Logs are enabled

### Operations
- **FR-22**: Module supports consumer-provided tags applied to all resources
- **FR-23**: ALB health checks use TFE's `/_health_check` endpoint
- **FR-24**: CloudWatch log group for TFE container logs

## Module Interface

### Key Inputs
| Variable | Type | Required | Description |
|----------|------|----------|-------------|
| `friendly_name_prefix` | string | yes | Prefix for resource naming |
| `tfe_hostname` | string | yes | FQDN for TFE (e.g., `tfe.pcarey.sbx.hashidemos.io`) |
| `tfe_license` | string | yes | TFE license string |
| `route53_zone_name` | string | yes | Route53 hosted zone name |
| `vpc_cidr` | string | no | VPC CIDR block (default: `10.0.0.0/16`) |
| `instance_type` | string | no | EC2 instance type (default: `m5.xlarge`) |
| `asg_min_size` | number | no | ASG minimum size (default: 2) |
| `asg_max_size` | number | no | ASG maximum size (default: 3) |
| `db_instance_class` | string | no | RDS instance class (default: `db.r6g.xlarge`) |
| `redis_node_type` | string | no | Redis node type (default: `cache.r6g.large`) |
| `kms_key_arn` | string | no | Existing KMS key ARN (module creates one if not provided) |
| `tags` | map(string) | no | Tags applied to all resources |

### Key Outputs
| Output | Description |
|--------|-------------|
| `tfe_url` | Full URL to access TFE |
| `tfe_hostname` | TFE hostname |
| `vpc_id` | VPC ID |
| `alb_dns_name` | ALB DNS name |
| `rds_endpoint` | RDS endpoint |
| `redis_endpoint` | Redis primary endpoint |
| `s3_bucket_name` | S3 bucket name |

## Success Criteria

1. TFE is accessible at the configured hostname via HTTPS
2. Active/Active mode is operational with 2+ instances serving requests
3. All data at rest is encrypted with KMS
4. All data in transit is encrypted with TLS
5. No resources are publicly accessible from the internet
6. Module deploys successfully with `terraform apply` using only required variables
7. Health checks confirm TFE is healthy on all instances
