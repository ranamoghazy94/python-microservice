
# Networking
resource "aws_vpc" "main" {
 cidr_block = var.vpc_cidr_block

 
 tags = {
   Name = "${var.env_prefix}-vpc"
 }
}

resource "aws_subnet" "public_subnets" {
  count = length(var.public_subnets)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index].cidr_block
  map_public_ip_on_launch = true
  availability_zone       = var.public_subnets[count.index].az

  tags = {
    Name = "pubsub${count.index + 1}-${var.env_prefix}"
  }
}


resource "aws_internet_gateway" "internet_igw" {
 vpc_id = aws_vpc.main.id
 tags = {
   Name = "${var.env_prefix}-igw"
 }
}

resource "aws_route_table" "public_route_table" {
 vpc_id = aws_vpc.main.id
 
 route {
   cidr_block = "0.0.0.0/0"
   gateway_id = aws_internet_gateway.internet_igw.id
 }
 tags = {
   Name = "${var.env_prefix}-public-rtb"
}
}

resource "aws_route_table_association" "public_assoc" {
  count          = length(var.public_subnets)
  subnet_id      = element(aws_subnet.public_subnets.*.id, count.index)
  route_table_id = aws_route_table.public_route_table.id
}


# Controlplane Role
resource "aws_iam_role" "eks-iam-role" {
  name = var.eks_iam_role
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

}
# WorkerNodes Role for LaunchTemplate
resource "aws_iam_role" "eks_workernode_role" {
  name = "${var.env_prefix}-eks-node-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
        
      },
      "Action": "sts:AssumeRole"
    }
  ]
  }
  EOF
}

## Attach the IAM policy to the IAM role
resource "aws_iam_role_policy_attachment" "AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks-iam-role.name
}
resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly-EKS" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks-iam-role.name
}

## Create the EKS cluster
resource "aws_eks_cluster" "eks" {
  name = var.eks_cluster_name
  role_arn = aws_iam_role.eks-iam-role.arn
  enabled_cluster_log_types = ["api", "audit", "scheduler", "controllerManager"]
  version = var.k8s_version
  vpc_config {
    # You can set these as just private subnets if the Control Plane will be private
    subnet_ids = aws_subnet.public_subnets[*].id
    security_group_ids      = [aws_security_group.eks_cluster_control_plane_sg.id]
  
  }

  depends_on = [
    aws_iam_role.eks-iam-role,
  ]
}

resource "aws_iam_role_policy_attachment" "AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_workernode_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_workernode_role.name
}

resource "aws_iam_role_policy_attachment" "EC2InstanceProfileForImageBuilderECRContainerBuilds" {
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilderECRContainerBuilds"
  role       = aws_iam_role.eks_workernode_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_workernode_role.name
}

resource "aws_iam_role_policy_attachment" "CloudWatchAgentServerPolicy-eks" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.eks_workernode_role.name
}

resource "aws_iam_role_policy_attachment" "AmazonEBSCSIDriverPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.eks_workernode_role.name
}

# Create Workenode group
resource "aws_eks_node_group" "worker-node-group" {
  cluster_name    = aws_eks_cluster.eks.name
  node_group_name = "workernodes-${var.env_prefix}"
  node_role_arn   = aws_iam_role.eks_workernode_role.arn
  subnet_ids      = aws_subnet.public_subnets[*].id
  instance_types = var.instance_type


   launch_template {
    id      = aws_launch_template.worker_lt.id
    version = "var.template_version"  # Change manually when updating
  }

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  depends_on = [
    aws_eks_cluster.eks,
    aws_iam_role.eks_workernode_role,
    aws_iam_role_policy_attachment.AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.AmazonEKS_CNI_Policy,
  ]
}
# Launch templates for worker nodes
resource "aws_launch_template" "worker_lt" {
  name_prefix   = "eks-worker-"
  image_id      = "var.ami" 
  vpc_security_group_ids= [aws_security_group.eks_cluster_worker_node_sg.id]
  
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "eks-worker-node"
    }
  }
}

### EKS Cluster Control Plane SG
resource "aws_security_group" "eks_cluster_control_plane_sg" {
  name        = "eks-cluster.control-plane-sg"
  description = "Control Plane Security group for EKS Cluster"
  vpc_id      = aws_vpc.main.id

  tags = {
   Name = "${var.env_prefix}-eks-cluster.control-plane-sg"
}
}

####
### EKS Cluster WorkerNode SG
resource "aws_security_group" "eks_cluster_worker_node_sg" {
  name        = "workernode.worker-node"
  description = "Worker Nodes Security group for EKS Cluster"
  vpc_id      = aws_vpc.main.id

  // Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
   Name = "${var.env_prefix}-eks-cluster.control-plane-sg"
}
}

resource "aws_security_group_rule" "cluster_outbound" {
  description              = "Allow cluster API Server to communicate with the worker nodes"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_cluster_control_plane_sg.id
  source_security_group_id = aws_security_group.eks_cluster_worker_node_sg.id
  to_port                  = 0
  type                     = "egress"
}

resource "aws_security_group_rule" "cluster_inbound" {
  description              = "Allow cluster API Server to communicate with the worker nodes"
  from_port                = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_cluster_control_plane_sg.id
  source_security_group_id = aws_security_group.eks_cluster_worker_node_sg.id
  to_port                  = 0
  type                     = "ingress"
}

# Allow inbound traffic on NodePort range from any source
resource "aws_security_group_rule" "nodeport_inbound" {
  description       = "Allow inbound traffic on NodePort range"
  from_port         = 30000
  to_port           = 32767
  protocol          = "TCP"
  security_group_id = aws_security_group.eks_cluster_worker_node_sg.id
  cidr_blocks = ["0.0.0.0/0"]
  # source_security_group_id = aws_security_group.nlb_sg.id
  type              = "ingress"
}

# Allow communication between worker nodes
resource "aws_security_group_rule" "nodes_internal" {
  description              = "Allow nodes to communicate with each other"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_cluster_worker_node_sg.id
  source_security_group_id = aws_security_group.eks_cluster_worker_node_sg.id
  type                     = "ingress"
}

## Allow worker nodes to receive communication from the control plane
resource "aws_security_group_rule" "nodes_control_plane_inbound_1" {
  description              = "Allow worker nodes to receive communication from the control plane"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  security_group_id        = aws_security_group.eks_cluster_worker_node_sg.id
  source_security_group_id = aws_security_group.eks_cluster_control_plane_sg.id 
  type                     = "ingress"
}


#  resource "aws_security_group" "nlb_sg" {
#     name        = "nlb-security-group-open-traffic"
#     description = "Security group for Network Load Balancer"
#     vpc_id      = aws_vpc.main.id

#     ingress {
#       from_port   = 80
#       to_port     = 80
#       protocol    = "tcp"
#       cidr_blocks = ["0.0.0.0/0"]
#     }
#     ingress {
#       from_port   = 443
#       to_port     = 443
#       protocol    = "tcp"
#       cidr_blocks = ["0.0.0.0/0"]
#     }
#     egress {
#       from_port   = 0
#       to_port     = 0
#       protocol    = "-1"
#       cidr_blocks = ["0.0.0.0/0"]
#     }
#   }



