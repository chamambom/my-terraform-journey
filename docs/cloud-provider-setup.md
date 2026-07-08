---
title: Cloud Provider Setup
nav_order: 7
---

# Cloud Provider Setup — Azure & AWS with Terraform

This page covers the setup and bootstrapping of Terraform for both Azure and AWS, including remote backend configuration, credential management, and provisioning workflows.

---

## Terraform Terminology

Remember these four bullet points!

    - Providers represent a cloud provider or a local provider
    - Resources can be invoked to create/update infrastructure locally or in the cloud
    - State is representation of the infrastructure created/updated by Terraform
    - Data Sources are "read-only" resources

There are 5 main commands within Terraform

    - Terraform Init:- Allows you to initialise a terraform working directory
    - Terraform Plan:- Generates an shows an execution plan
    - Terraform Apply:- Builds or changes infrastructure
    - Terraform Output:- Read an output from state file
    - Terraform Destroy:- Destroy Terraforms infrastructure

---

## Remote Backend State with Terraform and Azure blob and AWS S3 Storage

Developing Infrastructure code as a single developer result in the tfstate file being created and maintained on the local development computer. This is fine for a team of one, but having multiple versions of a state file can become an issue as more people join the team. I will show how to use a remote backend state on Azure Storage to host shared state files.

How do we address potential issues when working in a team to deploy infrastructure as code? We use a centralized state file that everyone has access to.

There are two steps to follow:

> we need to create a storage account.
> we configure the main.tf to use the remote state location.

NB - I will not be using Terraform to create the storage account. Terraform could be used, it will work the same. The remote state is stateful, meaning the data needs to persist through the lifecycle of the code. We can't simply delete and recreate the storage account without removing the state file. Because of that, in this example i will use powershell.

---

## Azure Setup

Test secure **Azure** provisioning using **Terraform**, utilising a [Remote Backend](https://www.terraform.io/docs/backends/types/azurerm.html) and a [Key Vault](https://azure.microsoft.com/en-gb/services/key-vault/) in Azure.

Terraform needs rights to access the storage account when running the terraform init, plan, and apply commands. We will use the storage account key for this. We could add the key to the main.tf file, but that would go against best practices of keeping security strings out of code. We will host the Storage Account key in Azure Key Vault.

### Prerequisites

1. [Install the Azure PowerShell module](https://docs.microsoft.com/en-us/powershell/azure/install-az-ps)
1. Ensure you are logged in to Azure (eg. `Connect-AzAccount`)

### Configure Azure for Secure Terraform Access

1. Open `azure-scripts\ConfigureAzureForSecureTerraformAccess.ps1` and update the `$adminUserDisplayName` variable to match your Admin User Display Name.
1. Run `azure-scripts\ConfigureAzureForSecureTerraformAccess.ps1`

The script does the following:

1. Creates an Azure Service Principle for Terraform.
1. Creates a new Resource Group.
1. Creates a new Storage Account.
1. Creates a new Storage Container.
1. Creates a new Key Vault.
1. Configures Key Vault Access Policies.
1. Creates Key Vault Secrets for these sensitive Terraform login details:
     - ARM_SUBSCRIPTION_ID
     - ARM_CLIENT_ID
     - ARM_CLIENT_SECRET
     - ARM_TENANT_ID
     - ARM_ACCESS_KEY

### Load Azure Key Vault secrets into Terraform environment variables

Now that Azure has been configured for secure Terraform access, the Key Vault secrets need to be loaded into environment variables, but only for the current PowerShell session.

1. Run `azure-scripts\LoadAzureTerraformSecretsToEnvVars.ps1`

### Install Terraform

Either [download Terraform and add to your path](https://learn.hashicorp.com/terraform/getting-started/install.html), or use the Chocolatey method below:

1. [Install Chocolatey](https://chocolatey.org/docs/installation)
1. Install Terraform: `choco install terraform`

### Provisioning

Now that Terraform is installed, the secure remote backend can be utilised whilst provisioning an Azure Resource Group and a Virtual Network:

1. Navigate to the `azure-examples\remote-backend\` folder.
1. Open `main.tf` and ensure you have updated the `storage_account_name` variable in the `backend` code block, to the new Storage Account Name created by the `ConfigureAzureForSecureTerraformAccess.ps1` script.
1. Initialise the Remote Backend and download plugins: `terraform init`
1. Create an execution plan (see planned changes): `terraform plan`
1. Apply the Terraform configuration: `terraform apply`
1. Enter `yes` to confirm the planned actions.

### Cleanup

You should now have a new Azure Resource Group (eg: `backend-test-rg`) with a Virtual Network (eg: `test-vnet`). To cleanup these Azure resources, you can also use Terraform to destroy what it created.

1. If this is a new PowerShell session, you will have to run `scripts\LoadAzureTerraformSecretsToEnvVars.ps1` again to reload the environment variables needed to Terraform to access Azure.
1. Navigate to the `azure-examples\remote-backend\` folder.
1. Remove the previously created Azure resources: `terraform destroy`
1. Enter `yes` to confirm the planned actions.

---

## AWS Setup

### Prerequisites

1. [Install the AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
1. Ensure you are logged in to AWS (eg. using AWS SSO via Granted, or access key + secret key)

### Configure AWS for Secure Terraform Access

I mostly using the AWS secret and access environmental variables. I will adapt this part to incorporate AWS secrets manager.

```hcl
provider "aws" {
    region     = "us-west-2"
    access_key = "my-access-key"
    secret_key = "my-secret-key"
}
```

---

## Code Examples

| Provider | Path | Description |
|---|---|---|
| Azure | [AZURE-Terraform/](../AZURE-Terraform/) | Hub-and-spoke, vWAN, utility snippets, Azure DevOps integration |
| AWS | [AWS-Terraform/](../AWS-Terraform/) | ASG/LB patterns, remote backend examples |
