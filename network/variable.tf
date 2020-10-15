variable "vpc_cidr"{
    default =""
    type= string
}
variable "subnet_cidr"{
    default=["10.0.1.0/24"]
    type =list(string)
}
