# Large Scale Active Directory Lab Environment

This Terraform project deploys a comprehensive Active Directory lab environment in Azure with a large number of domain controllers, client machines, and file servers.

## Environment Specifications

- **12 Domain Controllers**: Full Active Directory infrastructure with redundancy
- **24 Client Machines**: Windows workstations joined to the domain
- **8 File Servers**: Each with department-specific file shares
- **Complete AD Structure**: OUs, Groups, Users, and Service Accounts
- **Isolated Network**: Proper subnetting for different server roles

## Security Features

- Sensitive information stored in environment variables
- No hardcoded credentials in Terraform code
- Storage account access keys kept secure
- .gitignore configured to prevent accidental commit of sensitive files

## Prerequisites

1. Azure account and subscription
2. Terraform CLI installed
3. Azure CLI installed and authenticated
4. Storage account with a container for PowerShell scripts

## Setup Instructions

### 1. Prepare Script Storage

Upload all PowerShell scripts to your storage account:
- `setup_primary_dc.ps1`
- `setup_additional_dc.ps1`
- `setup_file_server.ps1`
- `post_deployment.ps1`

### 2. Prepare Environment Variables

```bash
# Copy the example env file
cp .env.example .env

# Edit with your secure values
nano .env  # or use your preferred editor
```

### 3. Load Environment Variables

```bash
# Load environment variables
source .env
```

### 4. Initialize Terraform

```bash
terraform init
```

### 5. Deploy Infrastructure

```bash
terraform apply
```

### 6. Post-Deployment Configuration

After deployment completes, connect to DC1 and run the post-deployment script:

```powershell
.\post_deployment.ps1 -DomainName "vaxlabs.local"
```

## Architecture Overview

The deployment creates a virtual network with three subnets:
- **Domain Controller Subnet**: Houses all 12 domain controllers
- **Client Subnet**: Contains all 24 client machines
- **File Server Subnet**: Contains all 8 file servers

Each machine type is provisioned with appropriate resources:
- DCs: Standard_B2ms (2 vCPUs, 8 GB RAM)
- Clients: Standard_B2s (2 vCPUs, 4 GB RAM)
- File Servers: Standard_B2ms (2 vCPUs, 8 GB RAM)

## Challenge Scenarios

This environment supports various security and administration challenges:

1. **Multi-Site AD Management**: Practice managing a distributed AD infrastructure
2. **Group Policy Implementation**: Create and deploy GPOs across a complex environment
3. **Permission Delegation**: Implement least-privilege access controls
4. **Site Replication**: Configure and test AD site replication
5. **Disaster Recovery**: Practice AD backup and recovery scenarios
6. **Security Hardening**: Identify and remediate security vulnerabilities
7. **User Management**: Manage a large number of users across different departments

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## Security Note

This environment is designed for learning and testing purposes. The default passwords in the example files should never be used in production environments.