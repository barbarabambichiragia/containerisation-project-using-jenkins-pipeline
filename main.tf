### create KeyPair ###

resource "tls_private_key" "pacpet1_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "pacpet1_prv" {
  content  = tls_private_key.pacpet1_key.private_key_pem
  filename = "pacpet1_prv"
}


resource "aws_key_pair" "pacpet1_pub_key" {
  key_name   = "pacpet1_pub_key"
  public_key = tls_private_key.pacpet1_key.public_key_openssh
}

# Create VPC
resource "aws_vpc" "pacpet1_vpc" {
  cidr_block = var.aws_vpc

  tags = {
    Name = "pacpet1_vpc"
  }
}

##2 Public Subnets
# Public Subnet 1
resource "aws_subnet" "pacpet1_pubsn_01" {
  vpc_id            = aws_vpc.pacpet1_vpc.id
  cidr_block        = var.aws_pubsub01
  availability_zone = "eu-west-2a"
  tags = {
    Name = "pacpet1_pubsn_01"
  }
}

# Public Subnet 2
resource "aws_subnet" "pacpet1_pubsn_02" {
  vpc_id            = aws_vpc.pacpet1_vpc.id
  cidr_block        = var.aws_pubsub02
  availability_zone = "eu-west-2b"
  tags = {
    Name = "pacpet1_pubsn_02"
  }
}

##2 Private Subnets
# Private Subnet 1
resource "aws_subnet" "pacpet1_prvsn_01" {
  vpc_id            = aws_vpc.pacpet1_vpc.id
  cidr_block        = var.aws_prvsub01
  availability_zone = "eu-west-2a"
  tags = {
    Name = "pacpet1_prvsn_01"
  }
}

#Private Subnet 2
resource "aws_subnet" "pacpet1_prvsn_02" {
  vpc_id            = aws_vpc.pacpet1_vpc.id
  cidr_block        = var.aws_prvsub02
  availability_zone = "eu-west-2b"
  tags = {
    Name = "pacpet1_prvsn_02"
  }
}

# Internet Gateway (This already attaches igw to vpc)
resource "aws_internet_gateway" "pacpet1_igw" {
  vpc_id = aws_vpc.pacpet1_vpc.id

  tags = {
    Name = "pacpet1_igw"
  }
}

#Create Elastic IP for NAT gateway
resource "aws_eip" "pacpet1_nat_eip" {
  vpc = true
  tags = {
    Name = "pacpet1_nat_eip"
  }
}

# Create NAT gateway
resource "aws_nat_gateway" "pacpet1_ngw" {
  allocation_id = aws_eip.pacpet1_nat_eip.id
  subnet_id     = aws_subnet.pacpet1_pubsn_01.id

  tags = {
    Name = "pacpet1_ngw"
  }

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.pacpet1_igw]
}

# Create Public Route Table
resource "aws_route_table" "pacpet1_igw_rt" {
  vpc_id = aws_vpc.pacpet1_vpc.id

  route {
    cidr_block = var.all_ip
    gateway_id = aws_internet_gateway.pacpet1_igw.id
  }

  tags = {
    Name = "pacpet1_igw_rt"
  }
}

## Associate the two public subnets
# Route table association for public subnet 1
resource "aws_route_table_association" "pacpet1_pub1_rt" {
  subnet_id      = aws_subnet.pacpet1_pubsn_01.id
  route_table_id = aws_route_table.pacpet1_igw_rt.id
}

# Route table association for public subnet 2
resource "aws_route_table_association" "pacpet1_pub2_rt" {
  subnet_id      = aws_subnet.pacpet1_pubsn_02.id
  route_table_id = aws_route_table.pacpet1_igw_rt.id
}

# Create Private Route Table
resource "aws_route_table" "pacpet1_ngw_rt" {
  vpc_id = aws_vpc.pacpet1_vpc.id

  route {
    cidr_block = var.all_ip
    gateway_id = aws_nat_gateway.pacpet1_ngw.id
  }

  tags = {
    Name = "pacpet1_ngw_rt"
  }
}

## Associate the two private subnets
# Route table association for private subnet 1
resource "aws_route_table_association" "pacpet1_prv1_rt" {
  subnet_id      = aws_subnet.pacpet1_prvsn_01.id
  route_table_id = aws_route_table.pacpet1_ngw_rt.id
}

# Route table association for private subnet 2
resource "aws_route_table_association" "pacpet1_prv2_rt" {
  subnet_id      = aws_subnet.pacpet1_prvsn_02.id
  route_table_id = aws_route_table.pacpet1_ngw_rt.id
}

##Create Two security groups

