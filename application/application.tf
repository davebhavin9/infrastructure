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
variable "cdbucket_name2"{
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
  //for demo purpose
  ingress {
    from_port = 22
    protocol = "tcp"
    to_port = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port = 8080
    protocol = "tcp"
    to_port = 8080
    security_groups = [aws_security_group.applicationlb.id]
  }
  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  
}

resource "aws_security_group" "applicationlb" {
  name = "application_lb"
  vpc_id = var.VPC_ID
  ingress {
    from_port = 443
    protocol = "tcp"
    to_port = 443
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
resource "aws_db_parameter_group" "default" {
  name   = "rds-mysql"
  family = "mysql5.7"

  parameter {
    name  = "performance_schema"
    value = true
    apply_method = "pending-reboot"
  }
}

resource "aws_db_instance" "csye6225-rds" {
  allocated_storage = 20
  storage_type = "gp2"
  engine = "mysql"
  engine_version = "5.7"
  instance_class = "db.t3.small"
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
  storage_encrypted=true
  parameter_group_name = aws_db_parameter_group.default.name
}

/*
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
           
  
}*/

resource "aws_launch_configuration" "asg_launch_config" {
  name          = "asg_launch_config"
  image_id      = data.aws_ami.ubuntu.image_id
  instance_type = "t2.micro"
  associate_public_ip_address = true
  key_name = var.key_name
  iam_instance_profile = aws_iam_instance_profile.EC2-CSYE6225.name
  security_groups= [aws_security_group.application-sg.id]

  root_block_device {
    /*device_name = "/dev/sda1"*/
    volume_type = "gp2"
   /* delete_on_termination = true*/
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
     echo  "TopicARN=${aws_sns_topic.default.arn}" >> home/ubuntu/.env
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
resource "aws_lb_target_group" "lb_target_gp" {
  name     = "lbtargetgp"
  port     = "8080"
  protocol = "HTTP"
  vpc_id   = var.VPC_ID
  tags= {
    name = "lb_target_gp"
  }
   stickiness {
    type = "lb_cookie"
    enabled = true
  }

    health_check {
    interval            = 15
    path                = "/"
    protocol            = "HTTP"
    timeout             = 10
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher = "200"
  }
}
resource "aws_autoscaling_group" "csye6225-asg" {
    
    name = "csye6225-asg"
    default_cooldown = 60
    max_size = 5
    min_size = 3
    desired_capacity = 3
    launch_configuration = aws_launch_configuration.asg_launch_config.name
    vpc_zone_identifier  = [var.SUBNET1,var.SUBNET2]
    target_group_arns = [aws_lb_target_group.lb_target_gp.arn]

    tag {
      key   = "Name"
      value = "EC2-CSYE6225"
      propagate_at_launch = true
  } 
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
   autoscaling_groups = [aws_autoscaling_group.csye6225-asg.id]
  
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
/*
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "api.${data.aws_route53_zone.selected.name}"
  type    = "A"
  ttl     = "300"
  records = [aws_launch_configuration.asg_launch_config.public_ip]
}
*/
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
                "s3:PutObjectAcl",
                "s3:Get*",
                "s3:List*"
            ],
            "Resource": [
                "arn:aws:s3:::${var.cdbucket_name}",
                "arn:aws:s3:::${var.cdbucket_name}/*",
                "arn:aws:s3:::${var.cdbucket_name2}",
                "arn:aws:s3:::${var.cdbucket_name2}/*"
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



resource "aws_autoscaling_policy" "instance_scale_up" {
    name = "instance_scale_up"
    cooldown = 60
    scaling_adjustment = 1
    adjustment_type = "ChangeInCapacity"
    autoscaling_group_name = aws_autoscaling_group.csye6225-asg.name
}

resource "aws_autoscaling_policy" "instance_scale_down" {
    name = "instance_scale_down"
    cooldown = 60
    scaling_adjustment = -1
    adjustment_type = "ChangeInCapacity"
    autoscaling_group_name = aws_autoscaling_group.csye6225-asg.name
}

resource "aws_cloudwatch_metric_alarm" "CPU-high" {
    alarm_name = "cpu-util-high-agents"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = "1"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "60"
    statistic = "Average"
    threshold = "5"
    alarm_description = "Scale-up if CPU > 5% for 10 minutes"
    alarm_actions = [
        aws_autoscaling_policy.instance_scale_up.arn
    ]
    dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.csye6225-asg.name
    }
}
resource "aws_cloudwatch_metric_alarm" "CPU-low" {
    alarm_name = "cpu-util-low-agents"
    comparison_operator = "LessThanThreshold"
    evaluation_periods = "1"
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = "60"
    statistic = "Average"
    threshold = "3"
    alarm_description = "Scale-down if CPU < 20% for 10 minutes"
    alarm_actions = [
        aws_autoscaling_policy.instance_scale_down.arn
    ]
    dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.csye6225-asg.name
    }
}


resource "aws_lb" "application_load_balancer" {
  name     = "application-load-balancer"
  internal = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"
  security_groups = [aws_security_group.applicationlb.id]
  subnets = [var.SUBNET1,var.SUBNET2,var.SUBNET3]

  tags = {
    Name = "application-load-balancer"
  }
}
data "aws_acm_certificate" "issued" {
  domain   = "prod.davebhavin.me"
  statuses = ["ISSUED"]
}

resource "aws_lb_listener" "alb-listner" {
  load_balancer_arn = aws_lb.application_load_balancer.arn
  port              = "443"
  protocol          = "HTTPS"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb_target_gp.arn
  }
  certificate_arn= data.aws_acm_certificate.issued.arn
}
/*
resource "aws_autoscaling_attachment" "asg_attachment_bar" {
  autoscaling_group_name = aws_autoscaling_group.csye6225-asg.id
  alb_target_group_arn   = aws_lb_target_group.lb_target_gp.arn
}
*/

resource "aws_route53_record" "alias_route53_record" {
  zone_id = "Z034428080LBB9GYOID3" 
  name    = "prod.davebhavin.me"
  type    = "A"

  alias {
    name                   = aws_lb.application_load_balancer.dns_name
    zone_id                = aws_lb.application_load_balancer.zone_id
    evaluate_target_health = true
  }
}

resource "aws_iam_role" "lambdaRole" {
  name = "lambdaRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "AmazonSESFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
  role       = aws_iam_role.lambdaRole.name
}
resource "aws_iam_role_policy_attachment" "AWSLambdaBasicExecutionRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambdaRole.name
}
resource "aws_iam_role_policy_attachment" "AmazonDynamoDBFullAccess" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  role       = aws_iam_role.lambdaRole.name
}

