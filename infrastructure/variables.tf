variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-south-1"
}

variable "eks-cluster-prefix" {
  description   = "Prefix for EKS cluster name"
  type          = string
  default       = "sre-challenge-eks"
}

variable "helm-repository-git" {
  description   = "Helm Git repository"
  type          = string
  default       = "https://lorenzo85.github.io/sre-challenge/"
}

variable "version-argocd" {
  description   = "Helm Git repository"
  type          = string
  default       = "1.0.0"
}

variable "version-kubernetes" {
  description   = "Kubernetes cluster version"
  type          = string
  default       = "1.27"
}
