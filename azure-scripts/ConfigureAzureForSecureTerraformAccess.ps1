<#
.SYNOPSIS
    Configures Azure for secure Terraform access.
.DESCRIPTION
    Configures Azure for secure Terraform access using Azure Key Vault.

    The following steps are automated:
    - Creates an Azure Service Principle for Terraform.
    - Creates a new Resource Group.
    - Creates a new Storage Account.
    - Creates a new Storage Container.
    - Creates a new Key Vault.
    - Configures Key Vault Access Policies.
    - Creates Key Vault Secrets for these sensitive Terraform login details:
        - ARM_SUBSCRIPTION_ID
        - ARM_CLIENT_ID
        - ARM_CLIENT_SECRET
        - ARM_TENANT_ID
        - ARM_ACCESS_KEY
.EXAMPLE
    Connect-AzAccount -UseDeviceAuthentication
    .\scripts\ConfigureAzureForSecureTerraformAccess.ps1 -adminUserDisplayName 'iac'

    Displays device login link, then configures secure Terraform access for admin user "iac"
.NOTES
    Assumptions:
    - Azure PowerShell module is installed: https://docs.microsoft.com/en-us/powershell/azure/install-az-ps
    - You are already logged into Azure before running this script (eg. Connect-AzAccount)
    - Use "Connect-AzAccount -UseDeviceAuthentication" if browser prompts don't work.
#>


[CmdletBinding()]
param (
    # This is used to assign yourself access to KeyVault
    $adminUserDisplayName = 'iac',
    $servicePrincipleName = 'terra-iac',
    $resourceGroupName = 'terra-iac-rg',
    $location = 'uksouth',
    $storageAccountSku = 'Standard_LRS',
    $storageContainerName = 'terra-iac-state',
    # Prepend random prefix with A character, as some resources cannot start with a number
    $randomPrefix = ("a" + -join ((48..57) + (97..122) | Get-Random -Count 8 | ForEach-Object { [char]$_ })),
    $vaultName = "$randomPrefix-terra-kv",
    $storageAccountName = "$($randomPrefix)terra"
)


#region Helper function for padded messages
function Write-HostPadded {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Message,

        [Parameter(Mandatory = $false)]
        [String]
        $ForegroundColor,

        [Parameter(Mandatory = $false)]
        [Int]
        $PadLength = 80,

        [Parameter(Mandatory = $false)]
        [Switch]
        $NoNewline
    )

    $writeHostParams = @{
        Object = $Message.PadRight($PadLength, '.')
    }

    if ($ForegroundColor) {
        $writeHostParams.Add('ForegroundColor', $ForegroundColor)
    }

    if ($NoNewline.IsPresent) {
        $writeHostParams.Add('NoNewline', $true)
    }

    Write-Host @writeHostParams
}
#endregion Helper function for padded messages


#region Check Azure login
Write-HostPadded -Message "Checking for an active Azure login..." -NoNewline

# Get current context
$azContext = Get-AzContext

if (-not $azContext) {
    Write-Host "ERROR!" -ForegroundColor 'Red'
    throw "There is no active login for Azure. Please login first (eg 'Connect-AzAccount'"
}
Write-Host "SUCCESS!" -ForegroundColor 'Green'
#endregion Check Azure login


#region Service Principle
Write-HostPadded -Message "Checking for an active Service Principle: [$servicePrincipleName]..." -NoNewline

# Get current context
$terraformSP = Get-AzADServicePrincipal -DisplayName $servicePrincipleName
Write-Host "SUCCESS!" -ForegroundColor 'Green'

if (-not $terraformSP) {
    Write-HostPadded -Message "Creating a Terraform Service Principle: [$servicePrincipleName] ..." -NoNewline
    try {
        $terraformSP = New-AzADServicePrincipal -DisplayName $servicePrincipleName -ErrorAction 'Stop'
        $servicePrinciplePassword=$terraformSP.PasswordCredentials.SecretText

        #$servicePrinciplePassword = [pscredential]::new($servicePrincipleName, $terraformSP.SecretText).GetNetworkCredential().Password
    } catch {
        Write-Host "ERROR!" -ForegroundColor 'Red'
        throw $_
    }
    Write-Host "SUCCESS!" -ForegroundColor 'Green'

} else {
    # Service Principle exists so renew password (as cannot retrieve current one-off password)
    $newSpCredential = $terraformSP | New-AzADSpCredential
    $servicePrinciplePassword=$newSpCredential.PasswordCredentials.SecretText
}
#endregion Service Principle


