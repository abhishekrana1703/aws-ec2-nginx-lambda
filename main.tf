provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
}

# Subnet
resource "aws_subnet" "main" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

# Route Table Association
resource "aws_route_table_association" "public_subnet" {
  subnet_id      = aws_subnet.main.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP and SSH"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance
resource "aws_instance" "web" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.main.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name               = aws_key_pair.generated_key.key_name

  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              amazon-linux-extras install nginx1 -y
              systemctl start nginx
              systemctl enable nginx
              echo "<h1>Welcome to NGINX running on EC2</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = var.instance_name
  }
}

# Lambda ZIP Packages
data "archive_file" "start_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/start_ec2.py"
  output_path = "${path.module}/lambda/start_ec2.zip"
}

data "archive_file" "stop_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/stop_ec2.py"
  output_path = "${path.module}/lambda/stop_ec2.zip"
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_ec2_exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# Lambda Functions
resource "aws_lambda_function" "start_ec2" {
  function_name = "startEC2Instance"
  filename      = data.archive_file.start_lambda.output_path
  handler       = "start_ec2.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_exec.arn
  environment {
    variables = {
      INSTANCE_ID = aws_instance.web.id
    }
  }
}

resource "aws_lambda_function" "stop_ec2" {
  function_name = "stopEC2Instance"
  filename      = data.archive_file.stop_lambda.output_path
  handler       = "stop_ec2.lambda_handler"
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_exec.arn
  environment {
    variables = {
      INSTANCE_ID = aws_instance.web.id
    }
  }
}

# EventBridge Rules
resource "aws_cloudwatch_event_rule" "start_rule" {
  name                = "start-ec2-daily"
  schedule_expression = "cron(0 8 * * ? *)" # 8 AM UTC
}

resource "aws_cloudwatch_event_rule" "stop_rule" {
  name                = "stop-ec2-daily"
  schedule_expression = "cron(0 20 * * ? *)" # 8 PM UTC
}

resource "aws_cloudwatch_event_target" "start_target" {
  rule      = aws_cloudwatch_event_rule.start_rule.name
  target_id = "startEC2"
  arn       = aws_lambda_function.start_ec2.arn
}

resource "aws_cloudwatch_event_target" "stop_target" {
  rule      = aws_cloudwatch_event_rule.stop_rule.name
  target_id = "stopEC2"
  arn       = aws_lambda_function.stop_ec2.arn
}

resource "aws_lambda_permission" "start_perm" {
  statement_id  = "AllowStartFromCW"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.start_ec2.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.start_rule.arn
}

resource "aws_lambda_permission" "stop_perm" {
  statement_id  = "AllowStopFromCW"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.stop_ec2.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.stop_rule.arn
}
