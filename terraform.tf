# Define the AWS provider
provider "aws" {
  region = "us-east-1"  # Replace with your desired AWS region
}

# Create a VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

# Create public and private subnets in different AZs
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

# Create network ACLs for public and private subnets
resource "aws_network_acl" "public_acl" {
  vpc_id = aws_vpc.my_vpc.id

  # Define public subnet ACL rules
  # Create rule number 100 for ingress and egress
  # Use "action" instead of "rule_action"
  # Allow HTTP (port 80) traffic from the internet
  ingress {
    rule_number   = 100
    action        = "allow"
    protocol      = "tcp"
    cidr_block    = "0.0.0.0/0"
    from_port     = 80
    to_port       = 80
  }

  egress {
    rule_number   = 100
    action        = "allow"
    protocol      = "-1"
    cidr_block    = "0.0.0.0/0"
    from_port     = 0
    to_port       = 65535
  }
}

resource "aws_network_acl" "private_acl" {
  vpc_id = aws_vpc.my_vpc.id

  # Define private subnet ACL rules
  # Create rule number 100 for ingress and egress
  # Use "action" instead of "rule_action"
  egress {
    rule_number   = 100
    action        = "allow"
    protocol      = "-1"
    cidr_block    = "0.0.0.0/0"
    from_port     = 0
    to_port       = 65535
  }
}

# Create security groups for public and private resources
resource "aws_security_group" "public_sg" {
  name        = "public-security-group"
  description = "Security group for public resources"

  # Define ingress rules for public resources (e.g., ALB)
  # Allow HTTP (port 80) traffic from the internet
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "private_sg" {
  name        = "private-security-group"
  description = "Security group for private resources"

  # Define ingress rules for private resources (e.g., database)
  # Allow traffic from the public subnet (ALB)
  ingress {
    from_port       = 5432  # Example database port
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }
}

# Create IAM roles and policies for secure access
resource "aws_iam_role" "ec2_role" {
  name = "my-ec2-role"

  # Define role permissions policies, for example:
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach policies to the IAM role as needed
resource "aws_iam_role_policy_attachment" "example" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"  # Example policy, replace with your desired policy
  role       = aws_iam_role.ec2_role.name
}

# Create an EC2 instance for the bastion host in the public subnet
resource "aws_instance" "bastion" {
  ami           = "ami-12345678"  # Replace with a suitable bastion host AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id
  key_name      = "your-bastion-key"  # Replace with your SSH key name

  # Additional bastion host configurations here

  tags = {
    Name = "BastionHost"
  }
}

# Create an Application Load Balancer (ALB) in the public subnet
resource "aws_lb" "web_lb" {
  name               = "web-lb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_subnet.id]

  enable_deletion_protection = false

  enable_http2 = true

  # Define listener, target group, and other ALB configurations
}

# Create DNS records using Route 53 (Assuming you have a Route 53 hosted zone)
resource "aws_route53_record" "web_app_dns" {
  zone_id = "your-route53-zone-id"  # Replace with your Route 53 hosted zone ID
  name    = "example.com"  # Replace with your domain name
  type    = "A"

  alias {
    name                   = aws_lb.web_lb.dns_name
    zone_id                = aws_lb.web_lb.zone_id
    evaluate_target_health = true
  }
}

# Output information about the resources
output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}

output "load_balancer_dns" {
  value = aws_lb.web_lb.dns_name
}
