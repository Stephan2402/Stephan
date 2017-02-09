<# 
    .SYNOPSIS 
    This script creates a new Exchange 2016 lab environment in Microsoft Azure.

    Thomas Stensitzki 

    THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE  
    RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER. 

    Version 1.0, 2017-xx-xx

    Please send ideas, comments and suggestions to support@granikos.eu 

    .LINK 
    More information can be found at http://scripts.granikos.eu

    .LINK
    Github: https://github.com/Apoc70/AzureLabs

    .DESCRIPTION 
    The script creates a new Exchange lab envrionment in Microsoft Azure.

    The systems creates are:
    - Windows Server 2016 domain controller (AD DS)
    - Exchange Server 2016
    
    .NOTES 
    Requirements 
    - AzureRM PowerShell module, http://www.thomasmaurer.ch/2016/05/how-to-install-the-azure-powershell-module/ 
    - Azure Subscription, https://azure.microsoft.com/de-de/free/ 
    - Windows Server 2012 R2  
    - 
    
    Revision History 
    -------------------------------------------------------------------------------- 
    1.0      Initial release 

    This PowerShell script has been developed using ISESteroids - www.powertheshell.com 

    .PARAMETER UseConfigurationFile
    Switch to use a local Xml configuration file, default = Settings.Xml

    .PARAMETER ConfigurationFile
    Use a Xml based configuration file to create the Exchange environment.

    .PARAMETER 

    .EXAMPLE
    Create an Exchange lab environment using the local default configuration file and the 'My Exchange Lab' setup
    
    .\New-ExchangeLab.ps1 -UseConfigurationFile -LabName 'My Exchange Lab' 

#>
[CmdletBinding()]
Param(
  [switch]$UseConfigurationFile,
  [string]$ConfigurationFile = 'Settings.xml',
  [string]$LabName = 'Exchange Base Lab'
)

# Check if AzureRM PowerShell module is present first
if(Get-Module -ListAvailable -Name AzureRM) {
  Import-Module -Name AzureRM
} 
else {
  Write-Error 'AzureRM PowerShell module not found. Install the module using Install-Module AzureRM.'
  Exit 99
}

# Define some script variables
$script:ProcessSteps = 8

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path


# FUNCTIONS ######################################################################

<#
    Helper function to update progress bar
#>
Function Update-ProgressBar {
  [CmdletBinding()]
  param(
    $Activity='',
    $Status='',
    $Step=1
    )

  Write-Progress -Id 1 -Activity $Activity -Status $Status -PercentComplete ((1/$script:ProcessSteps*$Step*100))
}

<#
    FUnction to connect to AzureRM 
#>
Function Connect-ToAzureRm {
  [CmdletBinding()]
  param( )


  try {
    # Enhancement needed https://github.com/Apoc70/AzureLabs/issues/1 
    
    # Fetch user credentials for Azure access
    # $AzureCredentials = Get-Credential -Message 'Provide your Azure login credentials'
    
    Add-AzureRmAccount # -Credential $AzureCredentials -SubscriptionId $script:AzureSubscriptionId -TenantId $script:AzureTenantId
    
    Update-ProgressBar -Activity 'Connecting to Azure' -Status 'Setting Azure Resource Manager Context' -Step 1
    
    # Set context
    Set-AzureRmContext -SubscriptionId $script:AzureSubscriptionId -TenantId $script:AzureTenantId
    
  }
  catch {
    Throw 'Some error occured connecting to your AzureRM subscription'
  }
  
  return $true
}


# MAIN ###########################################################################

# Using a configuration file?
if($UseConfigurationFile) {

  if(Test-Path -Path $(Join-Path -Path $scriptPath -ChildPath $ConfigurationFile)) {
  
    try {
      # Load Script settings file
      [xml]$Config = [xml](Get-Content -Path "$(Join-Path -Path $scriptPath -ChildPath $ConfigurationFile)")
    }
    catch {
      Write-Output 'Could not read settings file. Please check for valid Xml!'
      Throw $_.Exception.Message
    }

    # Fetch Azure configuration settings    
    $script:AzureSubscriptionId = $Config.Settings.Azure.SubscriptionId
    $script:AzureTenantId = $Config.Settings.Azure.TenantId
    
    # Fetch lab settings    
    if($LabName -ne '') {
      $LabConfiguration = $Config.Settings.Labs.Lab|Where-Object{$_.Name -eq $LabName}
    }
    else {
      # We need to have a lab name, please.
      
      Write-Output 'No lab configuration was selected.'
      Exit 98
    }
    
  }
  else {
    # Ooops, the configuration file could not be found
    Write-Error -Message "Settings file '$(ConfigurationFile)' missing"
    exit 99
  }
  
}

