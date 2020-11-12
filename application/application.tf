variable "username"{
    type=string
    default="us-east-1"
}
variable "password"{
    type=string
    default="us-east-1"
}
variable "aws_profile"{
    type=string
    default="us-east-1"
}
variable "aws_account_id"{
    type=string
    default="us-east-1"
}
variable "cdbucket_name"{
    type=string
    default="us-east-1"
}

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
    default="sshkey"
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
   # cidr_blocks = ["0.0.0.0/0"]
   security_groups = [aws_security_group.application-sg.id]
  }
  
}

resource "aws_s3_bucket" "csye6225-bucket" {
  bucket = "webapp.dave.bhavin"
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
resource "aws_s3_bucket_public_access_block" "csye6225-bucket" {
  bucket = aws_s3_bucket.csye6225-bucket.id

  block_public_acls   = true
  block_public_policy = true
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
  username = var.username
  password = var.password
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
   iam_instance_profile = aws_iam_instance_profile.EC2-CSYE6225.name
  subnet_id = var.SUBNET1
  key_name = var.key_name
  tags = {
    Name = "EC2-CSYE6225"
  }
  ebs_block_device {
    device_name = "/dev/sda1"
    volume_type = "gp2"
    delete_on_termination = true
    volume_size = 20
  }
   user_data = <<-EOF
    #!/bin/bash
    sudo mkdir home/ubuntu/webapp
    chmod 777 home/ubuntu/webapp
    sudo touch home/ubuntu/.env
    chmod 777 home/ubuntu/.env
    echo 'host='${aws_db_instance.csye6225-rds.address}'' >> home/ubuntu/.env
    echo 'bucket='${aws_iam_policy.WebAppS3.name}'' >> home/ubuntu/.env
    echo 'secret='${var.AWS_SECRET_ACCESS_KEY}'' >> home/ubuntu/.env
    echo 'access='${var.AWS_ACCESS_KEY_ID}'' >> home/ubuntu/.env
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
                "arn:aws:s3:::${aws_s3_bucket.csye6225-bucket.bucket}/*",
                "arn:aws:s3:::codedeploy-davebhavin-me",
                "arn:aws:s3:::codedeploy-davebhavin-me/*"
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

  
}
resource "aws_iam_instance_profile" "EC2-CSYE6225" {
  name = "EC2-CSYE6225"
  role = aws_iam_role.EC2-CSYE6225.name
}
resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.EC2-CSYE6225.name
  policy_arn = aws_iam_policy.WebAppS3.arn
}

resource "aws_iam_role" "CDServiceRole" {
  name = "CodeDeployServiceRole"

    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com",
        "Service": "s3.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  tags = {
    tag-key = "CDServiceRole"
  }
}

resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = aws_iam_role.CDServiceRole.name
}


resource "aws_codedeploy_app" "codedeploy-application" {
  name = "webapp"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_group" "codedeploy-dg" {
  app_name = aws_codedeploy_app.codedeploy-application.name
  deployment_group_name = "webapp-group"
  service_role_arn = aws_iam_role.CDServiceRole.arn
  auto_rollback_configuration {
    enabled = true
    events = ["DEPLOYMENT_FAILURE"]
  }
  deployment_config_name = "CodeDeployDefault.AllAtOnce"
  deployment_style {
    deployment_option = "WITHOUT_TRAFFIC_CONTROL"
    deployment_type = "IN_PLACE"
  }
  ec2_tag_filter {
    type = "KEY_AND_VALUE"
    key = "Name"
    value = "EC2-CSYE6225"
  }
}

data "aws_route53_zone" "selected" {
  name         = "prod.davebhavin.me"
  private_zone = false
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "api.${data.aws_route53_zone.selected.name}"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.csye6225-ec2.public_ip]
}

resource "aws_iam_policy" "Actions-To-S3" {
  name        = "Actions-Upload-To-S3"
  description = "Actions-Upload-To-S3 policy"
  policy      = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:Get*",
                "s3:List*"
            ],
            "Resource": [
                "arn:aws:s3:::${var.cdbucket_name}",
                "arn:aws:s3:::${var.cdbucket_name}/*"
            ]
        }
    ]
}
EOF

}
resource "aws_iam_user_policy_attachment" "Actions-Upload-To-S3-attachment" {
  user       = "ghactions"
  policy_arn = aws_iam_policy.Actions-To-S3.arn
}

resource "aws_iam_policy" "Actions-Code-Deploy" {
  name        = "Actions-Code-Deploy"
  description = "Actions-Code-Deploy policy"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:RegisterApplicationRevision",
        "codedeploy:GetApplicationRevision"
      ],
      "Resource": [
        "arn:aws:codedeploy:us-east-1:${var.aws_account_id}:application:webapp"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:CreateDeployment",
        "codedeploy:GetDeployment"
      ],
      "Resource": [
        "arn:aws:codedeploy:us-east-1:${var.aws_account_id}:deploymentgroup:webapp/webapp-group"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "codedeploy:GetDeploymentConfig"
      ],
      "Resource": [
        "arn:aws:codedeploy:us-east-1:${var.aws_account_id}:deploymentconfig:CodeDeployDefault.OneAtATime",
        "arn:aws:codedeploy:us-east-1:${var.aws_account_id}:deploymentconfig:CodeDeployDefault.HalfAtATime",
        "arn:aws:codedeploy:us-east-1:${var.aws_account_id}:deploymentconfig:CodeDeployDefault.AllAtOnce"
      ]
    }
  ]
}
EOF

}
resource "aws_iam_policy" "actions-ec2-ami" {
  name        = "actions-ec2-ami"
  description = " policy"

  policy = <<EOF
{
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action" : [
            "ec2:AttachVolume",
            "ec2:AuthorizeSecurityGroupIngress",
            "ec2:CopyImage",
            "ec2:CreateImage",
            "ec2:CreateKeypair",
            "ec2:CreateSecurityGroup",
            "ec2:CreateSnapshot",
            "ec2:CreateTags",
            "ec2:CreateVolume",
            "ec2:DeleteKeyPair",
            "ec2:DeleteSecurityGroup",
            "ec2:DeleteSnapshot",
            "ec2:DeleteVolume",
            "ec2:DeregisterImage",
            "ec2:DescribeImageAttribute",
            "ec2:DescribeImages",
            "ec2:DescribeInstances",
            "ec2:DescribeInstanceStatus",
            "ec2:DescribeRegions",
            "ec2:DescribeSecurityGroups",
            "ec2:DescribeSnapshots",
            "ec2:DescribeSubnets",
            "ec2:DescribeTags",
            "ec2:DescribeVolumes",
            "ec2:DetachVolume",
            "ec2:GetPasswordData",
            "ec2:ModifyImageAttribute",
            "ec2:ModifyInstanceAttribute",
            "ec2:ModifySnapshotAttribute",
            "ec2:RegisterImage",
            "ec2:RunInstances",
            "ec2:StopInstances",
            "ec2:TerminateInstances"
          ],
          "Resource" : "*"
      }]
    }
    EOF
    }
resource "aws_iam_user_policy_attachment" "Actions-Code-Deploy-attachment" {
  user       = "ghactions"
  policy_arn = aws_iam_policy.Actions-Code-Deploy.arn
}

resource "aws_iam_user_policy_attachment" "Actions-ec2-ami-attachment" {
  user       = "ghactions"
  policy_arn = aws_iam_policy.actions-ec2-ami.arn
}
resource "aws_iam_role_policy_attachment" "CloudWatchAgentServerPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  role       = aws_iam_role.EC2-CSYE6225.name
}