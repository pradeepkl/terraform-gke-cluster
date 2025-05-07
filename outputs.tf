# outputs.tf

output "kubernetes_cluster_name" {
  value       = google_container_cluster.primary.name
  description = "GKE Cluster Name"
}

output "kubernetes_cluster_host" {
  value       = "https://${google_container_cluster.primary.endpoint}"
  description = "GKE Cluster Host"
  sensitive   = true
}

output "region" {
  value       = "asia-south1"
  description = "GCP Region"
}

output "zone" {
  value       = "asia-south1-a"
  description = "GCP Zone"
}