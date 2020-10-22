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
variable "key_name"{
    type=string
    default="prod"
}
variable "ImageS3Bucket"{
    type=string
    default="10.0.2.0/16"
}
variable "AWS_SECRET_ACCESS_KEY"{
    type=string
    default="10.0.2.0/16"
}
variable "AWS_ACCESS_KEY_ID"{
    type=string
    default="10.0.2.0/16"
}

module "network" {
    source="./network"
    Vpc_Region=var.Vpc_Region
    Vpc_Name=var.Vpc_Name
    cidr_block=var.cidr_block
    subnets=var.subnets

}
module "application" {
  source = "./application"
  SUBNET1=module.network.SUBNET1
  SUBNET2=module.network.SUBNET2
  SUBNET3=module.network.SUBNET3
  VPC_ID=module.network.VPC_ID
  key_name=var.key_name
  ImageS3Bucket=var.ImageS3Bucket
  AWS_SECRET_ACCESS_KEY=var.AWS_SECRET_ACCESS_KEY
  AWS_ACCESS_KEY_ID=var.AWS_ACCESS_KEY_ID
}