#region Get Subscription
$taskMessage = "Finding Subscription and Tenant details"
Write-HostPadded -Message "`n$taskMessage..." -NoNewline
try {
    $subscription = Get-AzSubscription -ErrorAction 'Stop'
} catch {
    Write-Host "ERROR!" -ForegroundColor 'Red'
    throw $_
}
Write-Host "SUCCESS!" -ForegroundColor 'Green'
#endregion Get Subscription


#region New Resource Group
$taskMessage = "Creating Terraform Management Resource Group: [$resourceGroupName]"
Write-HostPadded -Message "`n$taskMessage..." -NoNewline
try {
    $azResourceGroupParams = @{
        Name        = $resourceGroupName
        Location    = $location
        Tag         = @{ keep = "true" }
        Force       = $true
        ErrorAction = 'Stop'
        Verbose     = $VerbosePreference
    }
    New-AzResourceGroup @azResourceGroupParams | Out-String | Write-Verbose
} catch {
    Write-Host "ERROR!" -ForegroundColor 'Red'
    throw $_
}
Write-Host "SUCCESS!" -ForegroundColor 'Green'
#endregion New Resource Group


#region New Storage Account
$taskMessage = "Creating Terraform backend Storage Account: [$storageAccountName]"
Write-HostPadded -Message "`n$taskMessage..." -NoNewline
try {
    $azStorageAccountParams = @{
        ResourceGroupName = $resourceGroupName
        Location          = $location
        Name              = $storageAccountName
        SkuName           = $storageAccountSku
        Kind              = 'StorageV2'
        ErrorAction       = 'Stop'
        Verbose           = $VerbosePreference
    }
    New-AzStorageAccount @azStorageAccountParams | Out-String | Write-Verbose
} catch {
    Write-Host "ERROR!" -ForegroundColor 'Red'
    throw $_
}
Write-Host "SUCCESS!" -ForegroundColor 'Green'
#endregion New Storage Account


#region Select Storage Container
$taskMessage = "Selecting Default Storage Account"
Write-HostPadded -Message "`n$taskMessage..." -NoNewline
try {
    $azCurrentStorageAccountParams = @{
        ResourceGroupName = $resourceGroupName
        AccountName       = $storageAccountName
        ErrorAction       = 'Stop'
        Verbose           = $VerbosePreference
    }
    Set-AzCurrentStorageAccount @azCurrentStorageAccountParams | Out-String | Write-Verbose
} catch {
    Write-Host "ERROR!" -ForegroundColor 'Red'
    throw $_
}
Write-Host "SUCCESS!" -ForegroundColor 'Green'
#endregion Select Storage Account


#region New Storage Container
$taskMessage = "Creating Terraform State Storage Container: [$storageContainerName]"
Write-HostPadded -Message "`n$taskMessage..." -NoNewline
try {
    $azStorageContainerParams = @{
        Name        = $storageContainerName
        Permission  = 'Off'
        ErrorAction = 'Stop'
        Verbose     = $VerbosePreference
    }
    New-AzStorageContainer @azStorageContainerParams | Out-String | Write-Verbose
} catch {
    Write-Host "ERROR!" -ForegroundColor 'Red'
    throw $_
}
Write-Host "SUCCESS!" -ForegroundColor 'Green'
#endregion New Storage Container


