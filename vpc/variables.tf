variable "name" { default = "main" }
variable "cidr_block" {}
variable "eks_cluster_name" { default = "" }
variable "production_mode" { default = false }
variable "enable_nat_gateway" { default = false }
variable "enable_ipv6" { default = false }

variable "cidr_subnet_newbits" { default = 4 }
variable "cidr_subnet_public_start_from" { default = 9 }
