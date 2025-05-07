# variables.tf

variable "project_id" {
  description = "The GCP project ID"
  type        = string
  default     = "gke-training-pr"
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  default     = "optum-gke-cluster"
}

variable "network" {
  description = "The VPC network to use"
  type        = string
  default     = "default"
}

variable "subnetwork" {
  description = "The subnetwork to use"
  type        = string
  default     = "default"
}

variable "pod_cidr" {
  description = "CIDR range for pods"
  type        = string
  default     = "10.48.0.0/14"
}

variable "service_cidr" {
  description = "CIDR range for services"
  type        = string
  default     = "10.52.0.0/20"
}

variable "environment" {
  description = "Environment label for the cluster"
  type        = string
  default     = "production"
}