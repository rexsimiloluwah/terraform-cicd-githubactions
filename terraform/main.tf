terraform {
  backend "s3" {
    bucket  = "terraform-cicd-template"
    key     = "aws/ec2-deploy/terraform.tfstate"
    region  = "us-west-2"
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  # constraint on the provider version                            
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.region
  profile = "ademola"
}

# Create VPC 
resource "aws_vpc" "ec2_server_vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "terraform_cicd_template_vpc"
  }
}

# Create Internet Gateway 
resource "aws_internet_gateway" "ec2_server_igw" {
  vpc_id = aws_vpc.ec2_server_vpc.id

  tags = {
    Name = "terraform_cicd_template_igw"
  }
}

# Create Custom Route Table
resource "aws_route_table" "ec2_server_route_table" {
  vpc_id = aws_vpc.ec2_server_vpc.id

  # receive all traffic 
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ec2_server_igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.ec2_server_igw.id
  }

  tags = {
    Name = "terraform_cicd_template_route_table"
  }
}

# Create a Subnet 
resource "aws_subnet" "ec2_server_subnet_1" {
  vpc_id     = aws_vpc.ec2_server_vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "terraform_cicd_template_subnet_1"
  }
}

# Associate Subnet with Route Table
resource "aws_route_table_association" "route_table_association" {
  subnet_id      = aws_subnet.ec2_server_subnet_1.id
  route_table_id = aws_route_table.ec2_server_route_table.id
}

# Create Security Group to Allow Traffic to Ports 22,80,443
resource "aws_security_group" "ec2_server_allow_web_sg" {
  name        = "allow_web"
  description = "Allow inbound traffic on ports 22,80,443"
  vpc_id      = aws_vpc.ec2_server_vpc.id

  ingress {
    description = "TLS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "terraform_cicd_template_allow_web_sg"
  }
}

# Create a Network Interface
resource "aws_network_interface" "ec2_server_network_interface" {
  subnet_id       = aws_subnet.ec2_server_subnet_1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.ec2_server_allow_web_sg.id]
}

# Assign an elastic IP to the network interface
resource "aws_eip" "ec2_server_eip" {
  vpc                       = true
  network_interface         = aws_network_interface.ec2_server_network_interface.id
  associate_with_private_ip = "10.0.1.50"
  # the igw must exist prior to association with the EIP 
  depends_on = [aws_internet_gateway.ec2_server_igw,aws_instance.ec2_server]
}

# Create a Key Pair
resource "aws_key_pair" "ec2_server_keypair" {
  key_name   = var.key_name
  public_key = var.public_key
}

# Create an IAM profile
resource "aws_iam_instance_profile" "ec2_server_iam_instance_profile" {
  name = "terraform_cicd_template_iam_profile"
  role = aws_iam_role.ec2_server_iam_role.name
}

data "aws_iam_policy_document" "instance_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Create an IAM role
resource "aws_iam_role" "ec2_server_iam_role" {
  name = "terraform_cicd_template_role"
  path = "/"

  assume_role_policy = data.aws_iam_policy_document.instance_assume_role_policy.json

  inline_policy {
    name = "container_registry_access_policy"

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action   = [
            "ecr:*",
            "cloudtrail:LookupEvents"
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "iam:CreateServiceLinkedRole"
          ]
          Effect = "Allow"
          Resource = "*"
          Condition = {
            StringEquals: {
                "iam:AWSServiceName": [
                  "replication.ecr.amazonaws.com"
                ]
            }
          }
        }
      ]
    })
  }
}

# Create the ubuntu server
resource "aws_instance" "ec2_server" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.ec2_server_keypair.key_name
  iam_instance_profile   = aws_iam_instance_profile.ec2_server_iam_instance_profile.name

  network_interface {
    network_interface_id = aws_network_interface.ec2_server_network_interface.id
    device_index         = 0
  }

  # user data 
  user_data = file("../scripts/install-apache.sh")

  connection {
    type        = "ssh"
    user        = "ubuntu"
    host        = self.public_ip
    private_key = file(var.private_key)
    timeout     = "4m"
  }

  tags = {
    Name = "terraform_cicd_template_ec2_server"
  }
}

