provider "aws"{
    region= "us-east-1"
}
variable "Vpc_Region"{
    type=string
    default="us-east-1"
}
variable "Vpc_Name"{
    type=string
    default="VPC"
}
variable "cidr_block"{
    type=string
    default="10.0.0.0/16"
}
variable "subnets" {
    type = list(string)
    default=["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  }
module "network" {
    source="./network"
    Vpc_Region=var.Vpc_Region
    Vpc_Name=var.Vpc_Name
    cidr_block=var.cidr_block
    subnets=var.subnets
}