#Security group for jenkins
resource "aws_security_group" "pacpet1_jenkins_sg" {
  name        = "pacpet1_frontend_sg"
  description = "Allow Jenkins traffic"
  vpc_id      = aws_vpc.pacpet1_vpc.id

  ingress {
    description = "Port traffic"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.all_ip]
  }

  ingress {
    description = "Allow http traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.all_ip]
  }
  ingress {
    description = "Allow ssh traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.all_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.all_ip]
  }

  tags = {
    Name = "pacpet1_jenkins_sg"
  }
}

#Security group for Ansible
resource "aws_security_group" "pacpet1_ansible_sg" {
  name        = "pacpet1_ansible_sg"
  description = "Allow traffic for ssh"
  vpc_id      = aws_vpc.pacpet1_vpc.id

  ingress {
    description = "Allow ssh traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.all_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "pacpet1_ansible_sg"
  }
}

#Security group for Mysql
resource "aws_security_group" "pacpet1_mysql_sg" {
  name        = "pacpet1_mysql_sg"
  description = "Allow traffic for mysql"
  vpc_id      = aws_vpc.pacpet1_vpc.id

  ingress {
    description = "Allow mysql traffic"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["${var.aws_pubsub01}", "${var.aws_pubsub02}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "pacpet1_mysql_sg"
  }
}

#Security group for SonarQube
resource "aws_security_group" "pacpet1_sq_sg" {
  name        = "pacpet1_sq_sg"
  description = "Allow traffic for SonarQube"
  vpc_id      = aws_vpc.pacpet1_vpc.id

  ingress {
    description = "Allow SonarQube traffic"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = [var.all_ip]
  }

  ingress {
    description = "Allow ssh traffic"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.all_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "pacpet1_mysql_sg"
  }
}
#Create DB password
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!*()-_=+[]{}<>:?"
}
resource "random_id" "db_username" {
  byte_length = 6
}


# Security group docker 
resource "aws_security_group" "pacpet1_docker_sg" {
  name        = "pacpet1_docker_sg"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.pacpet1_vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "docker"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
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

  tags = {
    Name = "pacpd_docker_sg"
  }
}


#create database subnet group
resource "aws_db_subnet_group" "pacpet1_sn_group" {
  name       = "pacpet1_sn_group"
  subnet_ids = [aws_subnet.pacpet1_prvsn_01.id, aws_subnet.pacpet1_prvsn_02.id]

  tags = {
    Name = "pacpet1_sn_group"
  }
}

#Create MySQL RDS Instance
resource "aws_db_instance" "pacpet1-rds" {
  identifier             = "pacpet1-database"
  storage_type           = "gp2"
  allocated_storage      = 20
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t2.micro"
  port                   = "3306"
  db_name                = "test"
  username               = random_id.db_username.id
  password               = random_password.db_password.result
  multi_az               = true
  parameter_group_name   = "default.mysql8.0"
  deletion_protection    = false
  skip_final_snapshot    = true
  db_subnet_group_name   = aws_db_subnet_group.pacpet1_sn_group.name
  vpc_security_group_ids = [aws_security_group.pacpet1_mysql_sg.id]
} 



# SonarQube Server
resource "aws_instance" "Sonarqube_Server" {
  ami                         = var.sonar_ami
  instance_type               = "t2.medium"
  subnet_id                   = aws_subnet.pacpet1_pubsn_01.id
  vpc_security_group_ids      = [aws_security_group.pacpet1_sq_sg.id]
  key_name                    = aws_key_pair.pacpet1_pub_key.key_name
  associate_public_ip_address = true
  user_data                   = local.sonarqube_user_data
  tags = {
    Name = "Sonarqube_Server"
  }
}


# JENKINS SERVER
resource "aws_instance" "pacpet1_Jenkins_Host" {
  ami                         = "ami-035c5dc086849b5de"
  instance_type               = "t2.medium"
  subnet_id                   = aws_subnet.pacpet1_pubsn_01.id
  vpc_security_group_ids      = [aws_security_group.pacpet1_jenkins_sg.id]
  key_name                    = aws_key_pair.pacpet1_pub_key.key_name
  associate_public_ip_address = true
  user_data                   = local.jenkins_user_data

  tags = {
    Name = "pacpet1_Jenkins_Host"
  }
}