resource "aws_lambda_function" "lambda" {
  filename      = "~/Desktop/CSYE6225/lambda.zip"
  function_name = "Email_Service"
  role          = aws_iam_role.lambdaRole.arn
  handler       = "lambda.emailService"

  runtime = "nodejs12.x"

  environment {
    variables = {
      Domain_Name = "prod.davebhavin.me"
    }
  }
}
resource "aws_sns_topic" "default" {
  name = "call-lambda-maybe"
}
resource "aws_lambda_permission" "with_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.default.arn
}

resource "aws_sns_topic_subscription" "lambda" {
  topic_arn = aws_sns_topic.default.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.lambda.arn
}

resource "aws_iam_policy" "SNS_policy" {
  name        = "SNS_policy"
  description = "SNS_policy"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": 
   [
     {
      "Effect":"Allow",
      "Action":[
          "SNS:Subscribe",
          "SNS:SetTopicAttributes",
          "SNS:RemovePermission",
          "SNS:Receive",
          "SNS:Publish",
          "SNS:ListSubscriptionsByTopic",
          "SNS:GetTopicAttributes",
          "SNS:DeleteTopic",
          "SNS:AddPermission"
      ],
      "Resource":"${aws_sns_topic.default.arn}"
     }
    ]
}
EOF

}
resource "aws_iam_user_policy_attachment" "LambdaExecution-attachment" {
  user       = "ghactions"
  policy_arn = "arn:aws:iam::aws:policy/AWSLambdaFullAccess"
}
resource "aws_iam_role_policy_attachment" "SNSTopicPolicy" {
  policy_arn = aws_iam_policy.SNS_policy.arn
  role       = aws_iam_role.EC2-CSYE6225.name
}
