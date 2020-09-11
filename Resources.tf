provider "aws" {
  region = "ap-south-1"
  profile = "vaishali"
}

resource "aws_vpc" "main" {
  cidr_block       = "192.168.0.0/16"
  instance_tenancy = "default"

  tags = {
    Name = "rupsvpc"
  }
}

resource "aws_subnet" "subnet1" {
  vpc_id     =  aws_vpc.main.id
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public_subnet"
  }
}

resource "aws_subnet" "subnet2" {
  vpc_id     =  aws_vpc.main.id
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "private_subnet"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id =  aws_vpc.main.id

  tags = {
    Name = "in_gateway"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id =  aws_vpc.main.id
  
  tags = {
    Name = "rupspublic_route_table"
  }
}

resource "aws_route_table_association" "a1" {
  subnet_id      = aws_subnet.subnet1.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_route" "r1" {
  route_table_id            =   aws_route_table.public_route_table.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id =  aws_internet_gateway.gw.id
  
}

resource "aws_eip" "eip" {
  vpc      = true
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.subnet1.id

  tags = {
    Name = "NAT gw"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id =  aws_vpc.main.id
  
  tags = {
    Name = "rupsprivate_route_table"
  }
}

resource "aws_route_table_association" "a2" {
  subnet_id      = aws_subnet.subnet2.id
  route_table_id = aws_route_table.private_route_table.id
}

resource "aws_route" "r2" {
  route_table_id            =   aws_route_table.private_route_table.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id  =   aws_nat_gateway.nat_gw.id
  
}

resource "tls_private_key" "this" {
  algorithm = "RSA"
}

module "key_pair" {
  source = "terraform-aws-modules/key-pair/aws"

  key_name   = "rups-deployer-key"
  public_key = tls_private_key.this.public_key_openssh
}

resource "aws_security_group" "sg1" {
  name        = "sg_wordpress"
  description = "Allow TLS inbound traffic"
  vpc_id      =   aws_vpc.main.id

  ingress {
    description = "ssh"
    from_port   = 0
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "http"
    from_port   = 0
    to_port     = 80
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
    Name = "sg_wordpress"
  }
}


resource "aws_security_group" "sg2" {
  name        = "sg_mysql"
  description = "Allow MYSQL"
  vpc_id      =   aws_vpc.main.id

  ingress {
    description = "MYSQL/Aurora"
    from_port   = 0
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
   
   ingress {
    description = "ssh"
    from_port   = 0
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
    Name = "sg_mysql"
  }
}


resource "aws_instance" "wordpress" {
  ami                  = "ami-7e257211"
  instance_type  = "t2.micro"
  key_name        = "rups-deployer-key"
  vpc_security_group_ids =  [  aws_security_group.sg1.id  ]
  subnet_id =  aws_subnet.subnet1.id
  
  tags = {
    Name = "wordpress-os"
  }
}


resource "aws_instance" "mysql" {
  ami                  = "ami-08706cb5f68222d09"
  instance_type  = "t2.micro"
  key_name        = "rups-deployer-key"
  vpc_security_group_ids =  [  aws_security_group.sg2.id  ]
  subnet_id =  aws_subnet.subnet2.id

  
  tags = {
    Name = "mysql-os"
  }
}

 

