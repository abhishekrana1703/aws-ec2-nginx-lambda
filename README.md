# 🚀 Automated AWS Infrastructure with Terraform: EC2 + Lambda + NGINX

This project automates AWS resource provisioning and lifecycle management using **Terraform** and **AWS CLI**. It provisions a complete environment including:

- A public **VPC**, subnet, internet gateway, route table, and security group
- An **EC2** instance running an **NGINX** web server accessible via the internet
- A local **SSH key pair** for EC2 login
- Two **AWS Lambda** functions to automatically start and stop the EC2 instance daily
- **Amazon EventBridge** rules to trigger the Lambda functions

---

## 🧱 Architecture

