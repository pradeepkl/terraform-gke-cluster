# GKE Cluster with Spot VMs

This repository contains Terraform scripts to deploy a Google Kubernetes Engine (GKE) cluster with spot VMs in the asia-south1-a zone (Mumbai, India).

## Infrastructure Overview

The Terraform scripts create the following resources:

- GKE cluster in asia-south1-a zone
- Node pool with 3 worker nodes
- Each node has 4 vCPUs and 16GB RAM (e2-standard-4)
- Spot VMs for cost optimization (60-91% cheaper than regular VMs)
- Basic network configuration with VPC-native networking
- Workload Identity enabled for secure access to Google Cloud services

## Prerequisites

Before you begin, you'll need:

1. [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) installed
2. [Terraform](https://www.terraform.io/downloads.html) (v1.0.0+) installed
3. A Google Cloud project with billing enabled
4. Required APIs enabled in your project
5. Appropriate IAM permissions to create GKE clusters

## File Structure

The repository contains the following files:

```
terraform-gke-cluster/
├── main.tf          # Main Terraform configuration
├── variables.tf     # Variable definitions
└── outputs.tf       # Output definitions
```

## Getting Started

### Step 1: Configure Authentication

Run the following command to authenticate with Google Cloud:

```bash
gcloud auth application-default login
```

### Step 2: Enable Required APIs

Enable the necessary APIs for your project:

```bash
gcloud services enable container.googleapis.com compute.googleapis.com --project=YOUR_PROJECT_ID
```

### Step 3: Initialize Terraform

Initialize the Terraform working directory:

```bash
terraform init
```

### Step 4: Plan the Deployment

Review the resources that will be created:

```bash
terraform plan
```

### Step 5: Deploy the Cluster

Apply the Terraform configuration to create the GKE cluster:

```bash
terraform apply
```

When prompted, type "yes" to confirm.

### Step 6: Configure kubectl

After the cluster is created, configure kubectl to interact with it:

```bash
gcloud container clusters get-credentials gke-cluster-mumbai --zone asia-south1-a --project YOUR_PROJECT_ID
```

### Step 7: Connect to the Cluster

After creating the GKE cluster, you need to configure your local environment to connect to it:

#### Option 1: Using gcloud command

The simplest way to connect to your GKE cluster is using the gcloud command:

```bash
gcloud container clusters get-credentials gke-cluster-mumbai --zone asia-south1-a --project YOUR_PROJECT_ID
```

This command:
- Updates your kubeconfig file with appropriate credentials and endpoint information
- Sets the current context to the newly created GKE cluster
- Allows kubectl to communicate with your cluster

#### Option 2: Manual kubeconfig setup

If you prefer to set up the connection manually:

1. Get the cluster credentials from the GCP Console or using Terraform output:
   ```bash
   terraform output -raw kubernetes_cluster_host
   ```

2. Get the cluster CA certificate:
   ```bash
   gcloud container clusters describe gke-cluster-mumbai \
     --zone asia-south1-a \
     --format="value(masterAuth.clusterCaCertificate)" | base64 --decode > ca.crt
   ```

3. Get an authentication token:
   ```bash
   gcloud auth print-access-token
   ```

4. Create or update your kubeconfig file:
   ```bash
   kubectl config set-cluster gke-cluster-mumbai \
     --server=https://YOUR_CLUSTER_ENDPOINT \
     --certificate-authority=ca.crt

   kubectl config set-credentials gke-user \
     --token=YOUR_AUTH_TOKEN

   kubectl config set-context gke-cluster-mumbai \
     --cluster=gke-cluster-mumbai \
     --user=gke-user

   kubectl config use-context gke-cluster-mumbai
   ```

#### Option 3: Using GCP Console

You can also connect to your cluster using the Google Cloud Console:

1. Go to the [GKE section](https://console.cloud.google.com/kubernetes) of the Google Cloud Console
2. Select your project
3. Find your cluster in the list and click on the "Connect" button
4. Click "Run in Cloud Shell" or copy the provided command to run locally

### Step 8: Verify the Connection

After connecting to the cluster, verify that you can access it:

```bash
kubectl get nodes
```

You should see your 3 worker nodes listed, each with the e2-standard-4 machine type.

To get more details about your cluster:

```bash
kubectl cluster-info
```

To view the running system pods:

```bash
kubectl get pods -n kube-system
```

## Understanding the Code

### main.tf

The `main.tf` file defines the GKE cluster and node pool configuration:

```terraform
provider "google" {
  project = var.project_id
  region  = "asia-south1"
}

resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = "asia-south1-a"
  
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = var.network
  subnetwork = var.subnetwork

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = var.pod_cidr
    services_ipv4_cidr_block = var.service_cidr
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "primary-spot-node-pool"
  location   = "asia-south1-a"
  cluster    = google_container_cluster.primary.name
  node_count = 3

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

    machine_type = "e2-standard-4"
    image_type = "COS_CONTAINERD"
    
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    spot = true

    taint {
      key    = "cloud.google.com/gke-spot"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
  }
}
```

Key features:
- `spot = true` enables Spot VMs for cost savings
- `machine_type = "e2-standard-4"` provides 4 vCPUs and 16GB RAM
- Taint ensures only workloads that tolerate spot VMs will run on these nodes

### variables.tf

The `variables.tf` file defines the variables used in the configuration:

```terraform
variable "project_id" {
  description = "The GCP project ID"
  type        = string
  default     = "gke-training-pr"
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  default     = "gke-cluster-mumbai"
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
```

### outputs.tf

The `outputs.tf` file defines the outputs that will be displayed after the deployment:

```terraform
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
```

## Considerations for Spot VMs

When using Spot VMs, keep in mind:

1. **Potential Interruptions**: Spot VMs can be preempted (terminated) at any time if Google Cloud needs the capacity back
2. **Deployment Strategy**: Use tolerations in your Kubernetes manifests to control which workloads run on spot VMs
3. **Stateful Applications**: Avoid running stateful applications on spot VMs unless you have proper data persistence and backup strategies
4. **High Availability**: Ensure critical services have multiple replicas across nodes to handle preemptions

Example toleration for pods that can run on spot VMs:

```yaml
tolerations:
- key: "cloud.google.com/gke-spot"
  operator: "Equal"
  value: "true"
  effect: "NoSchedule"
```

## Cost Optimization

The spot VMs configured in this setup offer significant cost savings (60-91% cheaper than regular VMs) while providing the same computing power (4 vCPUs, 16GB RAM).

## Cleaning Up

To avoid incurring charges, delete the resources when no longer needed:

```bash
terraform destroy
```

When prompted, type "yes" to confirm.

## Troubleshooting

### Common Issues

1. **Authentication Errors**:
   - Run `gcloud auth application-default login` again
   - Ensure you have the necessary IAM permissions

2. **API Not Enabled**:
   - Enable required APIs with `gcloud services enable container.googleapis.com compute.googleapis.com`

3. **Quota Exceeded**:
   - Request a quota increase for the necessary resources in the Google Cloud Console

4. **Node Pool Creation Failures**:
   - Check that the specified machine type is available in the selected zone
   - Verify your project has sufficient quota for the requested resources

## Additional Resources

- [Google Kubernetes Engine Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Terraform GKE Module Documentation](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)
- [Spot VMs in GKE](https://cloud.google.com/kubernetes-engine/docs/how-to/spot-vms)
- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)