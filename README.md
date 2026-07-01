# Super Mario on AWS EKS

Deployment of the Super Mario browser game (`sevenajay/mario:latest`) on AWS EKS using Terraform.

## Overview

This repo contains the Kubernetes manifests and Terraform configuration to spin up an EKS cluster and deploy the Super Mario game, accessible via an AWS LoadBalancer URL.

The Terraform configuration in `EKS-TF/` is sourced from:
`https://github.com/Aakibgithuber/Deployment-of-super-Mario-on-Kubernetes-using-terraform.git`

## Infrastructure Architecture

- **EC2 Ubuntu VM** — jump host (run as `root`/`sudo -i`) where all tooling is installed: Docker, Terraform, AWS CLI, kubectl
- **Terraform (`EKS-TF/`)** — provisions the EKS cluster using the account's default VPC and its subnets; state stored in S3 (`EKS/terraform.tfstate`)
- **IAM roles created by Terraform:**
  - `eks-cluster-cloud` — assumed by `eks.amazonaws.com`, gets `AmazonEKSClusterPolicy`
  - `eks-node-group-cloud` — assumed by `ec2.amazonaws.com`, gets `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`
- **EKS cluster** (`EKS_CLOUD`) — Kubernetes 1.31, single node group `Node-cloud` (`t2.medium`, 1–2 nodes, 20 GB disk)
- **Kubernetes resources** — `mario-deployment` (2 replicas, port 80) + `mario-service` (LoadBalancer, port 80)

## Prerequisites

The EC2 jump host needs:

1. An IAM role with `AdministratorAccess` + S3 full access attached **before** running Terraform
2. The following tools installed: Docker, Terraform (via HashiCorp apt repo), AWS CLI v2, kubectl

## Region Consistency

Three places must all reference the same AWS region:

| File | Setting |
| --- | --- |
| `EKS-TF/provider.tf` | `provider "aws" { region = "..." }` |
| `EKS-TF/backend.tf` | `backend "s3" { region = "..." }` |
| kubectl config step | `aws eks update-kubeconfig --region <region>` |

> `provider.tf` currently hardcodes `us-east-1`. Update all three locations if deploying to a different region.

## Deployment

```bash
# 1. Edit backend.tf — set your S3 bucket name and region
vi EKS-TF/backend.tf

# 2. Provision EKS
cd EKS-TF
terraform init
terraform validate
terraform plan
terraform apply --auto-approve

# 3. Point kubectl at the new cluster
aws eks update-kubeconfig --name EKS_CLOUD --region <region>

# 4. Deploy the game
cd ..
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# 5. Get the public URL — copy the LoadBalancer Ingress value
kubectl describe service mario-service
```

Open the LoadBalancer Ingress URL in a browser to play the game.

## Teardown

```bash
kubectl delete service mario-service
kubectl delete deployment mario-deployment
cd EKS-TF
terraform destroy --auto-approve
```

Then terminate the EC2 jump host manually in the AWS console.
