resource "random_string" "suffix" {
  length  = 8
  special = false
}

locals {
  cluster_name = "${var.eks-cluster-prefix}-${random_string.suffix.result}"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = local.cluster_name
  cluster_version = var.version-kubernetes

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
  }

  eks_managed_node_groups = {

    # An EKS managed node group for standard workloads (backends/frontends).
    node-group-workload = {
      name = "node-group-workload"

      instance_types = ["t3.small"]

      min_size     = 3
      max_size     = 10
      desired_size = 5
    }

    # An EKS managed node group for databases only workloads.
    node-group-database = {
      name = "node-group-database"

      # The instance_types for this case could be: db.m7g, db.m6g or any other db.* type instances.
      # For testing purposes, we will still use t3.small for this node group.
      instance_types = ["t3.small"]

      # We apply the workload-type label to all the nodes belonging to this node group, so that we can
      # define node affinities to pods running databases.
      labels = {
        workload-type = "database"
      }

      # We define taints on these nodes so that STANDARD workloads CANNOT be scheduled on these nodes
      # by k8s scheduler as they are reserved for database workloads. Database workload will therefore
      # have to be defined with tolerations in order to be scheduled on these nodes.
      taints = [
        {
          key    = "workload-type"
          value  = "database"
          effect = "NO_SCHEDULE"
        }
      ]

      min_size     = 2
      max_size     = 5
      desired_size = 3
    }

    # An EKS managed node group for CPU and Memory intenstive workloads (e.g Retool).
    node-group-large = {
        name = "node-group-large"

        # t3.2x large has 8 vCPU, 32 MB memory
        instance_types = ["t3.2xlarge"]

        # The workload-type label is useful to define node affinities to pods running these workloads.
        labels = {
          workload-type = "large"
        }

        # We define taints on these nodes so that STANDARD workloads CANNOT be scheduled on these nodes
        # by k8s scheduler as they are reserved for database workloads. Database workload will therefore
        # have to be defined with tolerations in order to be scheduled on these nodes.
        taints = [
          {
            key    = "workload-type"
            value  = "large"
            effect = "NO_SCHEDULE"
          }
        ]

        # For now we just set the constraint to have 1 VM of this type,
        # Because Retool requires that the cluster must have at least one node with 8x vCPUs and 16 GB of memory.
        # https://docs.retool.com/self-hosted/quickstarts/kubernetes/helm?#cluster-size
        min_size     = 1
        max_size     = 1
        desired_size = 1
    }
  }
}
