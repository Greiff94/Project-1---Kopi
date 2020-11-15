
variable "cluster_name" {
  description = "The name to set for the ECS cluster."
  type        = string
  default     = "my-cluster"
}

variable "service_name" {
  description = "The name to set for the ECS service."
  type        = string
  default     = "esc"
}
variable "vpc_id" {
  description = "vpc-0b1e1b0ebcb08d84b"
  type = string
  default = "vpc-0b1e1b0ebcb08d84b"
}