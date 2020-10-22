variable "ImageS3Bucket"{
  type=string
  default="us-east-1"
}
variable "AWS_ACCESS_KEY_ID"{
    type=string
    default="us-east-1"
}
variable "AWS_SECRET_ACCESS_KEY"{
    type=string
    default="us-east-1"
}
variable "key_name"{
    type=string
    default="prod"
}
variable "SUBNET3"{
    type=string
    default="us-east-1"
}
variable "SUBNET1"{
    type=string
    default="us-east-1"
}
variable "SUBNET2"{
    type=string
    default="us-east-1"
}
variable "VPC_ID"{
    type=string
    default="us-east-1"
}
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name = "name"
    values = ["CSYE6225*"]
  }
  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["202555839823"]
}

resource "aws_security_group" "application-sg" {
  name = "application_sg"
  description = "EC2 security group"
  vpc_id = var.VPC_ID
  ingress {
    from_port = 22
    protocol = "tcp"
    to_port = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    protocol = "tcp"
    to_port = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 443
    protocol = "tcp"
    to_port = 443
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 8080
    protocol = "tcp"
    to_port = 8080
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  
}


resource "aws_security_group" "csye6225-database-sg" {
  name = "csye6225-database-sg"
  vpc_id = var.VPC_ID
  description = "RDS Security group"
  ingress {
    from_port = 3306
    protocol = "tcp"
    to_port = 3306
    cidr_blocks = ["0.0.0.0/0"]
  }
  
}

resource "aws_s3_bucket" "csye6225-bucket" {
  bucket = "webapp.bhavin.dave"
  acl = "private"
  force_destroy = "true"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
      }
    }
  }
  lifecycle_rule {
    enabled = true

    transition {
      days = 30
      storage_class = "STANDARD_IA"
    }
  }
}
resource "aws_db_subnet_group" "rds_subnet" {
  name       = "rds_subnet"
  subnet_ids = [var.SUBNET1,var.SUBNET2]

  tags = {
    Name = "SUBNETGROUP"
  }
}

resource "aws_db_instance" "csye6225-rds" {
  allocated_storage = 20
  storage_type = "gp2"
  engine = "mysql"
  engine_version = "5.7"
  instance_class = "db.t3.micro"
  name  = "csye6225"
  identifier ="csye6225-f20"
  username = "csye6225fall2020"
  password = "foobarbaz"
  skip_final_snapshot= true
  multi_az = false
  vpc_security_group_ids =[aws_security_group.csye6225-database-sg.id]
  tags = {
      Name = "csye6225-rds"
  }
  db_subnet_group_name = aws_db_subnet_group.rds_subnet.name
}


resource "aws_instance" "csye6225-ec2" {
  ami = data.aws_ami.ubuntu.image_id
  instance_type = "t2.micro"
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.application-sg.id]
  depends_on = [aws_db_instance.csye6225-rds]

  subnet_id = var.SUBNET1
  key_name = var.key_name
  ebs_block_device {
    device_name = "/dev/sda1"
    volume_type = "gp2"
    delete_on_termination = true
    volume_size = 20
  }
   user_data = <<-EOF

    echo host=${aws_db_instance.csye6225-rds.address} >> .env
    echo bucket=${var.ImageS3Bucket} >> .env
    echo secret=${var.AWS_SECRET_ACCESS_KEY} >> .env
    echo access=${var.AWS_ACCESS_KEY_ID} >> .env
    chmod 777 .env
    mkdir webapp
     chmod 777 .env
    EOF          
           
  
}

resource "aws_dynamodb_table" "csye6225-dynamoDb" {
  hash_key = "id"
  name = "csy6225_dynamo"
  attribute {
    name = "id"
    type = "S"
  }
  
  read_capacity = 5
  write_capacity = 5
}

resource "aws_iam_policy" "WebAppS3" {
  name        = "WebAppS3"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "s3:Get*",
                "s3:List*",
                "s3:DeleteObject",
                "s3:PutObject"
            ],
            "Effect": "Allow",
              "Resource": [
                "arn:aws:s3:::${aws_s3_bucket.csye6225-bucket.bucket}",
                "arn:aws:s3:::${aws_s3_bucket.csye6225-bucket.bucket}/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role" "EC2-CSYE6225" {
  name = "EC2-CSYE6225"
  path = "/"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    Name = "EC2-CSYE6225"
  }
}
resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.EC2-CSYE6225.name
  policy_arn = aws_iam_policy.WebAppS3.arn
}