#Create Docker Server
resource "aws_instance" "pacpet1_dockerserver" {
  ami                         = "ami-03e5bf04af6d29553"
  instance_type               = "t2.medium"
  vpc_security_group_ids      = [aws_security_group.pacpet1_docker_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.pacpet1_pub_key.key_name
  subnet_id                   = aws_subnet.pacpet1_pubsn_01.id
  user_data                   = local.docker_user_data

  tags = {
    Name = "pacpet1_dockerserver"
  }
}

data "aws_instance" "pacpet1_dockerserver" {
  filter {
    name   = "tag:Name"
    values = ["pacpet1_dockerserver"]
  }
  depends_on = [
    aws_instance.pacpet1_dockerserver
  ]
}

#Create Ansible Server
resource "aws_instance" "pacpet1-ansible-server" {
  ami                         = "ami-035c5dc086849b5de"
  instance_type               = "t2.medium"
  vpc_security_group_ids      = ["${aws_security_group.pacpet1_ansible_sg.id}"]
  associate_public_ip_address = true
  subnet_id                   = aws_subnet.pacpet1_pubsn_01.id
  key_name                    = aws_key_pair.pacpet1_pub_key.key_name
  user_data_replace_on_change = true
  user_data                   = local.ansible_user_data



  tags = {
    Name = "pacpet1-ansible-server"
  }
}

### Deploy application before you proceed with AMI provisioning
#Create DockerHost AMI 
resource "aws_ami_from_instance" "pacpet1_dockerserver_AMI" {
  name               = "pacpet1_dockerserver_AMI"
  source_instance_id = data.aws_instance.pacpet1_dockerserver.id

  depends_on = [
    aws_instance.pacpet1_dockerserver,
  ]

  tags = {
    name = "pacpet1_dockerserver_AMI"
  }
}

#### Create AMI before you continue running the remaining jobs
#Create Target group for load Balancer
resource "aws_lb_target_group" "pacpet1-tg" {
  name     = "pacpet1-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = aws_vpc.pacpet1_vpc.id
  health_check {
    healthy_threshold   = 3
    unhealthy_threshold = 5
    interval            = 30
    timeout             = 5
    path                = "/"
  }
}

#Create Target group attachment
resource "aws_lb_target_group_attachment" "pacpet1-tg-attach" {
  target_group_arn = aws_lb_target_group.pacpet1-tg.arn
  target_id        = aws_instance.pacpet1_dockerserver.id
  port             = 8080

}

# Create load balance listener
resource "aws_lb_listener" "pacpet1_lb_listener" {
  load_balancer_arn = aws_lb.pacpet1-lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.pacpet1-tg.arn
  }
}

# Create Application Load Balancer 
resource "aws_lb" "pacpet1-lb" {
  name                       = "pacpet1-lb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.pacpet1_docker_sg.id]
  subnets                    = [aws_subnet.pacpet1_pubsn_01.id, aws_subnet.pacpet1_pubsn_02.id]
  enable_deletion_protection = false

}

#Create launch configuration
resource "aws_launch_configuration" "pacpet1-lc" {
  name_prefix                 = "pacpet1-lc"
  image_id                    = aws_ami_from_instance.pacpet1_dockerserver_AMI.id
  instance_type               = "t2.medium"
  security_groups             = [aws_security_group.pacpet1_docker_sg.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.pacpet1_pub_key.key_name
  user_data                   = local.docker_lc_user_data


}

# Create Autoscaling group
resource "aws_autoscaling_group" "pacpet1-asg" {
  name                      = "pacpet1-asg"
  desired_capacity          = 2
  max_size                  = 4
  min_size                  = 2
  health_check_grace_period = 300
  default_cooldown          = 60
  health_check_type         = "EC2"
  force_delete              = true
  launch_configuration      = aws_launch_configuration.pacpet1-lc.name
  vpc_zone_identifier       = [aws_subnet.pacpet1_pubsn_01.id, aws_subnet.pacpet1_pubsn_02.id]
  target_group_arns         = ["${aws_lb_target_group.pacpet1-tg.arn}"]
  tag {
    key                 = "Name"
    value               = "pacpet1-asg"
    propagate_at_launch = true
  }
}

# create Autoscaling group policy
resource "aws_autoscaling_policy" "pacpet1-asg-pol" {
  name                   = "pacpet1-asg-pol"
  policy_type            = "TargetTrackingScaling"
  adjustment_type        = "ChangeInCapacity"
  autoscaling_group_name = aws_autoscaling_group.pacpet1-asg.name
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60.0
  }
}

# Create Route 53
resource "aws_route53_zone" "hosted_zone" {
name = var.domain_name
 tags = {
 Environment = "hosted_zone"
 }
 }

resource "aws_route53_record" "pacpet1_A_record" {
 zone_id = aws_route53_zone.hosted_zone.zone_id
name = var.record_name
type = "A"

alias {
 name = aws_lb.pacpet1-lb.dns_name
 zone_id = aws_lb.pacpet1-lb.zone_id
evaluate_target_health = false
 }
}