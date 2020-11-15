
variable "cluster_name" {
  description = "The name to set for the ECS cluster."
  type        = string
  default     = "terratest-example"
}

variable "service_name" {
  description = "The name to set for the ECS service."
  type        = string
  default     = "terratest-example"
}