data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_id
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
  version                = "~> 1.10"
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "13.2.1"

  worker_ami_owner_id         = var.override_ami_owner_id != "" ? var.override_ami_owner_id : data.aws_partition.current.partition == "aws-cn" ? "961992271922" : "602401143452"
  worker_ami_owner_id_windows = data.aws_partition.current.partition == "aws-cn" ? "016951021795" : "801119661308"

  cluster_name       = var.cluster_name
  cluster_version    = var.cluster_version
  subnets            = var.subnet_ids
  write_kubeconfig   = true
  config_output_path = pathexpand("~/.kube/${var.tenant_name}-${var.cluster_name}")
  kubeconfig_name    = "${var.tenant_name}-${var.cluster_name}"
  worker_additional_security_group_ids = [
    module.eks_worker_sg.id,
  ]

  vpc_id = var.vpc_id

  # worker_additional_security_group_ids = []
  # workers_additional_policies = []

  node_groups_defaults = {
    ami_type  = "AL2_x86_64"
    disk_size = 50
  }

  workers_additional_policies = [
    aws_iam_policy.eks_assume_role.arn,
    "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ]

  workers_group_defaults = {
    key_name               = var.key_name
    public_ip              = var.worker_public_ip
    root_volume_size       = 50
    instance_type          = "c5.large"
    asg_recreate_on_change = true
    additional_userdata    = <<EOF
#!/bin/bash
cd /tmp
sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
sudo systemctl enable amazon-ssm-agent
sudo systemctl start amazon-ssm-agent
EOF
  }

  worker_groups_launch_template = local.worker_groups_launch_template

  map_roles    = var.map_roles
  map_users    = var.map_users
  map_accounts = var.map_accounts
}

resource "aws_iam_policy" "eks_assume_role" {
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "kube2iam",
      "Action": [
        "sts:AssumeRole"
      ],
      "Effect": "Allow",
      "Resource": "arn:${data.aws_partition.current.partition}:iam::${var.aws_account_id}:role/k8s-*"
    }
  ]
}
EOF
}

# this security group is used to provide identity for workers and is used as source group for other groups (like mysql in hosting account)
module "eks_worker_sg" {
  source = "../sg"

  name   = "eks-worker-${var.cluster_name}"
  vpc_id = var.vpc_id
}

output "eks_worker_sg_id" {
  value = module.eks_worker_sg.id
}