#region New KeyVault
$taskMessage = "Creating Terraform KeyVault: [$vaultName]"
Write-HostPadded -Message "`n$taskMessage..." -NoNewline
try {

    Register-AzResourceProvider -ProviderNamespace "Microsoft.KeyVault"

    $azKeyVaultParams = @{
        VaultName         = $vaultName
        ResourceGroupName = $resourceGroupName
        Location          = $location
        ErrorAction       = 'Stop'
        Verbose           = $VerbosePreference
    }
    New-AzKeyVault @azKeyVaultParams | Out-String | Write-Verbose
} catch {
    Write-Host "ERROR!" -ForegroundColor 'Red'
    throw $_
}
Write-Host "SUCCESS!" -ForegroundColor 'Green'
#endregion New KeyVault


#region Set KeyVault Access Policy
$taskMessage = "Setting KeyVault Access Policy for Admin User: [$adminUserDisplayName]"
Write-HostPadded -Message "`n$taskMessage..." -NoNewline
$adminADUser = Get-AzADUser -DisplayName $adminUserDisplayName
try {
    $azKeyVaultAccessPolicyParams = @{
        VaultName                 = $vaultName
        ResourceGroupName         = $resourceGroupName
        ObjectId                  = $adminADUser.Id
        PermissionsToKeys         = @('Get', 'List')
        PermissionsToSecrets      = @('Get', 'List', 'Set')
        PermissionsToCertificates = @('Get', 'List')
        ErrorAction               = 'Stop'
        Verbose                   = $VerbosePreference
    }
    Set-AzKeyVaultAccessPolicy @azKeyVaultAccessPolicyParams | Out-String | Write-Verbose
} catch {
    Write-Host "ERROR!" -ForegroundColor 'Red'
    throw $_
}
Write-Host "SUCCESS!" -ForegroundColor 'Green'

$taskMessage = "Setting KeyVault Access Policy for Terraform SP: [$servicePrincipleName]"
Write-HostPadded -Message "`n$taskMessage..." -NoNewline
try {
    $azKeyVaultAccessPolicyParams = @{
        VaultName                 = $vaultName
        ResourceGroupName         = $resourceGroupName
        ObjectId                  = $terraformSP.Id
        PermissionsToKeys         = @('Get', 'List')
        PermissionsToSecrets      = @('Get', 'List', 'Set')
        PermissionsToCertificates = @('Get', 'List')
        ErrorAction               = 'Stop'
        Verbose                   = $VerbosePreference
    }
    Set-AzKeyVaultAccessPolicy @azKeyVaultAccessPolicyParams | Out-String | Write-Verbose
} catch {
    Write-Host "ERROR!" -ForegroundColor 'Red'
    throw $_
}
Write-Host "SUCCESS!" -ForegroundColor 'Green'
#endregion Set KeyVault Access Policy


#region Terraform login variables
# Get Storage Access Key
$storageAccessKeys = Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName
$storageAccessKey = $storageAccessKeys[0].Value # only need one of the keys

$terraformLoginVars = @{
    'ARM-SUBSCRIPTION-ID' = $subscription.Id
    'ARM-CLIENT-ID'       = $terraformSP.AppId
    'ARM-CLIENT-SECRET'   = $servicePrinciplePassword
    'ARM-TENANT-ID'       = $subscription.TenantId
    'ARM-ACCESS-KEY'      = $storageAccessKey
}
Write-Host "`nTerraform login details:"
$terraformLoginVars | Out-String | Write-Host
#endregion Terraform login variables


#region Create KeyVault Secrets
$taskMessage = "Creating KeyVault Secrets for Terraform"
Write-HostPadded -Message "`n$taskMessage..." -NoNewline
try {
    foreach ($terraformLoginVar in $terraformLoginVars.GetEnumerator()) {
        $AzKeyVaultSecretParams = @{
            VaultName   = $vaultName
            Name        = $terraformLoginVar.Key
            SecretValue = (ConvertTo-SecureString  $terraformLoginVar.Value -AsPlainText -Force)
            ErrorAction = 'Stop'
            Verbose     = $VerbosePreference
        }
        Set-AzKeyVaultSecret @AzKeyVaultSecretParams | Out-String | Write-Verbose
    }
} catch {
    Write-Host "ERROR!" -ForegroundColor 'Red'
    throw $_
}
Write-Host "SUCCESS!" -ForegroundColor 'Green'
#endregion Create KeyVault Secrets