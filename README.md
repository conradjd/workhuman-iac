# Web Application Infrastructure Deployment

This repository contains the infrastructure code to deploy a web application stack using AWS services like EC2, Load Balancer, and Auto Scaling Group. This application can be accessed by hitting the DNS of the load balancer: [http://app-load-balancer-490116055.us-east-1.elb.amazonaws.com](http://app-load-balancer-490116055.us-east-1.elb.amazonaws.com)

## Overview

The project deploys the following infrastructure components:

- **AWS VPC**: A virtual private network to host the resources.
- **Public and Private Subnets**: For better separation of public and internal resources.
- **EC2 Instances**: For hosting both the web and database services.
- **Application Load Balancer (ALB)**: To route traffic between web instances.
- **Auto Scaling Group (ASG)**: Ensures high availability by scaling the web server instances based on load.
- **Security Groups**: To control access to the servers.
- **Route Tables & Internet Gateway**: To enable internet access for your EC2 instances.

### The app is deployed in the **US-East-1** region with the following architecture:

- **Web Servers**: Two web servers behind an application load balancer to handle HTTP requests.
- **Database Server**: A separate EC2 instance running the database, accessible only from the web servers.

## Accessing the Application

You can access the application by hitting the DNS of the load balancer at [http://app-load-balancer-490116055.us-east-1.elb.amazonaws.com](http://app-load-balancer-490116055.us-east-1.elb.amazonaws.com)

Alternatively, you can also access the application hosted on the web servers via the following IPs:

- **Web Server 1**: `44.195.36.85`
- **Web Server 2**: `3.91.174.137`

Simply open your browser and navigate to one of these IPs:

- **Web Server 1**: [http://44.195.36.85](http://44.195.36.85)
- **Web Server 2**: [http://3.91.174.137](http://3.91.174.137)

These servers will be load balanced through an AWS Application Load Balancer, so you can hit either IP to access the application.

## Getting Started

### Prerequisites

Ensure you have the following tools installed on your local machine:

- [Terraform](https://www.terraform.io/downloads.html) for managing infrastructure as code.
- [AWS CLI](https://aws.amazon.com/cli/) for managing AWS services.
- [Ansible](https://www.ansible.com/) for automating configuration management.

### Configuration

1. Clone this repository:

   ```bash
   git clone [<repo_url>](https://github.com/conradjd/workhuman-iac)
   cd workhuman-iac

2. Set up AWS credentials for Terraform and AWS CLI. If you haven't already, follow the guide on Configuring AWS CLI.

3. Define the key pair for your EC2 instances. Ensure you have an existing SSH key pair in AWS EC2, or create a new one via the AWS console. Provide the key name in terraform.tfvars:

**key_name = "your-key-pair-name"**

4. Adjust any other settings in the terraform.tfvars file, such as region or allowed IPs.


## Running Terraform

To deploy the infrastructure, run the following Terraform commands:

1. Initialize Terraform:

``terraform init``

2. Review the Terraform plan:

``terraform plan``

3. Apply the Terraform configuration:

``terraform apply``

This will provision the infrastructure as described in the main.tf file.


## Configuring with Ansible

You can automate the configuration of your instances using Ansible. The Ansible inventory file (inventory.yml) should list the public IPs of your instances.

```
all:
  children:
    web:
      hosts:
        webserver1:
          ansible_host: 44.195.36.85
          ansible_ssh_private_key_file: /path/to/your-private-key.pem
          ansible_user: ec2-user
        webserver2:
          ansible_host: 3.91.174.137
          ansible_ssh_private_key_file: /path/to/your-private-key.pem
          ansible_user: ec2-user
    db:
      hosts:
        dbserver:
          ansible_host: 3.87.215.65  # Replace with DB server IP
          ansible_ssh_private_key_file: /path/to/your-private-key.pem
          ansible_user: ec2-user
```

Then, run your playbook:
``` ansible-playbook -i inventory.yml your-playbook.yml ```

## Tearing Down the Infrastructure

To destroy the infrastructure when done:

``` terraform destroy ```
