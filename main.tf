provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

data "aws_ecs_cluster" "ecs-cluster" {
  cluster_name = "ecs-cluster"
}

##Set iam role and its policy

resource "aws_iam_role" "ecs-instance-role" {
  name = "ecs-instance-role"
  assume_role_policy = "${file("policies/ecs-instance-role.json")}"
}

resource "aws_iam_role_policy" "ecs-cluster" {
  name = "ecs_instance_role"
  role = "${aws_iam_role.ecs-instance-role.id}"
  policy = "${file("policies/ecs-instance-role-policy.json")}"
}

resource "aws_iam_instance_profile" "ecs" {
  name = "ecs-instance-profile"
  role = "${aws_iam_role.ecs-instance-role.name}"
}

resource "aws_iam_role" "ecs_service_role" {
    name = "ecs_service_role"
    assume_role_policy = "${file("policies/ecs-instance-role.json")}"
}

resource "aws_iam_role_policy" "ecs_service_role_policy" {
    name = "ecs_service_role_policy"
    policy = "${file("policies/ecs-service-role-policy.json")}"
    role = "${aws_iam_role.ecs_service_role.id}"
}

resource "aws_security_group" "web-ecr" {
    name = "web-ecr"
    description = "Web Security Group for ecr"

    ingress {
        from_port = 80
        to_port = 80
	protocol = "tcp"
	cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 22
        to_port = 22
	protocol = "tcp"
	cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
	from_port = 0
	to_port = 0
	protocol = "-1"
	cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_vpc" "main" {
    cidr_block = "10.0.0.0/16"
    enable_dns_hostnames = true
}

resource "aws_eip" "ip1" {
  instance = "${aws_instance.ecs_instance.id}"
  provisioner "local-exec" {
    command = "echo web1 ${aws_eip.ip1.public_ip} > ./ip_address.txt"
  }
}

resource "aws_instance" "ecs_instance" {
  count = 1

key_name                    = "aws_key_home"
ami                         = "ami-1d668865"
instance_type               = "t2.micro"
vpc_security_group_ids      = ["${aws_security_group.web-ecr.id}"]
iam_instance_profile        = "${aws_iam_instance_profile.ecs.name}"
user_data = "#!/bin/bash\necho ECS_CLUSTER=ecs-cluster > /etc/ecs/ecs.config"
connection {
  host = "${self.public_ip}"
  user = "ec2-user"
  private_key = "${file("../aws_key_home.pem")}"
  agent = "false"
  type = "ssh"
  timeout = "30s"
  }
}
