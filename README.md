# **Python microservice Task**

## **Overview**
This repository automates the provisioning and deployment of a Kubernetes-based application using **AWS**,**Terraform**,**GitHub Actions**, **Docker**, and **Kubernetes manifests**.

### **Tech Stack**
- **AWS** → CLoud Provider utilized for infrastructure deployment.
- **Terraform** → Infrastructure as Code (IaC) for provisioning AWS EKS.
- **GitHub Actions** → CI/CD pipeline for automating the build, push, and deployment process.
- **Docker** → Containerization of the application.
- **Kubernetes (K8s)** → Deployment and service management.

## **1. Infrastructure Provisioning with Terraform**
This repository contains Terraform configurations to provision the necessary AWS infrastructure for deploying an **EKS (Elastic Kubernetes Service) cluster**. The infrastructure includes:

- **VPC (Virtual Private Cloud)**: A dedicated network to ensure secure communication between resources.
- **EKS Cluster**: A fully managed Kubernetes control plane for running containerized workloads.
- **Worker Nodes**: Auto-scaled EC2 instances that run the Kubernetes workloads.
- **IAM Roles & Policies**: Identity and Access Management (IAM) roles with appropriate permissions for EKS
- **Security Groups**: Fine-grained access controls to regulate inbound and outbound traffic for the cluster and worker nodes.

## **2. Dockerization of Application**
The application is containerized using **Docker** to ensure consistency across different environments. The **Dockerfile** is included in the repository, and the containerization process is automated through a **GitHub Actions CI/CD pipeline**.

### **Dockerfile**
The application is built using a **Dockerfile** located in the repository root. It defines the necessary steps to create a lightweight, production-ready container image.

Example Dockerfile:
```dockerfile
FROM python:3.9-slim
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 5000
ENTRYPOINT ["python", "run.py"]
```
To ensure smooth execution of the application, add the following package to **`requirements.txt`**:
```sh
Werkzeug==2.2.2
```
This package is required to prevent errors during the runtime phase. Without this dependency, the application may fail to start correctly.

## **3. Kubernetes Deployment**
Kubernetes manifests are used to deploy the containerized application. The deployment consists of the following manifest files:

- **Deployment Manifest**: Defines the application pods, replicas, and container specifications.
- **Service Manifest**: Exposes the application externally via load balancer service.

By default, when a **LoadBalancer** type service is created in **AWS**, a **Classic Load Balancer (CLB)** is provisioned automatically.
If an **NLB (Network Load Balancer)** is required instead of the default **CLB**, the following annotation should be added to the **Service manifest**:
```yaml
annotations:
  service.beta.kubernetes.io/aws-load-balancer-type: "nlb"
```
For additional control, such as **attaching a custom security group** to the **NLB (Network Load Balancer)**, the **AWS Load Balancer Controller** should be used. This enables more advanced configurations and security enhancements.


  ## **4. GitHub Actions CI/CD Pipeline**
This repository includes an automated **CI/CD pipeline** using **GitHub Actions**, consisting of two primary workflows:

1. **Build and Deploy APP CI/CD**: creates a Docker image, and pushes it to a container registry then Deploy it to EKS Cluster
2. **Terraform CI/CD**: Automate Deployment of EKS infrastructure


