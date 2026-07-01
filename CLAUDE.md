# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This project deploys a Super Mario browser game (`sevenajay/mario:latest`) on AWS EKS using Terraform. `SuperMarioApp.go` is a plain-text runbook (not Go source code) containing step-by-step setup instructions and terminal output logs from an actual deployment.

The Kubernetes manifests (`deployment.yaml`, `service.yaml`) live in this repo. The Terraform configuration in `EKS-TF/` is sourced from the upstream repo cloned during initial setup:
`https://github.com/Aakibgithuber/Deployment-of-super-Mario-on-Kubernetes-using-terraform.git`

## Infrastructure Architecture

- **EC2 Ubuntu VM** — jump host (run as `root`/`sudo -i`) where all tooling is installed: Docker, Terraform, AWS CLI, kubectl
- **Terraform (`EKS-TF/`)** — provisions the EKS cluster using the account's default VPC and its subnets; state stored in S3 (`EKS/terraform.tfstate`)
- **IAM roles created by Terraform:**
  - `eks-cluster-cloud` — assumed by `eks.amazonaws.com`, gets `AmazonEKSClusterPolicy`
  - `eks-node-group-cloud` — assumed by `ec2.amazonaws.com`, gets `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`
- **EKS cluster** (`EKS_CLOUD`) — Kubernetes 1.31, single node group `Node-cloud` (`t2.medium`, 1–2 nodes, 20 GB disk)
- **Kubernetes resources** — `mario-deployment` (2 replicas, port 80) + `mario-service` (LoadBalancer, port 80)

## Region Consistency

Three places must reference the same AWS region:

| File | Setting |
|---|---|
| `EKS-TF/provider.tf` | `provider "aws" { region = "..." }` |
| `EKS-TF/backend.tf` | `backend "s3" { region = "..." }` |
| kubectl config step | `aws eks update-kubeconfig --region <region>` |

`provider.tf` currently hardcodes `us-east-1`. The actual deployment shown in `SuperMarioApp.go` ran in `ap-south-1` — the provider was edited before that run.

## Deployment Workflow

```bash
# 1. Edit backend.tf — set your S3 bucket name and region
vi EKS-TF/backend.tf

# 2. Provision EKS
cd EKS-TF
terraform init
terraform validate
terraform plan
terraform apply --auto-approve

# 3. Point kubectl at the new cluster (use the region from provider.tf)
aws eks update-kubeconfig --name EKS_CLOUD --region <region>

# 4. Deploy the game
cd ..
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml

# 5. Get the public URL
kubectl describe service mario-service   # copy LoadBalancer Ingress
```

## Teardown

```bash
kubectl delete service mario-service
kubectl delete deployment mario-deployment
cd EKS-TF
terraform destroy --auto-approve
# Terminate the EC2 jump host manually in the AWS console
```

## Prerequisites (EC2 Jump Host Setup)

The EC2 instance needs:
1. An IAM role with `AdministratorAccess` + S3 full access attached **before** running Terraform
2. Docker, Terraform (via HashiCorp apt repo), AWS CLI v2, and kubectl installed

These installation steps are documented in full in `SuperMarioApp.go`.
