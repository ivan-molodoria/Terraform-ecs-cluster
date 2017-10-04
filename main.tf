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
        from_port = 8000
        to_port = 8000
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

key_name                    = "aws_key_work"
ami                         = "ami-1d668865"
instance_type               = "t2.micro"
vpc_security_group_ids      = ["${aws_security_group.web-ecr.id}"]
iam_instance_profile        = "${aws_iam_instance_profile.ecs.name}"
user_data = "#!/bin/bash\necho ECS_CLUSTER=ecs-cluster > /etc/ecs/ecs.config"
connection {
  host = "${self.public_ip}"
  user = "ec2-user"
  private_key = "${file("/home/ivan/.ssh/aws_key_work.pem")}"
  agent = "false"
  type = "ssh"
  timeout = "30s"
  }
}

## Create task difinition
data "aws_ecs_task_definition" "web-task" {
task_definition = "${aws_ecs_task_definition.web-task.family}"
}

resource "aws_ecs_cluster" "ecs-cluster" {
 name = "ecs-cluster"
}

resource "aws_ecs_task_definition" "web-task" {
 family = "web-task"

 container_definitions = <<DEFINITION
[
 {
   "cpu": 128,
   "environment": [{
     "name": "SECRET",
     "value": "KEY"
   }],
   "essential": true,
   "image": "425987977703.dkr.ecr.us-west-2.amazonaws.com/test-repo:latest",
   "memory": 128,
   "memoryReservation": 64,
   "name": "angular",
   "portMappings": [{
        "containerPort": 8000,
        "hostPort": 8000
   }]
 }
]
DEFINITION
}

## Create ecs service

resource "aws_ecs_service" "service1" {
 name          = "web-service"
 cluster       = "${aws_ecs_cluster.ecs-cluster.id}"
 desired_count = 2

 # Track the latest ACTIVE revision
 task_definition = "${aws_ecs_task_definition.web-task.family}:${max("${aws_ecs_task_definition.web-task.revision}", "${data.aws_ecs_task_definition.web-task.revision}")}"
}




#resource "aws_ecs_service" "service1" {
#task_definition = "${aws_ecs_task_definition.web-task.arn}"
#  desired_count   = 1
#  iam_role        = "${aws_iam_role.foo.arn}"
#  depends_on      = ["aws_iam_role_policy.foo"]

#  placement_strategy {
#    type  = "binpack"
#    field = "cpu"
#  }

#  load_balancer {
#    elb_name       = "${aws_elb.foo.name}"
#    container_name = "mongo"
#  }

#  placement_constraints {
#    type       = "memberOf"
#    expression = "attribute:ecs.availability-zone in [us-west-2a, us-west-2b]"
#  }
#}
