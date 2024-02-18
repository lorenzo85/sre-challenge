data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "sre-challenge-vpc"

  # The VPC CIDR
  cidr = "10.0.0.0/16"

  # We select only 3 AZs in which the cluster nodes will be deployed on
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  # Public and Private subnets CIDRs
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  # This is just for testing purposes, should not use single NAT on production is it needs to be on every AZ.
  single_nat_gateway   = true

  # The VPC must have DNS hostname and DNS resolution support,
  # otherwise, EKS nodes can't register to your cluster.
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }
}
