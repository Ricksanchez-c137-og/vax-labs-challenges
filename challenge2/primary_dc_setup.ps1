param (
    [Parameter(Mandatory=$true)]
    [string]$DomainName,
    
    [Parameter(Mandatory=$true)]
    [string]$NetbiosName
)

# Configure error handling
$ErrorActionPreference = "Stop"
Start-Transcript -Path C:\setup_log.txt -Append

function Write-Log {
    param(
        [string]$Message,
        [string]$Status = "Info"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] [$Status] $Message"
    Add-Content -Path C:\setup_log.txt -Value "[$timestamp] [$Status] $Message"
}

try {
    Write-Log "Starting Primary Domain Controller setup for domain: $DomainName"
    
    # Install necessary Windows features
    Write-Log "Installing AD DS and DNS features..."
    Install-WindowsFeature -Name AD-Domain-Services, DNS -IncludeManagementTools
    
    # Configure networking for static IP
    Write-Log "Configuring network settings..."
    $netAdapter = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
    $currentIP = (Get-NetIPAddress -InterfaceIndex $netAdapter.ifIndex -AddressFamily IPv4).IPAddress
    $currentPrefix = (Get-NetIPAddress -InterfaceIndex $netAdapter.ifIndex -AddressFamily IPv4).PrefixLength
    $gateway = (Get-NetRoute -InterfaceIndex $netAdapter.ifIndex -DestinationPrefix "0.0.0.0/0").NextHop
    
    # Remove DHCP and set static IP
    Remove-NetIPAddress -InterfaceIndex $netAdapter.ifIndex -AddressFamily IPv4 -Confirm:$false
    New-NetIPAddress -InterfaceIndex $netAdapter.ifIndex -AddressFamily IPv4 -IPAddress $currentIP -PrefixLength $currentPrefix -DefaultGateway $gateway
    
    # Set DNS to point to itself (loopback)
    Set-DnsClientServerAddress -InterfaceIndex $netAdapter.ifIndex -ServerAddresses "127.0.0.1"
    
    # Create a new AD forest
    Write-Log "Creating new Active Directory forest: $DomainName"
    $securePassword = ConvertTo-SecureString "P@ssw0rd1234!" -AsPlainText -Force
    
    Install-ADDSForest `
        -CreateDnsDelegation:$false `
        -DatabasePath "C:\Windows\NTDS" `
        -DomainMode "WinThreshold" `
        -DomainName $DomainName `
        -DomainNetbiosName $NetbiosName `
        -ForestMode "WinThreshold" `
        -InstallDns:$true `
        -LogPath "C:\Windows\NTDS" `
        -NoRebootOnCompletion:$false `
        -SysvolPath "C:\Windows\SYSVOL" `
        -SafeModeAdministratorPassword $securePassword `
        -Force:$true
        
    # The computer will restart automatically after AD DS installation
    
} catch {
    Write-Log "An error occurred during setup: $_" -Status "Error"
    throw
}