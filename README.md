# Two-Tier Web Application Automation on AWS using Terraform

## Project Overview

This project implements a scalable, secure, and highly available two-tier web application architecture on AWS using Terraform.

The infrastructure is deployed across three isolated environments:

- Development
- Staging
- Production

Each environment is provisioned using reusable Terraform modules, ensuring consistency, modularity, and ease of deployment.

The project demonstrates practical experience with:

- AWS cloud architecture
- Infrastructure as Code (Terraform)
- Auto Scaling and Load Balancing
- Secure network design
- CI/CD pipeline validation

---

## Architecture Summary

The application follows a two-tier architecture:

| Layer | AWS Services | Purpose |
|---|---|---|
| Presentation Layer | ALB, EC2, ASG | Handles incoming traffic and serves web content |
| Storage Layer | S3 | Stores static images used by the application |

Each environment includes:

- VPC
- Public subnets (ALB, Bastion, NAT)
- Private subnets (Web servers)
- Internet Gateway
- NAT Gateway
- Security Groups

<img src="https://raw.githubusercontent.com/Ayush111003/aws-terraform-two-tier-webapp/main/images/figure1.jpg" width="700"><br>
*Figure 1: Architecture / Topology Diagram*

---

## Environment Configuration

| Environment | VPC CIDR | AZs | Public Subnets | Private Subnets | Desired | Max | Instance Type |
|---|---|---|---|---|---|---|---|
| Dev | 10.100.0.0/16 | 3 | 3 | 3 | 2 | 4 | t3.micro |
| Staging | 10.200.0.0/16 | 3 | 3 | 3 | 3 | 4 | t3.small |
| Production | 10.250.0.0/16 | 3 | 3 | 3 | 3 | 6 | t3.medium |

**Availability Zones:**

- `us-east-1b`
- `us-east-1c`
- `us-east-1d`

---

## Storage and Remote State

Each environment uses a dedicated S3 bucket for:

- Terraform state files
- Application image assets

This ensures:

- State isolation
- Clean separation of environments
- Safe deployments

<img src="https://raw.githubusercontent.com/Ayush111003/aws-terraform-two-tier-webapp/main/images/figure2-1.jpg" width="700"><br>
<img src="https://raw.githubusercontent.com/Ayush111003/aws-terraform-two-tier-webapp/main/images/figure2-2.jpg" width="700"><br>
<img src="https://raw.githubusercontent.com/Ayush111003/aws-terraform-two-tier-webapp/main/images/figure2-3.jpg" width="700"><br>
<img src="https://raw.githubusercontent.com/Ayush111003/aws-terraform-two-tier-webapp/main/images/figure2-4.jpg" width="700"><br>
*Figure 2: S3 Buckets and Image Storage Structure*

---

## Terraform Structure

The project uses a modular Terraform structure:

| Directory | Purpose |
|---|---|
| `modules/network` | VPC, subnets, routing, NAT, IGW |
| `modules/webservers` | ALB, ASG, EC2, IAM |
| `dev` / `staging` / `prod` | Environment-specific configurations |

This approach enables:

- Code reusability
- Clear separation of infrastructure layers
- Easier debugging and scaling

<img src="https://raw.githubusercontent.com/Ayush111003/aws-terraform-two-tier-webapp/main/images/figure3.jpg" width="700"><br>
*Figure 3: Cloud9 Project Directory Structure*

---

## Deployment Workflow

Each environment is deployed in two stages:

1. **Network Layer**
2. **Webserver Layer**

Commands used:

```bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
```

This ensures controlled and repeatable deployments.

<img src="https://raw.githubusercontent.com/Ayush111003/aws-terraform-two-tier-webapp/main/images/figure4-1.jpg" width="700"><br>
<img src="https://raw.githubusercontent.com/Ayush111003/aws-terraform-two-tier-webapp/main/images/figure4-2.jpg" width="700"><br>
*Figure 4: Terraform Apply Output (Deployment Execution)*

---

## Application Functionality (Output Verification)

Each EC2 instance is configured using Terraform `user_data` to:

- Install Apache
- Retrieve images from S3
- Generate a dynamic web page

The web page displays:

- Instance ID
- Hostname
- Availability Zone
- Environment

Refreshing the application through the ALB DNS displays different instance metadata across requests, confirming that traffic is being distributed across multiple EC2 instances.

<img src="https://raw.githubusercontent.com/Ayush111003/aws-terraform-two-tier-webapp/main/images/figure5-1.jpg" width="700"><br>
<img src="https://raw.githubusercontent.com/Ayush111003/aws-terraform-two-tier-webapp/main/images/figure5-2.jpg" width="700"><br>
<img src="https://raw.githubusercontent.com/Ayush111003/aws-terraform-two-tier-webapp/main/images/figure5-3.jpg" width="700"><br>
*Figure 5: Web Application Output (Instance Metadata + Image Loaded)*

---

## Load Balancing and Auto Scaling

The Application Load Balancer distributes traffic across EC2 instances in private subnets.

**Auto Scaling configuration:**

| Metric | Condition | Action |
|---|---|---|
| CPU Utilization | > 10% | Scale Out |
| CPU Utilization | < 5% | Scale In |

This ensures:

- High availability
- Fault tolerance
- Automatic scaling

---

## Security Implementation

The infrastructure follows AWS security best practices:

| Component | Implementation |
|---|---|
| EC2 Instances | Private subnets only |
| SSH Access | Through Bastion host |
| Security Groups | Restrict traffic between layers |
| IAM | Role-based access (no hardcoded credentials) |
| S3 Access | IAM-based secure access |

This design prevents direct exposure of internal resources.

---

## CI/CD Pipeline

A GitHub Actions pipeline is implemented for Terraform validation and security scanning.

**Pipeline includes:**

- `terraform fmt`
- `terraform validate`
- TFLint
- Trivy security scan

**Benefits:**

- Early detection of issues
- Enforced best practices
- Automated security checks

<img src="https://raw.githubusercontent.com/Ayush111003/aws-terraform-two-tier-webapp/main/images/figure6.png" width="700"><br>
*Figure 6: GitHub Actions Pipeline (Successful Execution)*

---

## Infrastructure Cleanup

Infrastructure is removed using:

```bash
terraform destroy
```

> **Important:** Destroy webservers before network to prevent dependency errors.

<img src="https://raw.githubusercontent.com/Ayush111003/aws-terraform-two-tier-webapp/main/images/figure7.jpg" width="700"><br>
*Figure 7: Terraform Destroy Process*

---

## Challenges and Solutions

| Challenge | Solution |
|---|---|
| IAM restrictions | Used existing LabRole |
| SSH issues | Fixed security groups and routing |
| User data not updating | Recreated instances |
| Destroy dependency errors | Correct resource deletion order |

---

## Key Learnings

- Multi-environment Terraform design
- AWS networking (VPC, subnets, NAT, routing)
- Load balancing and Auto Scaling
- Secure infrastructure design using IAM
- CI/CD integration for infrastructure

---

## Final Summary

This project demonstrates a complete AWS cloud infrastructure deployment using Terraform, including architecture design, automation, security, scalability, and lifecycle management.

It reflects practical, production-style experience in cloud engineering and DevOps workflows.
