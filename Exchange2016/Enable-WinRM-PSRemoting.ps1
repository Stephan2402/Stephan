<# 
    .SYNOPSIS 
    This script enables WinRM and PSRemoting on Azure VMs

    Stephan Verstegen 

    THIS CODE IS MADE AVAILABLE AS IS, WITHOUT WARRANTY OF ANY KIND. THE ENTIRE  
    RISK OF THE USE OR THE RESULTS FROM THE USE OF THIS CODE REMAINS WITH THE USER. 

    Version 1.0, 2017-02-13

    Please send ideas, comments and suggestions to support@granikos.eu 

    .LINK 
    More information can be found at http://blog.verstegen-online.de

    .LINK
    Github: https://github.com/

    .DESCRIPTION 
    This script enables WinRM and PSRemoting on Azure VMs.

    The script executes the following steps:
    - Create Inbound Firewall Rule for Port 5986 TCP
    - Create Self-Signed Certificate for HTTPs Connection
    - Add WinRM Listener HTTPs
    - Verify if Connection
    
    .NOTES 
    Requirements 
    - https://blogs.technet.microsoft.com/uktechnet/2016/02/11/configuring-winrm-over-https-to-enable-powershell-remoting/
    - 
    
    Revision History 
    --------------------------------------------------------------------------------
    1.0      Initial release 
   
 #>
$VmName = Hostname

#Firewall Rule on Azure VM
New-NetFirewallRule -DisplayName "WinRM_HTTPS" -Direction Inbound -Action Allow -Protocol TCP -Profile Any -LocalPort 5986

#Create Certificate
New-SelfSignedCertificate -DnsName $VMName -CertStoreLocation cert:\LocalMachine\My

#Get Certificate Thumbprint
$CertThumb = Get-ChildItem -Path "cert:/LocalMachine/my"
$CertThumb = $CertThumb.Thumbprint

#Enbale WinRM on Port 5986 for HTTPS
winrm create winrm/config/Listener?Address=*+Transport=HTTPS '@{Hostname="$VmName"; CertificateThumbprint="$CertThumb"}'

#Password to Secure String
#$pw = convertto-securestring -AsPlainText -Force -String <password>
#$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist "adm.sv",$pw

#PSSession aufbauen
#$sessionOptions = New-PSSessionOption -SkipCACheck -SkipCNCheck
#Enter-PSSession -ComputerName 52.174.23.106 -Credential $cred -UseSSL -SessionOption $sessionOptions