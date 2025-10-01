# configuring aws profile
provider "aws" {
  region = "us-east-1"
  profile = ""
}

# aws vpc
resource "aws_vpc" "vpc" {
  cidr_block = var.vpc_cidr
  instance_tenancy = "default"
  enable_dns_hostnames = true

  tags =  {
    Name = "${var.project_name}-vpc"
  }
  
}

# internet gateway
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id

   tags      = {
    Name    = "${var.project_name}-igw"
   }

}

# public subnet az1
resource "aws_subnet" "public_subnet_az1" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = var.public_subnet_az1_cidr
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  tags      = {
    Name    = "${var.project_name}-public-subnet-az1"
   }
}

resource "aws_subnet" "public_subnet_az2" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = var.public_subnet_az2_cidr
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  tags      = {
    Name    = "${var.project_name}-public-subnet-az2"
   }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route = {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags      = {
    Name    = "${var.project_name}-public-route-table"
   }

}

# associate public subnet az1 to "public route table"
resource "aws_route_table_association" "public_subnet_az1_route_table_association" {
  subnet_id = aws_subnet.public_subnet_az1.id
  route_table_id = aws_route_table.public_route_table.id
}
# associate public subnet az2 to "public route table"
resource "aws_route_table_association" "public_subnet_az2_route_table_association" {
  subnet_id = aws_subnet.public_subnet_az2.id
  route_table_id = aws_route_table.public_route_table.id
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners = ["099720109477"]
  
   filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# jenkins server with IAM role
resource "aws_instance" "jenkins_server" {
  ami = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.large"
  subnet_id = aws_subnet.public_subnet_az2.id
  key_name = "postgreskey"
  user_data = file("jenkins-maven-ansible-setup.sh")
  vpc_security_group_ids = [aws_security_group.jenkins_security_groups.id]
  iam_instance_profile = aws_iam_instance_profile.jenkins_instance_profile.name

    tags = {
    Name        = "jenkins server"
    Application = "jenkins"
  }
}

resource "aws_network_interface" "main_network_interface" {
  subnet_id = aws_subnet.public_subnet_az2.id

  tags      = {
  Name = "jenkins_network_interface"
  }
}

resource "aws_iam_role" "jenkins_role" {
  name               = "jenkins_role"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "ec2.amazonaws.com"  # Assuming Jenkins is running on EC2 instance
        },
        "Action" : "sts:AssumeRole"
      }
    ]
  })
}
