    # STEP 6 | Add Active Directory and DNS
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    Import-Module ASDSDeployment
    