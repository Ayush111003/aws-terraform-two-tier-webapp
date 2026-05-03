# Two-Tier Web Application Automation on AWS using Terraform

A scalable, secure, and highly available two-tier web application infrastructure on AWS, fully automated using Terraform and deployed across three isolated environments: **Development**, **Staging**, and **Production**.

---

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Traffic Flow](#traffic-flow)
- [Environment Configuration](#environment-configuration)
- [Terraform Structure](#terraform-structure)
- [Remote State Management](#remote-state-management)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Terraform Code](#terraform-code)
  - [modules/network/main.tf](#modulesnetworkmaintf)
  - [modules/network/variables.tf](#modulesnetworkvariablestf)
  - [modules/network/output.tf](#modulesnetworkoutputtf)
  - [dev/network/config.tf](#devnetworkconfigtf)
  - [dev/network/main.tf](#devnetworkmaintf)
  - [dev/network/variables.tf](#devnetworkvariablestf)
  - [dev/webservers/config.tf](#devwebserversconfigtf)
  - [dev/webservers/main.tf](#devwebserversmaintf)
  - [dev/webservers/variables.tf](#devwebserversvariablestf)
  - [dev/webservers/output.tf](#devwebserversoutputtf)
  - [install_httpd.tpl](#install_httpdtpl)
- [Load Balancing and Auto Scaling](#load-balancing-and-auto-scaling)
- [Security Implementation](#security-implementation)
- [GitHub Actions — CI/CD Pipeline](#github-actions--cicd-pipeline)
- [Infrastructure Cleanup](#infrastructure-cleanup)
- [Challenges and Solutions](#challenges-and-solutions)
- [Key Learnings](#key-learnings)

---

## Architecture Overview

The application follows a two-tier architecture:

| Layer | AWS Services | Purpose |
|---|---|---|
| Presentation Layer | ALB, EC2, ASG | Handles incoming traffic and serves web content |
| Storage Layer | S3 | Stores static images retrieved by web servers |

Each environment includes:

- VPC with environment-specific CIDR
- Public subnets — ALB, Bastion, NAT Gateway
- Private subnets — Web servers (EC2)
- Internet Gateway + NAT Gateway
- Security Groups (layered: ALB → Web → Bastion)

---

## Traffic Flow

### User Traffic (Internet → Application)

1. User sends HTTP request to the ALB DNS name
2. ALB receives the request in the public subnet
3. ALB forwards the request to the target group
4. Request routes to an EC2 instance in the private subnet
5. Web server responds with HTML and an S3-hosted image

### Internal Traffic (EC2 → S3)

1. EC2 instance starts via `user_data` script
2. IAM role (`LabInstanceProfile`) grants the instance access to S3
3. Instance runs `aws s3 cp` to pull images from the bucket
4. Images are served as part of the dynamic web page

### Admin Access (SSH via Bastion)

1. Admin connects to the Bastion host via SSH (public subnet, restricted to your IP)
2. From Bastion, admin connects to private EC2 instances using private IP
3. Direct SSH to private instances is not permitted — follows least-privilege access

---

## Environment Configuration

| Environment | VPC CIDR | AZs | Public Subnets | Private Subnets | Desired | Max | Instance Type |
|---|---|---|---|---|---|---|---|
| Dev | 10.100.0.0/16 | 3 | 3 | 3 | 2 | 4 | t3.micro |
| Staging | 10.200.0.0/16 | 3 | 3 | 3 | 3 | 4 | t3.small |
| Production | 10.250.0.0/16 | 3 | 3 | 3 | 3 | 6 | t3.medium |

**Availability Zones:** `us-east-1b` · `us-east-1c` · `us-east-1d`

---

## Terraform Structure

```
acs730-group2-terraform/
├── modules/
│   └── network/
│       ├── main.tf         # VPC, subnets, IGW, NAT, route tables
│       ├── variables.tf
│       └── output.tf
├── dev/
│   ├── network/
│   │   ├── config.tf       # Backend: group2-dev-bucket-terraform
│   │   ├── main.tf
│   │   ├── variables.tf    # CIDR: 10.100.0.0/16, t3.micro
│   │   └── output.tf
│   └── webservers/
│       ├── config.tf       # Remote state from dev network
│       ├── main.tf         # SG, Bastion, ALB, ASG, CloudWatch
│       ├── variables.tf
│       ├── output.tf
│       └── install_httpd.tpl
├── staging/
│   ├── network/            # CIDR: 10.200.0.0/16, t3.small
│   └── webservers/
└── prod/
    ├── network/            # CIDR: 10.250.0.0/16, t3.medium
    └── webservers/
└── .github/
    └── workflows/
        └── security-scan.yml
```

---

## Remote State Management

Each environment uses a dedicated S3 bucket, with separate state keys for each layer:

| Environment | S3 Bucket | Network State Key | Webserver State Key |
|---|---|---|---|
| Dev | `group2-dev-bucket-terraform` | `network/terraform.tfstate` | `webservers/terraform.tfstate` |
| Staging | `group2-staging-bucket-terraform` | `network/terraform.tfstate` | `webservers/terraform.tfstate` |
| Production | `group2-prod-bucket-terraform` | `network/terraform.tfstate` | `webservers/terraform.tfstate` |

Each bucket also contains an `images/` prefix for storing static assets served by the EC2 instances.

---

## Prerequisites

### Install Terraform in Cloud9

```bash
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum install -y terraform
terraform --version
```

### Clone the Repository

```bash
git clone https://github.com/Ayush111003/aws-terraform-two-tier-webapp.git
cd aws-terraform-two-tier-webapp
```

---

## Quick Start

Deploy all environments in this exact order — **Network before Webservers, Dev before Prod**:

```bash
# Dev
cd dev/network   && terraform init && terraform apply
cd ../webservers && terraform init && terraform apply -var="my_ip=$(curl -s ifconfig.me)/32"

# Staging
cd ../../staging/network   && terraform init && terraform apply
cd ../webservers            && terraform init && terraform apply -var="my_ip=$(curl -s ifconfig.me)/32"

# Prod
cd ../../prod/network    && terraform init && terraform apply
cd ../webservers         && terraform init && terraform apply -var="my_ip=$(curl -s ifconfig.me)/32"
```

---

## Terraform Code

### modules/network/main.tf

```hcl
locals {
  name = "${var.project_name}${var.environment}"
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${local.name}Vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.name}Igw"
  }
}

resource "aws_subnet" "public" {
  count                   = length(var.public_subnets)
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name}PublicSubnet${count.index + 1}"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.private_subnets)
  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name = "${local.name}PrivateSubnet${count.index + 1}"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${local.name}NatEip"
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  depends_on = [aws_internet_gateway.this]

  tags = {
    Name = "${local.name}NatGw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${local.name}PublicRt"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = {
    Name = "${local.name}PrivateRt"
  }
}

resource "aws_route_table_association" "public_assoc" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private_assoc" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
```

---

### modules/network/variables.tf

```hcl
variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "azs" {
  type = list(string)
}
```

---

### modules/network/output.tf

```hcl
output "vpc_id" {
  value = aws_vpc.this.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}
```

---

### dev/network/config.tf

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "group2-dev-bucket-terraform"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}
```

> Staging uses `group2-staging-bucket-terraform` and Prod uses `group2-prod-bucket-terraform`.

---

### dev/network/main.tf

```hcl
module "network" {
  source          = "../../modules/network"
  project_name    = var.project_name
  environment     = var.environment
  vpc_cidr        = var.vpc_cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets
  azs             = var.azs
}
```

---

### dev/network/variables.tf

```hcl
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "Group2"
}

variable "environment" {
  type    = string
  default = "Dev"
}

variable "vpc_cidr" {
  type    = string
  default = "10.100.0.0/16"
}

variable "public_subnets" {
  type = list(string)
  default = [
    "10.100.1.0/24",
    "10.100.2.0/24",
    "10.100.3.0/24"
  ]
}

variable "private_subnets" {
  type = list(string)
  default = [
    "10.100.11.0/24",
    "10.100.12.0/24",
    "10.100.13.0/24"
  ]
}

variable "azs" {
  type = list(string)
  default = [
    "us-east-1b",
    "us-east-1c",
    "us-east-1d"
  ]
}
```

> Staging defaults: `vpc_cidr = "10.200.0.0/16"`, `environment = "Staging"` · Prod: `vpc_cidr = "10.250.0.0/16"`, `environment = "Prod"`

---

### dev/webservers/config.tf

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "group2-dev-bucket-terraform"
    key    = "webservers/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = "group2-dev-bucket-terraform"
    key    = "network/terraform.tfstate"
    region = "us-east-1"
  }
}
```

---

### dev/webservers/main.tf

```hcl
locals {
  name               = "${var.project_name}${var.environment}"
  vpc_id             = data.terraform_remote_state.network.outputs.vpc_id
  public_subnet_ids  = data.terraform_remote_state.network.outputs.public_subnet_ids
  private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# ── Security Groups ────────────────────────────────────────────────────────────

resource "aws_security_group" "alb_sg" {
  name   = "${local.name}AlbSg"
  vpc_id = local.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}AlbSg" }
}

resource "aws_security_group" "bastion_sg" {
  name   = "${local.name}BastionSg"
  vpc_id = local.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}BastionSg" }
}

resource "aws_security_group" "web_sg" {
  name   = "${local.name}WebSg"
  vpc_id = local.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${local.name}WebSg" }
}

# ── Bastion Host ───────────────────────────────────────────────────────────────

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = local.public_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = var.instance_profile_name
  key_name                    = var.key_name

  tags = { Name = "${local.name}Bastion" }
}

# ── Application Load Balancer ──────────────────────────────────────────────────

resource "aws_lb" "alb" {
  name               = lower("${var.project_name}-${var.environment}-alb")
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = local.public_subnet_ids

  tags = { Name = "${local.name}Alb" }
}

resource "aws_lb_target_group" "tg" {
  name     = lower("${var.project_name}-${var.environment}-tg")
  port     = 80
  protocol = "HTTP"
  vpc_id   = local.vpc_id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = { Name = "${local.name}Tg" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# ── Launch Template + Auto Scaling Group ──────────────────────────────────────

resource "aws_launch_template" "web_lt" {
  name_prefix   = "${local.name}Lt-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    name = var.instance_profile_name
  }

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  user_data = base64encode(templatefile("${path.module}/install_httpd.tpl", {
    bucket_name = var.bucket_name
    environment = var.environment
  }))

  tag_specifications {
    resource_type = "instance"
    tags = { Name = "${local.name}Web" }
  }
}

resource "aws_autoscaling_group" "asg" {
  name                = "${local.name}Asg"
  desired_capacity    = var.desired_capacity
  min_size            = var.min_size
  max_size            = var.max_size
  vpc_zone_identifier = local.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.tg.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${local.name}Web"
    propagate_at_launch = true
  }
}

# ── Auto Scaling Policies ──────────────────────────────────────────────────────

resource "aws_autoscaling_policy" "scale_out" {
  name                   = "${local.name}ScaleOut"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 120
}

resource "aws_autoscaling_policy" "scale_in" {
  name                   = "${local.name}ScaleIn"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 120
}

# ── CloudWatch Alarms ──────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${local.name}HighCpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 10
  alarm_actions       = [aws_autoscaling_policy.scale_out.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${local.name}LowCpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 5
  alarm_actions       = [aws_autoscaling_policy.scale_in.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
}
```

---

### dev/webservers/variables.tf

```hcl
variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project_name" {
  type    = string
  default = "Group2"
}

variable "environment" {
  type    = string
  default = "Dev"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"   # staging: t3.small | prod: t3.medium
}

variable "desired_capacity" {
  type    = number
  default = 2            # staging: 3 | prod: 3
}

variable "min_size" {
  type    = number
  default = 1
}

variable "max_size" {
  type    = number
  default = 4            # prod: 6
}

variable "bucket_name" {
  type    = string
  default = "group2-dev-bucket-terraform"
}

variable "my_ip" {
  type        = string
  description = "Your public IP in CIDR format, e.g. 203.0.113.5/32"
}

variable "instance_profile_name" {
  type    = string
  default = "LabInstanceProfile"
}

variable "key_name" {
  type    = string
  default = "vockey"
}
```

---

### dev/webservers/output.tf

```hcl
output "alb_dns_name" {
  value       = aws_lb.alb.dns_name
  description = "Open this URL in your browser to test the Dev environment"
}

output "bastion_public_ip" {
  value       = aws_instance.bastion.public_ip
  description = "SSH to bastion: ssh -i vockey.pem ec2-user@<this_ip>"
}

output "asg_name" {
  value = aws_autoscaling_group.asg.name
}
```

---

### install_httpd.tpl

This template runs on every EC2 instance at launch via `user_data`. It installs Apache, pulls images from S3, retrieves instance metadata, and generates a dynamic HTML page.

```bash
#!/bin/bash
dnf update -y
dnf install -y httpd awscli

mkdir -p /var/www/html/images
aws s3 cp s3://${bucket_name}/images/ /var/www/html/images/ --recursive

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" -s)

INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s \
  http://169.254.169.254/latest/meta-data/instance-id)

HOSTNAME=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s \
  http://169.254.169.254/latest/meta-data/local-hostname)

AZ=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)

IMAGE_FILE=$(ls /var/www/html/images/ 2>/dev/null | head -1)

if [ "${environment}" = "Prod" ]; then
  BADGE_COLOR="#c0392b"
  BANNER_COLOR="#922b21"
elif [ "${environment}" = "Staging" ]; then
  BADGE_COLOR="#d68910"
  BANNER_COLOR="#b7770d"
else
  BADGE_COLOR="#1e8449"
  BANNER_COLOR="#196f3d"
fi

cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>ACS730 | ${environment}</title>
  ...
  <!-- Dynamic page showing Instance ID, Hostname, AZ, Environment -->
  <!-- Image loaded from S3 bucket -->
</head>
<body>
  ...
</body>
</html>
EOF

systemctl enable httpd
systemctl start httpd
```

Refreshing the ALB DNS shows different **Instance IDs** across requests — confirming load balancing is working correctly across all AZs.

---

## Load Balancing and Auto Scaling

The ALB is internet-facing, listens on port 80, and routes traffic to EC2 instances in private subnets across 3 AZs. Health checks run every 30 seconds — unhealthy instances are replaced automatically.

| Metric | Condition | Action | Cooldown |
|---|---|---|---|
| CPU Utilization | > 10% | Scale Out (+1) | 120s |
| CPU Utilization | < 5% | Scale In (-1) | 120s |

---

## Security Implementation

| Component | Implementation |
|---|---|
| EC2 Instances | Private subnets only — no public IPs |
| SSH Access | Only via Bastion host, restricted to `var.my_ip` |
| ALB Security Group | Allows port 80 from `0.0.0.0/0` |
| Web Security Group | Allows port 80 from ALB SG only; port 22 from Bastion SG only |
| Bastion Security Group | Allows port 22 from your IP only |
| IAM | EC2 uses `LabInstanceProfile` — no hardcoded credentials |
| S3 | Private bucket — access via IAM role only |
| Terraform State | Per-environment S3 buckets with isolated state keys |

---

## GitHub Actions — CI/CD Pipeline

Defined in `.github/workflows/security-scan.yml`.

**Triggers:**
- Every push to the `staging` branch
- Every pull request targeting the `prod` branch

**Pipeline jobs:**

```yaml
jobs:
  terraform-checks:
    strategy:
      matrix:
        environment: [dev, staging, prod]
    steps:
      - terraform fmt --check
      - terraform init -backend=false -no-color
      - terraform validate -no-color
      - uses: terraform-linters/setup-tflint@v4
      - tflint --init && tflint

  trivy-scan:
    steps:
      - uses: aquasecurity/trivy-action@0.35.0
        with:
          scan-type: fs
          scan-ref: .
          format: table
          exit-code: '1'
          severity: CRITICAL,HIGH
```

**Trigger manually:**

```bash
git checkout staging
git merge main
git push origin staging
```

All 4 checks (fmt, validate, TFLint, Trivy) must pass before merging to `prod`.

---

## Infrastructure Cleanup

> **Warning:** Always destroy **Webservers before Network**. Always destroy **Prod → Staging → Dev**.
> NAT Gateway charges per hour — destroy immediately after testing.

```bash
# Prod
cd prod/webservers  && terraform destroy -var="my_ip=YOUR_IP/32"
cd ../network       && terraform destroy

# Staging
cd ../../staging/webservers  && terraform destroy -var="my_ip=YOUR_IP/32"
cd ../network                && terraform destroy

# Dev
cd ../../dev/webservers  && terraform destroy -var="my_ip=YOUR_IP/32"
cd ../network            && terraform destroy
```

---

## Challenges and Solutions

| Challenge | Solution |
|---|---|
| Key pair not found (`InvalidKeyPair.NotFound`) | Ensured `vockey` key pair exists in AWS and matched the Terraform variable |
| SSH connectivity between instances | Fixed security group rules to allow port 22 from Bastion SG; used private IPs |
| `user_data` changes not reflecting | Terminated instances to force recreation — `user_data` only runs at launch |
| IAM restrictions (AWS Academy) | Used existing `LabRole` / `LabInstanceProfile` instead of creating new users |
| Destroy dependency errors | Followed correct order: webservers → network, prod → staging → dev |

---

## Key Learnings

- Designing multi-environment Terraform infrastructure with reusable modules
- AWS networking fundamentals — VPC, subnets, IGW, NAT Gateway, route tables
- Application Load Balancer and Auto Scaling Group integration with CloudWatch alarms
- Secure infrastructure design using IAM roles, private subnets, and layered security groups
- Remote state management with S3 backends and `terraform_remote_state` data sources
- CI/CD pipeline integration with GitHub Actions, TFLint, and Trivy security scanning
- Full infrastructure lifecycle management — from `terraform init` to `terraform destroy`

---

## Conclusion

This project demonstrates a complete AWS cloud infrastructure deployment using Terraform, covering architecture design, automation, security, scalability, and lifecycle management. The modular approach, remote state isolation, and CI/CD integration reflect production-grade DevOps and cloud engineering practices.
