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
resource "aws_vpc" "csye6225-vpc"{
    cidr_block= var.cidr_block
    enable_dns_hostnames =true
    enable_dns_support=true
    enable_classiclink_dns_support= true
    assign_generated_ipv6_cidr_block=false
    tags={
        Name= "csye6225-vpc"
    }
}
resource "aws_internet_gateway" "csye6225-igw"{
    vpc_id = aws_vpc.csye6225-vpc.id    
    tags={
        Name= "csye6225-igw"
    }
    depends_on=[aws_vpc.csye6225-vpc]
}


resource "aws_subnet" "csye6225-subnet-1"{
   
    cidr_block="10.0.1.0/24"
     vpc_id=aws_vpc.csye6225-vpc.id
     availability_zone="us-east-1a"
     map_public_ip_on_launch=true
     tags={
          Name= "csye6225-subnet-1"
     }
 }
 resource "aws_subnet" "csye6225-subnet-2"{
   
    cidr_block="10.0.2.0/24"
     vpc_id=aws_vpc.csye6225-vpc.id
     availability_zone="us-east-1b"
     map_public_ip_on_launch=true
     tags={
          Name= "csye6225-subnet-2"
     }
 }
 resource "aws_subnet" "csye6225-subnet-3"{
   
    cidr_block="10.0.3.0/24"
     vpc_id=aws_vpc.csye6225-vpc.id
     availability_zone="us-east-1c"
     map_public_ip_on_launch=true
     tags={
          Name= "csye6225-subnet-3"
     }
 }


resource "aws_route_table" "csye6225-route-table"{
    vpc_id= aws_vpc.csye6225-vpc.id

    route{
        cidr_block="0.0.0.0/0"
        gateway_id=aws_internet_gateway.csye6225-igw.id
    }
    tags={
        Name="csye-route-table"
    }
    depends_on=[aws_vpc.csye6225-vpc]
}

resource "aws_route_table_association" "csye6225-route-table-subnet-1"{
    subnet_id =aws_subnet.csye6225-subnet-1.id
    route_table_id =aws_route_table.csye6225-route-table.id
}
resource "aws_route_table_association" "csye6225-route-table-subnet-2"{
    subnet_id =aws_subnet.csye6225-subnet-2.id
    route_table_id =aws_route_table.csye6225-route-table.id
}
resource "aws_route_table_association" "csye6225-route-table-subnet-3"{
    subnet_id =aws_subnet.csye6225-subnet-3.id
    route_table_id =aws_route_table.csye6225-route-table.id

}

