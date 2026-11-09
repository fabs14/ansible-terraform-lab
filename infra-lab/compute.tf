locals {
  servers = {
    frontend = { subnet = "public", instance_type = "t3.small" }
    backend  = { subnet = "public", instance_type = "t3.small" }
    database = { subnet = "private", instance_type = "t3.micro" }
  }
}

data "aws_ami" "ubuntu" {
  owners = ["099720109477"]

  filter {
    name   = "image-id"
    values = [var.ubuntu_ami_id]
  }

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_key_pair" "operator" {
  key_name   = "${var.deployment_name}-operator"
  public_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
}

resource "aws_instance" "lab" {
  for_each = local.servers

  ami                         = data.aws_ami.ubuntu.id
  instance_type               = each.value.instance_type
  subnet_id                   = aws_subnet.lab[each.value.subnet].id
  associate_public_ip_address = each.value.subnet == "public"
  vpc_security_group_ids      = [aws_security_group.lab[each.key].id]
  key_name                    = aws_key_pair.operator.key_name

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 16
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  credit_specification {
    cpu_credits = "standard"
  }

  tags = { Name = "${var.deployment_name}-${each.key}", Role = each.key }

  depends_on = [aws_route.internet, aws_route_table_association.lab]
}
