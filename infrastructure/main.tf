provider "aws" {
  region = "us-east-1"
}

# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

# Subnets (Public for Web Server and for DB)
resource "aws_subnet" "web_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "web_subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "db_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

# Security Group for Web Server (Allow HTTP/HTTPS)
resource "aws_security_group" "web_sg" {
  name_prefix = "web_sg"
  vpc_id      = aws_vpc.main.id

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
  }

  # SSH access
  ingress {
    cidr_blocks = ["37.228.204.79/32"]
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
  }
}

variable "allowed_ips" {
  type    = list(string)
  default = ["37.228.204.79/32", "98.80.212.51/32"]  # List of IPs that can ssh to the db server
}

# Security Group for DB Server 
resource "aws_security_group" "db_sg" {
  name_prefix = "db_sg"
  vpc_id      = aws_vpc.main.id

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
  }

  dynamic "ingress" {
    for_each = var.allowed_ips
    content {
      from_port   = 22                    # Port to open (e.g., 22 for SSH)
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]       # Uses each IP from the variable
  }
}

  ingress {
    security_groups = [aws_security_group.web_sg.id]  # Allow MySQL from Web Server
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
  }
}

# Load Balancer Security Group (allow HTTP/HTTPS from the internet)
resource "aws_security_group" "elb_sg" {
  name   = "elb_sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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

# Application Load Balancer (ALB)
resource "aws_lb" "app_lb_web" {
  name               = "app-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.elb_sg.id]
  subnets            = [aws_subnet.web_subnet.id, aws_subnet.web_subnet_2.id]

  tags = {
    Name = "app-lb"
  }
}

# Target Group for Load Balancer
resource "aws_lb_target_group" "web_target_group" {
  name     = "web-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }
}

# Listener for Load Balancer
resource "aws_lb_listener" "app_lb_listener" {
  load_balancer_arn = aws_lb.app_lb_web.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_target_group.arn
  }
}

# Launch Template for Web Server (used in Auto Scaling Group)
resource "aws_launch_template" "web_launch_template" {
  name_prefix   = "web-template"
  image_id      = "ami-0984f4b9e98be44bf"
  instance_type = "t2.micro"
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # Encode the user data in BASE64
  user_data = base64encode(file("/Users/conraddcosta/Codebase/PythonAlgos/iac_assignment/workhuman-iac/ansible/playbooks/application.yml"))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "WebServer"
    }
  }
}

#Auto Scaling Group for Web Servers
resource "aws_autoscaling_group" "web_asg" {
  desired_capacity     = 2
  max_size             = 3
  min_size             = 1
  vpc_zone_identifier  = [aws_subnet.web_subnet.id]
  launch_template {
    id      = aws_launch_template.web_launch_template.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.web_target_group.arn]

  tag {
      key                 = "Name"
      value               = "WebServer-ASG"
      propagate_at_launch = true
    }
}

data "aws_instances" "web_instances" {
  instance_tags = {
    Name = "WebServer-ASG"  # Tag applied to instances in ASG
  }
}

# EC2 Instance for Database Server
resource "aws_instance" "db" {
  ami             = "ami-0984f4b9e98be44bf"
  instance_type   = "t2.micro"
  subnet_id       = aws_subnet.db_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  key_name        = var.key_name

  tags = {
    Name = "DBServer"
  }

  user_data = file("/Users/conraddcosta/Codebase/PythonAlgos/iac_assignment/workhuman-iac/ansible/playbooks/dbserver.yml")  # Ansible playbook to configure DB server
}

# Create an Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-internet-gateway"
  }
}

# Creating a Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associating the Route Table with application Subnet
resource "aws_route_table_association" "web_rt_association" {
  subnet_id      = aws_subnet.web_subnet.id
  route_table_id = aws_route_table.public_rt.id
}

# Associate the Route Table with the DB Subnet
resource "aws_route_table_association" "db_rt_association" {
  subnet_id      = aws_subnet.db_subnet.id
  route_table_id = aws_route_table.public_rt.id
}
