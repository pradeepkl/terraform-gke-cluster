# main.tf

provider "google" {
  project = var.project_id
  region  = "asia-south1"
}

resource "google_container_cluster" {
  name     = var.cluster_name
  location = "asia-south1-a"  # Mumbai, India zone a
  
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  # Specify network and subnetwork
  network    = var.network
  subnetwork = var.subnetwork

  # IP allocation policy for VPC-native cluster
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = var.pod_cidr
    services_ipv4_cidr_block = var.service_cidr
  }

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "primary-spot-node-pool"
  location   = "asia-south1-a"
  cluster    = google_container_cluster.name
  node_count = 3

  # Enable auto-repair and auto-upgrade for more resilience with Spot VMs
  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/compute",
    ]

    labels = {
      env = var.environment
    }

    # Specify machine type with 4 vCPUs and 16GB memory
    machine_type = "e2-standard-4"  # 4 vCPUs, 16GB memory
    
    # Use Container-Optimized OS with containerd runtime
    image_type = "COS_CONTAINERD"
    
    # Enable Workload Identity on the node pool
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Enable Spot VMs (preemptible instances)
    spot = true

    # You can also add a taint to ensure only workloads that tolerate Spot VMs
    # are scheduled on these nodes
    taint {
      key    = "cloud.google.com/gke-spot"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
  }
}