if(Connect-ToAzureRm) {
  # We are connected to AzureRm and can proceed
  
  if($LabConfiguration -ne $null) {
  
    # Resource Group
    $RGName = $LabConfiguration.ResourceGroup.Name
    $RGLocation = $LabConfiguration.ResourceGroup.Location
    $RGLocationShort = ([string]$LabConfiguration.ResourceGroup.LocationShort).ToLower()
    $RGStorageAccountName = $LabConfiguration.ResourceGroup.StorageAccountName
    $RGStorageType = $LabConfiguration.ResourceGroup.StorageType
    
    # Virtual Network
    $VNetSubnetConfig = $LabConfiguration.VirtualNetwork.SubnetConfig
    $VNetSubnetAddress = $LabConfiguration.VirtualNetwork.SubnetAddress
    $VNetName = $LabConfiguration.VirtualNetwork.Name
    $VNetAddressPrefix = $LabConfiguration.VirtualNetwork.AddressPrefix
    $VNetDNS = $LabConfiguration.VirtualNetwork.DNS
    
    # Admin User
    $AdminUsername = $LabConfiguration.Administrator.Username
    $AdminPasswordSecure = ([string]$LabConfiguration.Administrator.Password) | ConvertTo-SecureString -AsPlainText -Force
    $AdminCredentials = New-Object System.Management.Automation.PSCredential -ArgumentList $AdminUsername, $AdminPasswordSecure
    
    
    
    
    # STEP 1 | Check exisiting Resource Groups first
    Update-ProgressBar -Activity 'Provisioning Azure Resources' -Status "Querying resource group: $($RGName)" -Step 1 
      
    $CurrentResourceGroup = Get-AzureRmResourceGroup | Where-Object{$_.ResourceGroupName -eq $RGName}
    
    if($CurrentResourceGroup -ne $null) {
      Write-Output "A resource group named '$($RGName)' already exists!"
      
      # ToDo: Automatic deletion? 
      
      exit 97
    }
      
    # STEP 2 | Create new Resource Group
    
    Update-ProgressBar -Activity 'Provisioning Azure Resources' -Status "Creating resource group $($RGName)" -Step 2 
      
    $ResourceGroup = New-AzureRMResourceGroup -Name $RGName -Location $RGLocation
    
    # STEP 3 | Create Azure Storage Account
    
    Update-ProgressBar -Activity 'Provisioning Azure Resources' -Status "Creating storage account $($RGStorageAccountName)" -Step 3 
    
    $StorageAccount = New-AzureRMStorageAccount -Name $RGStorageAccountName -ResourceGroupName $RGName -Type $RGStorageType -Location $RGLocation
    
    # STEP 4 | Create Azure Virtual Network
    
    Update-ProgressBar -Activity 'Provisioning Azure Resources' -Status "Creating virtual network | Subnet $($VNetSubnetConfig)" -Step 3 
    
    # Define VNet subnet for server placement
    $exSubnet=New-AzureRMVirtualNetworkSubnetConfig -Name $VNetSubnetConfig -AddressPrefix $VNetSubnetAddress
    
    # Create new VNet 
    $VirtualNetwork = New-AzureRMVirtualNetwork -Name $VNetName -ResourceGroupName $RGName -Location $RGLocation -AddressPrefix $VNetAddressPrefix -Subnet $exSubnet -DNSServer $VNetDNS
    
    # Create Network Security rules
    $SecurityRules = New-Object 'System.Collections.Generic.List[Microsoft.Azure.Commands.Network.Models.PSSecurityRule]'
        
    foreach($Rule in $LabConfiguration.VirtualNetwork.SecurityRules.Rule) {
    
      # Build single security rule
      $RuleConfig = New-AzureRMNetworkSecurityRuleConfig -Name $Rule.Name -Description $Rule.Description -Access $Rule.Access -Protocol $Rule.Protocol -Direction $Rule.Direction -Priority $Rule.Priority -SourceAddressPrefix $Rule.SourceAddressPrefix -SourcePortRange $Rule.SourcePortRange -DestinationAddressPrefix $Rule.DestinationAddressPrefix -DestinationPortRange $Rule.DestinationPortRange   
      
      # Add NetworkSecurityRuleConfig to list
      $SecurityRules.Add($RuleConfig) 
    }
    
    # Create NetworkSecurityGroup    
    $NetworkSecurityGroup = New-AzureRMNetworkSecurityGroup -Name $VNetSubnetConfig -ResourceGroupName $RGName -Location $RGLocationShort -SecurityRules $SecurityRules
    
    $VirtualNetwork = Get-AzureRMVirtualNetwork -ResourceGroupName $RGName -Name $VNetName
    $NetworkSecurityGroup = Get-AzureRMNetworkSecurityGroup -Name $VNetSubnetConfig -ResourceGroupName $RGName
    
    Set-AzureRMVirtualNetworkSubnetConfig -VirtualNetwork $VirtualNetwork -Name $VNetSubnetConfig -AddressPrefix $VNetSubnetAddress -NetworkSecurityGroup $NetworkSecurityGroup
    
    # STEP 5 | Create servers
    
    $StorageAccount = Get-AzureRMStorageaccount | Where-Object {$_.ResourceGroupName -eq $RGName}
    

    # Create the servers
    foreach($Server in $LabConfiguration.Servers.Server) {
    
      Update-ProgressBar -Activity "Provisioning $($LabConfiguration.Servers.Server.Count) Servers" -Status "Working on server $($Server.Name)" -Step 2
      
      # Do the server stuff
      
      # Create Availability Set      
      $AvailabiliySet = New-AzureRMAvailabilitySet -Name $Server.AvailabilitySetName -ResourceGroupName $RGName -Location $RGLocation
      
      # Fetch a new public IP address
      $PublicIpAddressAllocationMethod = 'Dynamic'
      $NicName = "$($Server.Name)-NIC"
      $PublicIpAddress = New-AzureRMPublicIpAddress -Name $NicName -ResourceGroupName $RGName -Location $RGLocation -AllocationMethod $PublicIpAddressAllocationMethod
      
      $NetworkInterface = New-AzureRMNetworkInterface -Name $NicName -ResourceGroupName $RGName -Location $RGLocation -SubnetId $VirtualNetwork.Subnets[0].Id -PublicIpAddressId $PublicIpAddress.Id -PrivateIpAddress $Server.PrivateIpAddress
      
      $AvailabiliySet = Get-AzureRMAvailabilitySet -Name $Server.AvailabilitySetName -ResourceGroupName $RGName 
      
      # Create VM configuration
      $VmConfig = New-AzureRMVMConfig -VMName $Server.Name -VMSize $Server.VmSize -AvailabilitySetId $AvailabiliySet.Id
      
      # Create VHD target 
      $VhdURI = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/$($Server.Name)-$($VNetName)-ADDSDisk.vhd"
      $DataDiskName = "$($Server.Name)-$($VNetName)-Data"
      Add-AzureRMVMDataDisk -VM $VmConfig -Name $DataDiskName -DiskSizeInGB $Server.DiskSizeInGB -VhdUri $VhdURI  -CreateOption empty
      
      # Add operating system to VM configuration    
      $VmConfig = Set-AzureRMVMOperatingSystem -VM $VmConfig -Windows -ComputerName $Server.Name -Credential $AdminCredentials -ProvisionVMAgent -EnableAutoUpdate
      
      # SOurce Image
      $VmConfig = Set-AzureRMVMSourceImage -VM $VmConfig -PublisherName MicrosoftWindowsServer -Offer WindowsServer -Skus 2012-R2-Datacenter -Version "latest"
          
      $VmConfig = Add-AzureRMVMNetworkInterface -VM $VmConfig -Id $NetworkInterface.Id
      
      # Set OS disk
      $OsDiskUri = $StorageAccount.PrimaryEndpoints.Blob.ToString() + "vhds/$($Server.Name)-$($VNetName)-OSDisk.vhd"
      $OsDiskName = "$($Server.Name)-$($VNetName)-OS"
      $VmConfig = Set-AzureRMVMOSDisk -VM $VmConfig -Name $OsDiskName -VhdUri $OsDiskUri -CreateOption fromImage
      
      # Now create the VM
      New-AzureRMVM -ResourceGroupName $RGName -Location $RGLocation -VM $VmConfig
            
      
    }
  }  

}
else {
  # Whatever happend, we should provide some nice tips
}