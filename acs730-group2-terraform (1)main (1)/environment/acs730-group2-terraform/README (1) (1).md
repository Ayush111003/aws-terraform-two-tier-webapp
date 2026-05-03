# ACS730 - Final Project
## Two-Tier Web Application Automation with Terraform ##

**Group 2** | Winter 2026 | Professor: Leo Lu 

| Name | Student ID |
|------|-----------|
| Faizan Razzakbhai Sheikh | 114441256 |
| Ayush Patel | 129870259 |
| Marjan Haghighi | 127878254 |
| Sharun Manakkara | 148442247 |
| Nrupad Ganeshkumar Raval | 102465259 |

---

## Prerequisites (Do These BEFORE Running Terraform)

### 1. Install Terraform
```bash
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install terraform

# Verify installation
terraform --version
```

### 2. Configure AWS CLI (Skip if using AWS Academy - already configured)
```bash
aws configure
# Enter: Access Key, Secret Key, Region (us-east-1), Output (json)
```

### 3. S3 Buckets for Remote State (Create Manually in AWS Console)
Three separate buckets are required - one per environment:
- group2-dev-bucket-terraform
- group2-staging-bucket-terraform
- group2-prod-bucket-terraform

For each bucket:
- Region: us-east-1
- Enable versioning: Yes
- Block all public access: Yes

Also create an images/ folder inside each bucket and upload at least one image.
The web servers will pull images from their own environment bucket on boot.

### 4. Key Pair
This project uses the AWS Academy default key pair vockey.
No need to generate a new key pair.
To SSH into Bastion:
```bash
# Download vockey.pem from AWS Academy -> AWS Details -> Download PEM
chmod 400 labsuser.pem
ssh -i labsuser.pem ec2-user@<bastion_public_ip>
```

### 5. Update Your Admin IP (Required for Bastion SSH Access)
Find your public IP:
```bash
curl ifconfig.me
```
Pass it as a variable when running terraform apply:
```bash
terraform apply -var="my_ip=YOUR_IP/32"
```
Note: If using AWS Academy, your IP changes every session. Run this step each time.

---

## Architecture Summary

| Environment | VPC CIDR | Instances | Instance Type | S3 Bucket |
|-------------|----------|-----------|---------------|-----------|
| Dev | 10.100.0.0/16 | 2 | t3.micro | group2-dev-bucket-terraform |
| Staging | 10.200.0.0/16 | 3 | t3.small | group2-staging-bucket-terraform |
| Prod | 10.250.0.0/16 | 3 | t3.medium | group2-prod-bucket-terraform |

Each environment contains:

| Resource | Location |
|----------|----------|
| Public Subnet 1 | us-east-1b (Bastion + ALB) |
| Public Subnet 2 | us-east-1c (NAT GW + ALB) |
| Public Subnet 3 | us-east-1d (ALB) |
| Private Subnet 1 | us-east-1b (Web servers) |
| Private Subnet 2 | us-east-1c (Web servers) |
| Private Subnet 3 | us-east-1d (Web servers) |

---

## Deployment Steps (Run in This Exact Order!)

### Step 1 - Dev Network
```bash
cd dev/network
terraform init
terraform plan
terraform apply
```
Creates: Dev VPC (10.100.0.0/16), 3 public subnets, 3 private subnets, IGW, NAT GW, route tables

### Step 2 - Dev Webservers
```bash
cd ../webservers
terraform init
terraform plan -var="my_ip=YOUR_IP/32"
terraform apply -var="my_ip=YOUR_IP/32"
```
Creates: Bastion host, ALB, Launch Template, ASG (2 instances), CloudWatch alarms

Note down these outputs:
- alb_dns_name      open this in browser to test
- bastion_public_ip use this to SSH into bastion

### Step 3 - Staging Network
```bash
cd ../../staging/network
terraform init
terraform plan
terraform apply
```
Creates: Staging VPC (10.200.0.0/16), 3 public subnets, 3 private subnets, IGW, NAT GW, route tables

### Step 4 - Staging Webservers
```bash
cd ../webservers
terraform init
terraform plan -var="my_ip=YOUR_IP/32"
terraform apply -var="my_ip=YOUR_IP/32"
```
Creates: Bastion host, ALB, Launch Template, ASG (3 instances), CloudWatch alarms

### Step 5 - Prod Network
```bash
cd ../../prod/network
terraform init
terraform plan
terraform apply
```
Creates: Prod VPC (10.250.0.0/16), 3 public subnets, 3 private subnets, IGW, NAT GW, route tables

### Step 6 - Prod Webservers
```bash
cd ../webservers
terraform init
terraform plan -var="my_ip=YOUR_IP/32"
terraform apply -var="my_ip=YOUR_IP/32"
```
Creates: Bastion host, ALB, Launch Template, ASG (3 instances), CloudWatch alarms

---

## Verify Deployment

### Test Website
Open the alb_dns_name output in your browser.
You should see:
- Welcome to Group 2 page
- Environment badge (Green=Dev, Orange=Staging, Red=Prod)
- Instance ID, Hostname, Availability Zone
- Image loaded from S3 bucket

Refresh the page multiple times to see different Instance IDs - this proves load balancing is working.

### SSH to Bastion
```bash
ssh -i labsuser.pem ec2-user@<bastion_public_ip>
```

### From Bastion - SSH to Private Web Server
```bash
ssh ec2-user@<web_server_private_ip>
```

---

## GitHub Actions - Security Scan

Automated security scanning is configured using TFLint and Trivy:
- Triggers on every push to staging branch
- Triggers on every pull request to prod branch

Workflow file location: .github/workflows/security-scan.yml

To trigger manually - push any change to staging branch:
```bash
git checkout staging
git merge main
git push origin staging
```

---

## Cleanup (IMPORTANT - Destroy in This Exact Order!)

Always destroy webservers before network. Always destroy prod first.

```bash
# Prod
cd prod/webservers  && terraform destroy -var="my_ip=YOUR_IP/32"
cd ../network       && terraform destroy

# Staging
cd ../../staging/webservers && terraform destroy -var="my_ip=YOUR_IP/32"
cd ../network               && terraform destroy

# Dev
cd ../../dev/webservers && terraform destroy -var="my_ip=YOUR_IP/32"
cd ../network           && terraform destroy
```

WARNING: NAT Gateway charges per hour - always destroy after testing!

---

## Folder Structure

```
acs730-group2-terraform/
├── .github/
│   └── workflows/
│       └── security-scan.yml   # GitHub Actions tfsec security scan
├── modules/
│   └── network/                # Reusable VPC/subnet/NAT module
│       ├── main.tf
│       ├── variables.tf
│       └── output.tf
├── dev/
│   ├── network/                # Dev VPC, subnets, IGW, NAT GW, route tables
│   │   ├── config.tf
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── output.tf
│   └── webservers/             # Dev Bastion, ALB, ASG, CloudWatch
│       ├── config.tf
│       ├── main.tf
│       ├── variables.tf
│       ├── output.tf
│       └── install_httpd.tpl
├── staging/
│   ├── network/                # Staging VPC, subnets, IGW, NAT GW, route tables
│   └── webservers/             # Staging Bastion, ALB, ASG, CloudWatch
└── prod/
    ├── network/                # Prod VPC, subnets, IGW, NAT GW, route tables
    └── webservers/             # Prod Bastion, ALB, ASG, CloudWatch
```
