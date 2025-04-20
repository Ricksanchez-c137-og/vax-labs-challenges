# Secure Azure AD Lab Environment

This Terraform project deploys an Active Directory lab environment in Azure with enhanced security practices.

## Security Features

- Sensitive information is stored in environment variables or separate variable files
- Storage account access keys are kept secure
- All passwords and credentials are parameterized
- .gitignore configured to prevent accidental commit of sensitive files

## Prerequisites

1. Azure account and subscription
2. Terraform CLI installed
3. Azure CLI installed and authenticated
4. Storage account with container for scripts

## Setup Instructions

### 1. Prepare Environment Variables

```bash
# Copy the example env file
cp .env.example .env

# Edit with your secure values
nano .env  # or use your preferred editor
```

### 2. Load Environment Variables

```bash
# Load environment variables
source .env
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Deploy Infrastructure

```bash
terraform apply
```

## Configuration

The deployment is configurable through variables:

- Domain controllers: 2 VMs (DC01, DC02)
- Client machines: 3 VMs (Client1, Client2, Client3)
- Network: 1 VNet with separate subnets for DCs and clients

## Security Best Practices

1. **Never commit `.tfvars` or `.env` files to version control**
2. Rotate credentials regularly
3. Use Azure Key Vault for production environments
4. Consider using managed identities for authentication

## Script Deployment

Upload the required PowerShell scripts to your storage account:

1. `dc_setup.ps1` - Script to set up the first domain controller
2. `dc_join.ps1` - Script to join the second domain controller to the domain

## Cleanup

To destroy all resources:

```bash
terraform destroy
```