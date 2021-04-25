variable "mattermost_docker_image" {
  description = "Mattermost edition, e.g. mattermost-enterprise-edition, mm-ee-test"
  type        = string
}

variable "mattermost_docker_tag" {
  description = "Mattermost image tag, e.g. master, release-5.30, 704_60b27ef5_9f16e221_d6b4d697"
  type        = string
}

variable "edition" {
  description = "Mattermost edition, e.g. 'ce' for cloud, 'ee' for enterprise and 'te' for team"
  type        = string
  default     = "te"
}

variable "e2e_branch_or_commit" {
  description = "Branch or commit hash of E2E test from mattermost-webapp"
  type        = string
  default     = "master"
}

variable "cloud_user" {
  type = string
}

variable "e20_user" {
  type = string
}

variable "instance_count" {
  description = "Number of instances to launch"
  type        = number
  default     = 1
}

variable "max_instance_count" {
  description = "Max number of instances to launch"
  type        = number
  default     = 1
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "key_name" {
  type = string
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "availability_zone" {
  type    = string
  default = "us-east-1a"
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}
