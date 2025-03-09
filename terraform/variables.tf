
variable "vpc_cidr_block" {
  type = string
  default = "10.0.0.0/16"
}

variable "public_subnets" {
  type = list(object({
    cidr_block = string
    az          = string
  }))
  default = [
    { cidr_block = "10.0.1.0/24", az = "eu-west-1a" },
    { cidr_block = "10.0.2.0/24", az = "eu-west-1b" }
  ]
}
variable "eks_iam_role" {
  type = string
  default = "TestEKSCluster"
}
variable "worker_node_ports" {
  type = list
   default = [10250,10251,10252,10256,2380,4443,6443,2379,443,8443]
}

variable "eks_cluster_name" {
  type = string
  default = "TestEKS"
}

variable "k8s_version" {
  type = string
  default = "1.31"
}

variable "worker_node_iam" {
  type = string
  default = "TestWorkerNodes"
}

variable "max_size" {
  type = string
  default = 2
}

variable "desired_size" {
  type = string
  default = 1
}
variable "min_size" {
  type = string
  default = 1
}

variable "instance_type" {
  type = list
  default = ["t3.medium"]
}

variable "env_prefix" {
  type = string
  default = "Test"
}

variable "template_version" {
  type = string
  default = "1"
}

variable "template_version" {
  type = string
  default = "ami-092f20e24d901e20a"
}