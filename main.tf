# main.tf (root directory)

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region
}

# Optional: Store Terraform state in S3 with DynamoDB locking
# terraform {
#   backend "s3" {
#     bucket         = "your-terraform-state-bucket"
#     key            = "global/infrastructure.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "your-terraform-state-lock"
#     encrypt        = true
#   }
# }

# Call the VPC module
module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
}

# Call the Security Groups module
module "security_groups" {
  source = "./modules/security_groups"

  vpc_id = module.vpc.vpc_id
}

# Call the S3 module
module "s3_bucket" {
  source = "./modules/s3"

  bucket_name = "${var.project_name}-data-bucket"
}

# Call the IAM module
module "iam" {
  source = "./modules/iam"
}

# Call the RDS module
module "rds" {
  source = "./modules/rds"

  vpc_id              = module.vpc.vpc_id
  private_subnet_ids  = module.vpc.private_subnet_ids
  db_sg_id            = module.security_groups.rds_sg_id
  db_instance_user    = var.db_instance_user
  db_instance_password = var.db_instance_password # Use a secrets manager in production
}

# Call the ALB module
module "alb" {
  source = "./modules/alb"

  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  alb_sg_id           = module.security_groups.alb_sg_id
}

# Call the ECS module
module "ecs" {
  source = "./modules/ecs"

  vpc_id             = module.vpc.vpc_id
  private_subnet_ids = module.vpc.private_subnet_ids
  ecs_sg_id          = module.security_groups.ecs_sg_id
  alb_target_group_arn = module.alb.target_group_arn
  task_execution_role_arn = module.iam.ecs_task_execution_role_arn
}

