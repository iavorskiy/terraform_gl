provider "aws" {
  region                  = var.region
  shared_credentials_file = "/home/alex/.aws/creds"
}


data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}
#VPC create
resource "aws_vpc" "main" {
  cidr_block           = "192.168.1.0/24"
  enable_dns_hostnames = true

  tags = {
    Name = "main"
  }
}

# Create a new internet gateway for the VPC
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "main"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "main_route_table"
  }
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_subnet" "first" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "192.168.1.0/25"
  availability_zone = var.az_a

}

resource "aws_subnet" "second" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "192.168.1.128/25"
  availability_zone = var.az_b

}
resource "aws_main_route_table_association" "a" {
  vpc_id         = aws_vpc.main.id
  route_table_id = aws_route_table.main.id
}


resource "aws_security_group" "main_sg" {
  name        = "allow_80_22"
  description = "Allow 80 and 22 port inbound traffic"
  vpc_id      = aws_vpc.main.id

  # Разрешить входящие HTTP
  ingress {
    from_port   = var.application_port
    to_port     = var.application_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = var.ssh_port
    to_port     = var.ssh_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Разрешить все исходящие
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


#Create LB

resource "aws_lb" "front_end" {
  name               = "lb-tf"
  internal           = false
  load_balancer_type = "network"
  subnets            = [aws_subnet.first.id, aws_subnet.second.id]

  enable_cross_zone_load_balancing = true

  tags = {
    Environment = "production"
  }
}


resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.front_end.arn
  port              = "80"
  protocol          = "TCP"


  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.front_end.arn
  }
}

resource "aws_lb_target_group" "front_end" {
  name     = "tf-lb-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id
}


#Create instances

resource "aws_instance" "nginx1" {
  ami                         = data.aws_ami.ubuntu.id
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = "instance"
  subnet_id                   = aws_subnet.first.id
  user_data                   = file("web.conf")


  tags = {
    Name = "web-server-01"
  }

  vpc_security_group_ids = [
    aws_security_group.main_sg.id,

  ]
}



resource "aws_instance" "nginx2" {
  ami                         = data.aws_ami.ubuntu.id
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = "instance"
  subnet_id                   = aws_subnet.second.id
  user_data                   = file("web2.conf")

  tags = {
    Name = "web-server-02"
  }

  vpc_security_group_ids = [
    aws_security_group.main_sg.id,

  ]
}


resource "aws_lb_target_group_attachment" "vm1" {
  target_group_arn = aws_lb_target_group.front_end.arn
  target_id        = aws_instance.nginx1.id
  port             = var.application_port
}

resource "aws_lb_target_group_attachment" "vm2" {
  target_group_arn = aws_lb_target_group.front_end.arn
  target_id        = aws_instance.nginx2.id
  port             = var.application_port
}


resource "aws_key_pair" "instance" {
  key_name   = "instance"
  public_key = var.public_key
}
