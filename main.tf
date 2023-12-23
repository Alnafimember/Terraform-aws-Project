resource  "aws_vpc" "firstvpc" {
    cidr_block = var.cidr
}
resource "aws_subnet" "mysub1" {
    vpc_id = aws_vpc.firstvpc.id
    cidr_block = "10.0.0.0/24"
    availability_zone = "us-east-1a"
    map_public_ip_on_launch = true

}
resource "aws_subnet" "mysub2" {
    vpc_id = aws_vpc.firstvpc.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1b"
    map_public_ip_on_launch = true
    
}

resource "aws_internet_gateway" "ipw" {
    vpc_id = aws_vpc.firstvpc.id
}
resource "aws_route_table" "rot" {
    vpc_id = aws_vpc.firstvpc.id
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.ipw.id
  }
}
resource "aws_route_table_association" "rta1" {
    subnet_id = aws_subnet.mysub1.id
    route_table_id = aws_route_table.rot.id

}
resource "aws_route_table_association" "rta2" {
    subnet_id = aws_subnet.mysub2.id
    route_table_id = aws_route_table.rot.id

}
resource "aws_security_group" "websga" {
  name        = "webserver"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.firstvpc.id

  ingress {
    description      = "HTTP from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]

  }
  ingress {
    description      = "TLS from VPC"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

resource "aws_s3_bucket" "example" {
  bucket = "rafayterraformcreation"

}


resource "aws_instance" "server1" {
  ami = "ami-0c7217cdde317cfec"
  instance_type = "t2.micro"
  vpc_security_group_ids = [aws_security_group.websga.id]
  subnet_id = aws_subnet.mysub1.id
  user_data = base64encode(file("alnafi.sh"))

}

# create the loadbalancer for application
resource "aws_lb" "alb" {
  name = "mynewalb"
  internal = false
  load_balancer_type = "application"  

  security_groups = [aws_security_group.websga.id]
  subnets = [aws_subnet.mysub1.id, aws_subnet.mysub2.id]



}

resource "aws_lb_target_group" "lbg" {
  name = "mytgip"
  port = 80
  protocol = "HTTP"
  vpc_id = aws_vpc.firstvpc.id

  health_check {
    path = "/"
    port = 80
  }

}

resource "aws_lb_target_group_attachment" "awslbg" {
  target_group_arn = aws_lb_target_group.lbg.arn
  target_id = aws_instance.server1.id
  port = 80
  
}
resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port = 80
  protocol = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.lbg.arn
    type = "forward"
  }
}

output "loadbalancerdns" {
  value = aws_lb.alb.dns_name
}