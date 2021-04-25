terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
  backend "s3" {
    # Replace this with your bucket name!
    bucket = "change"
    key    = "change"
    region = "change"
    # Replace this with your DynamoDB table name!
    dynamodb_table = "change"
    encrypt        = true
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
}

# ------------------------------------------------------------------
# Data sources to get VPC, subnet, security group and AMI details
# ------------------------------------------------------------------

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

data "aws_subnet" "selected" {
  id = var.subnet_id
}

data "aws_security_group" "selected" {
  id = var.security_group_id
}

locals {
  instance_count = var.instance_count > var.max_instance_count ? var.max_instance_count : var.instance_count

  license = lookup({
    "ce"                      = var.cloud_user,
    "ee"                      = var.e20_user,
    "mattermost-team-edition" = "",
  }, var.edition, "")
}

data "template_file" "init" {
  count    = local.instance_count
  template = file("init.tpl")

  vars = {
    mattermost_docker_image = var.mattermost_docker_image
    mattermost_docker_tag   = var.mattermost_docker_tag
    e2e_branch_or_commit    = var.e2e_branch_or_commit
    license                 = local.license
    server_count            = count.index + 1
  }
}

# ------------------------------------------------------------------
# Resources to create
# ------------------------------------------------------------------

resource "aws_instance" "this" {
  count = local.instance_count

  ami               = data.aws_ami.ubuntu.id
  instance_type     = var.instance_type
  availability_zone = var.availability_zone
  key_name          = var.key_name
  root_block_device {
    volume_size = 20
  }

  subnet_id              = data.aws_subnet.selected.id
  vpc_security_group_ids = [data.aws_security_group.selected.id]

  user_data = data.template_file.init[count.index].rendered

  tags = {
    Name = format("test-server-%s-%s", terraform.workspace, count.index + 1)
  }
}
