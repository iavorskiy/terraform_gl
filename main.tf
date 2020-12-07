provider "aws" {
  region     = "us-west-2"
  shared_credentials_file = "/home/alex/.aws/credentials"


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

  owners = ["099720109477"] # Canonical
}

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
  availability_zone = "us-west-2a"

}

resource "aws_subnet" "second" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "192.168.1.128/25"
  availability_zone = "us-west-2b"

}
resource "aws_main_route_table_association" "a" {
  vpc_id         = aws_vpc.main.id
  route_table_id = aws_route_table.main.id
}


resource "aws_security_group" "main_sg" {
  name        = "allow_80"
  description = "Allow 80 port inbound traffic"
  vpc_id      = aws_vpc.main.id

  # Разрешить входящие HTTP
  ingress {
    from_port   = 80
    to_port     = 80
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




resource "aws_lb" "front_end" {
  name               = "test-lb-tf"
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
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id
}



# Define an output value of the IP of the EC2 instance
#output "aws-nginx-ip" {
#  value = aws_instance.web_server_01.public_ip
#}

# Create a new instance of the latest Ubuntu 14.04 on an
# t2.micro node with an AWS Tag naming it "web-server-01"
resource "aws_instance" "nginx1" {
  ami                         = data.aws_ami.ubuntu.id
  associate_public_ip_address = true
  instance_type               = "t2.micro"
  key_name                    = "instance"
  subnet_id                   = aws_subnet.first.id
  user_data                   = <<-EOF
#!/usr/bin/bash
sudo apt-get install nginx -y
echo "<h1>web-server-01</h1>" | sudo tee  /var/www/html/index.nginx-debian.html

EOF

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
  user_data                   = <<-EOF
  #!/usr/bin/bash
sudo apt-get install nginx -y
echo "<h1>web-server-02</h1>" | sudo tee  /var/www/html/index.nginx-debian.html

EOF

  tags = {
    Name = "web-server-02"
  }

  vpc_security_group_ids = [
    aws_security_group.main_sg.id,

  ]
}


resource "aws_lb_target_group_attachment" "test1" {
  target_group_arn = aws_lb_target_group.front_end.arn
  target_id        = aws_instance.nginx1.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "test2" {
  target_group_arn = aws_lb_target_group.front_end.arn
  target_id        = aws_instance.nginx2.id
  port             = 80
}


resource "aws_key_pair" "instance" {
  key_name   = "instance"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDCLSW49Yc9Ao4kuXR5Q29tNeslnGdm0iYiH2Rkm4B/7N2a55tDEneudDPV+7REP/kC4lYiAdY+DWE+Yign30q3nayckamefSSLETleXwwiozDM1TTrMbi4sDgGlCm0JcZBXAM1xW6HGPPyvyWWoQcl9kIVXaCNx0GpAiQ2CbPlFqrUBlMzk6pp3wzU6cSXHMFOv7ZjDFW0Doinxk900gy9/H3ERdBloOStfc52nvvqVDlN8f3vA3WFHrg5520oD6eCGeRD1wlgNLudHHeq48HYDc+AKQX/Yw8kuJWYd5gHu+QrC0648EY1D+ctBirszggAwYA1H5JTREI9y8Wfes7b alex@localhost.localdomain"
}

