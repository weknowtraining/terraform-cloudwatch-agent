variable "worker_iam_role_name" {
  description = "The EKS worker IAM role name"
}

variable "namespace" {
  description = "The k8s namespace to install the agent in"
}

variable "cluster_id" {
  description = "The EKS cluster_id"
}

variable "image" {
  default     = "amazon/cloudwatch-agent:1.247347.3b250378"
  description = "The Docker image to run"

  validation {
    condition     = can(regex("^(amazon|weknowtraining)/cloudwatch-agent:", var.image))
    error_message = "You must use an amazon or weknowtraining cloudwatch-agent image and include the version."
  }
}
